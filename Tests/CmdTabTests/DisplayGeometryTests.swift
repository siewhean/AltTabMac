import CoreGraphics
import XCTest
@testable import CmdTab

final class DisplayGeometryTests: XCTestCase {
    // CG global space: main display at the origin, a larger display stacked
    // above it (negative y), and one to the right with a different height.
    private let main = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let above = CGRect(x: 0, y: -1080, width: 1920, height: 1080)
    private let right = CGRect(x: 1440, y: 0, width: 2560, height: 1440)
    private var displays: [CGRect] { [main, above, right] }

    func testWindowOnStackedDisplayResolvesToThatDisplay() {
        let window = CGRect(x: 100, y: -900, width: 800, height: 600)
        XCTAssertEqual(DisplayGeometry.screenFrame(containing: window, displayBounds: displays), above)
    }

    func testWindowLowOnTallSideDisplayResolvesToThatDisplay() {
        // Below the main display's bottom edge, which AppKit coordinates
        // would have placed on no screen at all.
        let window = CGRect(x: 2000, y: 1000, width: 600, height: 300)
        XCTAssertEqual(DisplayGeometry.screenFrame(containing: window, displayBounds: displays), right)
    }

    func testStraddlingWindowFallsBackToFirstOverlappingDisplay() {
        let window = CGRect(x: -500, y: 100, width: 600, height: 400)
        XCTAssertEqual(DisplayGeometry.screenFrame(containing: window, displayBounds: displays), main)
        XCTAssertNil(DisplayGeometry.screenFrame(
            containing: CGRect(x: -5000, y: -5000, width: 10, height: 10),
            displayBounds: displays
        ))
    }

    func testAppKitMousePointConvertsToCGSpace() {
        // AppKit y = 1500 is 600 points above the main display's top edge.
        let point = DisplayGeometry.cgPoint(
            fromAppKit: CGPoint(x: 100, y: 1500),
            mainDisplayHeight: main.height
        )
        XCTAssertEqual(point, CGPoint(x: 100, y: -600))
        XCTAssertEqual(
            DisplayGeometry.screenFrame(
                containing: CGRect(origin: point, size: .zero),
                displayBounds: displays
            ),
            above
        )
    }
}
