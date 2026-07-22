import XCTest
@testable import CmdTab

final class CaptureFallbackTests: XCTestCase {
    func testPreparedPreferredCaptureWinsWithoutCallingFallback() {
        var fallbackCallCount = 0

        let result = AppSwitcher.resolvePreferredCapture(
            preferred: "raw-preferred",
            prepare: { raw in
                raw == "raw-preferred" ? "prepared-preferred" : nil
            },
            fallback: {
                fallbackCallCount += 1
                return "fallback"
            }
        )

        XCTAssertEqual(result, "prepared-preferred")
        XCTAssertEqual(fallbackCallCount, 0)
    }

    func testRejectedPreferredCaptureFallsThroughToFallback() {
        var fallbackCallCount = 0

        let result = AppSwitcher.resolvePreferredCapture(
            preferred: "blank-hardware-frame",
            prepare: { _ in nil },
            fallback: {
                fallbackCallCount += 1
                return "public-core-graphics-capture"
            }
        )

        XCTAssertEqual(result, "public-core-graphics-capture")
        XCTAssertEqual(fallbackCallCount, 1)
    }

    func testMissingPreferredCaptureFallsThroughToFallback() {
        var fallbackCallCount = 0

        let result: String? = AppSwitcher.resolvePreferredCapture(
            preferred: Optional<String>.none,
            prepare: { $0 },
            fallback: {
                fallbackCallCount += 1
                return "public-core-graphics-capture"
            }
        )

        XCTAssertEqual(result, "public-core-graphics-capture")
        XCTAssertEqual(fallbackCallCount, 1)
    }
}
