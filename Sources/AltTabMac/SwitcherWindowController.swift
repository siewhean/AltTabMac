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

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscapePressed?()
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - SwitcherWindowController

/// Hosts the SwiftUI SwitcherView inside a borderless, non-activating NSPanel.
/// The panel is pre-created at launch and simply shown/hidden to eliminate latency.
final class SwitcherWindowController {

    private var panel: SwitcherPanel!
    private let viewModel = SwitcherViewModel()
    private let appSwitcher = AppSwitcher()
    private let history = SwitcherHistoryStore.shared
    private let preferences = SwitcherPreferences.shared
    private var session: SwitcherCycleSession?

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
        buildPanel()
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

    func moveSelection(by delta: Int) {
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
        self.panel = panel
    }

    /// Activate whatever card the mouse is hovering over.
    /// Uses `viewModel.hoveredIndex` set by SwiftUI `.onHover` on each card —
    /// no coordinate math needed, works correctly with scrolled content.
    private func handleCardClick() {
        guard let idx = viewModel.hoveredIndex,
              idx >= 0, idx < viewModel.items.count else { return }

        let currentIdx = session?.selectedIndex ?? 0
        let delta = idx - currentIdx
        if delta != 0 { session?.move(by: delta) }
        viewModel.selectedIndex = idx

        // Clear HotkeyManager's trigger state BEFORE committing, so the
        // subsequent modifier-release event won't create a new session and
        // activate a different app.
        onClickCommit?()
        commitCurrentSelection()
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
        syncViewModelFromSession()
        return true
    }

    private func wireDataSources() {
        appSwitcher.onItemsChanged = { [weak self] _ in
            self?.refreshVisibleItemsIfNeeded()
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
            self?.appSwitcher.warmCache(force: true)
            self?.refreshVisibleItemsIfNeeded()
        }
    }

    private func items() -> [SwitcherItem] {
        let rawItems = appSwitcher.getItems()
        let currentFrontmost = currentFrontmostIdentity(availableItems: rawItems)
        return SwitcherOrdering.orderedItems(rawItems, history: history, currentFrontmost: currentFrontmost)
    }

    private func refreshVisibleItemsIfNeeded() {
        guard viewModel.isVisible, var session else { return }
        guard !session.pinsSnapshot else { return }

        let refreshedItems = items()
        guard !refreshedItems.isEmpty else { return }
        session.refreshItems(refreshedItems)
        self.session = session
        syncViewModelFromSession()

        if let screen = presentationScreen(for: preferences.switcherStyle) {
            switch preferences.switcherStyle {
            case .classicGrid:
                viewModel.layout = SwitcherLayoutMetrics.make(itemCount: refreshedItems.count, visibleFrame: screen.visibleFrame)
            case .commandPalette:
                viewModel.layout = SwitcherLayoutMetrics.makePalette(itemCount: refreshedItems.count, visibleFrame: screen.visibleFrame)
            case .radialMenu:
                viewModel.layout = SwitcherLayoutMetrics.makeRadial(itemCount: refreshedItems.count)
            }
        }
    }

    private func syncViewModelFromSession() {
        guard let session else { return }
        viewModel.mode = session.mode
        viewModel.items = session.items
        viewModel.selectedIndex = session.selectedIndex
    }

    private func syncViewModelSelection() {
        guard let session else { return }
        viewModel.selectedIndex = session.selectedIndex
        viewModel.items = session.items
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
        if viewModel.items.isEmpty, var session {
            let primedItems = items()
            guard !primedItems.isEmpty else { return }
            session.refreshItems(primedItems)
            self.session = session
            syncViewModelFromSession()
        }

        let targetScreen = presentationScreen(for: preferences.switcherStyle)

        if let screen = targetScreen {
            let visibleFrame = screen.visibleFrame
            let style = preferences.switcherStyle

            let layout: SwitcherLayoutMetrics
            switch style {
            case .classicGrid:
                layout = SwitcherLayoutMetrics.make(itemCount: viewModel.items.count, visibleFrame: visibleFrame)
            case .commandPalette:
                layout = SwitcherLayoutMetrics.makePalette(itemCount: viewModel.items.count, visibleFrame: visibleFrame)
            case .radialMenu:
                layout = SwitcherLayoutMetrics.makeRadial(itemCount: viewModel.items.count)
            }
            viewModel.layout = layout
            panel.setContentSize(NSSize(width: layout.contentWidth, height: layout.contentHeight))

            let ox: CGFloat
            let oy: CGFloat
            switch style {
            case .radialMenu:
                ox = visibleFrame.midX - layout.contentWidth / 2
                oy = visibleFrame.midY - layout.contentHeight / 2
            default:
                let safeFrame = visibleFrame.insetBy(dx: 18, dy: 18)
                let proposedX = visibleFrame.midX - layout.contentWidth / 2
                let proposedY = visibleFrame.midY - layout.contentHeight / 2
                ox = min(max(proposedX, safeFrame.minX), safeFrame.maxX - layout.contentWidth)
                oy = min(max(proposedY, safeFrame.minY), safeFrame.maxY - layout.contentHeight)
            }
            panel.setFrameOrigin(NSPoint(x: ox, y: oy))
        } else {
            viewModel.layout = .empty
        }

        panel.alphaValue = 1

        if makeKey {
            NSApp.activate(ignoringOtherApps: true)
        }
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        viewModel.isVisible = true
    }

    private func hidePanel() {
        viewModel.isVisible = false
        panel.alphaValue = 0
        panel.orderOut(nil)
        resetSessionState()
    }

    private func resetSessionState() {
        session = nil
        viewModel.items = []
        viewModel.selectedIndex = 0
        viewModel.layout = .empty
        viewModel.hoveredIndex = nil
        viewModel.searchQuery = ""
    }

    private func presentationScreen(for style: SwitcherStyle) -> NSScreen? {
        switch style {
        case .radialMenu:
            if viewModel.isVisible {
                return panel.screen ?? NSScreen.main ?? NSScreen.screens.first
            }
            return NSScreen.main ?? panel.screen ?? NSScreen.screens.first
        case .classicGrid, .commandPalette:
            let mouseLocation = NSEvent.mouseLocation
            return NSScreen.screens.first(where: { $0.visibleFrame.contains(mouseLocation) })
                ?? panel.screen
                ?? NSScreen.main
                ?? NSScreen.screens.first
        }
    }

    /// Filter `viewModel.items` to rows matching `query`, then reset selection.
    private func updatePaletteFilter(_ query: String) {
        let allItems = items()
        let filtered: [SwitcherItem]
        if query.isEmpty {
            filtered = allItems
        } else {
            let q = query.lowercased()
            filtered = allItems.filter {
                $0.title.lowercased().contains(q) || $0.subtitle.lowercased().contains(q)
            }
        }
        viewModel.items = filtered
        viewModel.selectedIndex = 0
        session?.refreshItems(filtered)
    }

    private func commitCurrentSelection() {
        guard let selectedItem = session?.commitSelection() else {
            hidePanel()
            return
        }

        history.noteActivation(selectedItem.historyIdentity)

        if let pid = selectedItem.historyIdentity.ownerPID {
            setFrontmostOverride(identity: selectedItem.historyIdentity, pid: pid)
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
}
