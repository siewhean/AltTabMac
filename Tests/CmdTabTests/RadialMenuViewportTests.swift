import XCTest
@testable import CmdTab

final class RadialMenuViewportTests: XCTestCase {
    func testViewportStartsWithFirstEightApps() {
        var state = RadialMenuViewportState()
        state.reset(itemCount: 12, selectedIndex: 0)

        XCTAssertEqual(state.visibleIndices, Array(0..<8))
        XCTAssertEqual(state.selectedSlot, 0)
    }

    func testMovingRightKeepsViewportStableForFirstThreeMoves() {
        var state = RadialMenuViewportState()
        state.reset(itemCount: 12, selectedIndex: 0)

        XCTAssertEqual(state.advance(direction: 1, itemCount: 12), 1)
        XCTAssertEqual(state.advance(direction: 1, itemCount: 12), 2)
        XCTAssertEqual(state.advance(direction: 1, itemCount: 12), 3)
        XCTAssertEqual(state.visibleIndices, Array(0..<8))
        XCTAssertEqual(state.selectedSlot, 3)
    }

    func testFourthRightMoveReplacesOppositeSlotWithoutRotatingRing() {
        var state = RadialMenuViewportState()
        state.reset(itemCount: 12, selectedIndex: 0)

        for _ in 0..<4 {
            _ = state.advance(direction: 1, itemCount: 12)
        }

        XCTAssertEqual(state.selectedSlot, 4)
        XCTAssertEqual(state.visibleIndices, [8, 1, 2, 3, 4, 5, 6, 7])
    }

    func testReversingDirectionMovesToImmediateLeftNeighborFirst() {
        var state = RadialMenuViewportState()
        state.reset(itemCount: 12, selectedIndex: 0)

        for _ in 0..<4 {
            _ = state.advance(direction: 1, itemCount: 12)
        }

        let selected = state.advance(direction: -1, itemCount: 12)
        XCTAssertEqual(selected, 3)
        XCTAssertEqual(state.selectedSlot, 3)
        XCTAssertEqual(state.visibleIndices, [8, 1, 2, 3, 4, 5, 6, 7])
    }

    func testFirstLeftMoveDoesNotReplaceWholeViewport() {
        var state = RadialMenuViewportState()
        state.reset(itemCount: 12, selectedIndex: 0)

        let selected = state.advance(direction: -1, itemCount: 12)
        XCTAssertEqual(selected, 7)
        XCTAssertEqual(state.selectedSlot, 7)
        XCTAssertEqual(state.visibleIndices, Array(0..<8))
    }

    func testFourthLeftMoveBeginsReplacingOppositeSlot() {
        var state = RadialMenuViewportState()
        state.reset(itemCount: 12, selectedIndex: 0)

        for _ in 0..<4 {
            _ = state.advance(direction: -1, itemCount: 12)
        }

        XCTAssertEqual(state.selectedSlot, 4)
        XCTAssertEqual(state.visibleIndices, [11, 1, 2, 3, 4, 5, 6, 7])
    }
}
