import AppKit
import ApplicationServices
import CoreGraphics
import XCTest
@testable import CmdTab

final class PrivateWindowCapabilityTests: XCTestCase {
    func testUnavailableIdentityAndFocusForceNonExactPath() {
        XCTAssertFalse(
            PrivateWindowCapabilityPolicy.permitsExactFocus(
                identity: .unavailable("identity bridge absent"),
                focus: .available
            )
        )
        XCTAssertFalse(
            PrivateWindowCapabilityPolicy.permitsExactFocus(
                identity: .available,
                focus: .unavailable("focus bridge absent")
            )
        )
        XCTAssertTrue(
            PrivateWindowCapabilityPolicy.permitsExactFocus(
                identity: .available,
                focus: .available
            )
        )
        XCTAssertFalse(
            ActivationOutcomePolicy.recordsExactWindowMRU(.applicationFallbackUnverified)
        )
    }

    func testFakeProviderPublishesSanitizedIdentityCaptureAndFocusReasons() {
        let provider = FakePrivateCapabilities(
            identity: .unavailable("identity bridge absent"),
            capture: .degraded("public Core Graphics fallback"),
            focus: .unavailable("focus bridge absent")
        )
        PrivateWindowCapabilityDiagnostics.shared.update(from: provider)
        defer {
            PrivateWindowCapabilityDiagnostics.shared.update(
                from: SystemPrivateWindowCapabilityProvider.shared
            )
        }

        let snapshot = PrivateWindowCapabilityDiagnostics.shared.snapshot()
        XCTAssertEqual(snapshot.identity, provider.identityStatus)
        XCTAssertEqual(snapshot.capture, provider.captureStatus)
        XCTAssertEqual(snapshot.focus, provider.focusStatus)
    }

    func testUnavailableCaptureResultLeavesPublicFallbackAvailable() {
        let provider = FakePrivateCapabilities(
            identity: .available,
            capture: .unavailable("capture bridge absent"),
            focus: .available
        )
        guard case .unavailable = provider.captureWindow(42) else {
            return XCTFail("fake must expose an unavailable private capture")
        }

        let fallback = AppSwitcher.resolvePreferredCapture(
            preferred: Optional<NSImage>.none,
            prepare: { $0 }
        ) {
            NSImage(size: NSSize(width: 20, height: 20))
        }
        XCTAssertNotNil(fallback)
    }
}

private final class FakePrivateCapabilities: PrivateWindowCapabilityProviding {
    let identityStatus: CapabilityStatus
    let captureStatus: CapabilityStatus
    let focusStatus: CapabilityStatus

    init(identity: CapabilityStatus, capture: CapabilityStatus, focus: CapabilityStatus) {
        identityStatus = identity
        captureStatus = capture
        focusStatus = focus
    }

    func windowID(for element: AXUIElement) -> PrivateCapabilityResult<CGWindowID> { .unavailable }
    func captureWindow(_ windowID: CGWindowID) -> PrivateCapabilityResult<NSImage> { .unavailable }
    func focusWindow(ownerPID: pid_t, windowID: CGWindowID) -> PrivateCapabilityResult<Void> { .unavailable }
}
