import AppKit
import XCTest
@testable import CmdTab

@MainActor
final class MenuBarPresentationTests: XCTestCase {
    func testToolTipIsAssignedOnlyWhenItChanges() {
        let button = NSButton()

        XCTAssertTrue(MenuBarPresentation.applyToolTip("First", to: button))
        XCTAssertEqual(button.toolTip, "First")
        XCTAssertFalse(
            MenuBarPresentation.applyToolTip("First", to: button),
            "Re-setting an identical tooltip makes AppKit show it at the pointer"
        )
        XCTAssertTrue(MenuBarPresentation.applyToolTip("Second", to: button))
        XCTAssertEqual(button.toolTip, "Second")
        XCTAssertFalse(MenuBarPresentation.applyToolTip("Second", to: nil))
    }
}
