import XCTest
@testable import CmdTab

final class WorkspaceProviderModelTests: XCTestCase {
    func testSnapshotRecognizesCurrentManagedSpace() {
        let snapshot = WindowWorkspaceSnapshot(
            memberships: [
                WorkspaceIdentity(
                    spaceID: 42,
                    displayIdentifier: "display-a",
                    kind: .user
                )
            ],
            currentSpaceIDs: [7, 42],
            stageManagerState: .activeSet,
            capability: .available
        )

        XCTAssertTrue(snapshot.isOnCurrentManagedSpace)
        XCTAssertEqual(snapshot.primaryWorkspace?.spaceID, 42)
        XCTAssertEqual(snapshot.primaryWorkspace?.stableKey, "workspace:display-a:42:user")
    }

    func testSnapshotRejectsOffSpaceMembership() {
        let snapshot = WindowWorkspaceSnapshot(
            memberships: [
                WorkspaceIdentity(
                    spaceID: 99,
                    displayIdentifier: "display-a",
                    kind: .fullscreen
                )
            ],
            currentSpaceIDs: [42],
            stageManagerState: .offCurrentSpace,
            capability: .available
        )

        XCTAssertFalse(snapshot.isOnCurrentManagedSpace)
        XCTAssertEqual(snapshot.stageManagerState, .offCurrentSpace)
    }

    func testFallbackIsExplicitlyDegradedInsteadOfPretendingToBeExact() {
        let snapshot = WindowWorkspaceSnapshot.fallback(
            isOnScreen: false,
            reason: "test capability unavailable"
        )

        XCTAssertEqual(snapshot.capability.level, .degraded)
        XCTAssertEqual(snapshot.capability.reason, "test capability unavailable")
        XCTAssertTrue(snapshot.memberships.isEmpty)
        XCTAssertTrue(snapshot.currentSpaceIDs.isEmpty)
        XCTAssertFalse(snapshot.isOnCurrentManagedSpace)
        XCTAssertEqual(snapshot.stageManagerState, .unknown)
    }

    func testWorkspaceMembershipFailureIsVisibleAndUsesPublicFallback() {
        let status = WindowWorkspaceProvider.membershipSnapshotFailureStatus()
        let snapshot = WindowWorkspaceSnapshot.fallback(
            isOnScreen: true,
            reason: status.reason ?? "missing status"
        )

        XCTAssertEqual(status.level, .failed)
        XCTAssertEqual(
            status.reason,
            "SkyLight could not resolve workspace membership; CmdTab is using the public on-screen fallback."
        )
        XCTAssertEqual(snapshot.capability.level, .degraded)
        XCTAssertEqual(snapshot.stageManagerState, .activeSet)
    }

    func testCapabilityFactoriesPreserveReasons() {
        XCTAssertEqual(CapabilityStatus.available.level, .available)
        XCTAssertEqual(CapabilityStatus.degraded("d").reason, "d")
        XCTAssertEqual(CapabilityStatus.unavailable("u").level, .unavailable)
        XCTAssertEqual(CapabilityStatus.failed("f").level, .failed)

        let inferredAvailable = StageManagerCapabilityPolicy.truthfulStatus(
            .available,
            stageManagerEnabled: true
        )
        XCTAssertEqual(inferredAvailable.level, .degraded)
        XCTAssertEqual(
            inferredAvailable.reason,
            StageManagerCapabilityPolicy.inferenceReason
        )

        let inferredDegraded = StageManagerCapabilityPolicy.truthfulStatus(
            .degraded("Direct Space activation is unavailable."),
            stageManagerEnabled: true
        )
        XCTAssertEqual(inferredDegraded.level, .degraded)
        XCTAssertTrue(inferredDegraded.reason?.contains("Direct Space activation") == true)
        XCTAssertTrue(inferredDegraded.reason?.contains("inferred") == true)

        let inferredFailure = StageManagerCapabilityPolicy.truthfulStatus(
            .failed("Workspace metadata failed."),
            stageManagerEnabled: true
        )
        XCTAssertEqual(inferredFailure.level, .failed)
        XCTAssertTrue(inferredFailure.reason?.contains("inferred") == true)
        XCTAssertEqual(
            StageManagerCapabilityPolicy.visibleLabel(for: .hiddenSet),
            "Inferred Hidden Set"
        )
    }
}
