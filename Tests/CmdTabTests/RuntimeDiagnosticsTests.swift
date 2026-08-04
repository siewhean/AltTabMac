import XCTest
@testable import CmdTab

final class RuntimeDiagnosticsTests: XCTestCase {
    func testSanitizedDiagnosticsExposeExactIdentityCapabilityState() {
        let snapshot = ProductionDiagnosticsSnapshot(
            accessibilityReady: true,
            screenRecordingReady: true,
            secureInput: .unavailable("Secure Event Input state is unavailable on this macOS build; CmdTab relies on event-tap disable behaviour."),
            exactIdentity: .failed("Exact AX window identity failed with result -25204."),
            hardwarePreview: .available,
            exactFocus: .available,
            workspace: .available,
            enabledProfileCount: 1,
            profileValidationIssues: [],
            durableRecordCount: 0,
            durableHistoryLocation: "~/Library/Application Support/CmdTab/window-history-v1.json",
            runtimeCounters: RuntimeDiagnostics().snapshot()
        )

        XCTAssertTrue(
            snapshot.sanitizedReport.contains(
                "exactWindowIdentity=failed:Exact AX window identity failed with result -25204."
            )
        )
        XCTAssertTrue(
            snapshot.sanitizedReport.contains(
                "secureInput=unavailable:Secure Event Input state is unavailable on this macOS build; CmdTab relies on event-tap disable behaviour."
            )
        )
    }

    func testSnapshotUsesFixedAggregateCountersOnly() {
        let diagnostics = RuntimeDiagnostics()

        diagnostics.increment(.previewCaptureFailure)
        diagnostics.increment(.previewCaptureFailure)
        diagnostics.increment(.previewRecoveryScheduled)
        diagnostics.increment(.previewRecoverySuccess)
        diagnostics.increment(.forcedRefreshReplay)

        let snapshot = diagnostics.snapshot()
        XCTAssertEqual(snapshot.count(for: .previewCaptureFailure), 2)
        XCTAssertEqual(snapshot.count(for: .previewRecoveryScheduled), 1)
        XCTAssertEqual(snapshot.count(for: .previewRecoverySuccess), 1)
        XCTAssertEqual(snapshot.count(for: .forcedRefreshReplay), 1)
        XCTAssertEqual(snapshot.count(for: .previewRecoveryRetry), 0)
        XCTAssertEqual(
            snapshot.sanitizedReport,
            """
            runtime.enrichedSnapshotMerge=0
            runtime.forcedRefreshReplay=1
            runtime.accessibilityIdentityLookupFailure=0
            runtime.previewCaptureFailure=2
            runtime.previewRecoveryScheduled=1
            runtime.previewRecoveryRetry=0
            runtime.previewRecoverySuccess=1
            runtime.previewFallbackPresentation=0
            """
        )
    }

    func testResetClearsProcessLocalCounters() {
        let diagnostics = RuntimeDiagnostics()
        diagnostics.increment(.previewFallbackPresentation)

        diagnostics.reset()

        XCTAssertEqual(
            RuntimeDiagnosticsCounter.allCases.map { diagnostics.snapshot().count(for: $0) },
            Array(repeating: 0, count: RuntimeDiagnosticsCounter.allCases.count)
        )
    }
}
