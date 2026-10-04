import AppKit
import XCTest
@testable import CmdTab

final class PermissionSetupTests: XCTestCase {
    func testDragUsesExactBundlePathIncludingSpacesAndDistinctCopies() {
        let running = URL(fileURLWithPath: "/Applications/Test Builds/CmdTab.app")
        XCTAssertEqual(PermissionSetupKind.draggableAppURL(bundleURL: running), running)
        let writer = running as NSURL
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        XCTAssertTrue(pasteboard.writeObjects([writer]))
        let draggedURL = NSURL(from: pasteboard) as URL?
        XCTAssertEqual(draggedURL, running)
        XCTAssertNotEqual(draggedURL, URL(fileURLWithPath: "/Applications/CmdTab.app"))
    }

    func testNonAppAndRemoteURLsAreNotOfferedAsPermissionApps() {
        XCTAssertNil(PermissionSetupKind.draggableAppURL(bundleURL:
            URL(fileURLWithPath: "/tmp/CmdTabTests.xctest")))
        XCTAssertNil(PermissionSetupKind.draggableAppURL(bundleURL:
            URL(string: "https://example.com/CmdTab.app")!))
    }

    @MainActor
    func testHelperStaysVisibleWhenSettingsOwnsFocusWithoutActivatingCmdTab() {
        let panel = PermissionSetupWindowController.makePanel()
        XCTAssertEqual(panel.level, .floating)
        XCTAssertTrue(panel.isFloatingPanel)
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(panel.styleMask.contains(.closable))
        XCTAssertTrue(panel.collectionBehavior.contains(.moveToActiveSpace))
    }
}
