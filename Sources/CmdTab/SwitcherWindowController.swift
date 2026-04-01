import AppKit
import SwiftUI

// MARK: - SwitcherPanel

/// Borderless NSPanel subclass that explicitly permits becoming the key window.
///
/// A plain `.borderless` NSPanel returns `false` for `canBecomeKey`, which means
/// `makeKeyAndOrderFront` has no effect and Esc (or any other key) is never
/// delivered to the panel via NSApp's event loop. Overriding here allows us to
/// call `makeKeyAndOrderFront` in *both* standalone and hotkey modes so the panel
/// reliably receives keyboard events regardless of CGEventTap availability.
///
/// Note: `.nonactivatingPanel` is still set in the style mask, so becoming key
/// does NOT activate the application — the previously-frontmost app remains the
/// active application. This is the same approach used by Spotlight and Alfred.
private final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool  { true  }
    override var canBecomeMain: Bool { false }

    /// Backup dismiss handler — fires when Esc arrives via NSApp's event loop
    /// (i.e. when CGEventTap is momentarily disabled and can't suppress the keyDown).
    var onEscapePressed: (() -> Void)?
    var onKeyEvent: ((NSEvent) -> Bool)?
    var onScrollEvent: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if onKeyEvent?(event) == true {
            return
        }
        if event.keyCode == 53 {
            onEscapePressed?()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onKeyEvent?(event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        if onScrollEvent?(event) == true {
            return
        }
        super.scrollWheel(with: event)
    }
}

private final class SwitcherBackdropPanel: NSPanel {
    override var canBecomeKey: Bool  { false }
    override var canBecomeMain: Bool { false }
}

