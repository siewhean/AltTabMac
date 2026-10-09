import XCTest
import CoreGraphics
@testable import CmdTab

/// Permission-free membership matrices. These tests deliberately exercise the
/// same decision/accounting boundary used by the live Core Graphics snapshot,
/// so a missing AX row can never be misreported as a positive rejection.
final class MembershipDiagnosticsTests: XCTestCase {
    func testCompleteAXCatalogKeepsBothCandidatesAndCountsExactMatches() {
        let inspection = AppSwitcher.AXAppInspection(
            approvedIDs: [1, 2],
            positivelyDisallowedIDs: [],
            identityFailures: 0
        )
        var metrics = SnapshotMembershipMetricsBuilder(cgWindowsEnumerated: 2)

        for id: CGWindowID in [1, 2] {
            let decision = membershipDecision(id, inspection: inspection)
            XCTAssertTrue(decision.isIncluded)
            metrics.recordCGCandidate(
                exactAXMatched: decision.isExactAXMatched,
                positivelyRejected: decision.isPositivelyRejected,
                unknownAXIdentity: decision.isUnknownIdentity
            )
        }

        XCTAssertEqual(metrics.metrics.cgWindowsEnumerated, 2)
        XCTAssertEqual(metrics.metrics.cgCandidateWindows, 2)
        XCTAssertEqual(metrics.metrics.exactAXMatchedWindows, 2)
        XCTAssertEqual(metrics.metrics.positivelyRejectedWindows, 0)
        XCTAssertEqual(metrics.metrics.unknownAXIdentityWindows, 0)
    }

    func testSilentAXOmissionKeepsUnknownCGCandidate() {
        let inspection = AppSwitcher.AXAppInspection(
            approvedIDs: [1, 2],
            positivelyDisallowedIDs: [],
            identityFailures: 0
        )
        var metrics = SnapshotMembershipMetricsBuilder(cgWindowsEnumerated: 3)

        for id: CGWindowID in [1, 2, 3] {
            let decision = membershipDecision(id, inspection: inspection)
            XCTAssertTrue(decision.isIncluded)
            metrics.recordCGCandidate(
                exactAXMatched: decision.isExactAXMatched,
                positivelyRejected: decision.isPositivelyRejected,
                unknownAXIdentity: decision.isUnknownIdentity
            )
        }

        XCTAssertEqual(metrics.metrics.cgCandidateWindows, 3)
        XCTAssertEqual(metrics.metrics.exactAXMatchedWindows, 2)
        XCTAssertEqual(metrics.metrics.unknownAXIdentityWindows, 1)
        XCTAssertEqual(metrics.metrics.positivelyRejectedWindows, 0)
    }

    func testPartiallyUnavailableAXIDBridgeKeepsUnmappedCandidate() {
        let inspection = AppSwitcher.AXAppInspection(
            approvedIDs: [1],
            positivelyDisallowedIDs: [],
            identityFailures: 1
        )
        var metrics = SnapshotMembershipMetricsBuilder(cgWindowsEnumerated: 2)

        for id: CGWindowID in [1, 2] {
            let decision = membershipDecision(id, inspection: inspection)
            XCTAssertTrue(decision.isIncluded)
            metrics.recordCGCandidate(
                exactAXMatched: decision.isExactAXMatched,
                positivelyRejected: decision.isPositivelyRejected,
                unknownAXIdentity: decision.isUnknownIdentity
            )
        }

        XCTAssertEqual(metrics.metrics.exactAXMatchedWindows, 1)
        XCTAssertEqual(metrics.metrics.unknownAXIdentityWindows, 1)
        XCTAssertEqual(metrics.metrics.positivelyRejectedWindows, 0)
    }

    func testAXOmissionKeepsEligibleLayerOneAndTwoCandidates() {
        for layer in [1, 2] {
            let decision = AppSwitcher.evaluateMembership(
                windowID: CGWindowID(layer + 10),
                inspection: nil,
                layer: layer,
                hasTitle: true,
                bounds: CGRect(x: 0, y: 0, width: 800, height: 600)
            )
            XCTAssertTrue(decision.isIncluded, "layer \(layer) must remain fail-open")
            XCTAssertTrue(decision.isUnknownIdentity)
        }
    }

    func testAXOmissionKeepsUntitledMinimumSizeCandidate() {
        let decision = AppSwitcher.evaluateMembership(
            windowID: 99,
            inspection: nil,
            layer: 0,
            hasTitle: false,
            bounds: CGRect(x: 0, y: 0, width: 120, height: 80)
        )
        XCTAssertTrue(decision.isIncluded)
        XCTAssertTrue(decision.isUnknownIdentity)
    }

    func testOnlyPositivelyMappedAXExclusionIsRejected() {
        let inspection = AppSwitcher.AXAppInspection(
            approvedIDs: [1],
            positivelyDisallowedIDs: [2],
            identityFailures: 0
        )
        var metrics = SnapshotMembershipMetricsBuilder(cgWindowsEnumerated: 2)

        let allowed = membershipDecision(1, inspection: inspection)
        let rejected = membershipDecision(2, inspection: inspection)
        XCTAssertTrue(allowed.isIncluded)
        XCTAssertFalse(rejected.isIncluded)
        XCTAssertTrue(rejected.isExactAXMatched)
        XCTAssertTrue(rejected.isPositivelyRejected)
        for decision in [allowed, rejected] {
            metrics.recordCGCandidate(
                exactAXMatched: decision.isExactAXMatched,
                positivelyRejected: decision.isPositivelyRejected,
                unknownAXIdentity: decision.isUnknownIdentity
            )
        }

        XCTAssertEqual(metrics.metrics.cgCandidateWindows, 2)
        XCTAssertEqual(metrics.metrics.exactAXMatchedWindows, 2)
        XCTAssertEqual(metrics.metrics.positivelyRejectedWindows, 1)
        XCTAssertEqual(metrics.metrics.unknownAXIdentityWindows, 0)
    }

    func testPreviewFailurePublishesTheCandidateAsUnavailable() {
        var metrics = SnapshotMembershipMetricsBuilder(cgWindowsEnumerated: 1)
        let unknown = AppSwitcher.evaluateMembership(
            windowID: 1,
            inspection: nil,
            layer: 0,
            hasTitle: true,
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600)
        )
        XCTAssertTrue(unknown.isIncluded)
        metrics.recordCGCandidate(
            exactAXMatched: unknown.isExactAXMatched,
            positivelyRejected: unknown.isPositivelyRejected,
            unknownAXIdentity: unknown.isUnknownIdentity
        )
        metrics.recordPublishedWindow(previewAvailable: false)

        XCTAssertEqual(metrics.metrics.exactWindowsPublished, 1)
        XCTAssertEqual(metrics.metrics.previewAvailable, 0)
        XCTAssertEqual(metrics.metrics.previewUnavailable, 1)
    }

    private func membershipDecision(
        _ id: CGWindowID,
        inspection: AppSwitcher.AXAppInspection
    ) -> AppSwitcher.WindowMembershipDecision {
        AppSwitcher.evaluateMembership(
            windowID: id,
            inspection: inspection,
            layer: 0,
            hasTitle: true,
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600)
        )
    }
}
