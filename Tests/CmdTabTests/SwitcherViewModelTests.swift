import XCTest
@testable import CmdTab

final class SwitcherViewModelTests: XCTestCase {
    func testResolvedSelectedIndexIsNilWhenThereAreNoItems() {
        let viewModel = SwitcherViewModel()
        viewModel.selectedIndex = 4

        XCTAssertNil(viewModel.resolvedSelectedIndex)
    }

    func testResolvedSelectedIndexClampsToLastVisibleItem() {
        let viewModel = makeViewModel(itemCount: 2)
        viewModel.selectedIndex = 7

        XCTAssertEqual(viewModel.resolvedSelectedIndex, 1)
    }

    func testMoveWrapsForwardAndBackward() {
        let viewModel = makeViewModel(itemCount: 3)
        viewModel.selectedIndex = 2

        viewModel.move(by: 1)
        XCTAssertEqual(viewModel.selectedIndex, 0)

        viewModel.move(by: -1)
        XCTAssertEqual(viewModel.selectedIndex, 2)
    }

    func testMoveDoesNothingWithoutItems() {
        let viewModel = SwitcherViewModel()
        viewModel.selectedIndex = 3

        viewModel.move(by: 1)
        viewModel.moveUp()
        viewModel.moveDown()

        XCTAssertEqual(viewModel.selectedIndex, 3)
    }

    func testGridNavigationWrapsAcrossUnevenLastRow() {
        let viewModel = makeViewModel(itemCount: 5)
        viewModel.layout = SwitcherLayoutMetrics(
            panelWidth: 800,
            panelHeight: 500,
            cardWidth: 200,
            cardHeight: 150,
            thumbnailHeight: 110,
            columns: 3,
            gridSpacing: 12,
            outerPadding: 16,
            contentHeight: 450
        )

        viewModel.selectedIndex = 1
        viewModel.moveUp()
        XCTAssertEqual(viewModel.selectedIndex, 4)

        viewModel.moveDown()
        XCTAssertEqual(viewModel.selectedIndex, 1)

        viewModel.selectedIndex = 4
        viewModel.moveDown()
        XCTAssertEqual(viewModel.selectedIndex, 1)
    }

    private func makeViewModel(itemCount: Int) -> SwitcherViewModel {
        let viewModel = SwitcherViewModel()
        viewModel.items = (0..<itemCount).map { index in
            makeItem(
                title: "Window \(index)",
                appID: "com.example.app\(index)",
                identity: .appWindow(
                    pid: Int32(100 + index),
                    windowID: UInt32(10 + index)
                )
            )
        }
        return viewModel
    }

    private func makeItem(
        title: String,
        appID: String,
        identity: SwitcherHistoryIdentity
    ) -> SwitcherItem {
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
