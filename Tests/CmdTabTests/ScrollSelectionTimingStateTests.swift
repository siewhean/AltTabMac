import AppKit
import XCTest
@testable import CmdTab

final class ScrollSelectionTimingStateTests: XCTestCase {
    func testSmallPacketsNeedDeliberateSwipeDistance() {
        var state = ScrollSelectionTimingState()
        XCTAssertNil(step(&state, y: -2, phase: .began, at: 10))
        for packet in 1...10 {
            XCTAssertNil(step(&state, y: -2, at: 10 + Double(packet) * 0.01))
        }
        XCTAssertEqual(step(&state, y: -2, at: 10.11), 1)
    }

    func testContinuedSwipeStepsNoMoreThanOncePerSecond() {
        var state = ScrollSelectionTimingState()
        XCTAssertEqual(step(&state, y: -30, phase: .began, at: 10), 1)
        for packet in 1...99 {
            XCTAssertNil(step(&state, y: -30, at: 10 + Double(packet) * 0.01))
        }
        XCTAssertEqual(step(&state, y: -30, at: 11), 1)
        XCTAssertNil(step(&state, y: -30, at: 11.01))
        XCTAssertEqual(step(&state, y: -30, at: 12), 1)
    }

    func testFreshSwipeRespondsBeforePreviousCooldownExpires() {
        var state = ScrollSelectionTimingState()
        XCTAssertEqual(step(&state, y: -30, phase: .began, at: 10), 1)
        XCTAssertNil(step(&state, y: 0, phase: .ended, at: 10.1))
        XCTAssertEqual(step(&state, y: 30, phase: .began, at: 10.2), -1)
    }

    func testMomentumNeverMovesSelection() {
        var state = ScrollSelectionTimingState()
        XCTAssertEqual(step(&state, y: -30, phase: .began, at: 10), 1)
        for phase: NSEvent.Phase in [.began, .changed, .ended] {
            XCTAssertNil(step(&state, y: -200, phase: [], momentum: phase, at: 12))
        }
    }

    func testEndingAndCancellingDoNotMoveOrCarryDistance() {
        for phase: NSEvent.Phase in [.ended, .cancelled] {
            var state = ScrollSelectionTimingState()
            XCTAssertNil(step(&state, y: -20, phase: .began, at: 10))
            XCTAssertNil(step(&state, y: -200, phase: phase, at: 10.1))
            XCTAssertNil(step(&state, y: -10, phase: .began, at: 10.2))
        }
    }

    func testHorizontalSwipeUsesDominantAxisAndReversalsDiscardDistance() {
        var state = ScrollSelectionTimingState()
        XCTAssertNil(step(&state, x: 20, y: -1, phase: .began, at: 10))
        XCTAssertNil(step(&state, x: -10, y: 1, at: 10.1))
        XCTAssertEqual(step(&state, x: -14, y: 1, at: 10.2), 1)
    }

    func testPreciseEventsWithoutPhasesRestartAfterIdle() {
        var state = ScrollSelectionTimingState()
        XCTAssertEqual(step(&state, y: -30, phase: [], at: 10), 1)
        XCTAssertNil(step(&state, y: -30, phase: [], at: 10.1))
        XCTAssertEqual(step(&state, y: 30, phase: [], at: 10.4), -1)
    }

    func testMouseWheelDetentsHaveNoTrackpadCooldown() {
        var state = ScrollSelectionTimingState()
        XCTAssertEqual(step(&state, y: -1, precise: false, phase: [], at: 10), 1)
        XCTAssertEqual(step(&state, y: 1, precise: false, phase: [], at: 10.01), -1)
    }

    func testSessionResetClearsPartialSwipeAndCooldown() {
        var state = ScrollSelectionTimingState()
        XCTAssertEqual(step(&state, y: -30, at: 10), 1)
        state.reset()
        XCTAssertNil(step(&state, y: -20, at: 10.1))
        XCTAssertEqual(step(&state, y: -4, at: 10.2), 1)
    }

    func testStaleOrDuplicateGestureBeginningsCannotResetCooldown() {
        var state = ScrollSelectionTimingState()
        XCTAssertEqual(step(&state, y: -30, phase: .began, at: 10), 1)
        XCTAssertNil(step(&state, y: -30, phase: .began, at: 10))
        XCTAssertNil(step(&state, y: -30, phase: .began, at: 9))
        XCTAssertNil(step(&state, y: -30, at: 10.1))
        XCTAssertEqual(step(&state, y: -30, at: 11), 1)
    }

