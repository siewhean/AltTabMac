import XCTest
@testable import CmdTab

final class SwitcherOrderingTests: XCTestCase {
    func testCurrentFrontmostMovesToEndAndKeepsInterleavedOrder() {
        let finderAIdentity = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 11)
        let arcIdentity = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 22)
        let finderBIdentity = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 33)

        let rawItems = [
            makeItem(title: "Finder A", appID: "com.apple.finder", identity: finderAIdentity),
            makeItem(title: "Arc", appID: "company.thebrowser.Browser", identity: arcIdentity),
            makeItem(title: "Finder B", appID: "com.apple.finder", identity: finderBIdentity),
        ]

        let ordered = SwitcherOrdering.orderedItems(
            rawItems,
            historyEntries: [finderBIdentity, arcIdentity, finderAIdentity],
            currentFrontmost: finderBIdentity
        )

        XCTAssertEqual(ordered.map(\.title), ["Arc", "Finder A", "Finder B"])
    }

    func testOrderingDoesNotLimitRepeatedApplications() {
        let rawItems = [
            makeItem(title: "Finder 1", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11)),
            makeItem(title: "Arc 1", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 21)),
            makeItem(title: "Finder 2", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 12)),
            makeItem(title: "Calendar", appID: "com.apple.iCal", identity: .appWindow(pid: 303, windowID: 31)),
            makeItem(title: "Finder 3", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 13)),
            makeItem(title: "Finder 4", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 14)),
            makeItem(title: "Arc 2", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22)),
        ]

        let ordered = SwitcherOrdering.orderedItems(
            rawItems,
            historyEntries: rawItems.map(\.historyIdentity),
            currentFrontmost: nil
        )

        XCTAssertEqual(ordered.map(\.title), ["Finder 1", "Arc 1", "Finder 2", "Calendar", "Finder 3", "Finder 4", "Arc 2"])
    }

    // MARK: - New interleaving & ordering tests

    /// Finder W1 (rank 0), Arc (rank 1), Finder W2 (rank 2).
    /// Frontmost = Finder W1 → moved to end.
    /// Expected: [Arc, Finder W2, Finder W1]
    func testInterleavedMRUOrderWithMultipleWindowsSameApp() {
        let finderW1 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let arc      = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)
        let finderW2 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 3)

        let rawItems = [
            makeItem(title: "Finder W1", appID: "com.apple.finder", identity: finderW1),
            makeItem(title: "Arc",       appID: "company.thebrowser.Browser", identity: arc),
            makeItem(title: "Finder W2", appID: "com.apple.finder", identity: finderW2),
        ]

        let ordered = SwitcherOrdering.orderedItems(
            rawItems,
            historyEntries: [finderW1, arc, finderW2],
            currentFrontmost: finderW1
        )

        XCTAssertEqual(ordered.map(\.title), ["Arc", "Finder W2", "Finder W1"])
    }

    func testLeadingWindowsFromCurrentAppStayInStrictRecencyOrder() {
        let notebookLM = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 21)
        let arcWindow  = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 22)
        let finder     = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 11)

        let rawItems = [
            makeItem(title: "NotebookLM", appID: "company.thebrowser.Browser", identity: notebookLM),
            makeItem(title: "Arc Window", appID: "company.thebrowser.Browser", identity: arcWindow),
            makeItem(title: "Finder", appID: "com.apple.finder", identity: finder),
        ]

        let ordered = SwitcherOrdering.orderedItems(
            rawItems,
            historyEntries: [notebookLM, arcWindow, finder],
            currentFrontmost: arcWindow
        )

        XCTAssertEqual(ordered.map(\.title), ["NotebookLM", "Finder", "Arc Window"])
    }

    /// Items with no history entries keep their original array offset order
    /// (no implicit per-app grouping by score proximity).
    func testNoHistoryFallbackPreservesOffsetOrderNotAppGrouping() {
        let finderW1 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 10)
        let arc      = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 20)
        let finderW2 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 30)
        let safari   = SwitcherHistoryIdentity.appWindow(pid: 303, windowID: 40)

        let rawItems = [
            makeItem(title: "Finder W1", appID: "com.apple.finder",              identity: finderW1),
            makeItem(title: "Arc",       appID: "company.thebrowser.Browser",    identity: arc),
            makeItem(title: "Finder W2", appID: "com.apple.finder",              identity: finderW2),
            makeItem(title: "Safari",    appID: "com.apple.Safari",              identity: safari),
        ]

        // No history → ordering by offset (original array order)
        let ordered = SwitcherOrdering.orderedItems(
            rawItems,
            historyEntries: [],
            currentFrontmost: nil
        )

        XCTAssertEqual(ordered.map(\.title), ["Finder W1", "Arc", "Finder W2", "Safari"])
    }

    func testWindowTilesDoNotUseAppLevelFallbackThatGroupsRepeatedApps() {
        let finderW1 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 10)
        let arcW1    = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 20)
        let finderW2 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 30)

        let rawItems = [
            makeItem(title: "Finder W1", appID: "com.apple.finder", identity: finderW1),
            makeItem(title: "Arc", appID: "company.thebrowser.Browser", identity: arcW1),
            makeItem(title: "Finder W2", appID: "com.apple.finder", identity: finderW2),
        ]

        let ordered = SwitcherOrdering.orderedItems(
            rawItems,
            historyEntries: [
                .appFallback(bundleID: "com.apple.finder", pid: 101),
                .appFallback(bundleID: "company.thebrowser.Browser", pid: 202),
            ],
            currentFrontmost: nil
        )

        XCTAssertEqual(ordered.map(\.title), ["Finder W1", "Arc", "Finder W2"])
    }

    func testSingleVisibleTileCanUseAppLevelFallbackWhenWindowIdentityChanges() {
        let pdfGearCurrent = SwitcherHistoryIdentity.appWindow(pid: 707, windowID: 71)
        let notebookLMCurrent = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 21)
        let telegramCurrent = SwitcherHistoryIdentity.appWindow(pid: 303, windowID: 31)

        let staleHistoryInActivationOrder = [
            SwitcherHistoryIdentity.appWindow(pid: 303, windowID: 3001),
            SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2001),
            SwitcherHistoryIdentity.appWindow(pid: 707, windowID: 7001),
        ]

        let rawItems = [
            makeItem(title: "Telegram", appID: "ru.keepcoder.Telegram", identity: telegramCurrent),
            makeItem(title: "NotebookLM", appID: "company.thebrowser.Browser", identity: notebookLMCurrent),
            makeItem(title: "PDFgear", appID: "com.pdfgear.PDFgear", identity: pdfGearCurrent),
        ]

        let store = SwitcherHistoryStore()
        staleHistoryInActivationOrder.forEach { store.noteActivation($0) }

        let ordered = SwitcherOrdering.orderedItems(
            rawItems,
            history: store,
            currentFrontmost: pdfGearCurrent
        )

        XCTAssertEqual(ordered.map(\.title), ["NotebookLM", "Telegram", "PDFgear"])
    }

    func testMultipleVisibleWindowsUseMostRecentVisibleSamePIDFrontmostFallback() {
        let finderW1 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 11)
        let arc = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 22)
        let finderW2 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 33)

        let rawItems = [
            makeItem(title: "Finder W2", appID: "com.apple.finder", identity: finderW2),
            makeItem(title: "Arc", appID: "company.thebrowser.Browser", identity: arc),
            makeItem(title: "Finder W1", appID: "com.apple.finder", identity: finderW1),
        ]

        let resolvedFrontmost = FrontmostResolution.effectiveIdentity(
            availableItems: rawItems,
            historyEntries: [finderW1, arc, finderW2],
            systemFrontmostIdentity: nil,
            systemFrontmostPID: 101,
            observedFrontmostPID: 101,
            overrideState: nil,
            now: 18.0
        )

        let ordered = SwitcherOrdering.orderedItems(
            rawItems,
            historyEntries: [finderW1, arc, finderW2],
            currentFrontmost: resolvedFrontmost
        )

        XCTAssertEqual(resolvedFrontmost, finderW1)
        XCTAssertEqual(ordered.map(\.title), ["Arc", "Finder W2", "Finder W1"])
    }

    /// Simulate Finder → Arc → Finder usage pattern.
    /// History = [Finder, Arc] (same window, deduplicated).
    /// Frontmost = Finder → moved to end.
    /// Expected first selection: Arc (not Finder again).
    func testFinderArcFinderPatternSelectsArcNotFinderAgain() {
        let finder = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let arc    = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)

        let rawItems = [
            makeItem(title: "Finder", appID: "com.apple.finder",           identity: finder),
            makeItem(title: "Arc",    appID: "company.thebrowser.Browser", identity: arc),
        ]

        // After Finder→Arc→Finder: history = [Finder (rank 0), Arc (rank 1)]
        let ordered = SwitcherOrdering.orderedItems(
            rawItems,
            historyEntries: [finder, arc],
            currentFrontmost: finder
        )

        // Finder moved to end; Arc is index 0 (the item to switch to)
        XCTAssertEqual(ordered.map(\.title), ["Arc", "Finder"])
        XCTAssertEqual(ordered.first?.title, "Arc")
    }

    /// After eager history note + second session with updated frontmost,
    /// selection skips the just-activated app.
    func testEagerHistoryNoteSecondSessionSkipsJustActivatedApp() {
        let finder = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let arc    = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)
        let safari = SwitcherHistoryIdentity.appWindow(pid: 303, windowID: 3)

        // First session: frontmost = Finder, history = [Finder, Arc, Safari]
        // After eager note for "Arc" selection: history = [Arc, Finder, Safari]
        let secondOrdered = SwitcherOrdering.orderedItems(
            [
                makeItem(title: "Finder", appID: "com.apple.finder",           identity: finder),
                makeItem(title: "Arc",    appID: "company.thebrowser.Browser", identity: arc),
                makeItem(title: "Safari", appID: "com.apple.Safari",           identity: safari),
            ],
            historyEntries: [arc, finder, safari],  // arc already noted eagerly
            currentFrontmost: arc                    // arc is now frontmost
        )

        // Arc is moved to end; Finder is index 0
        XCTAssertEqual(secondOrdered.map(\.title), ["Finder", "Safari", "Arc"])
        XCTAssertEqual(secondOrdered.first?.title, "Finder")
    }

    func testPaletteFilteringMatchesAppName() {
        // subtitle = app name; title = window title. Filtering matches on app name (subtitle).
        let items = [
            makeItem(title: "Calendar", appName: "Calendar", appID: "com.apple.iCal", identity: .appWindow(pid: 101, windowID: 1)),
            makeItem(title: "System Settings", appName: "System Settings", appID: "com.apple.systempreferences", identity: .appWindow(pid: 202, windowID: 2)),
            makeItem(title: "Notes", appName: "Notes", appID: "com.apple.Notes", identity: .appWindow(pid: 303, windowID: 3)),
        ]

        XCTAssertEqual(
            SwitcherWindowController.paletteFilteredItems(items, query: "calendar").first?.title,
            "Calendar"
        )
        XCTAssertEqual(
            SwitcherWindowController.paletteFilteredItems(items, query: "system").first?.title,
            "System Settings"
        )
        XCTAssertEqual(
            SwitcherWindowController.paletteFilteredItems(items, query: "settings").first?.title,
            "System Settings"
        )
        XCTAssertEqual(
            SwitcherWindowController.paletteFilteredItems(items, query: "notes").first?.title,
            "Notes"
        )
        XCTAssertEqual(
            SwitcherWindowController.paletteFilteredItems(items, query: "").map(\.title),
            items.map(\.title)
        )
    }

    private func makeItem(title: String, appName: String? = nil, appID: String, identity: SwitcherHistoryIdentity) -> SwitcherItem {
        SwitcherItem(
            title: title,
            subtitle: appName ?? appID,
            icon: nil,
            previewImage: nil,
            historyIdentity: identity,
            sourceAppIdentifier: appID,
            kind: .appWindow
        ) {}
    }
}
