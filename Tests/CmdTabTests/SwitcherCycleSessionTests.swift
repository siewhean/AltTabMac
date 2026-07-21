import XCTest
@testable import CmdTab

final class SwitcherCycleSessionTests: XCTestCase {
    func testRepeatedQuickPressUsesCurrentSnapshotSelection() throws {
        let finder = makeItem(title: "Finder", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11))
        let arc = makeItem(title: "Arc", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22))

        let firstSession = try XCTUnwrap(
            SwitcherCycleSession(
                mode: .app,
                items: [arc, finder],
                currentFrontmost: finder.historyIdentity,
                reverse: false,
                pinsSnapshot: true
            )
        )

        XCTAssertEqual(firstSession.commitSelection().title, "Arc")

        let secondSession = try XCTUnwrap(
            SwitcherCycleSession(
                mode: .app,
                items: [finder, arc],
                currentFrontmost: arc.historyIdentity,
                reverse: false,
                pinsSnapshot: true
            )
        )

        XCTAssertEqual(secondSession.commitSelection().title, "Finder")
    }

    func testInitialSelectionCanTargetAnotherWindowFromCurrentApp() throws {
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

    func testReverseInitialSelectionCanTargetAnotherWindowFromCurrentApp() throws {
        let notebookLM = makeItem(title: "NotebookLM", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 21))
        let arcWindow = makeItem(title: "Arc Window", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22))
        let finder = makeItem(title: "Finder", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11))

        let session = try XCTUnwrap(
            SwitcherCycleSession(
                mode: .app,
                items: [finder, arcWindow, notebookLM],
                currentFrontmost: notebookLM.historyIdentity,
                reverse: true,
                pinsSnapshot: true
            )
        )

        XCTAssertEqual(session.commitSelection().title, "Arc Window")
    }

    func testHoldToCycleAdvancesForwardBeforeCommit() throws {
        let arc = makeItem(title: "Arc", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22))
        let safari = makeItem(title: "Safari", appID: "com.apple.Safari", identity: .appWindow(pid: 303, windowID: 33))
        let finder = makeItem(title: "Finder", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11))

        var session = try XCTUnwrap(
            SwitcherCycleSession(
                mode: .app,
                items: [arc, safari, finder],
                currentFrontmost: finder.historyIdentity,
                reverse: false,
                pinsSnapshot: true
            )
        )

        session.advance(reverse: false)
        XCTAssertEqual(session.commitSelection().title, "Safari")
    }

    func testReverseCycleStartsAtPreviousItemAndMovesBackward() throws {
        let arc = makeItem(title: "Arc", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22))
        let safari = makeItem(title: "Safari", appID: "com.apple.Safari", identity: .appWindow(pid: 303, windowID: 33))
        let finder = makeItem(title: "Finder", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11))

        var session = try XCTUnwrap(
            SwitcherCycleSession(
                mode: .app,
                items: [arc, safari, finder],
                currentFrontmost: finder.historyIdentity,
                reverse: true,
                pinsSnapshot: true
            )
        )

        XCTAssertEqual(session.commitSelection().title, "Safari")

        session.advance(reverse: true)
        XCTAssertEqual(session.commitSelection().title, "Arc")
    }

    func testRefreshPreservesSelectedIdentityWhenItemsReorder() throws {
        let arc = makeItem(title: "Arc", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22))
        let safari = makeItem(title: "Safari", appID: "com.apple.Safari", identity: .appWindow(pid: 303, windowID: 33))
        let finder = makeItem(title: "Finder", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11))

        var session = try XCTUnwrap(
            SwitcherCycleSession(
                mode: .app,
                items: [arc, safari, finder],
                currentFrontmost: finder.historyIdentity,
                reverse: false,
                pinsSnapshot: false
            )
        )

        session.advance(reverse: false)
        session.refreshItems([finder, arc, safari])

        XCTAssertEqual(session.selectedIndex, 2)
        XCTAssertEqual(session.commitSelection().title, "Safari")
    }

    // MARK: - New tests for subsequent-switch correctness

    /// After committing a selection, the second session (with updated frontmost)
    /// starts at the correct item — not the just-activated app.
    func testSecondSessionAfterCommitStartsAtCorrectIndex() throws {
        let finder = makeItem(title: "Finder", appID: "com.apple.finder",           identity: .appWindow(pid: 101, windowID: 11))
        let arc    = makeItem(title: "Arc",    appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22))
        let safari = makeItem(title: "Safari", appID: "com.apple.Safari",           identity: .appWindow(pid: 303, windowID: 33))

        // First session: frontmost=Finder, items=[Arc, Safari, Finder(at end)]
        let firstSession = try XCTUnwrap(
            SwitcherCycleSession(
                mode: .app,
                items: [arc, safari, finder],
                currentFrontmost: finder.historyIdentity,
                reverse: false,
                pinsSnapshot: true
            )
        )
        XCTAssertEqual(firstSession.commitSelection().title, "Arc")

        // Simulate eager history note + second session where Arc is now frontmost
        // Items = [Finder, Safari, Arc(at end)] after ordering
        let secondSession = try XCTUnwrap(
            SwitcherCycleSession(
                mode: .app,
                items: [finder, safari, arc],
                currentFrontmost: arc.historyIdentity,
                reverse: false,
                pinsSnapshot: true
            )
        )
        XCTAssertEqual(secondSession.commitSelection().title, "Finder")
    }

    /// Reverse (Cmd+Shift+Tab) with three items starts at second-to-last item.
    func testReverseWithThreeItemsStartsAtSecondToLast() throws {
        let arc    = makeItem(title: "Arc",    appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22))
        let safari = makeItem(title: "Safari", appID: "com.apple.Safari",           identity: .appWindow(pid: 303, windowID: 33))
        let finder = makeItem(title: "Finder", appID: "com.apple.finder",           identity: .appWindow(pid: 101, windowID: 11))

        // Items = [arc, safari, finder_at_end] with finder as frontmost
        let session = try XCTUnwrap(
            SwitcherCycleSession(
                mode: .app,
                items: [arc, safari, finder],
                currentFrontmost: finder.historyIdentity,
                reverse: true,
                pinsSnapshot: true
            )
        )
        // Frontmost (finder) is last → reverse starts at index count-2 = Safari
        XCTAssertEqual(session.commitSelection().title, "Safari")
    }

    /// Move by delta wraps around correctly at boundaries.
    func testMoveByDeltaWrapsAround() throws {
        let arc    = makeItem(title: "Arc",    appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22))
        let safari = makeItem(title: "Safari", appID: "com.apple.Safari",           identity: .appWindow(pid: 303, windowID: 33))
        let finder = makeItem(title: "Finder", appID: "com.apple.finder",           identity: .appWindow(pid: 101, windowID: 11))

        var session = try XCTUnwrap(
            SwitcherCycleSession(mode: .app, items: [arc, safari, finder], currentFrontmost: nil, reverse: false, pinsSnapshot: true)
        )
        XCTAssertEqual(session.selectedIndex, 0)

        session.move(by: -1)  // wrap: 0 - 1 → count-1 = 2
        XCTAssertEqual(session.selectedIndex, 2)
        XCTAssertEqual(session.commitSelection().title, "Finder")
    }

    func testRemovingSelectedItemMovesSelectionToNearestRemainingNeighbor() throws {
        let arc = makeItem(title: "Arc", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22))
        let safari = makeItem(title: "Safari", appID: "com.apple.Safari", identity: .appWindow(pid: 303, windowID: 33))
        let finder = makeItem(title: "Finder", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11))

        var session = try XCTUnwrap(
            SwitcherCycleSession(
                mode: .app,
                items: [arc, safari, finder],
                currentFrontmost: nil,
                reverse: false,
                pinsSnapshot: false
            )
        )

        session.move(by: 1)
        XCTAssertEqual(session.commitSelection().title, "Safari")

        XCTAssertTrue(session.removeItem(withID: safari.id))
        XCTAssertEqual(session.commitSelection().title, "Finder")
        XCTAssertEqual(session.selectedIndex, 1)
    }

    func testRemovingApplicationSuppressionDropsAllMatchingTiles() throws {
        let finderWindowA = makeItem(title: "Finder A", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11))
        let finderWindowB = makeItem(title: "Finder B", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 12))
        let safari = makeItem(title: "Safari", appID: "com.apple.Safari", identity: .appWindow(pid: 303, windowID: 33))

        var session = try XCTUnwrap(
            SwitcherCycleSession(
                mode: .app,
                items: [finderWindowA, safari, finderWindowB],
                currentFrontmost: nil,
                reverse: false,
                pinsSnapshot: false
            )
        )

        XCTAssertTrue(
            session.removeItems { item in
                item.historyIdentity.ownerPID == 101
            }
        )
        XCTAssertEqual(session.items.map(\.title), ["Safari"])
        XCTAssertEqual(session.commitSelection().title, "Safari")
    }

    func testReplacingItemsResetsSelectionToFilteredIndex() throws {
        let mimestream = makeItem(title: "Mimestream", appID: "com.mimestream.Mimestream", identity: .appWindow(pid: 101, windowID: 11))
        let codex = makeItem(title: "Codex", appID: "com.openai.codex", identity: .appWindow(pid: 202, windowID: 22))
        let claude = makeItem(title: "Claude", appID: "com.anthropic.claude", identity: .appWindow(pid: 303, windowID: 33))

        var session = try XCTUnwrap(
            SwitcherCycleSession(
                mode: .app,
                items: [mimestream, codex, claude],
                currentFrontmost: nil,
                reverse: false,
                pinsSnapshot: false
            )
        )

        session.move(by: 2)
        XCTAssertEqual(session.commitSelection().title, "Claude")

        session.replaceItems([codex], selectedIndex: 0)
        XCTAssertEqual(session.selectedIndex, 0)
        XCTAssertEqual(session.commitSelection().title, "Codex")
    }

    private func makeItem(title: String, appID: String, identity: SwitcherHistoryIdentity) -> SwitcherItem {
        SwitcherItem(
            title: title,
            subtitle: appID,
            icon: nil,
            previewImage: nil,
            historyIdentity: identity,
            sourceAppIdentifier: appID,
            kind: .appWindow
        ) {}
    }
}