private final class SwitcherMirrorPanel: NSPanel {
    override var canBecomeKey: Bool  { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - SwitcherWindowController

/// Hosts the SwiftUI SwitcherView inside a borderless, non-activating NSPanel.
/// The panel is pre-created at launch and simply shown/hidden to eliminate latency.
final class SwitcherWindowController {
    private let itemMutationAnimation = Animation.spring(response: 0.24, dampingFraction: 0.84)
    private let quickActionSuppressionInterval: TimeInterval = 1.4
    private let trackpadStepThreshold: CGFloat = 26
    private let trackpadResetInterval: TimeInterval = 0.18

    private struct PendingItemSuppression {
        let target: SwitcherItemSuppressionTarget
        let expiresAtUptime: TimeInterval

        func matches(_ item: SwitcherItem) -> Bool {
            target.matches(item)
        }
    }

    private struct TrackpadNavigationState {
        var horizontal: CGFloat = 0
        var vertical: CGFloat = 0
        var lastEventUptime: TimeInterval = 0

        mutating func reset() {
            horizontal = 0
            vertical = 0
            lastEventUptime = 0
        }
    }

    private var panel: SwitcherPanel!
    private var backdropPanel: SwitcherBackdropPanel!
    private let viewModel = SwitcherViewModel()
    private let appSwitcher = AppSwitcher()
    private let history = SwitcherHistoryStore.shared
    private let searchMemory = SearchMemoryStore.shared
    private let preferences = SwitcherPreferences.shared
    private var session: SwitcherCycleSession?
    /// Total number of apps available when the palette session started.
    /// Used to keep the panel height fixed while the user filters.
    private var paletteFullItemCount: Int = 0
    private var mirroredPanels: [ObjectIdentifier: SwitcherMirrorPanel] = [:]
    private var pendingItemSuppressions: [PendingItemSuppression] = []
    private var lastObservedStyle: SwitcherStyle
    private var trackpadNavigationState = TrackpadNavigationState()

    /// Most recently observed frontmost app PID from NSWorkspace. A short-lived
    /// override is layered on top after switcher commits so quick re-presses
    /// can still behave correctly before the system notification arrives.
    private var activeFrontmostPID: pid_t = 0
    private var frontmostOverride: FrontmostOverrideState?

    var isVisible: Bool { viewModel.isVisible }
    var currentStyle: SwitcherStyle { preferences.switcherStyle }

    /// Called by `handleCardClick` so HotkeyManager can clear its trigger state
    /// before the modifier-release event fires. Without this, releasing Cmd after
    /// a mouse-click commit causes a second, spurious activation.
    var onClickCommit: (() -> Void)?

    init() {
        self.lastObservedStyle = SwitcherPreferences.shared.switcherStyle
        buildPanel()
        buildBackdropPanel()
        wireDataSources()
        _ = appSwitcher.primeCacheIfNeeded()
        appSwitcher.warmCache(force: true)

        // Seed activeFrontmostPID from the OS's current frontmost app.
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.activationPolicy == .regular,
           frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            activeFrontmostPID = frontmost.processIdentifier
        }
    }

    // MARK: - Public API (called from HotkeyManager on main thread)

    func showOrAdvance(reverse: Bool = false) {
        if !viewModel.isVisible {
            guard startSession(reverse: reverse) else { return }
            showPanel()
            return
        }

        if preferences.switcherStyle == .radialMenu {
            moveSelectionInRadialMenu(by: reverse ? -1 : 1)
            return
        }

        session?.advance(reverse: reverse)
        syncViewModelSelection()
    }

    func commitTriggerSession(reverse: Bool = false) {
        guard startSession(reverse: reverse) else { return }
        commitCurrentSelection()
    }

    func showStandalone() {
        guard startSession(reverse: false) else { return }
        showPanel(makeKey: true)
    }

    func applyStyleChangeFromSettings() {
        let currentStyle = preferences.switcherStyle
        lastObservedStyle = currentStyle
        refreshPanelContentRoots()

        if viewModel.isVisible {
            refreshVisibleItemsIfNeeded()
            showPanel(makeKey: false)
        } else {
            updateBackdropPanelIfNeeded()
            tearDownMirroredPanels()
        }
    }

    func applyCurrentStyleImmediately() {
        refreshPanelContentRoots()

        if viewModel.isVisible {
            refreshVisibleItemsIfNeeded()
            showPanel(makeKey: false)
            return
        }

        guard startSession(reverse: false) else { return }
        showPanel(makeKey: false)
    }

    func moveSelection(by delta: Int) {
        if preferences.switcherStyle == .radialMenu {
            moveSelectionInRadialMenu(by: delta)
            return
        }

        session?.move(by: delta)
        syncViewModelSelection()
    }

    func moveSelectionUp() {
        session?.moveUp(columns: viewModel.layout.columns)
        syncViewModelSelection()
    }

    func moveSelectionDown() {
        session?.moveDown(columns: viewModel.layout.columns)
        syncViewModelSelection()
    }

    /// Release key → activate selected item and hide.
    func confirmAndHide() {
        commitCurrentSelection()
    }

    /// Escape → hide without activating.
    func cancelAndHide() {
        hidePanel()
    }

    func performQuickAction(_ action: SwitcherQuickAction) {
        guard viewModel.selectedIndex >= 0, viewModel.selectedIndex < viewModel.items.count else { return }
        let selectedItem = viewModel.items[viewModel.selectedIndex]
        let execution = action.execution(for: selectedItem.kind)
        guard appSwitcher.performQuickAction(action, on: selectedItem) else { return }

        if let suppressionTarget = execution.suppressionTarget(for: selectedItem) {
            registerPendingSuppression(for: suppressionTarget)
        }

        if execution.removesSelectedItem,
           let suppressionTarget = execution.suppressionTarget(for: selectedItem) {
            animateSuppression(suppressionTarget)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.refreshVisibleItemsIfNeeded()
        }
    }

    func refreshPreviewCache() {
        appSwitcher.warmCache(force: true)
    }

    // MARK: - Command Palette search API (called from HotkeyManager)

    /// Append a printable character to the live search query.
    /// Only meaningful when style is .commandPalette; safe to call otherwise.
    func appendSearchCharacter(_ char: String) {
        guard !char.isEmpty else { return }
        let newQuery = viewModel.searchQuery + char
        viewModel.searchQuery = newQuery
        if preferences.switcherStyle == .commandPalette {
            updatePaletteFilter(newQuery)
        }
    }

    /// Remove the last character from the live search query.
    func deleteSearchCharacter() {
        var query = viewModel.searchQuery
        guard !query.isEmpty else { return }
        query.removeLast()
        viewModel.searchQuery = query
        if preferences.switcherStyle == .commandPalette {
            updatePaletteFilter(query)
        }
    }

    // MARK: - Private

    private func buildPanel() {
        let panel: SwitcherPanel = SwitcherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 130),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level         = .popUpMenu
        panel.isOpaque      = false
        panel.backgroundColor = .clear
        panel.hasShadow     = false          // shadow drawn by SwiftUI
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovable     = false
        panel.acceptsMouseMovedEvents = true

        // Install SwiftUI view via ClickableHostingView so mouseDown fires even
        // when the panel is not the key window (.nonactivatingPanel never becomes
        // key in the traditional sense, breaking SwiftUI .onTapGesture entirely).
        let rootView = SwitcherView(viewModel: viewModel)
        let hosting  = ClickableHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        // Wire clicks: use the hover-tracked index (set by SwiftUI .onHover
        // on each card) to determine which card was clicked. This eliminates
        // fragile coordinate math that broke with scroll offset and layout
        // mismatches.
        hosting.onCardClick = { [weak self] _ in
            self?.handleCardClick()
        }

        panel.contentView = hosting
        panel.onEscapePressed = { [weak self] in
            self?.cancelAndHide()
        }
        panel.onKeyEvent = { [weak self] event in
            self?.handlePanelKeyEvent(event) ?? false
        }
        panel.onScrollEvent = { [weak self] event in
            self?.handlePanelScrollEvent(event) ?? false
        }
        self.panel = panel
    }

