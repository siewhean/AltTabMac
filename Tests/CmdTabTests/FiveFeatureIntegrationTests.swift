import Foundation
import XCTest
@testable import CmdTab

final class FiveFeatureIntegrationTests: XCTestCase {
    func testCurrentSessionActivationRanksAboveRestoredDurableHistory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FiveFeatureIntegration-\(UUID().uuidString)", isDirectory: true)
        let file = directory.appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let durable = DurableSwitcherHistoryStore(
            fileURL: file,
            maximumRecords: 20,
            expirationInterval: 10_000
        )
        let restoredIdentity = SwitcherHistoryIdentity.appWindow(pid: 20, windowID: 2)
        let restoredDescriptor = descriptor(
            identity: restoredIdentity,
            title: "Restored"
        )
        durable.noteActivation(
            descriptor: restoredDescriptor,
            now: Date(timeIntervalSince1970: 100)
        )
        durable.waitForPendingWrites()

        let history = SwitcherHistoryStore(durableStore: durable)
        history.reconcileLiveWindows([restoredDescriptor])
        XCTAssertEqual(history.snapshot(), [restoredIdentity])

        let currentIdentity = SwitcherHistoryIdentity.appWindow(pid: 30, windowID: 3)
        history.noteActivation(
            currentIdentity,
            descriptor: descriptor(identity: currentIdentity, title: "Current")
        )

        XCTAssertEqual(history.snapshot().prefix(2), [currentIdentity, restoredIdentity])
    }

    func testProfileConfigurationCombinesMinimizedWorkspaceAndAppFilterPolicies() {
        let configuration = SwitcherSessionConfiguration(
            profileID: UUID(),
            profileName: "Production",
            style: .classicGrid,
            visibilityScope: .currentSpaceOnly,
            includeMinimizedWindows: true,
            displayPlacement: .allDisplays,
            appFilter: SwitcherProfileAppFilter(
                mode: .exclude,
                bundleIdentifiers: ["com.example.blocked"]
            ),
            releaseBehavior: .holdPrimaryModifier
        )

        XCTAssertTrue(configuration.includeMinimizedWindows)
        XCTAssertEqual(configuration.visibilityScope, .currentSpaceOnly)
        XCTAssertEqual(configuration.displayPlacement, .allDisplays)
        XCTAssertTrue(configuration.includes(bundleIdentifier: "com.example.allowed"))
        XCTAssertFalse(configuration.includes(bundleIdentifier: "com.example.blocked"))
    }

    func testRestoredOrderingKeepsExactWindowsInterleavedAcrossApps() {
        let a1 = item(pid: 1, windowID: 11, title: "A1", bundle: "com.example.a")
        let b1 = item(pid: 2, windowID: 21, title: "B1", bundle: "com.example.b")
        let a2 = item(pid: 1, windowID: 12, title: "A2", bundle: "com.example.a")
        let history: [SwitcherHistoryIdentity] = [
            b1.historyIdentity,
            a2.historyIdentity,
            a1.historyIdentity,
        ]

        let ordered = SwitcherOrdering.orderedItems(
            [a1, b1, a2],
            historyEntries: history,
            currentFrontmost: nil
        )
        XCTAssertEqual(ordered.map(\.title), ["B1", "A2", "A1"])
    }

    private func descriptor(
        identity: SwitcherHistoryIdentity,
        title: String
    ) -> LiveWindowHistoryDescriptor {
        LiveWindowHistoryDescriptor(
            identity: identity,
            bundleIdentifier: "com.example.test",
            title: title,
            documentURL: URL(fileURLWithPath: "/tmp/\(title).txt"),
            role: "AXWindow",
            subrole: "AXStandardWindow",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            displayIdentifier: "display-1",
            workspaceKey: "workspace:display-1:1:user"
        )
    }

    private func item(
        pid: pid_t,
        windowID: CGWindowID,
        title: String,
        bundle: String
    ) -> SwitcherItem {
        SwitcherItem(
            title: title,
            subtitle: bundle,
            icon: nil,
            previewImage: nil,
            historyIdentity: .appWindow(pid: pid, windowID: windowID),
            sourceAppIdentifier: bundle,
            kind: .appWindow,
            activate: {}
        )
    }
}
