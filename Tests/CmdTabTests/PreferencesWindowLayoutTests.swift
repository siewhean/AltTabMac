import AppKit
import SwiftUI
import XCTest
@testable import CmdTab

@MainActor
final class PreferencesWindowLayoutTests: XCTestCase {
    func testSettingsKeepsNativeTitlebarAndExplicitContentGeometry() throws {
        _ = NSApplication.shared
        let controller = PreferencesWindowController()
        let window = try XCTUnwrap(controller.window)
        defer { window.close() }

        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertFalse(window.styleMask.contains(.fullSizeContentView))
        XCTAssertFalse(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titleVisibility, .visible)
        XCTAssertEqual(window.contentMinSize, NSSize(width: 720, height: 760))
        XCTAssertEqual(window.contentView?.bounds.size, NSSize(width: 720, height: 760))
        XCTAssertFalse(window.isRestorable)

        let hosting = try XCTUnwrap(window.contentViewController as? NSHostingController<PreferencesView>)
        XCTAssertTrue(hosting.sizingOptions.isEmpty)
    }
}
