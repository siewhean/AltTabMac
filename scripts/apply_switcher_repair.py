#!/usr/bin/env python3
"""Apply the protected switcher-core repair with exact, asserted replacements.

This file is intentionally removed by the companion one-time workflow after the
modified Swift package passes its macOS test suite.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def replace_once(relative_path: str, old: str, new: str) -> None:
    path = ROOT / relative_path
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(
            f"Expected exactly one match in {relative_path}, found {count}:\n{old}"
        )
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


APP_SWITCHER = "Sources/CmdTab/AppSwitcher.swift"
WINDOW_CONTROLLER = "Sources/CmdTab/SwitcherWindowController.swift"
CYCLE_TESTS = "Tests/CmdTabTests/SwitcherCycleSessionTests.swift"
ACTIVATION_TESTS = "Tests/CmdTabTests/AppSwitcherActivationTests.swift"


# Phase 2: membership is independent of thumbnail capture.
replace_once(
    APP_SWITCHER,
    """        let representedWindowPIDs = Set(context.candidates.map(\\.ownerPID))
        let representedWindowAppIdentifiers = Set(context.candidates.map(\\.sourceAppIdentifier))
        var seenFallbackAppIdentifiers = Set<String>()

        let fallbackItems: [SwitcherItem] = context.runningApps
            .sorted(by: compareApps)
""",
    """        // Membership is based on emitted items, never raw candidates. A
        // failed screenshot therefore cannot suppress both the window tile and
        // its application fallback.
        let representedWindowPIDs = Set(windowItems.compactMap(\\.historyIdentity.ownerPID))
        let representedWindowAppIdentifiers = Set(windowItems.compactMap(\\.sourceAppIdentifier))
        var seenFallbackAppIdentifiers = Set<String>()
        let fallbackHistoryEntries = history.snapshot()

        let fallbackItems: [SwitcherItem] = context.runningApps
            .sorted {
                compareApps($0, $1, historyEntries: fallbackHistoryEntries)
            }
""",
)

replace_once(
    APP_SWITCHER,
    """    static func shouldDisplayWindowItem(
        previewImage: NSImage?,
        capturePreviews: Bool,
        allowPreviewlessItems: Bool = false
    ) -> Bool {
        if previewImage != nil { return true }
        return !capturePreviews && allowPreviewlessItems
    }
""",
    """    static func shouldDisplayWindowItem(
        previewImage: NSImage?,
        capturePreviews: Bool,
        allowPreviewlessItems: Bool = false
    ) -> Bool {
        // An eligible window remains a switcher item even when Screen Recording
        // is denied, a private capture API is unavailable, or a cached preview
        // expires. The UI already renders a safe icon/placeholder state.
        _ = previewImage
        _ = capturePreviews
        _ = allowPreviewlessItems
        return true
    }
""",
)

# Phase 3: reconcile the real system identity without promoting a provisional
# quick-switch override into permanent history.
replace_once(
    APP_SWITCHER,
    """    func currentFrontmostIdentity() -> SwitcherHistoryIdentity? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        return currentFrontmostIdentity(for: app)
    }

""",
    """    func currentFrontmostIdentity() -> SwitcherHistoryIdentity? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        return currentFrontmostIdentity(for: app)
    }

    @discardableResult
    func reconcileCurrentFrontmostHistory() -> SwitcherHistoryIdentity? {
        guard let identity = currentFrontmostIdentity() else { return nil }
        history.noteActivation(identity)
        return identity
    }

""",
)

replace_once(
    APP_SWITCHER,
    """        let allowedWindowIDsByPID = switcherDisplayWindowIDsByPID(for: runningApps)

        let allWindows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
""",
    """        let allowedWindowIDsByPID = switcherDisplayWindowIDsByPID(for: runningApps)
        let historyEntries = history.snapshot()

        let allWindows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
""",
)

replace_once(
    APP_SWITCHER,
    """        ).sorted(by: compareCandidates)

        let scopedCandidates = visibilityScopedCandidates(candidates)
