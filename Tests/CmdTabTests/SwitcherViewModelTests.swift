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
