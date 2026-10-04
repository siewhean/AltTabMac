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

    func testRightSideChordActivatesOnCleanShortRelease() {
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

        XCTAssertFalse(
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
        // Modifier chords commit on a clean release within 280ms, never on key-down.
        XCTAssertTrue(
            state.handleModifierChange(
                .rightOption,
                isDown: false,
                mode: .rightOptionDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 40.10
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightOptionDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 40.12
            )
        )
    }

    func testLeftSideChordActivatesOnCleanShortRelease() {
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

        XCTAssertFalse(
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
        // Modifier chords commit on a clean release within 280ms, never on key-down.
        XCTAssertTrue(
            state.handleModifierChange(
                .leftOption,
                isDown: false,
                mode: .leftOptionDoubleTap,
                leftCommandDown: true,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 50.10
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .leftCommand,
                isDown: false,
                mode: .leftOptionDoubleTap,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 50.12
            )
        )
    }

    func testHeldChordFiresOnceOnReleaseAndDoesNotRepeat() {
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

        XCTAssertFalse(
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
        // Repeated down events must not fire; releasing either key commits only once.
        XCTAssertTrue(
            state.handleModifierChange(
                .rightOption, isDown: false, mode: .rightOptionDoubleTap,
                leftCommandDown: false, leftOptionDown: false,
                rightCommandDown: true, rightOptionDown: false, now: 60.10
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightOption, isDown: false, mode: .rightOptionDoubleTap,
                leftCommandDown: false, leftOptionDown: false,
                rightCommandDown: true, rightOptionDown: false, now: 60.11
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand, isDown: false, mode: .rightOptionDoubleTap,
                leftCommandDown: false, leftOptionDown: false,
                rightCommandDown: false, rightOptionDown: false, now: 60.12
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
}
