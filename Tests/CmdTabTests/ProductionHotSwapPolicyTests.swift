import XCTest
@testable import CmdTab

final class ProductionHotSwapPolicyTests: XCTestCase {
    func testProductionModesExposeImmediateCommandDoubleTapsAndSideMatchedChords() {
        XCTAssertEqual(
            AlternateTriggerMode.productionHotSwapModes,
            [
                .disabled,
                .leftCommandDoubleTap,
                .rightCommandDoubleTap,
                .leftOptionDoubleTap,
                .rightOptionDoubleTap,
            ]
        )
        XCTAssertTrue(AlternateTriggerMode.leftCommandDoubleTap.isProductionImmediateDoubleTap)
        XCTAssertTrue(AlternateTriggerMode.rightCommandDoubleTap.isProductionImmediateDoubleTap)
        XCTAssertTrue(AlternateTriggerMode.leftOptionDoubleTap.isProductionSimultaneousChord)
        XCTAssertTrue(AlternateTriggerMode.rightOptionDoubleTap.isProductionSimultaneousChord)
        XCTAssertFalse(AlternateTriggerMode.disabled.isProductionImmediateDoubleTap)
        XCTAssertFalse(AlternateTriggerMode.disabled.isProductionSimultaneousChord)
    }

    func testOnlyLegacySingleTapModesMigrateToStandardOnly() {
        for mode in [
            AlternateTriggerMode.rightCommandTap,
            AlternateTriggerMode.rightOptionTap,
        ] {
            XCTAssertEqual(
                mode.productionSafeMode,
                .disabled,
                "Single-modifier mode \(mode.rawValue) must never remain active."
            )
        }

        for mode in [
            AlternateTriggerMode.leftCommandDoubleTap,
            AlternateTriggerMode.rightCommandDoubleTap,
            AlternateTriggerMode.leftOptionDoubleTap,
            AlternateTriggerMode.rightOptionDoubleTap,
        ] {
            XCTAssertEqual(mode.productionSafeMode, mode)
        }
    }

    func testImmediateDoubleCommandAcceptedButDelayedAndOptionAloneRejected() {
        var immediate = AlternateModifierTriggerState()
        XCTAssertFalse(change(
            &immediate,
            key: .leftCommand,
            isDown: true,
            mode: .leftCommandDoubleTap,
            now: 10.00
        ))
        XCTAssertFalse(change(
            &immediate,
            key: .leftCommand,
            isDown: false,
            mode: .leftCommandDoubleTap,
            now: 10.05
        ))
        XCTAssertFalse(change(
            &immediate,
            key: .leftCommand,
            isDown: true,
            mode: .leftCommandDoubleTap,
            now: 10.12
        ))
        XCTAssertTrue(change(
            &immediate,
            key: .leftCommand,
            isDown: false,
            mode: .leftCommandDoubleTap,
            now: 10.20
        ))

        var delayed = AlternateModifierTriggerState()
        XCTAssertFalse(change(
            &delayed,
            key: .rightCommand,
            isDown: true,
            mode: .rightCommandDoubleTap,
            now: 20.00
        ))
        XCTAssertFalse(change(
            &delayed,
            key: .rightCommand,
            isDown: false,
            mode: .rightCommandDoubleTap,
            now: 20.05
        ))
        XCTAssertFalse(change(
            &delayed,
            key: .rightCommand,
            isDown: true,
            mode: .rightCommandDoubleTap,
            now: 22.05
        ))
        XCTAssertFalse(change(
            &delayed,
            key: .rightCommand,
            isDown: false,
            mode: .rightCommandDoubleTap,
            now: 22.10
        ), "A two-second delay must never activate Hot Swap.")

        var overBoundary = AlternateModifierTriggerState()
        XCTAssertFalse(change(
            &overBoundary,
            key: .leftCommand,
            isDown: true,
            mode: .leftCommandDoubleTap,
            now: 30.00
        ))
        XCTAssertFalse(change(
            &overBoundary,
            key: .leftCommand,
            isDown: false,
            mode: .leftCommandDoubleTap,
            now: 30.05
        ))
        XCTAssertFalse(change(
            &overBoundary,
            key: .leftCommand,
            isDown: true,
            mode: .leftCommandDoubleTap,
            now: 30.25
        ))
        XCTAssertFalse(change(
            &overBoundary,
            key: .leftCommand,
            isDown: false,
            mode: .leftCommandDoubleTap,
            now: 30.31
        ), "A release-to-release gap above 250 ms must be rejected.")

        var chord = AlternateModifierTriggerState()
        XCTAssertFalse(
            chord.handleModifierChange(
                .leftOption,
                isDown: true,
                mode: .leftOptionDoubleTap,
                leftCommandDown: true,
                leftOptionDown: true,
                rightCommandDown: false,
                rightOptionDown: false,
                now: 40.00
            ),
            "Option alone must not activate even if an aggregate Command flag is stale."
        )
        XCTAssertFalse(change(
            &chord,
            key: .leftOption,
            isDown: false,
            mode: .leftOptionDoubleTap,
            now: 40.05
        ))

        var chordTiming = PhysicalModifierChordTimingState()
        chordTiming.noteModifierChange(.leftCommand, isDown: true, at: 41.00)
        XCTAssertFalse(change(
            &chord,
            key: .leftCommand,
            isDown: true,
            mode: .leftOptionDoubleTap,
            now: 41.00
        ))
        chordTiming.noteModifierChange(.leftOption, isDown: true, at: 41.05)
        let immediateChordStateAccepted = change(
            &chord,
            key: .leftOption,
            isDown: true,
            mode: .leftOptionDoubleTap,
            now: 41.05
        )
        XCTAssertTrue(immediateChordStateAccepted)
        XCTAssertTrue(chordTiming.accepts(keys: [.leftCommand, .leftOption]))

        var delayedChord = AlternateModifierTriggerState()
        var delayedChordTiming = PhysicalModifierChordTimingState()
        delayedChordTiming.noteModifierChange(.leftCommand, isDown: true, at: 50.00)
        XCTAssertFalse(change(
            &delayedChord,
            key: .leftCommand,
            isDown: true,
            mode: .leftOptionDoubleTap,
            now: 50.00
        ))
        delayedChordTiming.noteModifierChange(.leftOption, isDown: true, at: 50.30)
        let delayedChordStateAccepted = change(
            &delayedChord,
            key: .leftOption,
            isDown: true,
            mode: .leftOptionDoubleTap,
            now: 50.30
        )
        XCTAssertTrue(delayedChordStateAccepted)
        XCTAssertFalse(delayedChordTiming.accepts(keys: [.leftCommand, .leftOption]))
        XCTAssertFalse(
            delayedChordStateAccepted &&
                delayedChordTiming.accepts(keys: [.leftCommand, .leftOption]),
            "A delayed Command+Option chord must not activate in production."
        )
    }

    private func change(
        _ state: inout AlternateModifierTriggerState,
        key: PhysicalModifierTriggerKey,
        isDown: Bool,
        mode: AlternateTriggerMode,
        now: TimeInterval
    ) -> Bool {
        state.handleModifierChange(
            key,
            isDown: isDown,
            mode: mode,
            leftCommandDown: key == .leftCommand && isDown,
            leftOptionDown: key == .leftOption && isDown,
            rightCommandDown: key == .rightCommand && isDown,
            rightOptionDown: key == .rightOption && isDown,
            now: now
        )
    }
}
