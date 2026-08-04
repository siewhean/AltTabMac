import AppKit
import SwiftUI

private final class ProductionSwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    var onEscapePressed: (() -> Void)?
    var onKeyEvent: ((NSEvent) -> Bool)?
    var onScrollEvent: ((NSEvent) -> Bool)?
    var onRightMouseDown: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if onKeyEvent?(event) == true { return }
        if event.keyCode == 53 {
            onEscapePressed?()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onKeyEvent?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        if onScrollEvent?(event) == true { return }
        super.scrollWheel(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightMouseDown?()
    }
}

private final class ProductionSwitcherBackdropPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class ProductionSwitcherMirrorPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Profile-scoped production controller for the five-feature suite.
///
/// It freezes one `SwitcherSessionConfiguration` for each session, preventing
/// settings from one shortcut profile from leaking into another. Window
/// membership is provided by `ProductionAppSwitcher`; presentation and input
/// remain on the main thread.
final class ProductionSwitcherWindowController: NSObject {
    private struct PendingItemSuppression {
        let target: SwitcherItemSuppressionTarget
        let expiresAtUptime: TimeInterval

        func matches(_ item: SwitcherItem) -> Bool {
            target.matches(item)
        }
    }

    private let itemMutationAnimation = Animation.spring(response: 0.24, dampingFraction: 0.84)
    private let quickActionSuppressionInterval: TimeInterval = 1.4

    private var panel: ProductionSwitcherPanel!
    private var backdropPanel: ProductionSwitcherBackdropPanel!
    private let viewModel = SwitcherViewModel()
    private let appSwitcher = ProductionAppSwitcher()
    private let history = SwitcherHistoryStore.shared
    private let searchMemory = SearchMemoryStore.shared
    private let preferences = SwitcherPreferences.shared
    private let profileStore = SwitcherProfileStore.shared

    private var session: SwitcherCycleSession?
    private var activeConfiguration: SwitcherSessionConfiguration?
    private var paletteFullItemCount = 0
    private var mirroredPanels: [ObjectIdentifier: ProductionSwitcherMirrorPanel] = [:]
    private var pendingItemSuppressions: [PendingItemSuppression] = []
    private var deferredPresentation = DeferredSwitcherPresentation()
    private var activeFrontmostPID: pid_t = 0
    private var frontmostOverride: FrontmostOverrideState?

    var isVisible: Bool { viewModel.isVisible }
    var currentStyle: SwitcherStyle { activeConfiguration?.style ?? preferences.switcherStyle }
    var activeProfileID: UUID? { activeConfiguration?.profileID }
    var activeReleaseBehavior: SwitcherReleaseBehavior? { activeConfiguration?.releaseBehavior }

    var onClickCommit: (() -> Void)?
    var onLicenseAccessRequired: (() -> Void)?