    private func buildBackdropPanel() {
        let panel = SwitcherBackdropPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovable = false
        panel.ignoresMouseEvents = true

        let hosting = NSHostingView(rootView: SwitcherScreenBackdropView(viewModel: viewModel))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = hosting
        self.backdropPanel = panel
    }

    /// Activate whatever card the mouse is hovering over.
    /// Uses `viewModel.hoveredIndex` set by SwiftUI `.onHover` on each card —
    /// no coordinate math needed, works correctly with scrolled content.
    private func handleCardClick() {
        guard let idx = viewModel.hoveredIndex,
              idx >= 0, idx < viewModel.items.count else { return }

        // Use selectIndex so session.selectedIdentity is updated to match the
        // clicked item before commitCurrentSelection reads it.
        session?.selectIndex(idx)
        viewModel.selectedIndex = idx

        // Clear HotkeyManager's trigger state BEFORE committing, so the
        // subsequent modifier-release event won't create a new session and
        // activate a different app.
        onClickCommit?()
        commitCurrentSelection()
    }

    private func handlePanelKeyEvent(_ event: NSEvent) -> Bool {
        guard viewModel.isVisible else { return false }

        if preferences.switcherStyle == .commandPalette {
            if event.keyCode == 51 {
                deleteSearchCharacter()
                return true
            }

            if let searchableCharacter = searchableCharacter(from: event) {
                appendSearchCharacter(searchableCharacter)
                return true
            }

            return false
        }

        let modifierFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let commandHeld = modifierFlags.contains(.command)
        let acceptsBareQuickAction = preferences.switcherStyle != .commandPalette &&
            !commandHeld &&
            !modifierFlags.contains(.option) &&
            !modifierFlags.contains(.control)

        guard let action = SwitcherQuickAction.action(
            forKeyCode: Int64(event.keyCode),
            keyEquivalent: event.charactersIgnoringModifiers,
            commandHeld: commandHeld,
            acceptsBareShortcut: acceptsBareQuickAction
        ) else {
            return false
        }

        performQuickAction(action)
        return true
    }

