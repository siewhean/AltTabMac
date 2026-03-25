import XCTest
@testable import AltTabMac

final class HotkeyTriggerStateTests: XCTestCase {
    func testRevealRequiresMatchingArmedInvocation() {
        var state = HotkeyTriggerStateMachine()
        let invocation = makeInvocation(generation: 1, modifier: .command)

        state.arm(invocation)

        XCTAssertNil(state.revealIfArmed(generation: 2, modifier: .command))
        XCTAssertEqual(state.phase, .armed(invocation))

        XCTAssertEqual(state.revealIfArmed(generation: 1, modifier: .command), invocation)
        XCTAssertEqual(state.phase, .visible(invocation))
    }

    func testEarlyModifierReleaseAbortsArmedTriggerAndBlocksLaterReveal() {
        var state = HotkeyTriggerStateMachine()
        let invocation = makeInvocation(generation: 3, modifier: .command)

        state.arm(invocation)

        XCTAssertEqual(state.handleModifierRelease(.command), .abort(invocation))
        XCTAssertEqual(state.phase, .cancelled(invocation))
        XCTAssertNil(state.revealIfArmed(generation: 3, modifier: .command))
    }

    func testVisibleModifierReleaseCommitsCurrentInvocation() {
        var state = HotkeyTriggerStateMachine()
        let invocation = makeInvocation(generation: 5, modifier: .option)

        state.arm(invocation)
        XCTAssertEqual(state.revealIfArmed(generation: 5, modifier: .option), invocation)

        XCTAssertEqual(state.handleModifierRelease(.option), .commit(invocation))
        XCTAssertEqual(state.phase, .committed(invocation))
    }

    func testCancelHandlesArmedAndVisibleStatesWithOnePath() {
        var armedState = HotkeyTriggerStateMachine()
        let armedInvocation = makeInvocation(generation: 7, modifier: .command)
        armedState.arm(armedInvocation)
        XCTAssertEqual(armedState.cancel(), armedInvocation)
        XCTAssertEqual(armedState.phase, .cancelled(armedInvocation))

        var visibleState = HotkeyTriggerStateMachine()
        let visibleInvocation = makeInvocation(generation: 8, modifier: .option)
        visibleState.arm(visibleInvocation)
        XCTAssertEqual(visibleState.revealIfArmed(generation: 8, modifier: .option), visibleInvocation)
        XCTAssertEqual(visibleState.cancel(), visibleInvocation)
        XCTAssertEqual(visibleState.phase, .cancelled(visibleInvocation))
    }

    private func makeInvocation(generation: Int, modifier: HotkeyTriggerModifier) -> HotkeyPendingInvocation {
        HotkeyPendingInvocation(
            generation: generation,
            mode: modifier == .command ? .app : .tab,
            reverse: false,
            modifier: modifier
        )
    }
}
