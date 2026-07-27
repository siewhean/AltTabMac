import XCTest
@testable import CmdTab

final class WindowManagementActionTests: XCTestCase {
    private let visible = CGRect(x: 100, y: 50, width: 1200, height: 900)

    func testHalfTilesFillVisibleHeightWithoutEscapingDisplay() {
        let left = WindowGeometryPlanner.tiledFrame(.leftHalf, visibleFrame: visible)
        let right = WindowGeometryPlanner.tiledFrame(.rightHalf, visibleFrame: visible)

        XCTAssertEqual(left, CGRect(x: 100, y: 50, width: 600, height: 900))
        XCTAssertEqual(right, CGRect(x: 700, y: 50, width: 600, height: 900))
        XCTAssertEqual(left.union(right), visible)
    }

    func testThirdTilesCoverVisibleFrameDeterministically() {
        let first = WindowGeometryPlanner.tiledFrame(.firstThird, visibleFrame: visible)
        let centre = WindowGeometryPlanner.tiledFrame(.centerThird, visibleFrame: visible)
        let last = WindowGeometryPlanner.tiledFrame(.lastThird, visibleFrame: visible)

        XCTAssertEqual(first.minX, visible.minX, accuracy: 1)
        XCTAssertEqual(last.maxX, visible.maxX, accuracy: 1)
        XCTAssertEqual(first.height, visible.height)
        XCTAssertEqual(centre.height, visible.height)
        XCTAssertEqual(last.height, visible.height)
        XCTAssertLessThanOrEqual(abs(first.width + centre.width + last.width - visible.width), 2)
    }

    func testCenteredFramePreservesSizeWhenItFits() {
        let result = WindowGeometryPlanner.centeredFrame(
            windowSize: CGSize(width: 640, height: 480),
            visibleFrame: visible
        )

        XCTAssertEqual(result.size, CGSize(width: 640, height: 480))
        XCTAssertEqual(result.midX, visible.midX, accuracy: 0.5)
        XCTAssertEqual(result.midY, visible.midY, accuracy: 0.5)
        XCTAssertTrue(visible.contains(result))
    }

    func testCenteredFrameClampsOversizedWindow() {
        let result = WindowGeometryPlanner.centeredFrame(
            windowSize: CGSize(width: 2400, height: 1800),
            visibleFrame: visible
        )
        XCTAssertEqual(result, visible)
    }

    func testConstrainedFrameNeverEscapesDestination() {
        let result = WindowGeometryPlanner.constrained(
            CGRect(x: -500, y: 2_000, width: 3_000, height: 12),
            to: visible
        )

        XCTAssertTrue(visible.contains(result))
        XCTAssertEqual(result.width, visible.width)
        XCTAssertGreaterThanOrEqual(result.height, 120)
    }

    func testAppKitToAccessibilityCoordinateConversion() {
        let appKitFrame = CGRect(x: 100, y: 200, width: 500, height: 300)
        let converted = WindowGeometryPlanner.appKitFrameToAX(
            appKitFrame,
            mainDisplayTop: 1_200
        )

        XCTAssertEqual(converted, CGRect(x: 100, y: 700, width: 500, height: 300))
    }

    func testOnlyForceQuitRequiresConfirmationAndRemovesItem() {
        for action in WindowManagementAction.allCases {
            XCTAssertEqual(action.requiresConfirmation, action == .forceQuitApplication)
            XCTAssertEqual(action.removesSelectedItem, action == .forceQuitApplication)
        }
    }
}
