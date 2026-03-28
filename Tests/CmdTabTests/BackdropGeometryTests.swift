import XCTest
@testable import CmdTab

final class BackdropGeometryTests: XCTestCase {
    func testRemappedFrameNormalizesIntoDestinationVisibleFrame() {
        let sourceScreenFrame = CGRect(x: 0, y: 0, width: 3440, height: 1440)
        let destinationScreenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let sourceWindowFrame = CGRect(x: 860, y: 180, width: 1720, height: 1080)

        let remapped = BackdropGeometry.remappedFrame(
            windowFrame: sourceWindowFrame,
            sourceScreenFrame: sourceScreenFrame,
            destinationScreenFrame: destinationScreenFrame
        )

        XCTAssertEqual(remapped.width, 756, accuracy: 0.5)
        XCTAssertEqual(remapped.height, 736.5, accuracy: 0.6)
        XCTAssertEqual(remapped.midX, destinationScreenFrame.midX, accuracy: 0.5)
        XCTAssertEqual(remapped.midY, destinationScreenFrame.midY, accuracy: 0.5)
    }

    func testPromotedFrameFillsDestinationWhenAspectMatches() {
        let sourceScreenFrame = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        let destinationScreenFrame = CGRect(x: 0, y: 0, width: 1200, height: 750)

        let remapped = BackdropGeometry.remappedFrame(
            windowFrame: sourceScreenFrame,
            sourceScreenFrame: sourceScreenFrame,
            destinationScreenFrame: destinationScreenFrame
        )

        XCTAssertEqual(remapped.width, destinationScreenFrame.width, accuracy: 0.5)
        XCTAssertEqual(remapped.height, destinationScreenFrame.height, accuracy: 0.5)
        XCTAssertEqual(
            BackdropGeometry.promotedFrame(windowFrame: remapped, screenFrame: destinationScreenFrame),
            destinationScreenFrame
        )
    }

    func testFullscreenSourceWindowAdoptsDestinationAspectRatio() {
        let sourceScreenFrame = CGRect(x: 0, y: 0, width: 3440, height: 1440)
        let destinationScreenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)

        let remapped = BackdropGeometry.remappedFrame(
            windowFrame: sourceScreenFrame,
            sourceScreenFrame: sourceScreenFrame,
            destinationScreenFrame: destinationScreenFrame
        )

        XCTAssertEqual(remapped.width, destinationScreenFrame.width, accuracy: 0.5)
        XCTAssertEqual(remapped.height, destinationScreenFrame.height, accuracy: 0.5)
        XCTAssertEqual(
            BackdropGeometry.promotedFrame(windowFrame: remapped, screenFrame: destinationScreenFrame),
            destinationScreenFrame
        )
    }
}