    func testDelayedPacketsCannotReplaySeveralStepsTogether() {
        var state = ScrollSelectionTimingState()
        var steps: [Int] = []
        for packet in 0...100 {
            if let result = step(&state, y: -30,
                                 phase: packet == 0 ? .began : .changed,
                                 at: 10 + Double(packet) * 0.02, deliveredAt: 12) {
                steps.append(result)
            }
        }
        XCTAssertEqual(steps, [1])
        XCTAssertNil(step(&state, y: -30, at: 12.5, deliveredAt: 12.5))
        XCTAssertEqual(step(&state, y: -30, at: 13, deliveredAt: 13), 1)
    }

    func testOldBeginningCannotResetPacingButFreshGestureCan() {
        var state = ScrollSelectionTimingState()
        XCTAssertEqual(step(&state, y: -30, phase: .began, at: 10, deliveredAt: 10), 1)
        XCTAssertNil(step(&state, y: -30, phase: .began, at: 10.01, deliveredAt: 10.4))
        XCTAssertNil(step(&state, y: -30, at: 10.4, deliveredAt: 10.4))
        XCTAssertEqual(step(&state, y: 30, phase: .began, at: 10.5, deliveredAt: 10.5), -1)
    }

    func testNativeTimestampOriginDoesNotAffectIngressPacing() throws {
        for nativeTimestamp: UInt64 in [0, 1_000_000_000, 999_000_000_000_000] {
            let cg = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                                         wheelCount: 2, wheel1: -30, wheel2: 0, wheel3: 0))
            cg.timestamp = nativeTimestamp
            cg.setIntegerValueField(.scrollWheelEventScrollPhase, value: 1)
            let event = try XCTUnwrap(NSEvent(cgEvent: cg))
            let input = ScrollSelectionInput(event: event, receivedAt: 10)
            XCTAssertEqual(input.receivedAt, 10)
            XCTAssertTrue(input.isPrecise)
            XCTAssertEqual(input.phase, .began)
            var state = ScrollSelectionTimingState()
            XCTAssertEqual(state.selectionStep(input, deliveredAt: 10.01), 1)
            XCTAssertNil(state.selectionStep(input, deliveredAt: 10.02))
        }
    }

    func testGlobalAdapterRetainsMomentumAndHorizontalDelta() throws {
        let cg = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                                     wheelCount: 2, wheel1: 2, wheel2: 30, wheel3: 0))
        cg.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2)
        cg.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 2)
        let input = ScrollSelectionInput(event: try XCTUnwrap(NSEvent(cgEvent: cg)), receivedAt: 10)
        XCTAssertEqual(input.phase, .changed)
        XCTAssertEqual(input.momentumPhase, .changed)
        XCTAssertEqual(input.deltaX, 30)
        XCTAssertEqual(input.deltaY, 2)
        var state = ScrollSelectionTimingState()
        XCTAssertNil(state.selectionStep(input, deliveredAt: 10.01))
    }

    func testPriorPresentationPacketsCannotMoveReopenedSelector() throws {
        let cg = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                                     wheelCount: 1, wheel1: -30, wheel2: 0, wheel3: 0))
        cg.setIntegerValueField(.scrollWheelEventScrollPhase, value: 1)
        let event = try XCTUnwrap(NSEvent(cgEvent: cg))
        var state = ScrollSelectionTimingState()
        let oldInput = ScrollSelectionInput(event: event, receivedAt: 10)
        XCTAssertNil(state.selectionStep(oldInput, deliveredAt: 10.1, presentationStartedAt: 10.05))
        let freshInput = ScrollSelectionInput(event: event, receivedAt: 10.06)
        XCTAssertEqual(state.selectionStep(freshInput, deliveredAt: 10.1, presentationStartedAt: 10.05), 1)
    }

    private func step(
        _ state: inout ScrollSelectionTimingState,
        x: Double = 0,
        y: Double,
        precise: Bool = true,
        phase: NSEvent.Phase = .changed,
        momentum: NSEvent.Phase = [],
        at timestamp: TimeInterval,
        deliveredAt: TimeInterval? = nil
    ) -> Int? {
        state.selectionStep(deltaX: x, deltaY: y, isPrecise: precise,
                            phase: phase, momentumPhase: momentum, at: timestamp,
                            deliveredAt: deliveredAt)
    }
}
