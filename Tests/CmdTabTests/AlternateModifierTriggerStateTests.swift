import XCTest
@testable import CmdTab

final class AlternateModifierTriggerStateTests: XCTestCase {
    func testRightCommandSingleTapActivates() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightCommandTap,
                now: 10.0
            )
        )
        XCTAssertTrue(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightCommandTap,
                now: 10.12
            )
        )
    }

    func testRightCommandDoubleTapRequiresSecondTap() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightCommandDoubleTap,
                now: 20.0
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightCommandDoubleTap,
                now: 20.08
            )
        )

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightCommandDoubleTap,
                now: 20.24
            )
        )
        XCTAssertTrue(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightCommandDoubleTap,
                now: 20.32
            )
        )
    }

    func testLongHoldDoesNotActivateAlternateTrigger() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .rightOption,
                isDown: true,
                mode: .rightOptionTap,
                now: 30.0
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightOption,
                isDown: false,
                mode: .rightOptionTap,
                now: 30.5
            )
        )
    }

    func testInterveningKeyCancelsPendingTap() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: .rightCommandTap,
                now: 40.0
            )
        )
        state.noteInterveningKeyDown(now: 40.05)
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: .rightCommandTap,
                now: 40.1
            )
        )
    }

    func testExpiredDoubleTapWindowDoesNotActivate() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .rightOption,
                isDown: true,
                mode: .rightOptionDoubleTap,
                now: 50.0
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightOption,
                isDown: false,
                mode: .rightOptionDoubleTap,
                now: 50.1
            )
        )

        XCTAssertFalse(
            state.handleModifierChange(
                .rightOption,
                isDown: true,
                mode: .rightOptionDoubleTap,
                now: 50.8
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightOption,
                isDown: false,
                mode: .rightOptionDoubleTap,
                now: 50.9
            )
        )
    }

    func testLeftCommandDoubleTapRequiresSecondTap() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .leftCommand,
                isDown: true,
                mode: .leftCommandDoubleTap,
                now: 60.0
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .leftCommand,
                isDown: false,
                mode: .leftCommandDoubleTap,
                now: 60.08
            )
        )

        XCTAssertFalse(
            state.handleModifierChange(
                .leftCommand,
                isDown: true,
                mode: .leftCommandDoubleTap,
                now: 60.24
            )
        )
        XCTAssertTrue(
            state.handleModifierChange(
                .leftCommand,
                isDown: false,
                mode: .leftCommandDoubleTap,
                now: 60.32
            )
        )
    }

    func testLeftOptionDoubleTapRequiresSecondTap() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .leftOption,
                isDown: true,
                mode: .leftOptionDoubleTap,
                now: 70.0
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .leftOption,
                isDown: false,
                mode: .leftOptionDoubleTap,
                now: 70.09
            )
        )

        XCTAssertFalse(
            state.handleModifierChange(
                .leftOption,
                isDown: true,
                mode: .leftOptionDoubleTap,
                now: 70.24
            )
        )
        XCTAssertTrue(
            state.handleModifierChange(
                .leftOption,
                isDown: false,
                mode: .leftOptionDoubleTap,
                now: 70.31
            )
        )
    }

    func testStandardCommandTabSuppressesImmediateDoubleTapHotSwap() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .leftCommand,
                isDown: true,
                mode: .leftCommandDoubleTap,
                now: 80.0
            )
        )

        state.noteStandardShortcut(using: .leftCommand, now: 80.05)

        XCTAssertFalse(
            state.handleModifierChange(
                .leftCommand,
                isDown: false,
                mode: .leftCommandDoubleTap,
                now: 80.10
            )
        )

        XCTAssertFalse(
            state.handleModifierChange(
                .leftCommand,
                isDown: true,
                mode: .leftCommandDoubleTap,
                now: 80.24
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .leftCommand,
                isDown: false,
                mode: .leftCommandDoubleTap,
                now: 80.31
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .leftCommand,
                isDown: true,
                mode: .leftCommandDoubleTap,
                now: 80.36
            )
        )
        XCTAssertTrue(
            state.handleModifierChange(
                .leftCommand,
                isDown: false,
                mode: .leftCommandDoubleTap,
                now: 80.43
            )
        )
    }

    func testStandardShortcutResetsExistingDoubleTapCounter() {
        var state = AlternateModifierTriggerState()

        XCTAssertFalse(
            state.handleModifierChange(
                .leftCommand,
                isDown: true,
                mode: .leftCommandDoubleTap,
                now: 90.0
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .leftCommand,
                isDown: false,
                mode: .leftCommandDoubleTap,
                now: 90.08
            )
        )

        state.noteStandardShortcut(now: 90.12)

        XCTAssertFalse(
            state.handleModifierChange(
                .leftCommand,
                isDown: true,
                mode: .leftCommandDoubleTap,
                now: 90.20
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .leftCommand,
                isDown: false,
                mode: .leftCommandDoubleTap,
                now: 90.28
            )
        )
    }
}
