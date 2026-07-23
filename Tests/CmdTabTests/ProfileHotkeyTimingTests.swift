import XCTest
@testable import CmdTab

final class SwitcherProfileSafetyTests_ProfileHotkeyTiming: XCTestCase {
    func testQuickReleaseCommitsWithoutOverlay() throws {
        var chord = ShortcutChordTimingState()
        chord.noteModifierChange(.command, isDown: true, at: 9.95)
        XCTAssertTrue(
            chord.accepts(primaryModifier: .command, keyDownAt: 10),
            "A normal near-simultaneous Command-Tab chord must be accepted."
        )
        chord.noteModifierChange(.command, isDown: false, at: 10.01)
        XCTAssertFalse(
            chord.accepts(primaryModifier: .command, keyDownAt: 10.02),
            "A shortcut cannot be accepted after its modifier has been released."
        )

        let match = makeMatch()
        var state = ProfileHotkeyTimingState()
        assertScheduledReveal(
            state.registerHiddenTrigger(
                match: match,
                startedAtUptime: 10,
                isRepeat: false
            ),
            at: 10.2
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
                now: 20.199,
                heldModifiers: [.command]
            )
        )
        XCTAssertEqual(
            state.handleRevealDeadline(
                now: 20.2,
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
        var chord = ShortcutChordTimingState(maximumLeadInterval: 0.16)
        chord.noteModifierChange(.command, isDown: true, at: 79)
        XCTAssertFalse(
            chord.accepts(primaryModifier: .command, keyDownAt: 79.17),
            "Holding Command and pressing Tab later must not switch."
        )
        XCTAssertFalse(
            chord.accepts(primaryModifier: .option, keyDownAt: 79.05),
            "An unobserved primary modifier must fail closed."
        )

        chord.reset()
        chord.noteModifierChange(.command, isDown: true, at: 79.2)
        chord.noteInterveningKeyDown()
        XCTAssertFalse(
            chord.accepts(primaryModifier: .command, keyDownAt: 79.25),
            "Command-V or any unrelated key must disarm the modifier gesture before a later release."
        )
        chord.noteModifierChange(.command, isDown: false, at: 79.3)
        chord.noteModifierChange(.command, isDown: true, at: 79.4)
        XCTAssertTrue(
            chord.accepts(primaryModifier: .command, keyDownAt: 79.45),
            "A fresh deliberate Command-Tab chord must work after the contaminated gesture ends."
        )

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
            now: 90.2,
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
        var chord = PhysicalModifierChordTimingState(
            maximumSeparation: 0.16
        )
        chord.noteModifierChange(.leftCommand, isDown: true, at: 99)
        chord.noteModifierChange(.leftOption, isDown: true, at: 99.12)
        XCTAssertTrue(
            chord.accepts(keys: [.leftCommand, .leftOption])
        )
        chord.reset()
        chord.noteModifierChange(.rightCommand, isDown: true, at: 99)
        chord.noteModifierChange(.rightOption, isDown: true, at: 99.17)
        XCTAssertFalse(
            chord.accepts(keys: [.rightCommand, .rightOption]),
            "A delayed Hot Swap modifier chord must not activate."
        )
        XCTAssertEqual(
            AlternateTriggerMode.leftOptionDoubleTap.simultaneousChordKeys,
            [.leftCommand, .leftOption]
        )
        XCTAssertEqual(
            AlternateTriggerMode.rightOptionDoubleTap.simultaneousChordKeys,
            [.rightCommand, .rightOption]
        )

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
            at: 110.2
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
            at: 110.25
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
