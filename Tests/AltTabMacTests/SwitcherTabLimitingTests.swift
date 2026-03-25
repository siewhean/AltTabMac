import XCTest
@testable import AltTabMac

final class SwitcherTabLimitingTests: XCTestCase {
    func testRecentTabLimitIsAppliedAfterMRUOrdering() {
        let tabA = makeTab(title: "Docs", url: "https://example.com/docs")
        let tabB = makeTab(title: "Mail", url: "https://example.com/mail")
        let tabC = makeTab(title: "Issues", url: "https://example.com/issues")

        let limited = SwitcherTabLimiting.limitedRecentTabs(
            [tabA, tabB, tabC],
            historyEntries: [tabC.historyIdentity, tabA.historyIdentity, tabB.historyIdentity],
            currentFrontmost: tabC.historyIdentity,
            limit: 2
        )

        XCTAssertEqual(limited.map(\.title), ["Docs", "Mail"])
    }

    func testZeroLimitKeepsAllTabs() {
        let tabs = [
            makeTab(title: "Docs", url: "https://example.com/docs"),
            makeTab(title: "Mail", url: "https://example.com/mail"),
            makeTab(title: "Issues", url: "https://example.com/issues"),
        ]

        let limited = SwitcherTabLimiting.limitedRecentTabs(
            tabs,
            historyEntries: tabs.map(\.historyIdentity),
            currentFrontmost: nil,
            limit: 0
        )

        XCTAssertEqual(limited.map(\.title), tabs.map(\.title))
    }

    private func makeTab(title: String, url: String) -> SwitcherItem {
        let identity = SwitcherHistoryIdentity.browserTab(
            bundleID: "company.thebrowser.Browser",
            url: url,
            title: title
        )

        return SwitcherItem(
            title: title,
            subtitle: url,
            icon: nil,
            previewImage: nil,
            historyIdentity: identity,
            sourceAppIdentifier: "company.thebrowser.Browser",
            kind: .browserTab
        ) {}
    }
}
