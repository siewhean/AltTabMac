import CoreGraphics
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

    func testDeliberateTabsBeforeQuickReleaseAdvanceTheCommit() {
        let match = makeMatch()
        let reverse = ShortcutProfileMatch(
            profileID: match.profileID,
            reverse: true,
            releaseBehavior: .holdPrimaryModifier,
            primaryModifier: .command
        )
        var state = ProfileHotkeyTimingState()
        _ = state.registerHiddenTrigger(match: match, startedAtUptime: 10, isRepeat: false)
        state.registerAdditionalAdvance(match: match, isRepeat: false)
        state.registerAdditionalAdvance(match: match, isRepeat: true)
        state.registerAdditionalAdvance(match: makeMatch(), isRepeat: false)
        state.registerAdditionalAdvance(match: reverse, isRepeat: false)

        XCTAssertEqual(
            state.handleModifierRelease(.command, switcherVisible: false, activeProfileID: nil),
            .quickSwitch(match, additionalAdvances: [false, true]),
            "Fast Command-Tab-Tab must land on the second item; key repeat and other profiles never advance."
        )
    }

    func testEarlyAdvancesAreHandedToTheRevealExactlyOnce() {
        let match = makeMatch()
        var state = ProfileHotkeyTimingState()
        _ = state.registerHiddenTrigger(match: match, startedAtUptime: 10, isRepeat: false)
        state.registerAdditionalAdvance(match: match, isRepeat: false)

        XCTAssertEqual(
            state.handleRevealDeadline(now: 10.2, heldModifiers: [.command]),
            .showOverlay(match, additionalAdvances: [false])
        )
        XCTAssertEqual(
            state.handleModifierRelease(.command, switcherVisible: true, activeProfileID: match.profileID),
            .confirmSelection(match),
            "The revealed session keeps release ownership without replaying its early advances."
        )
    }

    func testPhysicalModifierStateComesFromDeviceFlagBits() {
        let leftCommand = PhysicalModifierDeviceFlags(
            flags: CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x08)
        )
        XCTAssertTrue(leftCommand.isDown(.leftCommand))
        XCTAssertFalse(leftCommand.isDown(.rightCommand))

        let rightPair = PhysicalModifierDeviceFlags(
            flags: CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue |
                CGEventFlags.maskAlternate.rawValue | 0x10 | 0x40)
        )
        XCTAssertEqual(
            [rightPair.leftCommand, rightPair.rightCommand, rightPair.leftOption, rightPair.rightOption],
            [false, true, false, true]
        )
        XCTAssertFalse(
            PhysicalModifierDeviceFlags(flags: []).isDown(.leftOption),
            "Released modifiers read as up even if an earlier event was missed."
        )
    }

    func testEventTimestampsConvertFromEitherUnitAndRejectImplausibleValues() {
        let now: TimeInterval = 500
        XCTAssertEqual(
            EventTimestampClock.uptime(eventTimestamp: 0, now: now),
            now,
            "Synthesized events carry timestamp 0 and must not open a negative interval."
        )
        XCTAssertEqual(
            EventTimestampClock.uptime(
                eventTimestamp: 499_900_000_000, now: now,
                timebaseNumerator: 125, timebaseDenominator: 3
            ),
            499.9, accuracy: 0.000_001
        )
        let machTicks = UInt64(499.9 * 1_000_000_000 * 3 / 125)
        XCTAssertEqual(
            EventTimestampClock.uptime(
                eventTimestamp: machTicks, now: now,
                timebaseNumerator: 125, timebaseDenominator: 3
            ),
            499.9, accuracy: 0.000_001,
            "Mach absolute-time ticks are converted rather than compressed 41.7x."
        )
        XCTAssertEqual(
            EventTimestampClock.uptime(
                eventTimestamp: 900_000_000_000, now: now,
                timebaseNumerator: 1, timebaseDenominator: 1
            ),
            now,
            "A timestamp in the future falls back to the current uptime."
        )
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