    private func handlePanelScrollEvent(_ event: NSEvent) -> Bool {
        guard viewModel.isVisible else { return false }
        guard event.hasPreciseScrollingDeltas else { return false }

        let now = ProcessInfo.processInfo.systemUptime
        if now - trackpadNavigationState.lastEventUptime > trackpadResetInterval {
            trackpadNavigationState.reset()
        }
        trackpadNavigationState.lastEventUptime = now

        let directionMultiplier: CGFloat = event.isDirectionInvertedFromDevice ? -1 : 1
        let horizontalDelta = CGFloat(event.scrollingDeltaX) * directionMultiplier
        let verticalDelta = CGFloat(event.scrollingDeltaY) * directionMultiplier

        guard abs(horizontalDelta) > 0.01 || abs(verticalDelta) > 0.01 else {
            return false
        }

        if abs(horizontalDelta) >= abs(verticalDelta) {
            trackpadNavigationState.vertical = 0
            trackpadNavigationState.horizontal += horizontalDelta

            while abs(trackpadNavigationState.horizontal) >= trackpadStepThreshold {
                let step = trackpadNavigationState.horizontal > 0 ? 1 : -1
                moveSelection(by: step)
                trackpadNavigationState.horizontal -= CGFloat(step) * trackpadStepThreshold
            }
        } else {
            trackpadNavigationState.horizontal = 0
            trackpadNavigationState.vertical += verticalDelta

            while abs(trackpadNavigationState.vertical) >= trackpadStepThreshold {
                if trackpadNavigationState.vertical > 0 {
                    moveSelectionUp()
                    trackpadNavigationState.vertical -= trackpadStepThreshold
                } else {
                    moveSelectionDown()
                    trackpadNavigationState.vertical += trackpadStepThreshold
                }
            }
        }

        return true
    }

    private func searchableCharacter(from event: NSEvent) -> String? {
        let modifierFlags = event.modifierFlags.intersection([.command, .option, .control, .function])
        guard !modifierFlags.contains(.option),
              !modifierFlags.contains(.control),
              !modifierFlags.contains(.function) else {
            return nil
        }

        guard let characters = event.charactersIgnoringModifiers,
              characters.count == 1,
              let scalar = characters.unicodeScalars.first,
              scalar.value >= 32,
              scalar.value != 127 else {
            return nil
        }

        return String(scalar)
    }

    private func makeSession(reverse: Bool) -> SwitcherCycleSession? {
        let snapshot = items()
        let currentFrontmost = currentFrontmostIdentity(availableItems: snapshot)
        return SwitcherCycleSession(
            mode: .app,
            items: snapshot,
            currentFrontmost: currentFrontmost,
            reverse: reverse,
            pinsSnapshot: false
        )
    }

    private func startSession(reverse: Bool) -> Bool {
        guard let newSession = makeSession(reverse: reverse) else { return false }
        session = newSession
        if preferences.switcherStyle == .commandPalette {
            paletteFullItemCount = newSession.items.count
        }
        syncViewModelFromSession()
        return true
    }

