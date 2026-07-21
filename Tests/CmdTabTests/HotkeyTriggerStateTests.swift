import XCTest
@testable import CmdTab

final class HotkeyTriggerStateTests: XCTestCase {
    func testCommandReleaseBeforeRevealQuickSwitchesWithoutShowingOverlay() {
        var state = HotkeyTriggerState()

        assertScheduledReveal(
            state.registerHiddenTabTrigger(modifier: .command, reverse: false, startedAtUptime: 10.0),
            equals: 10.1
        )

        XCTAssertEqual(
            state.handleModifierRelease(.command, switcherVisible: false),
            .quickSwitch(reverse: false)
        )
        XCTAssertFalse(state.hasPendingTrigger)
    }

    func testCommandHoldPastDeadlineShowsOverlay() {
        var state = HotkeyTriggerState()

        _ = state.registerHiddenTabTrigger(modifier: .command, reverse: false, startedAtUptime: 1.0)

        XCTAssertNil(
            state.handleRevealDeadline(now: 1.099, heldModifiers: [.command])
        )
        XCTAssertEqual(
            state.handleRevealDeadline(now: 1.1, heldModifiers: [.command]),
            .showOverlay(reverse: false, modifier: .command)
        )
        XCTAssertTrue(state.hasPendingTrigger)
    }

    func testRepeatedCommandTabBeforeRevealDoesNotReschedule() throws {
        var state = HotkeyTriggerState()

        assertScheduledReveal(
            state.registerHiddenTabTrigger(modifier: .command, reverse: false, startedAtUptime: 2.0),
            equals: 2.1
        )
        XCTAssertNil(
            state.registerHiddenTabTrigger(modifier: .command, reverse: true, startedAtUptime: 2.05)
        )

        let pendingTrigger = try XCTUnwrap(state.pendingTrigger)
        XCTAssertEqual(state.pendingModifier, .command)
        XCTAssertEqual(pendingTrigger.reverse, false)
        XCTAssertEqual(pendingTrigger.startedAtUptime, 2.0, accuracy: 0.0001)
        XCTAssertEqual(pendingTrigger.revealAtUptime, 2.1, accuracy: 0.0001)
    }

    func testReverseCommandTriggerPreservesReverseFlagForQuickSwitchAndReveal() {
        var quickSwitchState = HotkeyTriggerState()
        _ = quickSwitchState.registerHiddenTabTrigger(modifier: .command, reverse: true, startedAtUptime: 3.0)
        XCTAssertEqual(
            quickSwitchState.handleModifierRelease(.command, switcherVisible: false),
            .quickSwitch(reverse: true)
        )

        var revealState = HotkeyTriggerState()
        _ = revealState.registerHiddenTabTrigger(modifier: .command, reverse: true, startedAtUptime: 4.0)
        XCTAssertEqual(
            revealState.handleRevealDeadline(now: 4.1, heldModifiers: [.command]),
            .showOverlay(reverse: true, modifier: .command)
        )
    }

    func testCommandReleaseAfterOverlayShowsConfirmsSelection() {
        var state = HotkeyTriggerState()

        _ = state.registerHiddenTabTrigger(modifier: .command, reverse: false, startedAtUptime: 5.0)
        _ = state.handleRevealDeadline(now: 5.1, heldModifiers: [.command])

        XCTAssertEqual(
            state.handleModifierRelease(.command, switcherVisible: true),
            .confirmSelection
        )
        XCTAssertFalse(state.hasPendingTrigger)
    }

    func testEscapeDuringPendingClearsPendingCleanly() {
        var state = HotkeyTriggerState()

        _ = state.registerHiddenTabTrigger(modifier: .command, reverse: false, startedAtUptime: 6.0)
        state.cancelPendingTrigger()

        XCTAssertFalse(state.hasPendingTrigger)
        XCTAssertNil(state.handleModifierRelease(.command, switcherVisible: false))
    }

    func testDismissalCancellationPreventsModifierReleaseAction() {
        var state = HotkeyTriggerState()

        _ = state.registerHiddenTabTrigger(modifier: .command, reverse: false, startedAtUptime: 9.0)
        _ = state.handleRevealDeadline(now: 9.1, heldModifiers: [.command])
        state.cancelPendingTrigger()

        XCTAssertNil(state.handleModifierRelease(.command, switcherVisible: false))
        XCTAssertFalse(state.hasPendingTrigger)
    }

    func testOptionTriggerReschedulesOnRepeatedTab() throws {
        var state = HotkeyTriggerState()

        assertScheduledReveal(
            state.registerHiddenTabTrigger(modifier: .option, reverse: false, startedAtUptime: 7.0),
            equals: 7.0
        )
        assertScheduledReveal(
            state.registerHiddenTabTrigger(modifier: .option, reverse: true, startedAtUptime: 7.05),
            equals: 7.05
        )

        let pendingTrigger = try XCTUnwrap(state.pendingTrigger)
        XCTAssertEqual(state.pendingModifier, .option)
        XCTAssertEqual(pendingTrigger.reverse, true)
        XCTAssertEqual(pendingTrigger.startedAtUptime, 7.05, accuracy: 0.0001)
    }

    func testRevealDeadlineWithoutHeldCommandFallsBackToQuickSwitch() {
        var state = HotkeyTriggerState()

        _ = state.registerHiddenTabTrigger(modifier: .command, reverse: false, startedAtUptime: 8.0)

        XCTAssertEqual(
            state.handleRevealDeadline(now: 8.1, heldModifiers: []),
            .quickSwitch(reverse: false)
        )
        XCTAssertFalse(state.hasPendingTrigger)
    }

    private func assertScheduledReveal(
        _ action: HotkeyTriggerAction?,
        equals expected: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .scheduleReveal(atUptime)? = action else {
            XCTFail("Expected a scheduled reveal action", file: file, line: line)
            return
        }

        XCTAssertEqual(atUptime, expected, accuracy: 0.0001, file: file, line: line)
    }
}
