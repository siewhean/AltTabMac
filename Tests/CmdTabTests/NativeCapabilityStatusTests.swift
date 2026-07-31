import XCTest
@testable import CmdTab

final class NativeCapabilityStatusTests: XCTestCase {
    func testUnavailableSymbolHasExplicitUnavailableStatus() {
        let status = NativeCapabilityStatusEvaluator.operationStatus(
            symbolAvailable: false,
            resultCode: nil,
            capability: "Exact AX window identity"
        )

        XCTAssertEqual(status.level, .unavailable)
        XCTAssertEqual(
            status.reason,
            "Exact AX window identity is unavailable on this macOS build."
        )
    }

    func testNonzeroOperationResultIsReportedAsFailure() {
        let status = NativeCapabilityStatusEvaluator.operationStatus(
            symbolAvailable: true,
            resultCode: -25204,
            capability: "SkyLight exact-window focus"
        )

        XCTAssertEqual(status.level, .failed)
        XCTAssertEqual(
            status.reason,
            "SkyLight exact-window focus failed with result -25204."
        )
    }

    func testSuccessfulOperationIsAvailable() {
        let status = NativeCapabilityStatusEvaluator.operationStatus(
            symbolAvailable: true,
            resultCode: 0,
            capability: "SkyLight hardware preview capture"
        )

        XCTAssertEqual(status, .available)
    }
}