""",
    """        ).sorted {
            compareCandidates($0, $1, historyEntries: historyEntries)
        }

        let scopedCandidates = visibilityScopedCandidates(candidates)
""",
)

replace_once(
    APP_SWITCHER,
    """    private func currentFrontmostIdentity(for app: NSRunningApplication) -> SwitcherHistoryIdentity? {
        let allowedWindowIDsByPID = switcherDisplayWindowIDsByPID(for: [app])
        let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
""",
    """    private func currentFrontmostIdentity(for app: NSRunningApplication) -> SwitcherHistoryIdentity? {
        let allowedWindowIDsByPID = switcherDisplayWindowIDsByPID(for: [app])
        let historyEntries = history.snapshot()
        let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
""",
)

replace_once(
    APP_SWITCHER,
    """        ).sorted(by: compareCandidates)

        if let focusedWindowID = focusedWindowID(for: app.processIdentifier) {
""",
    """        ).sorted {
            compareCandidates($0, $1, historyEntries: historyEntries)
        }

        if let focusedWindowID = focusedWindowID(for: app.processIdentifier) {
""",
)

replace_once(
    APP_SWITCHER,
    """    private func compareCandidates(_ lhs: WindowCandidate, _ rhs: WindowCandidate) -> Bool {
        let lhsRank = history.rank(of: lhs.historyIdentity)
        let rhsRank = history.rank(of: rhs.historyIdentity)

        switch (lhsRank, rhsRank) {
        case let (.some(l), .some(r)) where l != r: return l < r
        case (.some, .none): return true
        case (.none, .some): return false
        default: break
        }

        if lhs.sortScore != rhs.sortScore { return lhs.sortScore > rhs.sortScore }
        return lhs.orderIndex < rhs.orderIndex
    }

    private func compareApps(_ lhs: NSRunningApplication, _ rhs: NSRunningApplication) -> Bool {
        let lhsIdentity = SwitcherHistoryIdentity.appFallback(bundleID: sourceAppIdentifier(for: lhs), pid: lhs.processIdentifier)
        let rhsIdentity = SwitcherHistoryIdentity.appFallback(bundleID: sourceAppIdentifier(for: rhs), pid: rhs.processIdentifier)

        let lhsRank = history.rank(of: lhsIdentity) ?? history.rankForApp(bundleID: lhs.bundleIdentifier, pid: lhs.processIdentifier) ?? Int.max
        let rhsRank = history.rank(of: rhsIdentity) ?? history.rankForApp(bundleID: rhs.bundleIdentifier, pid: rhs.processIdentifier) ?? Int.max

        if lhsRank != rhsRank { return lhsRank < rhsRank }
        return (lhs.localizedName ?? "") < (rhs.localizedName ?? "")
    }
""",
    """    private func compareCandidates(
        _ lhs: WindowCandidate,
        _ rhs: WindowCandidate,
        historyEntries: [SwitcherHistoryIdentity]
    ) -> Bool {
        let lhsRank = historyEntries.firstIndex(of: lhs.historyIdentity)
        let rhsRank = historyEntries.firstIndex(of: rhs.historyIdentity)

        switch (lhsRank, rhsRank) {
        case let (.some(l), .some(r)) where l != r: return l < r
        case (.some, .none): return true
        case (.none, .some): return false
        default: break
        }

        if lhs.sortScore != rhs.sortScore { return lhs.sortScore > rhs.sortScore }
        return lhs.orderIndex < rhs.orderIndex
    }

    private func compareApps(
        _ lhs: NSRunningApplication,
        _ rhs: NSRunningApplication,
        historyEntries: [SwitcherHistoryIdentity]
    ) -> Bool {
        func rank(for app: NSRunningApplication) -> Int {
            let identity = SwitcherHistoryIdentity.appFallback(
                bundleID: sourceAppIdentifier(for: app),
                pid: app.processIdentifier
            )
            return historyEntries.firstIndex(of: identity)
                ?? historyEntries.firstIndex {
                    $0.matches(
                        bundleID: app.bundleIdentifier,
                        pid: app.processIdentifier
                    )
                }
                ?? Int.max
        }

        let lhsRank = rank(for: lhs)
        let rhsRank = rank(for: rhs)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        return (lhs.localizedName ?? "") < (rhs.localizedName ?? "")
    }
""",
)

# Phase 4: prefer the intended fallback window and record only verified success.
replace_once(
    APP_SWITCHER,
    """        var value: CFTypeRef?
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
           let windows = value as? [AXUIElement], let first = windows.first {
            raiseWindow(first, ownerPID: app.processIdentifier)
        }
""",
    """        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let preferredWindows = [
            preferredWindow(for: axApp, attribute: kAXFocusedWindowAttribute as CFString),
            preferredWindow(for: axApp, attribute: kAXMainWindowAttribute as CFString),
        ].compactMap { $0 }

        if let preferred = preferredWindows.first(where: { isStandardWindow($0) }) {
            raiseWindow(preferred, ownerPID: app.processIdentifier)
        } else {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
               let windows = value as? [AXUIElement],
               let target = windows.first(where: { isStandardWindow($0) }) ?? windows.first {
                raiseWindow(target, ownerPID: app.processIdentifier)
            }
        }
""",
)

replace_once(
    APP_SWITCHER,
    """    private func scheduleWindowFocusRetry(for candidate: WindowCandidate, attempt: Int) {
        guard attempt < activationRetryLimit else { return }
        let delay = 0.05 + Double(attempt) * 0.08
""",
    """    private func scheduleWindowFocusRetry(for candidate: WindowCandidate, attempt: Int) {
        guard attempt < activationRetryLimit else {
            if clearPendingActivation(candidate.ownerPID) {
                os_log(
                    .error,
                    log: appSwitcherLog,
                    "Window activation failed after retries (pid=%{public}d, window=%{public}u)",
                    candidate.ownerPID,
                    candidate.id
                )
            }
            return
        }
        let delay = 0.05 + Double(attempt) * 0.08
""",
)

replace_once(
    APP_SWITCHER,
    """        guard attempt < activationRetryLimit else {
            // Retries exhausted — record the history anyway so recency ordering
            // stays correct even when the app was slow to become frontmost.
            confirmActivation(identity: identity, pid: app.processIdentifier)
            return
        }
""",
    """        guard attempt < activationRetryLimit else {
            if clearPendingActivation(app.processIdentifier) {
                os_log(
                    .error,
                    log: appSwitcherLog,
                    "Application activation failed after retries (pid=%{public}d)",
                    app.processIdentifier
                )
            }
            return
        }
""",
)

replace_once(
    APP_SWITCHER,
    """        guard attempt < activationRetryLimit,
              let app = NSRunningApplication(processIdentifier: candidate.ownerPID) else {
            // Retries exhausted — if the app is at least frontmost, confirm with
            // whatever identity we have so the history still gets updated.
            if currentSystemFrontmostPID() == candidate.ownerPID {
                confirmActivation(identity: candidate.historyIdentity, pid: candidate.ownerPID)
            }
            return
        }
""",
    """        guard attempt < activationRetryLimit,
              let app = NSRunningApplication(processIdentifier: candidate.ownerPID) else {
            if clearPendingActivation(candidate.ownerPID) {
                os_log(
                    .error,
                    log: appSwitcherLog,
                    "Exact window activation failed after retries (pid=%{public}d, window=%{public}u)",
                    candidate.ownerPID,
                    candidate.id
                )
            }
            return
        }
""",
)

# Session start reconciles only the real OS identity; commit creates a short
# provisional override for immediate re-presses but does not persist history.
replace_once(
    WINDOW_CONTROLLER,
    """    private func items() -> [SwitcherItem] {
        let rawItems = appSwitcher.getItems()
        let visibleItems = applyingPendingSuppressions(to: rawItems)
        let currentFrontmost = currentFrontmostIdentity(availableItems: visibleItems)
        return SwitcherOrdering.orderedItems(visibleItems, history: history, currentFrontmost: currentFrontmost)
    }
""",
    """    private func items() -> [SwitcherItem] {
        let rawItems = appSwitcher.getItems()
        let visibleItems = applyingPendingSuppressions(to: rawItems)
        _ = appSwitcher.reconcileCurrentFrontmostHistory()
        let currentFrontmost = currentFrontmostIdentity(availableItems: visibleItems)
        return SwitcherOrdering.orderedItems(
            visibleItems,
            history: history,
            currentFrontmost: currentFrontmost
        )
    }
""",
)

replace_once(
    WINDOW_CONTROLLER,
    """        let selectedItem = session.commitSelection()

        let rememberedQuery = preferences.switcherStyle == .commandPalette ? viewModel.searchQuery : ""
""",
    """        let selectedItem = session.commitSelection()

        // Make an immediate second trigger deterministic while AppKit and
        // NSWorkspace finish activation. This is deliberately provisional:
        // AppSwitcher writes permanent MRU only after exact focus confirmation.
        if let pid = selectedItem.historyIdentity.ownerPID {
            activeFrontmostPID = pid
            setFrontmostOverride(identity: selectedItem.historyIdentity, pid: pid)
        }

        let rememberedQuery = preferences.switcherStyle == .commandPalette ? viewModel.searchQuery : ""
""",
)

# Replace contradictory tests with the protected behavior contract.
replace_once(
    CYCLE_TESTS,
    """    func testInitialSelectionSkipsOtherWindowsFromCurrentApp() throws {
        let notebookLM = makeItem(title: "NotebookLM", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 21))
        let arcWindow = makeItem(title: "Arc Window", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22))
        let finder = makeItem(title: "Finder", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11))

        let session = try XCTUnwrap(
            SwitcherCycleSession(
                mode: .app,
                items: [arcWindow, finder, notebookLM],
                currentFrontmost: notebookLM.historyIdentity,
                reverse: false,
                pinsSnapshot: true
            )
        )

        XCTAssertEqual(session.commitSelection().title, "Finder")
    }
""",
    """    func testInitialSelectionFollowsStrictMRUEvenForSameApplication() throws {
        let notebookLM = makeItem(title: "NotebookLM", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 21))
        let arcWindow = makeItem(title: "Arc Window", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22))
        let finder = makeItem(title: "Finder", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11))

        let session = try XCTUnwrap(
            SwitcherCycleSession(
                mode: .app,
                items: [arcWindow, finder, notebookLM],
                currentFrontmost: notebookLM.historyIdentity,
                reverse: false,
                pinsSnapshot: true
            )
        )

        XCTAssertEqual(session.commitSelection().title, "Arc Window")
    }
