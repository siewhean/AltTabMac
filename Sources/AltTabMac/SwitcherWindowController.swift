import AppKit
import SwiftUI

/// Hosts the SwiftUI SwitcherView inside a borderless, non-activating NSPanel.
/// The panel is pre-created at launch and simply shown/hidden to eliminate latency.
final class SwitcherWindowController {

    private var panel: NSPanel!
    private let viewModel = SwitcherViewModel()
    private let appSwitcher = AppSwitcher()
    private let tabSwitcher = TabSwitcher()
    private let history = SwitcherHistoryStore.shared
    private let preferences = SwitcherPreferences.shared
    private var session: SwitcherCycleSession?

    /// PID of the app we believe is currently frontmost. Updated BOTH when
    /// we internally activate an app AND when the OS reports an external
    /// activation (user clicked on a window). Using PID instead of exact
    /// SwitcherHistoryIdentity avoids false negatives from window ID changes
    /// across cache rebuilds — PIDs are stable for a process's lifetime.
    private var activeFrontmostPID: pid_t = 0

    var isVisible: Bool { viewModel.isVisible }
    var currentMode: SwitcherMode { viewModel.mode }
    var currentStyle: SwitcherStyle { preferences.switcherStyle }

    /// Called by `handleCardClick` so HotkeyManager can clear its trigger state
    /// before the modifier-release event fires. Without this, releasing Cmd after
    /// a mouse-click commit causes a second, spurious activation.
    var onClickCommit: (() -> Void)?

