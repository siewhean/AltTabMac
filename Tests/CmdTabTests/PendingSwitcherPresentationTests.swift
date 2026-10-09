import XCTest
@testable import CmdTab

final class PendingSwitcherPresentationTests: XCTestCase {
    func testHeldColdOverlayResumesExactlyOnceWhenInventoryArrives() {
        let request = PendingSwitcherPresentation(profileID: UUID(), reverse: true, makeKey: false, requiredModifier: .command)
        var state = PendingSwitcherPresentationState(pending: request)
        XCTAssertNil(state.takeWhenReady(inventoryReady: false, heldModifiers: [.command]))
        XCTAssertEqual(state.pending, request)
        XCTAssertEqual(state.takeWhenReady(inventoryReady: true, heldModifiers: [.command]), request)
        XCTAssertNil(state.takeWhenReady(inventoryReady: true, heldModifiers: [.command]))
    }

    func testReleaseBeforeInventoryCannotRevealOrActivateLater() {
        var state = PendingSwitcherPresentationState(pending: .init(profileID: UUID(), reverse: false, makeKey: false, requiredModifier: .option))
        XCTAssertNil(state.takeWhenReady(inventoryReady: true, heldModifiers: []))
        XCTAssertNil(state.takeWhenReady(inventoryReady: true, heldModifiers: [.option]))
    }

    func testCancelledRequestStaysCancelledAfterModifierIsPressedAgain() {
        var state = PendingSwitcherPresentationState(pending: .init(profileID: UUID(), reverse: false, makeKey: false, requiredModifier: .command))
        state.cancel()
        XCTAssertNil(state.takeWhenReady(inventoryReady: true, heldModifiers: [.command]))
    }

    func testStandalonePracticeResumesWithoutHeldModifier() {
        let request = PendingSwitcherPresentation(profileID: UUID(), reverse: false, makeKey: true, requiredModifier: nil)
        var state = PendingSwitcherPresentationState(pending: request)
        XCTAssertNil(state.takeWhenReady(inventoryReady: false, heldModifiers: []))
        XCTAssertEqual(state.takeWhenReady(inventoryReady: true, heldModifiers: []), request)
    }

    func testNoPendingRequestDoesNotChangeWarmSession() {
        var state = PendingSwitcherPresentationState()
        XCTAssertNil(state.takeWhenReady(inventoryReady: true, heldModifiers: [.command]))
    }
}
