import XCTest
@testable import AltTabMac

final class SwitcherPreferencesTests: XCTestCase {
    func testClampRecentTabsKeepsValueInsideConfiguredRange() {
        XCTAssertEqual(SwitcherPreferences.clampRecentTabs(-10), SwitcherPreferences.maxRecentTabsRange.lowerBound)
        XCTAssertEqual(SwitcherPreferences.clampRecentTabs(999), SwitcherPreferences.maxRecentTabsRange.upperBound)
        XCTAssertEqual(SwitcherPreferences.clampRecentTabs(12), 12)
    }

    func testMaxRecentTabsSetterClampsAndPersists() {
        let preferences = SwitcherPreferences.shared
        let originalValue = preferences.maxRecentTabs
        defer {
            preferences.maxRecentTabs = originalValue
        }

        preferences.maxRecentTabs = 999
        XCTAssertEqual(preferences.maxRecentTabs, SwitcherPreferences.maxRecentTabsRange.upperBound)
        XCTAssertEqual(UserDefaults.standard.object(forKey: "maxRecentTabs") as? Int, SwitcherPreferences.maxRecentTabsRange.upperBound)

        preferences.maxRecentTabs = -4
        XCTAssertEqual(preferences.maxRecentTabs, SwitcherPreferences.maxRecentTabsRange.lowerBound)
        XCTAssertEqual(UserDefaults.standard.object(forKey: "maxRecentTabs") as? Int, SwitcherPreferences.maxRecentTabsRange.lowerBound)
    }
}