    init() {
        buildPanel()
        wireDataSources()
        warmCaches(force: true)

        // Seed activeFrontmostPID from the OS's current frontmost app.
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.activationPolicy == .regular,
           frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            activeFrontmostPID = frontmost.processIdentifier
        }
    }

    // MARK: - Public API (called from HotkeyManager on main thread)

    /// Prepare or advance the hotkey-triggered session without revealing it yet.
    func prepareTriggerSession(mode: SwitcherMode, reverse: Bool = false) {
        if session?.mode != mode || session?.pinsSnapshot != true {
            viewModel.searchQuery = ""
            guard startSession(mode: mode, reverse: reverse, pinsSnapshot: true) else { return }
            return
        }

        session?.advance(reverse: reverse)
        syncViewModelSelection()
    }

    func revealPreparedTriggerSession() {
        guard session != nil else { return }
        syncViewModelFromSession()
        showPanel()
    }

    func showStandalone(mode: SwitcherMode) {
        guard startSession(mode: mode, reverse: false, pinsSnapshot: false) else { return }
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

    func cancelPreparedOrVisibleSession() {
        if viewModel.isVisible {
            hidePanel()
        } else {
            resetSessionState()
        }
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
        let panel = NSPanel(
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

    private func makeSession(mode: SwitcherMode, reverse: Bool, pinsSnapshot: Bool) -> SwitcherCycleSession? {
        let snapshot = items(for: mode)
        let currentFrontmost = currentFrontmostIdentity(for: mode, availableItems: snapshot)
        return SwitcherCycleSession(
            mode: mode,
            items: snapshot,
            currentFrontmost: currentFrontmost,
            reverse: reverse,
            pinsSnapshot: pinsSnapshot
        )
    }

    private func startSession(mode: SwitcherMode, reverse: Bool, pinsSnapshot: Bool) -> Bool {
        guard let newSession = makeSession(mode: mode, reverse: reverse, pinsSnapshot: pinsSnapshot) else { return false }
        session = newSession
        syncViewModelFromSession()
        return true
    }

    private func wireDataSources() {
        appSwitcher.onItemsChanged = { [weak self] _ in
            self?.refreshVisibleItemsIfNeeded(triggeredBy: .app)
        }

        tabSwitcher.onItemsChanged = { [weak self] _ in
            self?.refreshVisibleItemsIfNeeded(triggeredBy: .tab)
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
        }

        NotificationCenter.default.addObserver(
            forName: SwitcherPreferences.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.warmCaches(force: true)
            self?.refreshVisibleItemsIfNeeded(triggeredBy: self?.viewModel.mode ?? .app)
        }
    }

    private func warmCaches(force: Bool = false) {
        appSwitcher.warmCache(force: force)
        tabSwitcher.warmCache(force: force || preferences.includeTabsInAppSwitcher || preferences.primaryMode == .tab)
    }

    private func items(for mode: SwitcherMode) -> [SwitcherItem] {
        let rawItems: [SwitcherItem]
        switch mode {
        case .app:
            var items = appSwitcher.getItems()
            if preferences.includeTabsInAppSwitcher {
                let tabItems = limitedRecentTabItems(tabSwitcher.getItems())
                let uniqueTabItems = tabItems.filter { tabItem in
                    !items.contains { $0.dedupeKey == tabItem.dedupeKey }
                }
                items.append(contentsOf: uniqueTabItems)
            }
            rawItems = items
        case .tab:
            rawItems = limitedRecentTabItems(tabSwitcher.getItems())
        }

        let currentFrontmost = currentFrontmostIdentity(for: mode, availableItems: rawItems)
        return SwitcherOrdering.orderedItems(rawItems, history: history, currentFrontmost: currentFrontmost)
    }

    private func refreshVisibleItemsIfNeeded(triggeredBy mode: SwitcherMode) {
        guard viewModel.isVisible, var session else { return }
        guard mode == session.mode || (session.mode == .app && preferences.includeTabsInAppSwitcher && mode == .tab) else { return }
        guard !session.pinsSnapshot else { return }

        let refreshedItems = items(for: session.mode)
        guard !refreshedItems.isEmpty else { return }
        session.refreshItems(refreshedItems)
        self.session = session
        syncViewModelFromSession()

        if let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main {
            viewModel.layout = SwitcherLayoutMetrics.make(itemCount: refreshedItems.count, visibleFrame: screen.visibleFrame)
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

    private func limitedRecentTabItems(_ items: [SwitcherItem]) -> [SwitcherItem] {
        let limit = preferences.maxRecentTabs
        guard limit > 0 else { return items }

        return SwitcherTabLimiting.limitedRecentTabs(
            items,
            historyEntries: history.snapshot(),
            currentFrontmost: tabSwitcher.currentFrontmostIdentity(),
            limit: limit
        )
    }

    /// Determine which identity represents the "currently active" app/window
    /// so that `orderedItems` can move it to the end of the list.
    ///
    /// Uses PID-based matching against `activeFrontmostPID` — this is robust
    /// because PIDs are stable for a process's lifetime, unlike window IDs
    /// which can change across cache rebuilds. Falls back to the OS report
    /// only if PID matching finds nothing in the available items.
    private func currentFrontmostIdentity(for mode: SwitcherMode, availableItems: [SwitcherItem]) -> SwitcherHistoryIdentity? {
        // 1. PID-based lookup: find the highest-ranked (most recent) item
        //    belonging to the app we know is frontmost. This works even when
        //    window IDs changed since we last activated.
        let pid = activeFrontmostPID
        if pid != 0 {
            // Among items matching this PID, prefer the one with the best
            // (lowest) history rank — that's the specific window the user
            // most recently interacted with.
            let historyEntries = history.snapshot()
            let matching = availableItems.filter { $0.historyIdentity.ownerPID == pid }
            if !matching.isEmpty {
                let best = matching.min { lhs, rhs in
                    let lhsRank = historyEntries.firstIndex(of: lhs.historyIdentity) ?? Int.max
                    let rhsRank = historyEntries.firstIndex(of: rhs.historyIdentity) ?? Int.max
                    return lhsRank < rhsRank
                }
                if let best {
                    return best.historyIdentity
                }
            }
        }

        // 2. Fallback: ask the data sources for the OS-level frontmost.
        switch mode {
        case .tab:
            return tabSwitcher.currentFrontmostIdentity()
        case .app:
            if preferences.includeTabsInAppSwitcher,
               let tabIdentity = tabSwitcher.currentFrontmostIdentity(),
               availableItems.contains(where: { $0.historyIdentity == tabIdentity }) {
                return tabIdentity
            }
            return appSwitcher.currentFrontmostIdentity()
        }
    }

    /// - Parameter makeKey: Pass `true` when showing via menu-bar / standalone click so
    ///   the panel becomes the key window and SwiftUI tap gestures fire correctly.
    ///   Pass `false` (default) when showing via ⌘Tab so the current app stays key.
    private func showPanel(makeKey: Bool = false) {
        guard !viewModel.items.isEmpty else { return }

        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { $0.visibleFrame.contains(mouseLocation) }) ?? NSScreen.main

        if let screen = targetScreen {
            let visibleFrame = screen.visibleFrame
            let style = preferences.switcherStyle

            // Choose the layout metrics for the active style.
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

            // Choose the panel origin for the active style.
            let ox: CGFloat
            let oy: CGFloat
            switch style {
            case .radialMenu:
                // Centre the radial panel on the cursor, constrained to the screen.
                let inset = visibleFrame.insetBy(dx: layout.contentWidth / 2, dy: layout.contentHeight / 2)
                ox = min(max(mouseLocation.x - layout.contentWidth / 2, inset.minX), inset.maxX)
                oy = min(max(mouseLocation.y - layout.contentHeight / 2, inset.minY), inset.maxY)
            default:
                // Centre all other styles on the screen.
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
            // Standalone / menu-bar mode: activate the app and make the panel
            // the key window so SwiftUI gesture recognisers receive mouse events.
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else {
            // Hotkey mode: keep the current app active, just overlay the panel.
            panel.orderFrontRegardless()
        }
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
        viewModel.searchQuery = ""   // clear palette search so next open is fresh
    }

    /// Filter `viewModel.items` to rows matching `query`, then reset selection.
    /// Navigation (arrows, Tab) operates on the already-filtered item list so
    /// no changes to SwitcherCycleSession or HotkeyManager are needed.
    private func updatePaletteFilter(_ query: String) {
        let allItems = items(for: viewModel.mode)
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

        // Eagerly record the selection in history BEFORE hiding the panel.
        // This ensures that if the user presses Cmd+Tab again immediately,
        // the next session's orderedItems already sees the correct MRU order
        // and moves the just-selected app to the end of the list.
        history.noteActivation(selectedItem.historyIdentity)

        // Record the PID we're about to activate. This is the critical fix:
        // using PID (not exact identity) means even if the cache rebuilds with
        // different window IDs, we still correctly identify the frontmost app.
        if let pid = selectedItem.historyIdentity.ownerPID {
            activeFrontmostPID = pid
        }

        hidePanel()
        activateSelection(selectedItem)
    }

    private func activateSelection(_ item: SwitcherItem) {
        // Activate SYNCHRONOUSLY — no delay. The panel is already hidden
        // (orderOut is synchronous) and the panel is .nonactivatingPanel so
        // NSApp was never the frontmost app. Any delay here directly translates
        // to user-perceived lag AND creates a race window where the next
        // Cmd+Tab sees stale state.
        item.activate()
    }
}
