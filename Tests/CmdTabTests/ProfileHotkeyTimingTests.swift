import XCTest
@testable import CmdTab

final class SwitcherProfileSafetyTests_ProfileHotkeyTiming: XCTestCase {
    func testQuickReleaseCommitsWithoutOverlay() throws {
        let match = makeMatch()
        var state = ProfileHotkeyTimingState()
        assertScheduledReveal(
            state.registerHiddenTrigger(
                match: match,
                startedAtUptime: 10,
                isRepeat: false
            ),
            at: 10.1
        )
        XCTAssertEqual(
            state.handleModifierRelease(
                .command,
                switcherVisible: false,
                activeProfileID: nil
            ),
            .quickSwitch(match)
        )
        XCTAssertFalse(state.hasPendingTrigger)
    }

    func testHeldModifierRevealsMatchingProfile() {
        let match = makeMatch()
        var state = ProfileHotkeyTimingState()
        _ = state.registerHiddenTrigger(
            match: match,
            startedAtUptime: 20,
            isRepeat: false
        )
        XCTAssertNil(
            state.handleRevealDeadline(
                now: 20.099,
                heldModifiers: [.command]
            )
        )
        XCTAssertEqual(
            state.handleRevealDeadline(
                now: 20.1,
                heldModifiers: [.command]
            ),
            .showOverlay(match)
        )
        XCTAssertTrue(state.hasPendingTrigger)
    }

    func testReverseDirectionSurvivesQuickPath() {
        let match = makeMatch(reverse: true)
        var state = ProfileHotkeyTimingState()
        _ = state.registerHiddenTrigger(
            match: match,
            startedAtUptime: 30,
            isRepeat: false
        )
        XCTAssertEqual(
            state.handleModifierRelease(
                .command,
                switcherVisible: false,
                activeProfileID: nil
            ),
            .quickSwitch(match)
        )
    }

    func testRepeatedHiddenKeyDownDoesNotRescheduleDeadline() {
        let match = makeMatch()
        var state = ProfileHotkeyTimingState()
        _ = state.registerHiddenTrigger(
            match: match,
            startedAtUptime: 40,
            isRepeat: false
        )
        XCTAssertNil(
            state.registerHiddenTrigger(
                match: match,
                startedAtUptime: 99,
                isRepeat: false
            )
        )
        XCTAssertEqual(state.pendingTrigger?.startedAtUptime, 40)
    }

    func testAutorepeatIsIgnoredWhilePending() {
        let match = makeMatch()
        var state = ProfileHotkeyTimingState()
        _ = state.registerHiddenTrigger(
            match: match,
            startedAtUptime: 50,
            isRepeat: false
        )
        XCTAssertNil(
            state.registerHiddenTrigger(
                match: match,
                startedAtUptime: 51,
                isRepeat: true
            )
        )
        XCTAssertEqual(state.pendingTrigger?.startedAtUptime, 50)
    }

    func testLateDeadlineStillUsesOriginalTrigger() {
        let match = makeMatch()
        var state = ProfileHotkeyTimingState()
        _ = state.registerHiddenTrigger(
            match: match,
            startedAtUptime: 60,
            isRepeat: false
        )
        XCTAssertEqual(
            state.handleRevealDeadline(
                now: 600,
                heldModifiers: [.command]
            ),
            .showOverlay(match)
        )
        XCTAssertEqual(state.pendingTrigger?.startedAtUptime, 60)
    }

    func testVisibleMatchingProfileReleaseConfirms() {
        let match = makeMatch()
        var state = ProfileHotkeyTimingState()
        _ = state.registerHiddenTrigger(
            match: match,
            startedAtUptime: 70,
            isRepeat: false
        )
        XCTAssertEqual(
            state.handleModifierRelease(
                .command,
                switcherVisible: true,
                activeProfileID: match.profileID
            ),
            .confirmSelection(match)
        )
    }

    func testCancelPreventsFollowUpCommit() {
        let match = makeMatch()
        var state = ProfileHotkeyTimingState()
        _ = state.registerHiddenTrigger(
            match: match,
            startedAtUptime: 80,
            isRepeat: false
        )
        state.cancel()
        XCTAssertNil(
            state.handleModifierRelease(
                .command,
                switcherVisible: false,
                activeProfileID: nil
            )
        )
    }

    func testVisibleRepeatRetainsReleaseOwnership() {
        let match = makeMatch()
        var state = ProfileHotkeyTimingState()
        _ = state.registerHiddenTrigger(
            match: match,
            startedAtUptime: 90,
            isRepeat: false
        )
        _ = state.handleRevealDeadline(
            now: 90.1,
            heldModifiers: [.command]
        )

        XCTAssertEqual(state.pendingMatch, match)
        XCTAssertEqual(
            state.handleModifierRelease(
                .command,
                switcherVisible: true,
                activeProfileID: match.profileID
            ),
            .confirmSelection(match)
        )
    }

    func testReplacingVisibleProfileTransfersReleaseOwnership() {
        let first = makeMatch()
        let second = ShortcutProfileMatch(
            profileID: UUID(),
            reverse: true,
            releaseBehavior: .holdPrimaryModifier,
            primaryModifier: .option
        )
        var state = ProfileHotkeyTimingState()
        state.beginVisibleTrigger(match: first, startedAtUptime: 100)
        state.beginVisibleTrigger(match: second, startedAtUptime: 101)

        XCTAssertEqual(state.pendingMatch, second)
        XCTAssertNil(
            state.handleModifierRelease(
                .command,
                switcherVisible: true,
                activeProfileID: second.profileID
            )
        )
        XCTAssertEqual(
            state.handleModifierRelease(
                .option,
                switcherVisible: true,
                activeProfileID: second.profileID
            ),
            .confirmSelection(second)
        )
    }

    func testOptionRepeatReschedulesFromLatestEventTimestamp() {
        let match = ShortcutProfileMatch(
            profileID: UUID(),
            reverse: false,
            releaseBehavior: .holdPrimaryModifier,
            primaryModifier: .option
        )
        var state = ProfileHotkeyTimingState()
        assertScheduledReveal(
            state.registerHiddenTrigger(
                match: match,
                startedAtUptime: 110,
                isRepeat: false
            ),
            at: 110.1
        )
        assertScheduledReveal(
            state.registerHiddenTrigger(
                match: ShortcutProfileMatch(
                    profileID: match.profileID,
                    reverse: true,
                    releaseBehavior: .holdPrimaryModifier,
                    primaryModifier: .option
                ),
                startedAtUptime: 110.05,
                isRepeat: false
            ),
            at: 110.15
        )
        XCTAssertEqual(state.pendingTrigger?.startedAtUptime, 110.05)
        XCTAssertEqual(state.pendingMatch?.reverse, true)
    }

    private func assertScheduledReveal(
        _ action: ProfileHotkeyTimingAction?,
        at expected: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .scheduleReveal(atUptime)? = action else {
            XCTFail(
                "Expected a scheduled reveal action",
                file: file,
                line: line
            )
            return
        }
        XCTAssertEqual(
            atUptime,
            expected,
            accuracy: 0.000_001,
            file: file,
            line: line
        )
    }

    private func makeMatch(
        reverse: Bool = false
    ) -> ShortcutProfileMatch {
        ShortcutProfileMatch(
            profileID: UUID(),
            reverse: reverse,
            releaseBehavior: .holdPrimaryModifier,
            primaryModifier: .command
        )
    }
}
