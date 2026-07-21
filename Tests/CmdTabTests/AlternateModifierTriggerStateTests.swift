import XCTest
@testable import CmdTab

final class AlternateModifierTriggerStateTests: XCTestCase {
    func testRightCommandDoubleTapRequiresQuickSecondTap() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 10.0
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 10.08
            )
        )

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 10.22
            )
        )
        XCTAssertTrue(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 10.30
            )
        )
    }

    func testLeftCommandDoubleTapRequiresQuickSecondTap() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .leftCommand,
                isDown: true,
                mode: .leftCommandDoubleTap,
                leftCommandDown: true,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 20.0
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .leftCommand,
                isDown: false,
                mode: .leftCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 20.07
            )
        )

        XCTAssertFalse(
            state.handleModifierChange(
                .leftCommand,
                isDown: true,
                mode: .leftCommandDoubleTap,
                leftCommandDown: true,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 20.20
            )
        )
        XCTAssertTrue(
            state.handleModifierChange(
                .leftCommand,
                isDown: false,
                mode: .leftCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 20.28
            )
        )
    }

    func testSlowSecondCommandTapDoesNotActivate() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 30.0
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 30.08
            )
        )

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 31.20
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 31.28
            )
        )
    }

    func testRightSideChordActivatesWhenSecondKeyGoesDown() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightOptionDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 40.0
            )
        )

        XCTAssertTrue(
            state.handleModifierChange(
                .rightOption,
                isDown: true,
                mode: .rightOptionDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: true,
                now: 40.02
            )
        )
    }

    func testLeftSideChordActivatesWhenSecondKeyGoesDown() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .leftOption,
                isDown: true,
                mode: .leftOptionDoubleTap,
                leftCommandDown: false,
                leftOptionDown: true,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 50.0
            )
        )

        XCTAssertTrue(
            state.handleModifierChange(
                .leftCommand,
                isDown: true,
                mode: .leftOptionDoubleTap,
                leftCommandDown: true,
                leftOptionDown: true,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 50.03
            )
        )
    }

    func testHoldingChordDoesNotRetriggerUntilReleased() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightOptionDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 60.0
            )
        )

        XCTAssertTrue(
            state.handleModifierChange(
                .rightOption,
                isDown: true,
                mode: .rightOptionDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: true,
                now: 60.02
            )
        )

        XCTAssertFalse(
            state.handleModifierChange(
                .rightOption,
                isDown: true,
                mode: .rightOptionDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: true,
                now: 60.04
            )
        )
    }

    func testStandardShortcutResetsTriggeredStates() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 70.0
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 70.08
            )
        )

        state.noteStandardShortcut(now: 70.10)

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 70.18
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 70.26
            )
        )
    }

    func testDisabledModeNeverActivates() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .disabled,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 80.0
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightOption,
                isDown: true,
                mode: .disabled,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: true,
                now: 80.02
            )
        )
    }

    func testDoubleTapInterruptedByNonTargetKeyDownResetsPendingTap() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 90.0
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 90.08
            )
        )

        state.noteInterveningKeyDown(
            key: nil,
            mode: .rightCommandDoubleTap,
            now: 90.12
        )

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 90.20
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 90.28
            )
        )
    }

    func testDoubleTapInterruptedByOtherModifierDownResetsPendingTap() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 100.0
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 100.08
            )
        )

        state.noteInterveningModifierDown(
            key: .rightOption,
            mode: .rightCommandDoubleTap,
            now: 100.12
        )

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 100.20
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 100.28
            )
        )
    }

    func testPureConsecutiveDoubleTapStillActivatesWithoutInterruption() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 110.0
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 110.08
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 110.20
            )
        )
        XCTAssertTrue(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightCommandDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 110.28
            )
        )
    }
}
