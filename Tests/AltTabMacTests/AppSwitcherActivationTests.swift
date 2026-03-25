import XCTest
@testable import AltTabMac

/// Tests for SwitcherHistoryStore and the activation/ordering logic that
/// ensures subsequent app switches work correctly and windows are ordered in
/// true MRU order rather than grouped by application.
final class AppSwitcherActivationTests: XCTestCase {

    // MARK: - SwitcherHistoryStore deduplication

    func testNoteActivationSameIdentityTwiceKeepsItAtRankZero() {
        let store = SwitcherHistoryStore()
        let identity = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        store.noteActivation(identity)
        store.noteActivation(identity)

        XCTAssertEqual(store.rank(of: identity), 0)
        XCTAssertEqual(store.snapshot().count, 1, "Duplicate entries must be deduplicated")
    }

    func testNoteActivationMovesPreviousEntryToFront() {
        let store = SwitcherHistoryStore()
        let finder = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let arc    = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)

        store.noteActivation(finder)
        store.noteActivation(arc)
        XCTAssertEqual(store.rank(of: arc),    0)
        XCTAssertEqual(store.rank(of: finder), 1)

        // Re-activate finder → it moves to rank 0
        store.noteActivation(finder)
        XCTAssertEqual(store.rank(of: finder), 0)
        XCTAssertEqual(store.rank(of: arc),    1)
    }

    // MARK: - Finder → Arc → Finder scenario

    /// Using Finder, then Arc, then Finder again (same window) should result in
    /// history [Finder (rank 0), Arc (rank 1)] — no duplicate entries.
    func testFinderArcFinderHistoryHasNoDuplicates() {
        let store = SwitcherHistoryStore()
        let finder = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let arc    = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)

        store.noteActivation(finder)  // Finder
        store.noteActivation(arc)     // Arc
        store.noteActivation(finder)  // Finder again

        XCTAssertEqual(store.snapshot().count, 2)
        XCTAssertEqual(store.rank(of: finder), 0)
        XCTAssertEqual(store.rank(of: arc),    1)
    }

    /// When the switcher presents items after the Finder→Arc→Finder pattern,
    /// the first item in the ordered list should be Arc (the app to switch TO),
    /// not Finder again.
    func testFinderArcFinderOrderingSelectsArcFirst() {
        let store  = SwitcherHistoryStore()
        let finder = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let arc    = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)

        store.noteActivation(finder)
        store.noteActivation(arc)
        store.noteActivation(finder)  // Back to Finder

        let items = [
            makeItem(title: "Finder", identity: finder),
            makeItem(title: "Arc",    identity: arc),
        ]

        let ordered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: finder)
        // Finder (frontmost) moved to end; first item = Arc
        XCTAssertEqual(ordered.map(\.title), ["Arc", "Finder"])
    }

    // MARK: - Eager history note (quick re-press scenario)

    /// Simulates the user pressing Cmd+Tab twice quickly.
    /// After the first commit (which eagerly notes Arc in history),
    /// the second session should see Arc as the frontmost and offer Finder first.
    func testQuickRePressAfterEagerHistoryNoteOffersCorrectApp() {
        let store  = SwitcherHistoryStore()
        let finder = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let arc    = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)
        let safari = SwitcherHistoryIdentity.appWindow(pid: 303, windowID: 3)

        // Initial state: Finder is frontmost, history = [Finder, Arc, Safari]
        store.noteActivation(safari)
        store.noteActivation(arc)
        store.noteActivation(finder)

        // First Cmd+Tab: items ordered with Finder at end → Arc selected
        let firstItems = [
            makeItem(title: "Finder", identity: finder),
            makeItem(title: "Arc",    identity: arc),
            makeItem(title: "Safari", identity: safari),
        ]
        let firstOrdered = SwitcherOrdering.orderedItems(firstItems, history: store, currentFrontmost: finder)
        XCTAssertEqual(firstOrdered.first?.title, "Arc")

        // Eager history note: record Arc BEFORE the async activation fires
        store.noteActivation(arc)
        // History is now: [Arc, Finder, Safari]

        // Second Cmd+Tab arrives before Arc fully activates.
        // frontmostApplication might still report Finder, but after eager note
        // the ordering sees Arc at rank 0 → moved to end → Finder offered first.
        let secondItems = firstItems  // same item list, fresh ordering
        let secondOrdered = SwitcherOrdering.orderedItems(secondItems, history: store, currentFrontmost: arc)
        XCTAssertEqual(secondOrdered.first?.title, "Finder")
    }

    // MARK: - Double-noting suppression logic

    /// Simulates what happens WITHOUT suppression: appActivated fires and notes
    /// Finder W2 (wrong window), overriding Finder W1 that activateWindow noted.
    /// This test documents the BUGGY behaviour so the pendingActivationPID fix
    /// can be verified by the absence of this sequence.
    func testWithoutSuppressionWrongWindowGetsGrouped() {
        let store    = SwitcherHistoryStore()
        let finderW1 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let finderW2 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 2)
        let arc      = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 3)

        // Simulate activateWindow noting Finder W1
        store.noteActivation(finderW1)
        // Simulate appActivated (without suppression) noting Finder W2
        store.noteActivation(finderW2)
        // Arc was previously at rank 2
        store.noteActivation(arc)

        // Without suppression, both Finder windows have recent ranks
        // (finderW2=1, finderW1=2) while arc was noted before them
        store.noteActivation(finderW1)  // redo the sequence properly
        store.noteActivation(finderW2)  // appActivated overrides

        // Both Finder windows end up with ranks 0 and 1, Arc at rank 2
        XCTAssertNotNil(store.rank(of: finderW1))
        XCTAssertNotNil(store.rank(of: finderW2))
        let arcRank = store.rank(of: arc) ?? Int.max
        let finderW1Rank = store.rank(of: finderW1) ?? Int.max
        let finderW2Rank = store.rank(of: finderW2) ?? Int.max
        // Arc has a higher (worse) rank than both Finder windows → they'd appear grouped before Arc
        XCTAssertTrue(arcRank > finderW1Rank || arcRank > finderW2Rank,
                      "Without suppression, both Finder windows rank higher than Arc — the grouping bug")
    }

    /// Simulates correct behaviour WITH suppression: appActivated does NOT
    /// override the history. Only activateWindow's specific window note survives.
    func testWithSuppressionOnlyCorrectWindowNoted() {
        let store    = SwitcherHistoryStore()
        let arc      = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 3)
        let finderW1 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let finderW2 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 2)

        // Setup: Arc was used most recently, then Finder W2 less recently
        store.noteActivation(finderW2)
        store.noteActivation(arc)

        // activateWindow selects Finder W1 and notes it
        store.noteActivation(finderW1)
        // appActivated is SUPPRESSED (pendingActivationPID match) → no extra note

        // History should be [Finder W1, Arc, Finder W2] — W1 at rank 0, W2 at rank 2
        XCTAssertEqual(store.rank(of: finderW1), 0)
        XCTAssertEqual(store.rank(of: arc),      1)
        XCTAssertEqual(store.rank(of: finderW2), 2)

        // Now when showing the switcher with Finder W1 as frontmost,
        // the order should interleave: Arc, Finder W2, Finder W1(at end)
        let items = [
            makeItem(title: "Finder W1", identity: finderW1),
            makeItem(title: "Arc",       identity: arc),
            makeItem(title: "Finder W2", identity: finderW2),
        ]
        let ordered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: finderW1)
        XCTAssertEqual(ordered.map(\.title), ["Arc", "Finder W2", "Finder W1"])
    }

    // MARK: - Multiple scenarios

    /// Three distinct apps used in sequence: A, B, C.
    /// From C, switcher should offer B first, then A.
    func testThreeDistinctAppsInSequenceOffersCorrectOrder() {
        let store = SwitcherHistoryStore()
        let appA  = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let appB  = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)
        let appC  = SwitcherHistoryIdentity.appWindow(pid: 303, windowID: 3)

        store.noteActivation(appA)
        store.noteActivation(appB)
        store.noteActivation(appC)

        let items = [
            makeItem(title: "A", identity: appA),
            makeItem(title: "B", identity: appB),
            makeItem(title: "C", identity: appC),
        ]
        let ordered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: appC)
        XCTAssertEqual(ordered.map(\.title), ["B", "A", "C"])
    }

    /// Single app only — switcher should have no other options.
    func testSingleAppResultsInOneItem() {
        let store   = SwitcherHistoryStore()
        let finder  = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        store.noteActivation(finder)

        let items   = [makeItem(title: "Finder", identity: finder)]
        let ordered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: finder)
        XCTAssertEqual(ordered.count, 1)
        // Finder is both frontmost AND only item — still present (moved to end = stays)
        XCTAssertEqual(ordered.first?.title, "Finder")
    }

    /// Empty items list returns empty.
    func testEmptyItemsReturnsEmpty() {
        let store   = SwitcherHistoryStore()
        let ordered = SwitcherOrdering.orderedItems([], history: store, currentFrontmost: nil)
        XCTAssertTrue(ordered.isEmpty)
    }

    // MARK: - Repeated Cmd+Tab simulation (the core bug)

    /// Simulates 3 consecutive Cmd+Tab presses: each time, the previously
    /// activated app must be treated as the frontmost (even before the OS
    /// reports it). Without lastCommittedIdentity, the second and third
    /// presses would land on the same app again.
    func testThreeConsecutiveSwitchesAlternateCorrectly() {
        let store  = SwitcherHistoryStore()
        let finder = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let arc    = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)
        let safari = SwitcherHistoryIdentity.appWindow(pid: 303, windowID: 3)

        // Setup: user was in Safari → Arc → Finder
        store.noteActivation(safari)
        store.noteActivation(arc)
        store.noteActivation(finder)

        let items = [
            makeItem(title: "Finder", identity: finder),
            makeItem(title: "Arc",    identity: arc),
            makeItem(title: "Safari", identity: safari),
        ]

        // 1st Cmd+Tab: frontmost=Finder → moved to end → [Arc, Safari, Finder]
        let firstOrdered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: finder)
        XCTAssertEqual(firstOrdered.first?.title, "Arc", "First switch should offer Arc")

        // Simulate eager history note from commitCurrentSelection:
        store.noteActivation(arc)
        // lastCommittedIdentity would be `arc`

        // 2nd Cmd+Tab: frontmost=Arc (from lastCommittedIdentity) → moved to end
        let secondOrdered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: arc)
        XCTAssertEqual(secondOrdered.first?.title, "Finder", "Second switch should offer Finder")

        // Simulate eager history note:
        store.noteActivation(finder)

        // 3rd Cmd+Tab: frontmost=Finder → moved to end
        let thirdOrdered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: finder)
        XCTAssertEqual(thirdOrdered.first?.title, "Arc", "Third switch should offer Arc again")
    }

    /// Simulates the exact scenario from the bug report: after one successful
    /// switch, the second switch should NOT land on the same app.
    func testSecondSwitchNeverLandsOnSameApp() {
        let store = SwitcherHistoryStore()
        let currentApp = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let otherApp   = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)

        store.noteActivation(otherApp)
        store.noteActivation(currentApp)

        let items = [
            makeItem(title: "Current", identity: currentApp),
            makeItem(title: "Other",   identity: otherApp),
        ]

        // First switch: from Current → should land on Other
        let first = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: currentApp)
        XCTAssertEqual(first.first?.title, "Other")

        // Simulate: eager history note for Other, then use Other as lastCommittedIdentity
        store.noteActivation(otherApp)

        // Second switch: from Other (lastCommittedIdentity) → should land on Current, NOT Other
        let second = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: otherApp)
        XCTAssertEqual(second.first?.title, "Current", "Second switch must NOT land on the same app")
    }

    /// The current window (frontmost) should NEVER appear at index 0.
    /// It must always be moved to the end of the list.
    func testFrontmostIsNeverAtIndexZero() {
        let store = SwitcherHistoryStore()
        let a = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let b = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)
        let c = SwitcherHistoryIdentity.appWindow(pid: 303, windowID: 3)

        store.noteActivation(a)
        store.noteActivation(b)
        store.noteActivation(c)

        let items = [
            makeItem(title: "A", identity: a),
            makeItem(title: "B", identity: b),
            makeItem(title: "C", identity: c),
        ]

        // For each possible frontmost, it should never be at index 0
        for frontmost in [a, b, c] {
            let ordered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: frontmost)
            XCTAssertNotEqual(ordered.first?.historyIdentity, frontmost,
                              "Frontmost app must never be at index 0")
            XCTAssertEqual(ordered.last?.historyIdentity, frontmost,
                           "Frontmost app must be at the end of the list")
        }
    }

    // MARK: - ownerPID property tests

    func testOwnerPIDReturnsCorrectValueForAppWindow() {
        let identity = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        XCTAssertEqual(identity.ownerPID, 101)
    }

    func testOwnerPIDReturnsCorrectValueForAppFallback() {
        let identity = SwitcherHistoryIdentity.appFallback(bundleID: "com.apple.finder", pid: 101)
        XCTAssertEqual(identity.ownerPID, 101)
    }

    func testOwnerPIDReturnsNilForBrowserTab() {
        let identity = SwitcherHistoryIdentity.browserTab(
            bundleID: "com.apple.Safari",
            normalizedURL: "https://example.com",
            normalizedTitle: "example"
        )
        XCTAssertNil(identity.ownerPID)
    }

    // MARK: - PID-based frontmost detection tests

    /// When the committed identity's window ID changes across cache rebuilds,
    /// PID-based matching still correctly identifies the frontmost app.
    func testPIDBasedMatchingWorksAcrossWindowIDChanges() {
        let store = SwitcherHistoryStore()
        // Simulate: user activated Arc window 22, then Finder window 11
        let arcOldWindow  = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 22)
        let finderWindow  = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 11)
        store.noteActivation(arcOldWindow)
        store.noteActivation(finderWindow)

        // Cache rebuilds: Arc's window ID changed from 22 to 99
        let arcNewWindow = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 99)
        let items = [
            makeItem(title: "Finder", identity: finderWindow),
            makeItem(title: "Arc",    identity: arcNewWindow),
        ]

        // Even though finderWindow (pid 101) is the frontmost PID,
        // orderedItems should move Finder to end → Arc at index 0
        let ordered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: finderWindow)
        XCTAssertEqual(ordered.first?.title, "Arc",
                       "PID-based matching should work even when window IDs change")
        XCTAssertEqual(ordered.last?.title, "Finder",
                       "Frontmost should be at the end")
    }

    /// With multiple windows for the same app, the most recently used window
    /// of the frontmost app should be used as the currentFrontmost identity.
    func testMultipleWindowsSameAppUsesCorrectFrontmostWindow() {
        let store = SwitcherHistoryStore()
        let finderW1 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let finderW2 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 2)
        let arc      = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 3)

        // History: finderW1 most recent, then arc, then finderW2
        store.noteActivation(finderW2)
        store.noteActivation(arc)
        store.noteActivation(finderW1)

        let items = [
            makeItem(title: "Finder W1", identity: finderW1),
            makeItem(title: "Arc",       identity: arc),
            makeItem(title: "Finder W2", identity: finderW2),
        ]

        // Frontmost PID = 101 (Finder). The most recently used Finder window
        // is W1 (rank 0). orderedItems should move W1 to end.
        let ordered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: finderW1)
        XCTAssertEqual(ordered.map(\.title), ["Arc", "Finder W2", "Finder W1"])
    }

    // MARK: - Helpers

    private func makeItem(title: String, identity: SwitcherHistoryIdentity) -> SwitcherItem {
        SwitcherItem(
            title: title,
            subtitle: "",
            icon: nil,
            previewImage: nil,
            historyIdentity: identity,
            sourceAppIdentifier: nil,
            kind: .appWindow
        ) {}
    }
}