    override init() {
        super.init()
        buildPanel()
        buildBackdropPanel()
        wireDataSources()
        _ = appSwitcher.primeCacheIfNeeded()
        appSwitcher.warmCache(force: true)

        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.activationPolicy == .regular,
           frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            activeFrontmostPID = frontmost.processIdentifier
        }
    }

    // MARK: Public input API

    func showOrAdvance(reverse: Bool = false, profileID: UUID? = nil) {
        let resolvedID = profileID ?? defaultProfileID()
        guard let resolvedID else { return }

        if !viewModel.isVisible || activeProfileID != resolvedID {
            if viewModel.isVisible { hidePanel() }
            guard startSession(reverse: reverse, profileID: resolvedID) else {
                deferSelectorPresentation(profileID: resolvedID, reverse: reverse)
                return
            }
            deferredPresentation.cancel()
            showPanel()
            return
        }

        if currentStyle == .radialMenu {
            moveSelectionInRadialMenu(by: reverse ? -1 : 1)
        } else {
            session?.advance(reverse: reverse)
            syncViewModelSelection()
        }
    }

    func commitTriggerSession(reverse: Bool = false, profileID: UUID? = nil) {
        guard let profileID = profileID ?? defaultProfileID() else { return }
        guard startSession(reverse: reverse, profileID: profileID) else {
            // A release before scoped enrichment finishes still owns one quick
            // switch. Complete it only after the exact snapshot is available.
            deferredPresentation.deferCommit(profileID: profileID, reverse: reverse)
            return
        }
        deferredPresentation.cancel()
        commitCurrentSelection()
    }

    func showStandalone() {
        guard let profileID = defaultProfileID(),
              startSession(reverse: false, profileID: profileID) else {
            return
        }
        showPanel(makeKey: true)
    }

    func applyStyleChangeFromSettings() {
        guard let profileID = activeProfileID,
              let configuration = profileStore.configuration(
                for: profileID,
                preferences: preferences
              ) else {
            refreshPanelContentRoots()
            return
        }
        let styleChanged = configuration.style != currentStyle
        activeConfiguration = configuration
        appSwitcher.applySessionConfiguration(configuration)
        if styleChanged { refreshPanelContentRoots() }
        if viewModel.isVisible {
            refreshVisibleItemsIfNeeded()
            showPanel(makeKey: false)
        }
    }

    func applyCurrentStyleImmediately() {
        if viewModel.isVisible {
            refreshPanelContentRoots()
            refreshVisibleItemsIfNeeded()
            showPanel(makeKey: false)
            return
        }
        showStandalone()
    }

    func moveSelection(by delta: Int) {
        if currentStyle == .radialMenu {
            moveSelectionInRadialMenu(by: delta)
        } else {
            session?.move(by: delta)
            syncViewModelSelection()
        }
    }

    func moveSelectionUp() {
        session?.moveUp(columns: viewModel.layout.columns)
        syncViewModelSelection()
    }

    func moveSelectionDown() {
        session?.moveDown(columns: viewModel.layout.columns)
        syncViewModelSelection()
    }

    func confirmAndHide() {
        commitCurrentSelection()
    }

    func cancelAndHide() {
        deferredPresentation.cancel()
        hidePanel()
    }

    func appendSearchCharacter(_ character: String) {
        guard !character.isEmpty else { return }
        let query = viewModel.searchQuery + character
        viewModel.searchQuery = query
        if currentStyle == .commandPalette {
            updatePaletteFilter(query)
        }
    }

    func deleteSearchCharacter() {
        var query = viewModel.searchQuery
        guard !query.isEmpty else { return }
        query.removeLast()
        viewModel.searchQuery = query
        if currentStyle == .commandPalette {
            updatePaletteFilter(query)
        }
    }

    func performQuickAction(_ action: SwitcherQuickAction) {
        guard let selected = selectedItem() else { return }
        let execution = action.execution(for: selected.kind)
        guard appSwitcher.performQuickAction(action, on: selected) else { return }

        if let target = execution.suppressionTarget(for: selected) {
            registerPendingSuppression(for: target)
            if execution.removesSelectedItem {
                animateSuppression(target)
            }
        }
        scheduleRefresh()
    }

    func managementActionAvailability(
        _ action: WindowManagementAction
    ) -> WindowActionAvailability {
        guard let selected = selectedItem() else {
            return .unsupported("No switcher item is selected.")
        }
        return appSwitcher.managementActionAvailability(action, on: selected)
    }

    func performManagementAction(_ action: WindowManagementAction) {
        guard let selected = selectedItem() else { return }
        let availability = appSwitcher.managementActionAvailability(action, on: selected)
        guard availability.isSupported else {
            showActionAlert(
                title: "Action Unavailable",
                message: availability.reason ?? "The selected application does not support this action."
            )
            return
        }

        if action.requiresConfirmation {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Force Quit \(selected.subtitle)?"
            alert.informativeText = "Unsaved changes in this application may be lost. Only the selected application process will be terminated."
            alert.addButton(withTitle: "Force Quit")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        let result = appSwitcher.performManagementAction(action, on: selected)
        guard result.succeeded else {
            showActionAlert(title: "Action Failed", message: result.message)
            return
        }

        if action.removesSelectedItem {
            let target = SwitcherItemSuppressionTarget.application(
                pid: selected.ownerPID,
                sourceAppIdentifier: selected.sourceAppIdentifier
            )
            registerPendingSuppression(for: target)
            animateSuppression(target)
        }
        scheduleRefresh()
    }

    func refreshPreviewCache() {
        appSwitcher.warmCache(force: true)
    }

    // MARK: Panel construction

    private func buildPanel() {
        let panel = ProductionSwitcherPanel(
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
        panel.acceptsMouseMovedEvents = true

        let hosting = ClickableHostingView(
            rootView: ProfileSwitcherView(viewModel: viewModel, style: currentStyle)
        )
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.onCardClick = { [weak self] _ in self?.handleCardClick() }
        panel.contentView = hosting
        panel.onEscapePressed = { [weak self] in self?.cancelAndHide() }
        panel.onKeyEvent = { [weak self] event in
            self?.handlePanelKeyEvent(event) ?? false
        }
        panel.onScrollEvent = { [weak self] event in
            self?.isVisible == true && event.hasPreciseScrollingDeltas
        }
        panel.onRightMouseDown = { [weak self] in self?.showManagementMenu() }
        self.panel = panel
    }

    private func buildBackdropPanel() {
        let panel = ProductionSwitcherBackdropPanel(
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
        panel.contentView = NSHostingView(
            rootView: SwitcherScreenBackdropView(viewModel: viewModel)
        )
        self.backdropPanel = panel
    }

    private func refreshPanelContentRoots() {
        if let hosting = panel.contentView as? ClickableHostingView<ProfileSwitcherView> {
            hosting.rootView = ProfileSwitcherView(viewModel: viewModel, style: currentStyle)
            hosting.onCardClick = { [weak self] _ in self?.handleCardClick() }
        }
        if let hosting = backdropPanel.contentView as? NSHostingView<SwitcherScreenBackdropView> {
            hosting.rootView = SwitcherScreenBackdropView(viewModel: viewModel)
        }
        for mirror in mirroredPanels.values {
            if let hosting = mirror.contentView as? NSHostingView<ProfileSwitcherView> {
                hosting.rootView = ProfileSwitcherView(viewModel: viewModel, style: currentStyle)
            }
        }
    }

    // MARK: Sessions and data

    private func defaultProfileID() -> UUID? {
        profileStore.profilesSnapshot().first(where: \.isEnabled)?.id
    }

    private func startSession(reverse: Bool, profileID: UUID) -> Bool {
        let hasAccess = MainActor.assumeIsolated {
            LicensingController.shared.ensureUsageAllowed(openLicensing: { [weak self] in
                self?.onLicenseAccessRequired?()
            })
        }
        guard hasAccess,
              let configuration = profileStore.configuration(
                for: profileID,
                preferences: preferences
              ) else {
            return false
        }

        activeConfiguration = configuration
        appSwitcher.applySessionConfiguration(configuration)
        refreshPanelContentRoots()

        let snapshot = items()
        guard !snapshot.isEmpty else { return false }
        let currentFrontmost = currentFrontmostIdentity(availableItems: snapshot)
        guard let newSession = SwitcherCycleSession(
            mode: .app,
            items: snapshot,
            currentFrontmost: currentFrontmost,
            reverse: reverse,
            pinsSnapshot: false
        ) else {
            return false
        }
        session = newSession
        if currentStyle == .commandPalette {
            paletteFullItemCount = newSession.items.count
        }
        syncViewModelFromSession()
        return true
    }

    private func items() -> [SwitcherItem] {
        let raw = applyingPendingSuppressions(to: appSwitcher.getItems())
        _ = appSwitcher.reconcileCurrentFrontmostHistory()
        return SwitcherOrdering.orderedItems(
            raw,
            history: history,
            currentFrontmost: currentFrontmostIdentity(availableItems: raw)
        )
    }

    private func wireDataSources() {
        appSwitcher.onItemsChanged = { [weak self] _ in
            DispatchQueue.main.async {
                self?.fulfillDeferredPresentationIfPossible()
                self?.refreshVisibleItemsIfNeeded()
            }
        }
        appSwitcher.onActivationConfirmed = { [weak self] identity, pid in
            guard let self else { return }
            self.activeFrontmostPID = pid
            self.setFrontmostOverride(identity: identity, pid: pid)
        }

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
        ) { [weak self] _ in self?.handleConfigurationChange() }
        NotificationCenter.default.addObserver(
            forName: SwitcherProfileStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.handleConfigurationChange() }
    }

    private func handleConfigurationChange() {
        guard let profileID = activeProfileID,
              let configuration = profileStore.configuration(
                for: profileID,
                preferences: preferences
              ) else {
            if viewModel.isVisible { hidePanel() }
            return
        }
        let styleChanged = configuration.style != currentStyle
        activeConfiguration = configuration
        appSwitcher.applySessionConfiguration(configuration)
        if styleChanged { refreshPanelContentRoots() }
        refreshVisibleItemsIfNeeded()
        updateBackdropPanelIfNeeded()
    }

    private func refreshVisibleItemsIfNeeded() {
        guard viewModel.isVisible, var session, !session.pinsSnapshot else { return }
        let refreshed = items()
        guard !refreshed.isEmpty else {
            hidePanel()
            return
        }

        if currentStyle == .commandPalette {
            let filtered = Self.paletteFilteredItems(
                refreshed,
                query: viewModel.searchQuery,
                rememberedStableKey: searchMemory.rememberedStableKey(for: viewModel.searchQuery)
            )
            if filtered.isEmpty && !viewModel.searchQuery.isEmpty {
                self.session = nil
                viewModel.items = []
                viewModel.selectedIndex = 0
            } else {
                session.refreshItems(filtered)
                self.session = session
                syncViewModelFromSession()
            }
        } else {
            let previousIDs = session.items.map(\.id)
            session.refreshItems(refreshed)
            self.session = session
            syncViewModelFromSession(animated: previousIDs != session.items.map(\.id))
        }
        updateVisibleLayout()
    }

    private func deferSelectorPresentation(profileID: UUID, reverse: Bool) {
        guard let profile = profileStore.profile(id: profileID) else { return }
        let shortcut = reverse ? (profile.reverseShortcut ?? profile.forwardShortcut) : profile.forwardShortcut
        let requiredModifier = profile.releaseBehavior == .holdPrimaryModifier
            ? shortcut.modifiers.primaryReleaseModifier
            : nil
        deferredPresentation.deferShow(
            profileID: profileID,
            reverse: reverse,
            requireHeldModifier: requiredModifier
        )
    }

    private func fulfillDeferredPresentationIfPossible() {
        guard !viewModel.isVisible,
              let action = deferredPresentation.takeReadyAction(
                isModifierHeld: isModifierHeld
              ) else {
            return
        }

        switch action {
        case let .show(profileID, reverse, _):
            guard startSession(reverse: reverse, profileID: profileID) else {
                // Enrichment can publish an intermediate empty snapshot. Keep
                // the request until an exact scoped result is available.
                deferSelectorPresentation(profileID: profileID, reverse: reverse)
                return
            }
            showPanel()

        case let .commit(profileID, reverse):
            guard startSession(reverse: reverse, profileID: profileID) else {
                deferredPresentation.deferCommit(profileID: profileID, reverse: reverse)
                return
            }
            commitCurrentSelection()
        }
    }

    private func isModifierHeld(_ modifier: HotkeyModifier) -> Bool {
        switch modifier {
        case .command:
            return NSEvent.modifierFlags.contains(.command)
        case .option:
            return NSEvent.modifierFlags.contains(.option)
        }
    }

    private func syncViewModelFromSession(animated: Bool = false) {
        guard let session else { return }
        let update = {
            self.viewModel.mode = session.mode
            self.viewModel.items = session.items
            self.viewModel.selectedIndex = session.selectedIndex
            if let hovered = self.viewModel.hoveredIndex, hovered >= session.items.count {
                self.viewModel.hoveredIndex = nil
            }
            if self.currentStyle == .radialMenu {
                self.viewModel.radialViewportState.reset(
                    itemCount: session.items.count,
                    selectedIndex: session.selectedIndex
                )
            }
        }
        if animated { withAnimation(itemMutationAnimation, update) } else { update() }
    }

    private func syncViewModelSelection() {
        guard let session else { return }
        viewModel.selectedIndex = session.selectedIndex
        viewModel.items = session.items
        if let hovered = viewModel.hoveredIndex, hovered >= session.items.count {
            viewModel.hoveredIndex = nil
        }
        updateBackdropPanelIfNeeded()
    }

    private func moveSelectionInRadialMenu(by delta: Int) {
        guard var session, !session.items.isEmpty else { return }
        var viewport = viewModel.radialViewportState
        if viewport.visibleIndices.count != min(RadialMenuViewportState.maxVisible, session.items.count) {
            viewport.reset(itemCount: session.items.count, selectedIndex: session.selectedIndex)
        }
        let next = viewport.advance(direction: delta, itemCount: session.items.count)
        session.selectIndex(next)
        self.session = session
        viewModel.radialViewportState = viewport
        viewModel.selectedIndex = next
        viewModel.items = session.items
        updateBackdropPanelIfNeeded()
    }

    // MARK: Panel input and actions

    private func handleCardClick() {
        guard let index = viewModel.hoveredIndex,
              viewModel.items.indices.contains(index) else { return }
        session?.selectIndex(index)
        viewModel.selectedIndex = index
        onClickCommit?()
        commitCurrentSelection()
    }

    private func handlePanelKeyEvent(_ event: NSEvent) -> Bool {
        guard viewModel.isVisible else { return false }
        switch event.keyCode {
        case 53:
            cancelAndHide()
            return true
        case 36, 76:
            confirmAndHide()
            return true
        case 123:
            moveSelection(by: -1)
            return true
        case 124:
            moveSelection(by: 1)
            return true
        case 125:
            moveSelectionDown()
            return true
        case 126:
            moveSelectionUp()
            return true
        default:
            break
        }

        if currentStyle == .commandPalette {
            if event.keyCode == 51 {
                deleteSearchCharacter()
                return true
            }
            if let character = searchableCharacter(from: event) {
                appendSearchCharacter(character)
                return true
            }
            return false
        }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let commandHeld = flags.contains(.command)
        let acceptsBare = !commandHeld && !flags.contains(.option) && !flags.contains(.control)
        guard let action = SwitcherQuickAction.action(
            forKeyCode: Int64(event.keyCode),
            keyEquivalent: event.charactersIgnoringModifiers,
            commandHeld: commandHeld,
            acceptsBareShortcut: acceptsBare
        ) else {
            return false
        }
        performQuickAction(action)
        return true
    }

    private func searchableCharacter(from event: NSEvent) -> String? {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .function])
        guard !flags.contains(.option), !flags.contains(.control), !flags.contains(.function),
              let characters = event.charactersIgnoringModifiers,
              characters.count == 1,
              let scalar = characters.unicodeScalars.first,
              scalar.value >= 32,
              scalar.value != 127 else {
            return nil
        }
        return String(scalar)
    }

    private func showManagementMenu() {
        if let hovered = viewModel.hoveredIndex, viewModel.items.indices.contains(hovered) {
            session?.selectIndex(hovered)
            viewModel.selectedIndex = hovered
        }
        guard selectedItem() != nil else { return }

        let menu = NSMenu(title: "Window Actions")
        for action in WindowManagementAction.allCases {
            let availability = managementActionAvailability(action)
            let item = NSMenuItem(
                title: action.title,
                action: #selector(handleManagementMenuItem(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = action.rawValue
            item.isEnabled = availability.isSupported
            item.toolTip = availability.reason
            menu.addItem(item)
            if action == .toggleFullscreen || action == .tileLastThird {
                menu.addItem(.separator())
            }
        }

        let point = panel.contentView?.convert(
            panel.convertPoint(fromScreen: NSEvent.mouseLocation),
            from: nil
        ) ?? .zero
        menu.popUp(positioning: nil, at: point, in: panel.contentView)
    }

    @objc private func handleManagementMenuItem(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let action = WindowManagementAction(rawValue: raw) else { return }
        performManagementAction(action)
    }

    private func selectedItem() -> SwitcherItem? {
        guard viewModel.items.indices.contains(viewModel.selectedIndex) else { return nil }
        return viewModel.items[viewModel.selectedIndex]
    }

    private func showActionAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: Ordering, commit, suppression

    private func currentFrontmostIdentity(
        availableItems: [SwitcherItem]
    ) -> SwitcherHistoryIdentity? {
        FrontmostResolution.effectiveIdentity(
            availableItems: availableItems,
            historyEntries: history.snapshot(),
            systemFrontmostIdentity: appSwitcher.currentFrontmostIdentity(),
            systemFrontmostPID: currentSystemFrontmostPID(),
            observedFrontmostPID: activeFrontmostPID,
            overrideState: frontmostOverride,
            now: ProcessInfo.processInfo.systemUptime
        )
    }

    private func commitCurrentSelection() {
        guard var session else {
            hidePanel()
            return
        }
        session.selectIndex(viewModel.selectedIndex)
        self.session = session
        let selected = session.commitSelection()

        if let pid = selected.ownerPID {
            activeFrontmostPID = pid
            setFrontmostOverride(identity: selected.historyIdentity, pid: pid)
        }
        if currentStyle == .commandPalette, !viewModel.searchQuery.isEmpty {
            searchMemory.noteSelection(
                query: viewModel.searchQuery,
                identity: selected.historyIdentity
            )
        }

        hidePanel()
        DispatchQueue.main.async { selected.activate() }
    }

    private func registerPendingSuppression(for target: SwitcherItemSuppressionTarget) {
        pendingItemSuppressions.removeAll { $0.target == target }
        pendingItemSuppressions.append(
            PendingItemSuppression(
                target: target,
                expiresAtUptime: ProcessInfo.processInfo.systemUptime + quickActionSuppressionInterval
            )
        )
    }

    private func applyingPendingSuppressions(
        to items: [SwitcherItem]
    ) -> [SwitcherItem] {
        let now = ProcessInfo.processInfo.systemUptime
        pendingItemSuppressions = pendingItemSuppressions.filter { pending in
            now <= pending.expiresAtUptime && items.contains(where: pending.matches)
        }
        return items.filter { item in
            !pendingItemSuppressions.contains { $0.matches(item) }
        }
    }

    private func animateSuppression(_ target: SwitcherItemSuppressionTarget) {
        guard var session, session.removeItems(where: target.matches) else { return }
        if session.items.isEmpty {
            hidePanel()
            return
        }
        self.session = session
        syncViewModelFromSession(animated: true)
        updateVisibleLayout()
    }

    private func scheduleRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.refreshVisibleItemsIfNeeded()
        }
    }

    private func updatePaletteFilter(_ query: String) {
        let filtered = Self.paletteFilteredItems(
            items(),
            query: query,
            rememberedStableKey: searchMemory.rememberedStableKey(for: query)
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
            session = SwitcherCycleSession(
                mode: .app,
                items: filtered,
                currentFrontmost: currentFrontmostIdentity(availableItems: filtered),
                reverse: false,
                pinsSnapshot: false
            )
        }
        syncViewModelFromSession()
        updateVisibleLayout()
    }

    static func paletteFilteredItems(
        _ items: [SwitcherItem],
        query: String,
        rememberedStableKey: String? = nil
    ) -> [SwitcherItem] {
        PaletteSearch.rankedItems(
            items,
            query: query,
            rememberedStableKey: rememberedStableKey
        )
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
        let override = FrontmostOverrideState(
            identity: identity,
            pid: pid,
            startedAtUptime: ProcessInfo.processInfo.systemUptime
        )
        frontmostOverride = override
        DispatchQueue.main.asyncAfter(deadline: .now() + FrontmostResolution.overrideGraceInterval) { [weak self] in
            guard let self, self.frontmostOverride == override else { return }
            if self.currentSystemFrontmostPID() != pid { self.frontmostOverride = nil }
        }
    }

    // MARK: Presentation

    private func showPanel(makeKey: Bool = false) {
        if viewModel.items.isEmpty, var session {
            let refreshed = items()
            guard !refreshed.isEmpty else { return }
            session.refreshItems(refreshed)
            self.session = session
            syncViewModelFromSession()
        }

        refreshPanelContentRoots()
        let targetScreen = presentationScreen()
        if let targetScreen {
            applyPanelPlacement(on: targetScreen)
        } else {
            viewModel.layout = .empty
        }
        updateBackdropPanelIfNeeded()
        updateMirroredPanelsIfNeeded(primaryScreen: targetScreen)
        panel.alphaValue = 1
        if makeKey { NSApp.activate(ignoringOtherApps: true) }
        backdropPanel.orderFrontRegardless()
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        viewModel.isVisible = true
    }

    private func hidePanel() {
        deferredPresentation.cancel()
        viewModel.isVisible = false
        panel.alphaValue = 0
        panel.orderOut(nil)
        backdropPanel.orderOut(nil)
        tearDownMirroredPanels()
        session = nil
        activeConfiguration = nil
        paletteFullItemCount = 0
        viewModel.items = []
        viewModel.selectedIndex = 0
        viewModel.radialViewportState = RadialMenuViewportState()
        viewModel.layout = .empty
        viewModel.hoveredIndex = nil
        viewModel.searchQuery = ""
    }

    private func updateVisibleLayout() {
        guard let screen = presentationScreen() else { return }
        applyPanelPlacement(on: screen)
    }

    private func presentationScreen() -> NSScreen? {
        let active = activeWindowScreen(for: viewModel.items.isEmpty ? items() : viewModel.items)
        let cursor = cursorScreen()
        switch activeConfiguration?.displayPlacement ?? preferences.displayPlacement {
        case .activeWindowDisplay:
            return active ?? cursor ?? panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        case .cursorDisplay:
            return cursor ?? active ?? panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        case .allDisplays:
            return active ?? cursor ?? panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        }
    }

    private func applyPanelPlacement(on screen: NSScreen) {
        let visibleFrame = screen.visibleFrame
        let count = max(viewModel.items.count, 1)
        let layout: SwitcherLayoutMetrics
        switch currentStyle {
        case .classicGrid:
            layout = SwitcherLayoutMetrics.make(itemCount: count, visibleFrame: visibleFrame)
        case .commandPalette:
            layout = SwitcherLayoutMetrics.makePalette(
                itemCount: max(paletteFullItemCount, count),
                visibleFrame: visibleFrame
            )
        case .radialMenu:
            layout = SwitcherLayoutMetrics.makeRadial(itemCount: count)
        }
        viewModel.layout = layout
        panel.setContentSize(NSSize(width: layout.contentWidth, height: layout.contentHeight))
        panel.setFrameOrigin(panelOrigin(on: screen, layout: layout))
        updateBackdropFrame(for: screen)
    }

    private func panelOrigin(on screen: NSScreen, layout: SwitcherLayoutMetrics) -> NSPoint {
        let visibleFrame = screen.visibleFrame
        if currentStyle == .radialMenu {
            return NSPoint(
                x: visibleFrame.midX - layout.contentWidth / 2,
                y: visibleFrame.midY - layout.contentHeight / 2
            )
        }
        let safe = visibleFrame.insetBy(dx: 18, dy: 18)
        let proposedX = visibleFrame.midX - layout.contentWidth / 2
        let proposedY = visibleFrame.midY - layout.contentHeight / 2
        return NSPoint(
            x: min(max(proposedX, safe.minX), safe.maxX - layout.contentWidth),
            y: min(max(proposedY, safe.minY), safe.maxY - layout.contentHeight)
        )
    }

    private func activeWindowScreen(for items: [SwitcherItem]) -> NSScreen? {
        guard let identity = currentFrontmostIdentity(availableItems: items),
              let frame = items.first(where: { $0.historyIdentity == identity })?.backdropFrame else {
            return nil
        }
        let center = NSPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
            ?? NSScreen.screens.first { $0.visibleFrame.intersects(frame) }
    }

    private func cursorScreen() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(point) }
    }

    private func updateBackdropFrame(for screen: NSScreen) {
        backdropPanel.setFrame(screen.frame, display: false)
        viewModel.backdropScreenFrame = screen.frame
        viewModel.backdropVisibleFrame = screen.visibleFrame
    }

    private func updateBackdropPanelIfNeeded() {
        guard viewModel.isVisible || !viewModel.items.isEmpty,
              preferences.showSelectedPreviewBackdrop,
              let screen = panel.screen ?? presentationScreen() else {
            backdropPanel.orderOut(nil)
            return
        }
        updateBackdropFrame(for: screen)
        backdropPanel.orderFrontRegardless()
    }

    private func updateMirroredPanelsIfNeeded(primaryScreen: NSScreen?) {
        guard activeConfiguration?.displayPlacement == .allDisplays,
              let primaryScreen,
              NSScreen.screens.count > 1 else {
            tearDownMirroredPanels()
            return
        }
        var activeKeys = Set<ObjectIdentifier>()
        for screen in NSScreen.screens where screen != primaryScreen {
            let key = ObjectIdentifier(screen)
            activeKeys.insert(key)
            let mirror = mirroredPanels[key] ?? buildMirrorPanel()
            mirroredPanels[key] = mirror
            mirror.setContentSize(
                NSSize(width: viewModel.layout.contentWidth, height: viewModel.layout.contentHeight)
            )
            mirror.setFrameOrigin(panelOrigin(on: screen, layout: viewModel.layout))
            mirror.orderFrontRegardless()
        }
        for (key, mirror) in mirroredPanels where !activeKeys.contains(key) {
            mirror.orderOut(nil)
            mirroredPanels.removeValue(forKey: key)
        }
    }

    private func buildMirrorPanel() -> ProductionSwitcherMirrorPanel {
        let mirror = ProductionSwitcherMirrorPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 130),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        mirror.level = .popUpMenu
        mirror.isOpaque = false
        mirror.backgroundColor = .clear
        mirror.hasShadow = false
        mirror.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        mirror.isMovable = false
        mirror.ignoresMouseEvents = true
        mirror.contentView = NSHostingView(
            rootView: ProfileSwitcherView(viewModel: viewModel, style: currentStyle)
        )
        return mirror
    }

    private func tearDownMirroredPanels() {
        mirroredPanels.values.forEach { $0.orderOut(nil) }
        mirroredPanels.removeAll()
    }
}