    private func wireDataSources() {
        appSwitcher.onItemsChanged = { [weak self] _ in
            self?.refreshVisibleItemsIfNeeded()
        }
        appSwitcher.onActivationConfirmed = { [weak self] identity, pid in
            guard let self else { return }
            self.activeFrontmostPID = pid
            self.setFrontmostOverride(identity: identity, pid: pid)
        }

        // Track external app activations (user clicked on a window, Dock click, etc.)
        // so that activeFrontmostPID stays correct even between our own switches.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.activationPolicy == .regular,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else {
                return
            }
            self.activeFrontmostPID = app.processIdentifier
            if self.frontmostOverride?.pid != app.processIdentifier {
                self.frontmostOverride = nil
            }
        }

        NotificationCenter.default.addObserver(
            forName: SwitcherPreferences.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePreferencesDidChange()
        }
    }

    private func handlePreferencesDidChange() {
        appSwitcher.warmCache(force: true)

        let currentStyle = preferences.switcherStyle
        let styleDidChange = currentStyle != lastObservedStyle
        lastObservedStyle = currentStyle

        if styleDidChange {
            refreshPanelContentRoots()
        }

        refreshVisibleItemsIfNeeded()

        if styleDidChange, viewModel.isVisible {
            showPanel(makeKey: false)
        } else {
            updateBackdropPanelIfNeeded()
        }
    }

    private func items() -> [SwitcherItem] {
        let rawItems = appSwitcher.getItems()
        let visibleItems = applyingPendingSuppressions(to: rawItems)
        let currentFrontmost = currentFrontmostIdentity(availableItems: visibleItems)
        return SwitcherOrdering.orderedItems(visibleItems, history: history, currentFrontmost: currentFrontmost)
    }

    private func refreshVisibleItemsIfNeeded() {
        guard viewModel.isVisible, var session else { return }
        guard !session.pinsSnapshot else { return }

        let refreshedItems = items()
        guard !refreshedItems.isEmpty else {
            hidePanel()
            return
        }

        if preferences.switcherStyle == .commandPalette {
            let filteredItems = Self.paletteFilteredItems(
                refreshedItems,
                query: viewModel.searchQuery,
                rememberedStableKey: searchMemory.rememberedStableKey(for: viewModel.searchQuery)
            )
            if filteredItems.isEmpty && !viewModel.searchQuery.isEmpty {
                self.session = nil
                viewModel.items = []
                viewModel.selectedIndex = 0
            } else {
                session.refreshItems(filteredItems)
                self.session = session
                syncViewModelFromSession(animated: false)
            }
        } else {
            let previousIDs = session.items.map(\.id)
            session.refreshItems(refreshedItems)
            self.session = session
            let refreshedIDs = session.items.map(\.id)
            let shouldAnimateRefresh = previousIDs != refreshedIDs
            syncViewModelFromSession(animated: shouldAnimateRefresh)
        }

        updateVisibleLayout()
    }

    private func syncViewModelFromSession(animated: Bool = false) {
        guard let session else { return }
        let applyState = {
            self.viewModel.mode = session.mode
            self.viewModel.items = session.items
            self.viewModel.selectedIndex = session.selectedIndex
            if let hoveredIndex = self.viewModel.hoveredIndex,
               hoveredIndex >= session.items.count {
                self.viewModel.hoveredIndex = nil
            }
            if self.preferences.switcherStyle == .radialMenu {
                self.viewModel.radialViewportState.reset(
                    itemCount: session.items.count,
                    selectedIndex: session.selectedIndex
                )
            }
        }

        if animated {
            withAnimation(itemMutationAnimation, applyState)
        } else {
            applyState()
        }
    }

    private func syncViewModelSelection() {
        guard let session else { return }
        viewModel.selectedIndex = session.selectedIndex
        viewModel.items = session.items
        if let hoveredIndex = viewModel.hoveredIndex,
           hoveredIndex >= session.items.count {
            viewModel.hoveredIndex = nil
        }
    }

    private func moveSelectionInRadialMenu(by delta: Int) {
        guard var session else { return }
        guard !session.items.isEmpty else { return }

        var viewport = viewModel.radialViewportState
        if viewport.visibleIndices.count != min(RadialMenuViewportState.maxVisible, session.items.count) {
            viewport.reset(itemCount: session.items.count, selectedIndex: session.selectedIndex)
        }

        let nextIndex = viewport.advance(direction: delta, itemCount: session.items.count)
        session.selectIndex(nextIndex)
        self.session = session
        viewModel.radialViewportState = viewport
        viewModel.selectedIndex = session.selectedIndex
        viewModel.items = session.items
    }

    private func animateSuppression(_ suppressionTarget: SwitcherItemSuppressionTarget) {
        guard var session else { return }
        guard session.removeItems(where: { suppressionTarget.matches($0) }) else { return }

        if session.items.isEmpty {
            hidePanel()
            return
        }

        self.session = session
        syncViewModelFromSession(animated: true)
        updateVisibleLayout()
        updateBackdropPanelIfNeeded()
    }

    private func updateVisibleLayout() {
        guard let screen = presentationScreen(for: preferences.switcherStyle) else { return }

        let visibleCount = max(viewModel.items.count, 1)
        switch preferences.switcherStyle {
        case .classicGrid:
            viewModel.layout = SwitcherLayoutMetrics.make(itemCount: visibleCount, visibleFrame: screen.visibleFrame)
        case .commandPalette:
            let paletteCount = max(paletteFullItemCount, visibleCount)
            viewModel.layout = SwitcherLayoutMetrics.makePalette(itemCount: paletteCount, visibleFrame: screen.visibleFrame)
        case .radialMenu:
            viewModel.layout = SwitcherLayoutMetrics.makeRadial(itemCount: visibleCount)
        }

        if viewModel.isVisible {
            applyPanelPlacement(on: screen, style: preferences.switcherStyle)
        }
    }

    private func registerPendingSuppression(for target: SwitcherItemSuppressionTarget) {
        let expiresAt = ProcessInfo.processInfo.systemUptime + quickActionSuppressionInterval
        pendingItemSuppressions.removeAll { $0.target == target }
        pendingItemSuppressions.append(
            PendingItemSuppression(target: target, expiresAtUptime: expiresAt)
        )
    }

    private func applyingPendingSuppressions(to rawItems: [SwitcherItem]) -> [SwitcherItem] {
        let now = ProcessInfo.processInfo.systemUptime
        pendingItemSuppressions = pendingItemSuppressions.filter { suppression in
            guard now <= suppression.expiresAtUptime else { return false }
            return rawItems.contains(where: suppression.matches)
        }

        guard !pendingItemSuppressions.isEmpty else { return rawItems }
        return rawItems.filter { item in
            !pendingItemSuppressions.contains(where: { $0.matches(item) })
        }
    }

    /// Determine which identity represents the "currently active" app/window
    /// so that `orderedItems` can move it to the end of the MRU list.
    ///
    /// Uses the live system frontmost app when available, with a very short
    /// override window after a switcher commit so quick re-presses still
    /// behave like Windows-style Alt-Tab even before NSWorkspace catches up.
    private func currentFrontmostIdentity(availableItems: [SwitcherItem]) -> SwitcherHistoryIdentity? {
        let historyEntries = history.snapshot()
        return FrontmostResolution.effectiveIdentity(
            availableItems: availableItems,
            historyEntries: historyEntries,
            systemFrontmostIdentity: appSwitcher.currentFrontmostIdentity(),
            systemFrontmostPID: currentSystemFrontmostPID(),
            observedFrontmostPID: activeFrontmostPID,
            overrideState: frontmostOverride,
            now: ProcessInfo.processInfo.systemUptime
        )
    }

    /// - Parameter makeKey: Pass `true` when showing via menu-bar / standalone click so
    ///   `NSApp.activate` is also called, making our app the active one for the session.
    private func showPanel(makeKey: Bool = false) {
        trackpadNavigationState.reset()
        if viewModel.items.isEmpty, var session {
            let primedItems = items()
            guard !primedItems.isEmpty else { return }
            session.refreshItems(primedItems)
            self.session = session
            syncViewModelFromSession()
        }

        refreshPanelContentRoots()

        let targetScreen = presentationScreen(for: preferences.switcherStyle)

        if let screen = targetScreen {
            applyPanelPlacement(on: screen, style: preferences.switcherStyle)
        } else {
            viewModel.layout = .empty
        }

        updateBackdropPanelIfNeeded()
        updateMirroredPanelsIfNeeded(primaryScreen: targetScreen, style: preferences.switcherStyle)
        panel.alphaValue = 1

        if makeKey {
            NSApp.activate(ignoringOtherApps: true)
        }
        backdropPanel.orderFrontRegardless()
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        viewModel.isVisible = true
    }

    private func hidePanel() {
        trackpadNavigationState.reset()
        viewModel.isVisible = false
        panel.alphaValue = 0
        panel.orderOut(nil)
        backdropPanel.orderOut(nil)
        tearDownMirroredPanels()
        resetSessionState()
    }

    private func resetSessionState() {
        session = nil
        paletteFullItemCount = 0
        viewModel.items = []
        viewModel.selectedIndex = 0
        viewModel.radialViewportState = RadialMenuViewportState()
        viewModel.layout = .empty
        viewModel.hoveredIndex = nil
        viewModel.searchQuery = ""
    }

    private func presentationScreen(for style: SwitcherStyle) -> NSScreen? {
        let activeScreen = activeWindowScreen(for: viewModel.items.isEmpty ? items() : viewModel.items)
        let cursorScreen = cursorScreen()

        switch preferences.displayPlacement {
        case .activeWindowDisplay:
            return activeScreen ?? cursorScreen ?? panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        case .cursorDisplay:
            return cursorScreen ?? activeScreen ?? panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        case .allDisplays:
            return activeScreen ?? cursorScreen ?? panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        }
    }

    private func updateBackdropFrame(for screen: NSScreen) {
        backdropPanel.setFrame(screen.frame, display: false)
        viewModel.backdropScreenFrame = screen.frame
        viewModel.backdropVisibleFrame = screen.visibleFrame
    }

    private func updateBackdropPanelIfNeeded() {
        guard viewModel.isVisible || !viewModel.items.isEmpty else {
            backdropPanel.orderOut(nil)
            return
        }

        guard preferences.showSelectedPreviewBackdrop,
              let screen = panel.screen ?? presentationScreen(for: preferences.switcherStyle) else {
            backdropPanel.orderOut(nil)
            return
        }

        updateBackdropFrame(for: screen)
        backdropPanel.orderFrontRegardless()
    }

    /// Filter `viewModel.items` to rows matching `query`, then reset selection.
    private func updatePaletteFilter(_ query: String) {
        let allItems = items()
        let rememberedStableKey = searchMemory.rememberedStableKey(for: query)
        let filtered = Self.paletteFilteredItems(
            allItems,
            query: query,
            rememberedStableKey: rememberedStableKey
        )

        guard !filtered.isEmpty else {
            session = nil
            viewModel.items = []
            viewModel.selectedIndex = 0
            updateVisibleLayout()
            return
        }

        if var session {
            session.replaceItems(filtered, selectedIndex: 0)
            self.session = session
        } else {
            self.session = SwitcherCycleSession(
                mode: .app,
                items: filtered,
                currentFrontmost: currentFrontmostIdentity(availableItems: filtered),
                reverse: false,
                pinsSnapshot: false
            )
        }

        syncViewModelFromSession(animated: false)
        updateVisibleLayout()
    }

    private func commitCurrentSelection() {
        guard var session else {
            hidePanel()
            return
        }

        session.selectIndex(viewModel.selectedIndex)
        self.session = session

        let selectedItem = session.commitSelection()

        let rememberedQuery = preferences.switcherStyle == .commandPalette ? viewModel.searchQuery : ""
        if !rememberedQuery.isEmpty {
            searchMemory.noteSelection(query: rememberedQuery, identity: selectedItem.historyIdentity)
        }

        hidePanel()
        DispatchQueue.main.async { [weak self] in
            self?.activateSelection(selectedItem)
        }
    }

    private func activateSelection(_ item: SwitcherItem) {
        item.activate()
    }

    private func currentSystemFrontmostPID() -> pid_t {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return 0
        }
        return app.processIdentifier
    }

    private func setFrontmostOverride(identity: SwitcherHistoryIdentity, pid: pid_t) {
        let startedAt = ProcessInfo.processInfo.systemUptime
        let override = FrontmostOverrideState(identity: identity, pid: pid, startedAtUptime: startedAt)
        frontmostOverride = override

        DispatchQueue.main.asyncAfter(deadline: .now() + FrontmostResolution.overrideGraceInterval) { [weak self] in
            guard let self, self.frontmostOverride == override else { return }
            if self.currentSystemFrontmostPID() != pid {
                self.frontmostOverride = nil
            }
        }
    }

    private func applyPanelPlacement(on screen: NSScreen, style: SwitcherStyle) {
        let visibleFrame = screen.visibleFrame

        let layout: SwitcherLayoutMetrics
        switch style {
        case .classicGrid:
            layout = SwitcherLayoutMetrics.make(itemCount: viewModel.items.count, visibleFrame: visibleFrame)
        case .commandPalette:
            let paletteCount = max(paletteFullItemCount, viewModel.items.count)
            layout = SwitcherLayoutMetrics.makePalette(itemCount: paletteCount, visibleFrame: visibleFrame)
        case .radialMenu:
            layout = SwitcherLayoutMetrics.makeRadial(itemCount: viewModel.items.count)
        }

        viewModel.layout = layout
        panel.setContentSize(NSSize(width: layout.contentWidth, height: layout.contentHeight))
        panel.setFrameOrigin(panelOrigin(on: screen, layout: layout, style: style))
        updateBackdropFrame(for: screen)
    }

    private func panelOrigin(on screen: NSScreen, layout: SwitcherLayoutMetrics, style: SwitcherStyle) -> NSPoint {
        let visibleFrame = screen.visibleFrame
        switch style {
        case .radialMenu:
            return NSPoint(
                x: visibleFrame.midX - layout.contentWidth / 2,
                y: visibleFrame.midY - layout.contentHeight / 2
            )
        case .classicGrid, .commandPalette:
            let safeFrame = visibleFrame.insetBy(dx: 18, dy: 18)
            let proposedX = visibleFrame.midX - layout.contentWidth / 2
            let proposedY = visibleFrame.midY - layout.contentHeight / 2
            return NSPoint(
                x: min(max(proposedX, safeFrame.minX), safeFrame.maxX - layout.contentWidth),
                y: min(max(proposedY, safeFrame.minY), safeFrame.maxY - layout.contentHeight)
            )
        }
    }

    private func activeWindowScreen(for items: [SwitcherItem]) -> NSScreen? {
        guard !items.isEmpty else { return nil }
        let currentFrontmost = currentFrontmostIdentity(availableItems: items)
        guard let currentFrontmost else { return nil }
        guard let frame = items.first(where: { $0.historyIdentity == currentFrontmost })?.backdropFrame else {
            return nil
        }
        let center = NSPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first(where: { $0.frame.contains(center) })
            ?? NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) })
    }

    static func paletteFilteredItems(
        _ items: [SwitcherItem],
        query: String,
        rememberedStableKey: String? = nil
    ) -> [SwitcherItem] {
        PaletteSearch.rankedItems(items, query: query, rememberedStableKey: rememberedStableKey)
    }

    private func cursorScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
    }

    private func updateMirroredPanelsIfNeeded(primaryScreen: NSScreen?, style: SwitcherStyle) {
        guard preferences.displayPlacement == .allDisplays,
              let primaryScreen,
              NSScreen.screens.count > 1 else {
            tearDownMirroredPanels()
            return
        }

        var activeKeys = Set<ObjectIdentifier>()

        for screen in NSScreen.screens where screen != primaryScreen {
            let key = ObjectIdentifier(screen)
            activeKeys.insert(key)

            let mirrorPanel = mirroredPanels[key] ?? buildMirrorPanel()
            mirroredPanels[key] = mirrorPanel
            mirrorPanel.setContentSize(NSSize(width: viewModel.layout.contentWidth, height: viewModel.layout.contentHeight))
            mirrorPanel.setFrameOrigin(panelOrigin(on: screen, layout: viewModel.layout, style: style))
            mirrorPanel.orderFrontRegardless()
        }

        for (key, panel) in mirroredPanels where !activeKeys.contains(key) {
            panel.orderOut(nil)
            mirroredPanels.removeValue(forKey: key)
        }
    }

    private func buildMirrorPanel() -> SwitcherMirrorPanel {
        let panel = SwitcherMirrorPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 130),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovable = false
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: SwitcherView(viewModel: viewModel))
        return panel
    }

    private func refreshPanelContentRoots() {
        if let hosting = panel.contentView as? ClickableHostingView<SwitcherView> {
            hosting.rootView = SwitcherView(viewModel: viewModel)
            hosting.onCardClick = { [weak self] _ in
                self?.handleCardClick()
            }
        }

        if let hosting = backdropPanel.contentView as? NSHostingView<SwitcherScreenBackdropView> {
            hosting.rootView = SwitcherScreenBackdropView(viewModel: viewModel)
        }

        for mirrorPanel in mirroredPanels.values {
            if let hosting = mirrorPanel.contentView as? NSHostingView<SwitcherView> {
                hosting.rootView = SwitcherView(viewModel: viewModel)
            }
        }
    }

    private func tearDownMirroredPanels() {
        for panel in mirroredPanels.values {
            panel.orderOut(nil)
        }
        mirroredPanels.removeAll()
    }
}
