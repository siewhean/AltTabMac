import XCTest
@testable import CmdTab

final class NativeCapabilityStatusTests: XCTestCase {
    func testExactAXLookupUnavailableReportsStatusWithoutAnIdentity() {
        let result = AXWindowIdentityLookup.resolution(
            symbolAvailable: false,
            resultCode: nil,
            windowID: 91
        )

        XCTAssertNil(result.windowID)
        XCTAssertEqual(result.status.level, .unavailable)
        XCTAssertEqual(
            result.status.reason,
            "Exact AX window identity is unavailable on this macOS build."
        )
    }

    func testExactAXLookupFailureReportsStatusWithoutAnIdentity() {
        let result = AXWindowIdentityLookup.resolution(
            symbolAvailable: true,
            resultCode: -25204,
            windowID: 91
        )

        XCTAssertNil(result.windowID)
        XCTAssertEqual(result.status.level, .failed)
        XCTAssertEqual(
            result.status.reason,
            "Exact AX window identity failed with result -25204."
        )
    }

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

    func testSecureInputUnavailableIsNotReportedAsInactive() {
        let status = SecureInputMonitor.evaluation(
            symbolAvailable: false,
            isEnabled: false
        )

        XCTAssertEqual(status.level, .unavailable)
        XCTAssertEqual(
            status.reason,
            "Secure Event Input state is unavailable on this macOS build; CmdTab relies on event-tap disable behaviour."
        )
    }

    func testSecureInputActiveReportsShortcutBypass() {
        let status = SecureInputMonitor.evaluation(
            symbolAvailable: true,
            isEnabled: true
        )

        XCTAssertEqual(status.level, .degraded)
        XCTAssertEqual(
            status.reason,
            "Secure Event Input is active; CmdTab bypasses shortcut interception."
        )
    }

    func testSecureInputInactiveIsAvailable() {
        let status = SecureInputMonitor.evaluation(
            symbolAvailable: true,
            isEnabled: false
        )

        XCTAssertEqual(status.level, .available)
        XCTAssertEqual(status.reason, "Secure Event Input is inactive.")
    }
}
