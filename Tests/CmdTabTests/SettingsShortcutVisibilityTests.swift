import AppKit
import XCTest
@testable import CmdTab

@MainActor
final class SettingsShortcutVisibilityTests: XCTestCase {
    func testHidingSettingsPreservesDraftAndUnrelatedWindows() {
        _ = NSApplication.shared
        let settings = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let profiles = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let unrelated = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let draft = NSTextField(string: "Unsaved profile draft")
        profiles.contentView = draft
        settings.identifier = SettingsWindowVisibilityPolicy.settingsIdentifier
        profiles.identifier = SettingsWindowVisibilityPolicy.profilesIdentifier
        defer { [settings, profiles, unrelated].forEach { $0.orderOut(nil) } }
        [settings, profiles, unrelated].forEach { $0.orderFrontRegardless() }

        SettingsWindowVisibilityPolicy.hideSettings(in: [settings, profiles, unrelated])

        XCTAssertFalse(settings.isVisible)
        XCTAssertFalse(profiles.isVisible)
        XCTAssertTrue(unrelated.isVisible)
        XCTAssertTrue(profiles.contentView === draft)
        XCTAssertEqual(draft.stringValue, "Unsaved profile draft")
        profiles.orderFrontRegardless()
        XCTAssertTrue(profiles.isVisible, "Explicit reopening must remain possible")
    }

    func testReopenDoesNotOpenSettings() throws {
        _ = NSApplication.shared
        let preferences = PreferencesWindowController()
        let window = try XCTUnwrap(preferences.window)
        defer { window.orderOut(nil) }
        window.orderOut(nil)

        XCTAssertFalse(SettingsWindowVisibilityPolicy.handleReopen(onboardingWindow: nil))
        XCTAssertFalse(window.isVisible)
        XCTAssertFalse(SettingsWindowVisibilityPolicy.handleReopen(onboardingWindow: NSWindow()))
        XCTAssertFalse(window.isVisible)
    }

    func testProductionShortcutHidesSettingsBeforeInventoryOrAuthorization() throws {
        _ = NSApplication.shared
        let preferences = PreferencesWindowController()
        let window = try XCTUnwrap(preferences.window)
        let switcher = ProductionSwitcherWindowController()
        var licensingPresentations = 0
        switcher.onLicenseAccessRequired = { licensingPresentations += 1 }
        defer { switcher.cancelAndHide(); window.orderOut(nil) }

        window.orderFrontRegardless()
        switcher.showOrAdvance()
        XCTAssertFalse(window.isVisible)
        XCTAssertEqual(licensingPresentations, 0)

        switcher.cancelAndHide()
        window.orderFrontRegardless()
        switcher.commitTriggerSession()
        XCTAssertFalse(window.isVisible)
        XCTAssertEqual(licensingPresentations, 0)
    }
}
