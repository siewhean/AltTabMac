import XCTest
@testable import CmdTab

final class ProductionHotSwapPolicyTests: XCTestCase {
    func testProductionModesExposeOnlySimultaneousSideMatchedChords() {
        XCTAssertEqual(
            AlternateTriggerMode.productionHotSwapModes,
            [.disabled, .leftOptionDoubleTap, .rightOptionDoubleTap]
        )
        XCTAssertTrue(AlternateTriggerMode.leftOptionDoubleTap.isProductionSimultaneousChord)
        XCTAssertTrue(AlternateTriggerMode.rightOptionDoubleTap.isProductionSimultaneousChord)
        XCTAssertFalse(AlternateTriggerMode.disabled.isProductionSimultaneousChord)
    }

    func testLegacyModifierOnlyModesMigrateToStandardOnly() {
        let legacyModes: [AlternateTriggerMode] = [
            .rightCommandTap,
            .rightCommandDoubleTap,
            .rightOptionTap,
            .leftCommandDoubleTap,
        ]

        for mode in legacyModes {
            XCTAssertEqual(
                mode.productionSafeMode,
                .disabled,
                "Modifier-only mode \(mode.rawValue) must never remain active."
            )
        }
    }

    func testTwoCommandTapsCannotActivateAfterProductionNormalization() {
        var state = AlternateModifierTriggerState()
        let safeMode = AlternateTriggerMode.rightCommandDoubleTap.productionSafeMode

        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: safeMode,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 10
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: safeMode,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 10.08
            )
        )

        // A two-second delay is explicitly covered, but the production policy is
        // stronger: modifier-only double taps are disabled at every interval.
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: true,
                mode: safeMode,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: true,
                rightOptionDown: false,
                now: 12.08
            )
        )
        XCTAssertFalse(
            state.handleModifierChange(
                .rightCommand,
                isDown: false,
                mode: safeMode,
                leftCommandDown: false,
                leftOptionDown: false,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 12.16
            )
        )
    }
}
