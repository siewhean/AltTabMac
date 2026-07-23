import XCTest
@testable import CmdTab

final class ProductionVisualStateTests: XCTestCase {
    func testWorstCapabilityChoosesHighestSeverity() {
        let available = item(
            id: 1,
            workspace: WindowWorkspaceSnapshot(
                memberships: [],
                currentSpaceIDs: [],
                stageManagerState: .disabled,
                capability: .available
            )
        )
        let degraded = item(
            id: 2,
            workspace: .fallback(
                isOnScreen: true,
                reason: "degraded fixture"
            )
        )
        let failed = item(
            id: 3,
            workspace: WindowWorkspaceSnapshot(
                memberships: [],
                currentSpaceIDs: [],
                stageManagerState: .unknown,
                capability: .failed("failed fixture")
            )
        )

        XCTAssertEqual(
            ProductionCapabilitySummary.worstStatus(in: [available, degraded, failed]),
            .failed("failed fixture")
        )
    }

    func testMissingWorkspaceMetadataIsReportedAsUnavailable() {
        let result = ProductionCapabilitySummary.worstStatus(
            in: [item(id: 1, workspace: nil)]
        )

        XCTAssertEqual(result.level, .unavailable)
        XCTAssertTrue(result.reason?.contains("safe visible-window fallback") == true)
    }

    func testSwitcherItemRetainsMinimizedFullscreenAndWorkspaceState() {
        let workspace = WindowWorkspaceSnapshot(
            memberships: [
                WorkspaceIdentity(
                    spaceID: 7,
                    displayIdentifier: "display-1",
                    kind: .fullscreen
                )
            ],
            currentSpaceIDs: [3],
            stageManagerState: .hiddenSet,
            capability: .degraded("fixture")
        )
        let value = SwitcherItem(
            title: "Fixture",
            subtitle: "WindowLab",
            icon: nil,
            previewImage: nil,
            historyIdentity: .appWindow(pid: 1, windowID: 9),
            sourceAppIdentifier: "net.cmdtab.fixture.WindowLab",
            isMinimized: true,
            isFullscreen: true,
            workspaceSnapshot: workspace,
            activate: {}
        )

        XCTAssertTrue(value.isMinimized)
        XCTAssertTrue(value.isFullscreen)
        XCTAssertEqual(value.workspaceSnapshot?.stageManagerState, .hiddenSet)
        XCTAssertFalse(value.workspaceSnapshot?.isOnCurrentManagedSpace ?? true)
    }

    private func item(
        id: UInt32,
        workspace: WindowWorkspaceSnapshot?
    ) -> SwitcherItem {
        SwitcherItem(
            title: "Window \(id)",
            subtitle: "WindowLab",
            icon: nil,
            previewImage: nil,
            historyIdentity: .appWindow(pid: 10, windowID: id),
            sourceAppIdentifier: "net.cmdtab.fixture.WindowLab",
            workspaceSnapshot: workspace,
            activate: {}
        )
    }
}