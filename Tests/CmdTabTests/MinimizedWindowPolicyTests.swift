import ApplicationServices
import XCTest
@testable import CmdTab

final class MinimizedWindowPolicyTests: XCTestCase {
    func testMinimizedStandardWindowIsIncludedOnlyWhenEnabled() {
        XCTAssertFalse(
            AXWindowCatalog.isEligible(
                role: kAXWindowRole as String,
                subrole: kAXStandardWindowSubrole as String,
                parentRole: kAXApplicationRole as String,
                isMinimized: true,
                includeMinimized: false
            )
        )
        XCTAssertTrue(
            AXWindowCatalog.isEligible(
                role: kAXWindowRole as String,
                subrole: kAXStandardWindowSubrole as String,
                parentRole: kAXApplicationRole as String,
                isMinimized: true,
                includeMinimized: true
            )
        )
    }

    func testChildWindowNeverBecomesTopLevelSwitcherTarget() {
        XCTAssertFalse(
            AXWindowCatalog.isEligible(
                role: kAXWindowRole as String,
                subrole: kAXStandardWindowSubrole as String,
                parentRole: kAXWindowRole as String,
                isMinimized: false,
                includeMinimized: true
            )
        )
    }

    func testFloatingPanelRemainsExcludedByDefault() {
        XCTAssertFalse(
            AXWindowCatalog.isEligible(
                role: kAXWindowRole as String,
                subrole: kAXFloatingWindowSubrole as String,
                parentRole: kAXApplicationRole as String,
                isMinimized: false,
                includeMinimized: true
            )
        )
        XCTAssertTrue(
            AXWindowCatalog.isEligible(
                role: kAXWindowRole as String,
                subrole: kAXFloatingWindowSubrole as String,
                parentRole: kAXApplicationRole as String,
                isMinimized: false,
                includeMinimized: true,
                allowFloating: true
            )
        )
    }

    func testFullscreenWindowSubroleRemainsEligible() {
        XCTAssertTrue(
            AXWindowCatalog.isEligible(
                role: kAXWindowRole as String,
                subrole: "AXFullScreenWindow",
                parentRole: kAXApplicationRole as String,
                isMinimized: false,
                includeMinimized: false
            )
        )
    }
}
