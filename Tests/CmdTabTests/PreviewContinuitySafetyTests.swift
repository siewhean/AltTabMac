import AppKit
import XCTest
@testable import CmdTab

final class PreviewContinuitySafetyTests: XCTestCase {
    override func tearDown() {
        SwitcherPreviewContinuityStore.resetForTesting()
        super.tearDown()
    }

    func testIdentityContinuityIsLongLivedButNeverCrossesWindowOrProcessGeneration() {
        let image = NSImage(size: NSSize(width: 120, height: 90))
        let capturedAt = Date(timeIntervalSince1970: 100)
        let identity = "app-window:77:700|com.example.gpu|launch-1"

        _ = SwitcherPreviewContinuityStore.resolve(
            key: "title-and-frame-v1",
            identityKey: identity,
            preview: image,
            backdrop: image,
            captureAccessAllowed: true,
            now: capturedAt
        )

        let anotherWindow = SwitcherPreviewContinuityStore.resolve(
            key: "title-and-frame-v2",
            identityKey: "app-window:77:701|com.example.gpu|launch-1",
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 105)
        )
        XCTAssertNil(anotherWindow.preview)

        let restartedProcess = SwitcherPreviewContinuityStore.resolve(
            key: "title-and-frame-v2",
            identityKey: "app-window:77:700|com.example.gpu|launch-2",
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 105)
        )
        XCTAssertNil(restartedProcess.preview)

        let stillCurrent = SwitcherPreviewContinuityStore.resolve(
            key: "title-and-frame-v3",
            identityKey: identity,
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 699)
        )
        XCTAssertTrue(stillCurrent.preview === image)

        let expired = SwitcherPreviewContinuityStore.resolve(
            key: "title-and-frame-v4",
            identityKey: identity,
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 701)
        )
        XCTAssertNil(expired.preview)
    }

    func testExactMetadataKeyCannotCrossProcessGeneration() {
        let image = NSImage(size: NSSize(width: 120, height: 90))
        let capturedAt = Date(timeIntervalSince1970: 200)
        let exactKey = "same-pid-window-title-frame"

        _ = SwitcherPreviewContinuityStore.resolve(
            key: exactKey,
            identityKey: "app-window:77:700|com.example.gpu|launch-1",
            preview: image,
            backdrop: image,
            captureAccessAllowed: true,
            now: capturedAt
        )

        let restartedProcess = SwitcherPreviewContinuityStore.resolve(
            key: exactKey,
            identityKey: "app-window:77:700|com.example.gpu|launch-2",
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 205)
        )

        XCTAssertNil(restartedProcess.preview)
        XCTAssertNil(restartedProcess.backdrop)
    }

    func testPermissionDenialRequiresStableFalseSignalAndSuccessfulAccessResetsIt() {
        let start = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: false,
                preflightGranted: false,
                now: start
            )
        )
        XCTAssertTrue(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: false,
                preflightGranted: false,
                now: Date(timeIntervalSince1970: 1_000.5)
            )
        )
        XCTAssertFalse(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: false,
                preflightGranted: false,
                now: Date(timeIntervalSince1970: 1_001.1)
            )
        )
        XCTAssertTrue(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: false,
                preflightGranted: true,
                now: Date(timeIntervalSince1970: 1_001.2)
            )
        )
        XCTAssertTrue(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: false,
                preflightGranted: false,
                now: Date(timeIntervalSince1970: 1_001.3)
            ),
            "A newly granted or successful capture must begin a fresh denial confirmation window."
        )
    }
}
