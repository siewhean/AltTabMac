import XCTest
@testable import CmdTab

final class ActivationOutcomeTests: XCTestCase {
    func testOnlyVerifiedExactActivationMayAdvanceExactWindowMRU() {
        XCTAssertTrue(ActivationOutcomePolicy.recordsExactWindowMRU(.exactVerified))
        XCTAssertFalse(ActivationOutcomePolicy.recordsExactWindowMRU(.applicationFallbackUnverified))
        XCTAssertFalse(ActivationOutcomePolicy.recordsExactWindowMRU(.targetDisappeared))
        XCTAssertFalse(ActivationOutcomePolicy.recordsExactWindowMRU(.accessibilityUnavailable))
        XCTAssertFalse(ActivationOutcomePolicy.recordsExactWindowMRU(.failure))
    }

    func testTrackerSeparatesRequestedAndTerminalOutcomes() {
        let tracker = ActivationOutcomeTracker()
        tracker.recordRequested()
        tracker.record(.applicationFallbackUnverified)
        tracker.record(.targetDisappeared)
        tracker.record(.failure)

        XCTAssertEqual(
            tracker.snapshot(),
            ActivationOutcomeMetrics(
                requested: 1,
                exactVerified: 0,
                applicationFallbackUnverified: 1,
                targetDisappeared: 1,
                accessibilityUnavailable: 0,
                verificationFailure: 1
            )
        )
    }

    func testExactSelectionRaisesOnlyTheSelectedWindowAmongTwoSiblings() {
        let selected = ExactWindowActivationPolicy.selectedWindowIndex(
            selectedWindowID: 101,
            mappedWindowIDs: [202, 101]
        )

        XCTAssertEqual(selected, 1)
    }

    func testExactSelectionRaisesOnlyTheSelectedWindowAmongFiveSiblings() {
        let selected = ExactWindowActivationPolicy.selectedWindowIndex(
            selectedWindowID: 303,
            mappedWindowIDs: [101, 202, 303, 404, 505]
        )

        XCTAssertEqual(selected, 2)
    }

    func testExactSelectionNeverSubstitutesSiblingForMissingOrStaleMapping() {
        XCTAssertNil(
            ExactWindowActivationPolicy.selectedWindowIndex(
                selectedWindowID: 101,
                mappedWindowIDs: [202, 303]
            ),
            "A focused, minimized, or otherwise available sibling is not the selected window."
        )
        XCTAssertNil(
            ExactWindowActivationPolicy.selectedWindowIndex(
                selectedWindowID: 101,
                mappedWindowIDs: [nil, nil]
            ),
            "Unavailable AX identity must retry/fail rather than raise an arbitrary window."
        )
        XCTAssertNil(
            ExactWindowActivationPolicy.selectedWindowIndex(
                selectedWindowID: 101,
                mappedWindowIDs: []
            ),
            "A target destroyed during activation has no sibling fallback."
        )
    }

    func testExactSelectionRequiresTheSelectedWindowToBeVisibleOnCurrentSpace() {
        XCTAssertTrue(ExactWindowActivationPolicy.mayConfirm(
            frontmostPID: 42,
            focusedWindowID: 164,
            targetPID: 42,
            targetWindowID: 164,
            isOnScreen: true
        ))
        XCTAssertFalse(ExactWindowActivationPolicy.mayConfirm(
            frontmostPID: 42,
            focusedWindowID: 164,
            targetPID: 42,
            targetWindowID: 164,
            isOnScreen: false
        ), "AX focus can still name the fullscreen window after macOS switches away from its Space.")
        XCTAssertFalse(ExactWindowActivationPolicy.mayConfirm(
            frontmostPID: 42,
            focusedWindowID: 165,
            targetPID: 42,
            targetWindowID: 164,
            isOnScreen: true
        ))
        XCTAssertFalse(ExactWindowActivationPolicy.mayConfirm(
            frontmostPID: 43,
            focusedWindowID: 164,
            targetPID: 42,
            targetWindowID: 164,
            isOnScreen: true
        ))
    }

    func testActivationUsesCurrentSpaceAfterInventoryBecameStale() {
        let desktop = WorkspaceIdentity(spaceID: 1, displayIdentifier: "display", kind: .user)
        let fullscreen = WorkspaceIdentity(spaceID: 2, displayIdentifier: "display", kind: .fullscreen)
        let provider = ActivationWorkspaceProvider(
            snapshot: WindowWorkspaceSnapshot(
                memberships: [desktop],
                currentSpaceIDs: [fullscreen.spaceID],
                stageManagerState: .disabled,
                capability: .available
            )
        )

        ProductionAppSwitcher.prepareWorkspaceForActivation(
            ownerPID: 42,
            windowID: 101,
            workspaceProvider: provider,
            isOnScreen: { _, _ in false }
        )

        XCTAssertEqual(provider.refreshed, 1)
        XCTAssertEqual(provider.requestedWindowID, 101)
        XCTAssertEqual(provider.activatedWorkspace, desktop)
    }

