import CoreGraphics
import XCTest
@testable import CmdTab

final class EventTapRecoveryTests: XCTestCase {
    func testWatchdogRecoversSilentDisableAndInvalidationWithoutTouchingHealthyTap() {
        var trusted = true
        var valid = true
        var enabled = true
        var actions: [String] = []
        let watchdog = EventTapWatchdog(
            isTrusted: { trusted },
            hasValidTap: { valid },
            isEnabled: { enabled },
            reinstall: { actions.append("install"); valid = true; enabled = true },
            reenable: { actions.append("enable"); enabled = true },
            suspend: { actions.append("suspend"); valid = false }
        )
        watchdog.checkHealth()
        XCTAssertTrue(actions.isEmpty)
        enabled = false // No disabled notification was delivered.
        watchdog.checkHealth()
        watchdog.checkHealth()
        XCTAssertEqual(actions, ["enable"])
        valid = false // Invalid Mach port after a system transition.
        watchdog.checkHealth()
        XCTAssertEqual(actions, ["enable", "install"])
        trusted = false
        watchdog.checkHealth()
        watchdog.checkHealth()
        XCTAssertEqual(actions, ["enable", "install", "suspend"])
        trusted = true
        watchdog.checkHealth()
        XCTAssertEqual(actions, ["enable", "install", "suspend", "install"])
    }

    func testMissingTapIsNotInstalledWithoutAccessibility() {
        let watchdog = EventTapWatchdog(
            isTrusted: { false },
            hasValidTap: { false },
            isEnabled: { XCTFail("Cannot query an unavailable tap"); return false },
            reinstall: { XCTFail("Cannot install without Accessibility") },
            reenable: { XCTFail("Cannot enable without Accessibility") },
            suspend: { XCTFail("No tap to suspend") }
        )
        watchdog.checkHealth()
    }

    func testSecureInputUnavailableSymbolDoesNotDisableAllShortcuts() {
        XCTAssertFalse(SecureInputMonitor.isEnabled(symbolResult: nil))
        XCTAssertFalse(SecureInputMonitor.isEnabled(symbolResult: 0))
        XCTAssertTrue(SecureInputMonitor.isEnabled(symbolResult: 1))
        XCTAssertTrue(SecureInputMonitor.isEnabled(symbolResult: 255))
    }

    func testCommandTabStillRoutesWhileEditingButOrdinaryTextPassesThrough() {
        for flags: CGEventFlags in [.maskCommand, [.maskCommand, .maskShift]] {
            XCTAssertFalse(ProfileHotkeyManager.shouldBypassForActiveTextInput(
                keyCode: 48, flags: flags, hasActiveTextInput: true
            ))
        }
        XCTAssertTrue(ProfileHotkeyManager.shouldBypassForActiveTextInput(
            keyCode: 9, flags: .maskCommand, hasActiveTextInput: true
        ))
        XCTAssertTrue(ProfileHotkeyManager.shouldBypassForActiveTextInput(
            keyCode: 0, flags: [], hasActiveTextInput: true
        ))
        XCTAssertFalse(ProfileHotkeyManager.shouldBypassForActiveTextInput(
            keyCode: 48, flags: .maskAlternate, hasActiveTextInput: false
        ))
    }
}
