import XCTest
@testable import CmdTab

final class SwitcherViewModelTests: XCTestCase {
    func testResolvedSelectedIndexClampsToLastVisibleItem() {
        let viewModel = SwitcherViewModel()
        viewModel.items = [
            makeItem(title: "Finder", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11)),
            makeItem(title: "Arc", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22)),
        ]
        viewModel.selectedIndex = 7

        XCTAssertEqual(viewModel.resolvedSelectedIndex, 1)
    }

    func testResolvedSelectedIndexIsNilWhenItemsEmpty() {
        let viewModel = SwitcherViewModel()
        viewModel.items = []
        viewModel.selectedIndex = 0

        XCTAssertNil(viewModel.resolvedSelectedIndex)
    }

    func testResolvedSelectedIndexNegativeClampsToZero() {
        let viewModel = SwitcherViewModel()
        viewModel.items = [
            makeItem(title: "Finder", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11)),
        ]
        viewModel.selectedIndex = -5

        XCTAssertEqual(viewModel.resolvedSelectedIndex, 0)
    }

    func testCycleForwardWrapsAround() {
        let viewModel = SwitcherViewModel()
        viewModel.items = [
            makeItem(title: "Finder", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11)),
            makeItem(title: "Arc", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22)),
        ]
        viewModel.selectedIndex = 1
        viewModel.move(by: 1)

        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func testCycleBackwardWrapsAround() {
        let viewModel = SwitcherViewModel()
        viewModel.items = [
            makeItem(title: "Finder", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11)),
            makeItem(title: "Arc", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22)),
        ]
        viewModel.selectedIndex = 0
        viewModel.move(by: -1)

        XCTAssertEqual(viewModel.selectedIndex, 1)
    }

    func testSearchQueryState() {
        let viewModel = SwitcherViewModel()
        viewModel.searchQuery = "Arc"
        XCTAssertEqual(viewModel.searchQuery, "Arc")
    }

    func testMoveUpAndDownNavigation() {
        let viewModel = SwitcherViewModel()
        viewModel.items = (0..<6).map { i in
            makeItem(title: "Item \(i)", appID: "app.\(i)", identity: .appWindow(pid: pid_t(100 + i), windowID: CGWindowID(i)))
        }
        viewModel.layout = SwitcherLayoutMetrics(
            columns: 3,
            cardWidth: 100,
            cardHeight: 100,
            thumbnailHeight: 60,
            gridSpacing: 10,
            outerPadding: 10,
            contentWidth: 300,
            contentHeight: 200
        )
        viewModel.selectedIndex = 0
        viewModel.moveDown()
        XCTAssertEqual(viewModel.selectedIndex, 3)

        viewModel.moveUp()
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    private func makeItem(title: String, appID: String, identity: SwitcherHistoryIdentity) -> SwitcherItem {
        SwitcherItem(
            title: title,
            subtitle: appID,
            icon: nil,
            previewImage: nil,
            historyIdentity: identity,
            sourceAppIdentifier: appID,
            kind: .appWindow
        ) {}
    }
}