    func testActivationLeavesAlreadyVisibleFullscreenSpaceAlone() {
        let desktop = WorkspaceIdentity(spaceID: 1, displayIdentifier: "display", kind: .user)
        let provider = ActivationWorkspaceProvider(
            snapshot: WindowWorkspaceSnapshot(
                memberships: [desktop],
                currentSpaceIDs: [],
                stageManagerState: .disabled,
                capability: .available
            )
        )

        ProductionAppSwitcher.prepareWorkspaceForActivation(
            ownerPID: 42,
            windowID: 101,
            workspaceProvider: provider,
            isOnScreen: { _, _ in true }
        )

        XCTAssertEqual(provider.refreshed, 1)
        XCTAssertNil(provider.activatedWorkspace)
    }

    func testManagedSpaceOverridesStaleCGOnscreenBit() {
        let desktop = WorkspaceIdentity(spaceID: 1, displayIdentifier: "display", kind: .user)
        let provider = ActivationWorkspaceProvider(
            snapshot: WindowWorkspaceSnapshot(
                memberships: [desktop],
                currentSpaceIDs: [2],
                stageManagerState: .disabled,
                capability: .available
            )
        )

        ProductionAppSwitcher.prepareWorkspaceForActivation(
            ownerPID: 42,
            windowID: 101,
            workspaceProvider: provider,
            isOnScreen: { _, _ in true }
        )

        XCTAssertEqual(provider.activatedWorkspace, desktop)
    }

    func testCurrentManagedSpaceDoesNotSwitchWhenCGReportsOffscreen() {
        let desktop = WorkspaceIdentity(spaceID: 1, displayIdentifier: "display", kind: .user)
        let provider = ActivationWorkspaceProvider(
            snapshot: WindowWorkspaceSnapshot(
                memberships: [desktop],
                currentSpaceIDs: [1],
                stageManagerState: .disabled,
                capability: .available
            )
        )

        ProductionAppSwitcher.prepareWorkspaceForActivation(
            ownerPID: 42,
            windowID: 101,
            workspaceProvider: provider,
            isOnScreen: { _, _ in false }
        )

        XCTAssertNil(provider.activatedWorkspace)
    }

    func testBaseCGWindowWithoutAXMetadataPreparesSpaceBeforeExactActivation() {
        let desktop = WorkspaceIdentity(spaceID: 1, displayIdentifier: "display", kind: .user)
        let provider = ActivationWorkspaceProvider(
            snapshot: WindowWorkspaceSnapshot(
                memberships: [desktop],
                currentSpaceIDs: [2],
                stageManagerState: .disabled,
                capability: .available
            )
        )
        var baseActivated = false
        let base = SwitcherItem(
            title: "Window A",
            subtitle: "Fixture",
            icon: nil,
            previewImage: nil,
            historyIdentity: .appWindow(pid: 42, windowID: 101)
        ) {
            XCTAssertEqual(provider.activatedWorkspace, desktop)
            baseActivated = true
        }

        let prepared = ProductionAppSwitcher.preparedBaseItem(
            base,
            workspaceProvider: provider,
            isOnScreen: { _, _ in false }
        )
        XCTAssertFalse(prepared.allowsPreviewRecovery)
        prepared.activate()

        XCTAssertTrue(baseActivated)
        XCTAssertEqual(provider.requestedWindowID, 101)
    }
}

private final class ActivationWorkspaceProvider: WindowWorkspaceProviding {
    let snapshotValue: WindowWorkspaceSnapshot
    var refreshed = 0
    var requestedWindowID: CGWindowID?
    var activatedWorkspace: WorkspaceIdentity?

    var status: CapabilityStatus { .available }

    init(snapshot: WindowWorkspaceSnapshot) {
        snapshotValue = snapshot
    }

    func refresh() { refreshed += 1 }

    func snapshot(for windowID: CGWindowID, isOnScreen: Bool) -> WindowWorkspaceSnapshot {
        requestedWindowID = windowID
        return snapshotValue
    }

    func prepareActivation(of workspace: WorkspaceIdentity) -> Bool {
        activatedWorkspace = workspace
        return true
    }
}