""",
)

replace_once(
    ACTIVATION_TESTS,
    """    func testPreviewlessWindowTilesAreDroppedInFinalThumbnailPass() {
        XCTAssertFalse(AppSwitcher.shouldDisplayWindowItem(previewImage: nil, capturePreviews: true))
        XCTAssertTrue(AppSwitcher.shouldDisplayWindowItem(previewImage: NSImage(size: NSSize(width: 10, height: 10)), capturePreviews: true))
        XCTAssertFalse(AppSwitcher.shouldDisplayWindowItem(previewImage: nil, capturePreviews: false))
        XCTAssertTrue(AppSwitcher.shouldDisplayWindowItem(previewImage: nil, capturePreviews: false, allowPreviewlessItems: true))
    }
""",
    """    func testPreviewlessWindowTilesRemainVisibleInEveryCachePhase() {
        XCTAssertTrue(AppSwitcher.shouldDisplayWindowItem(previewImage: nil, capturePreviews: true))
        XCTAssertTrue(AppSwitcher.shouldDisplayWindowItem(previewImage: NSImage(size: NSSize(width: 10, height: 10)), capturePreviews: true))
        XCTAssertTrue(AppSwitcher.shouldDisplayWindowItem(previewImage: nil, capturePreviews: false))
        XCTAssertTrue(AppSwitcher.shouldDisplayWindowItem(previewImage: nil, capturePreviews: false, allowPreviewlessItems: true))
    }
""",
)

print("Applied switcher repair replacements successfully.")
