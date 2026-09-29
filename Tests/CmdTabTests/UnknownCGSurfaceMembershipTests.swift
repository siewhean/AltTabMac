import AppKit
import XCTest
@testable import CmdTab

final class UnknownCGSurfaceMembershipTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 100)

    func testRawUnnamedOffscreenSurfaceWithCompleteFreshAXSiblingIsExcluded() {
        let result = decision(row())
        XCTAssertFalse(result.isIncluded)
        XCTAssertTrue(result.isUnknownIdentity)
        XCTAssertFalse(result.isPositivelyRejected, "A heuristic must not claim positive AX rejection")
    }

    func testVisibleUntitledAndOffspaceTitledWindowsArePreserved() {
        XCTAssertTrue(decision(row(onScreen: true)).isIncluded)
        XCTAssertTrue(decision(row(title: "Document")).isIncluded)
    }

    func testMissingCGTitleIsNotConfusedWithExplicitlyEmptyTitle() {
        XCTAssertTrue(decision(row(title: nil)).isIncluded)
    }

    func testMinimizedStandardSiblingStillExcludesUnnamedOffscreenHelpers() {
        let minimizedExcluded = AppSwitcher.AXAppInspection(
            approvedIDs: [], positivelyDisallowedIDs: [1], identityFailures: 0,
            enumerationComplete: true, isTrusted: true, completedAt: now,
            standardWindowIDs: [1]
        )
        XCTAssertFalse(decision(row(), inspection: minimizedExcluded).isIncluded)
        var main = row(title: "Document")
        main[kCGWindowNumber as String] = NSNumber(value: 1)
        XCTAssertFalse(decision(main, inspection: minimizedExcluded).isIncluded)
        let minimizedIncluded = AppSwitcher.AXAppInspection(
            approvedIDs: [1], positivelyDisallowedIDs: [], identityFailures: 0,
            enumerationComplete: true, isTrusted: true, completedAt: now,
            standardWindowIDs: [1]
        )
        XCTAssertTrue(decision(main, inspection: minimizedIncluded).isIncluded)
        XCTAssertFalse(decision(row(), inspection: minimizedIncluded).isIncluded)
    }

    func testMinimizedSiblingEvidenceDoesNotOverrideUnknownWindowSafeguards() {
        for (complete, age) in [(false, 0.0), (true, 1.01)] {
            let sibling = AppSwitcher.AXAppInspection(
                approvedIDs: [], positivelyDisallowedIDs: [1], identityFailures: 0,
                enumerationComplete: complete, isTrusted: true,
                completedAt: now.addingTimeInterval(-age), standardWindowIDs: [1]
            )
            XCTAssertTrue(decision(row(), inspection: sibling).isIncluded)
        }
        let sibling = AppSwitcher.AXAppInspection(
            approvedIDs: [], positivelyDisallowedIDs: [1], identityFailures: 0,
            enumerationComplete: true, isTrusted: true, completedAt: now,
            standardWindowIDs: [1]
        )
        XCTAssertTrue(decision(row(onScreen: true), inspection: sibling).isIncluded)
        XCTAssertTrue(decision(row(title: nil), inspection: sibling).isIncluded)
        XCTAssertTrue(decision(row(title: "Document"), inspection: sibling).isIncluded)
    }

    func testExactAXAndPreviouslyConfirmedWindowsArePreserved() {
        var exact = inspection()
        exact = AppSwitcher.AXAppInspection(
            approvedIDs: [99], positivelyDisallowedIDs: [], identityFailures: 0,
            enumerationComplete: true, isTrusted: true, completedAt: now
        )
        XCTAssertTrue(decision(row(), inspection: exact).isIncluded)
        XCTAssertTrue(AppSwitcher.evaluateMembership(
            windowInfo: row(), inspection: inspection(), previouslyConfirmed: true, now: now
        ).isIncluded)
    }

    func testDeniedFailedIncompleteOrUnresolvedAXPreservesCandidate() {
        XCTAssertTrue(AppSwitcher.evaluateMembership(windowInfo: row(), inspection: nil, now: now).isIncluded)
        for inspection in [
            inspection(trusted: false), inspection(complete: false), inspection(failures: 1)
        ] {
            XCTAssertTrue(decision(row(), inspection: inspection).isIncluded)
        }
    }

    func testNoApprovedSiblingAndExpiredCatalogPreserveCandidate() {
        XCTAssertTrue(decision(row(), inspection: inspection(approved: [])).isIncluded)
        XCTAssertTrue(decision(row(), inspection: inspection(age: 1.01)).isIncluded)
        XCTAssertTrue(decision(row(), inspection: inspection(age: -1)).isIncluded)
    }

    func testPositiveRejectionStillWinsOverHistoricalConfirmation() {
        let rejected = AppSwitcher.AXAppInspection(
            approvedIDs: [1], positivelyDisallowedIDs: [99], identityFailures: 0
        )
        let result = AppSwitcher.evaluateMembership(
            windowInfo: row(), inspection: rejected, previouslyConfirmed: true, now: now
        )
        XCTAssertFalse(result.isIncluded)
        XCTAssertTrue(result.isPositivelyRejected)
    }

    func testConfirmationSurvivesAXOmissionOnlyForSameLiveProcessGeneration() {
        var store = ConfirmedSwitcherWindowIdentities()
        let first = store.update(generations: [10: now], currentIDs: [10: [99]], approvedIDs: [10: [99]])
        XCTAssertEqual(first[10], [99])
        let omitted = store.update(generations: [10: now], currentIDs: [10: [99]], approvedIDs: [:])
        XCTAssertEqual(omitted[10], [99])
        let reusedPID = store.update(
            generations: [10: now.addingTimeInterval(10)], currentIDs: [10: [99]], approvedIDs: [:]
        )
        XCTAssertEqual(reusedPID[10], [])
    }

    func testClosedWindowsAndTerminatedProcessesLoseConfirmation() {
        var store = ConfirmedSwitcherWindowIdentities()
        _ = store.update(generations: [10: now], currentIDs: [10: [99]], approvedIDs: [10: [99]])
        XCTAssertEqual(store.update(generations: [10: now], currentIDs: [:], approvedIDs: [:])[10], [])
        XCTAssertEqual(store.update(generations: [10: now], currentIDs: [10: [99]], approvedIDs: [:])[10], [])
        XCTAssertTrue(store.update(generations: [:], currentIDs: [:], approvedIDs: [:]).isEmpty)
    }

    func testRawClassificationFeedsFinalPublicationWithoutExtraTile() {
        let candidateIDs: [CGWindowID] = [1, 99]
        let candidates = candidateIDs.compactMap { id -> SwitcherItem? in
            var raw = row()
            raw[kCGWindowNumber as String] = NSNumber(value: id)
            guard decision(raw).isIncluded else { return nil }
            return item(id)
        }
        let fallback = SwitcherItem(
            title: "Editor", subtitle: "", icon: nil, previewImage: nil,
            historyIdentity: .appFallback(bundleID: "editor", pid: 10),
            sourceAppIdentifier: "editor", kind: .appFallback, activate: {}
        )
        let configuration = SwitcherSessionConfiguration(
            profileID: UUID(), profileName: "Test", style: .classicGrid,
            visibilityScope: .allSpaces, includeMinimizedWindows: false,
            displayPlacement: .activeWindowDisplay, appFilter: .all, releaseBehavior: .holdPrimaryModifier
        )
        let finalized = ProductionMembershipFinalizer.items(
            candidates, fallbackItems: [fallback], metadataByIdentity: [:],
            configuration: configuration, globalVisibility: .allSpaces, globalIncludesMinimized: false
        )
        XCTAssertEqual(finalized.map(\.windowID), [1])
    }

    func testMinimizedDialogSiblingClassifiesHelperWithoutPublishingMinimizedWindow() {
        let standard = AppSwitcher.shouldAllowAXWindow(
            role: "AXWindow", subrole: "AXDialog", parentRole: "AXApplication",
            isMinimized: true, includeMinimized: true
        )
        XCTAssertTrue(standard, "Minimized AppKit main windows use AXDialog on this host")
        XCTAssertFalse(AppSwitcher.shouldAllowAXWindow(
            role: "AXWindow", subrole: "AXDialog", parentRole: "AXApplication",
            isMinimized: true, includeMinimized: false
        ))
        XCTAssertFalse(AppSwitcher.shouldAllowAXWindow(
            role: "AXWindow", subrole: "AXDialog", parentRole: "AXApplication",
            isMinimized: false, includeMinimized: true
        ))
        let inventory = AppSwitcher.AXAppInspection(
            approvedIDs: [], positivelyDisallowedIDs: [1], identityFailures: 0,
            enumerationComplete: true, isTrusted: true, completedAt: now,
            standardWindowIDs: standard ? [1] : []
        )
        XCTAssertFalse(decision(row(), inspection: inventory).isIncluded,
                       "An excluded minimized main window still establishes a real sibling for helper classification")
        var minimizedRow = row(title: "Calendar")
        minimizedRow[kCGWindowNumber as String] = NSNumber(value: 1)
        XCTAssertFalse(decision(minimizedRow, inspection: inventory).isIncluded)
    }

    func testSlowSiblingDoesNotDisableHelperPolicyForEarlierApplication() {
        var refreshes = 0
        let refreshed = AppSwitcher.freshInspectionForCandidates(inspection(age: 2), now: now) {
            refreshes += 1
            return self.inspection()
        }
        XCTAssertEqual(refreshes, 1)
        XCTAssertFalse(decision(row(), inspection: refreshed).isIncluded)
        _ = AppSwitcher.freshInspectionForCandidates(refreshed, now: now) {
            refreshes += 1
            return self.inspection()
        }
        XCTAssertEqual(refreshes, 1, "Fresh evidence must not trigger another AX walk")
    }

    func testLive500PointHelpersDoNotDuplicateVisibleAndMinimizedSiblings() {
        // Exact IDs and states from the September 27 desktop probe. Capture
        // availability is deliberately irrelevant to membership.
        for (realID, helperID, minimized) in [
            (CGWindowID(104), CGWindowID(1375), false),
            (CGWindowID(89), CGWindowID(770), true),
            (CGWindowID(113), CGWindowID(213), false)
        ] {
            let evidence = AppSwitcher.AXAppInspection(
                approvedIDs: [realID], positivelyDisallowedIDs: [], identityFailures: 0,
                enumerationComplete: true, isTrusted: true, completedAt: now,
                standardWindowIDs: [realID], minimizedIDs: minimized ? [realID] : []
            )
            var helper = row()
            helper[kCGWindowNumber as String] = NSNumber(value: helperID)
            helper[kCGWindowBounds as String] = CGRect(x: 0, y: 467, width: 500, height: 500).dictionaryRepresentation
            var real = row(title: "Document", onScreen: !minimized)
            real[kCGWindowNumber as String] = NSNumber(value: realID)
            let publishedIDs = [real, helper].compactMap { raw -> CGWindowID? in
                guard decision(raw, inspection: evidence).isIncluded else { return nil }
                return (raw[kCGWindowNumber as String] as? NSNumber)?.uint32Value
            }
            XCTAssertEqual(publishedIDs, [realID])
        }
    }

    func testFailedRefreshDoesNotRelabelOldEvidenceAsFresh() {
        let refreshed = AppSwitcher.freshInspectionForCandidates(inspection(age: 2), now: now) {
            self.inspection(complete: false)
        }
        XCTAssertTrue(decision(row(), inspection: refreshed).isIncluded)
    }

    func testInternallyHiddenTitledWindowIsExcludedDespiteHistoricalConfirmation() {
        XCTAssertFalse(hiddenDecision().isIncluded)
        XCTAssertFalse(hiddenDecision(memberships: []).isIncluded)
        XCTAssertTrue(hiddenDecision(onScreen: true).isIncluded)
        XCTAssertTrue(hiddenDecision(applicationHidden: true).isIncluded)
        XCTAssertTrue(hiddenDecision(memberships: [2]).isIncluded)
        XCTAssertTrue(hiddenDecision(currentIDs: []).isIncluded)
        XCTAssertTrue(hiddenDecision(capability: .degraded("uncertain")).isIncluded)
        XCTAssertTrue(hiddenDecision(stage: .hiddenSet).isIncluded)
    }

    func testHiddenFindingSurvivesSpaceChangeWithoutSuppressingUnobservedOffSpaceWindow() {
        let hidden = hiddenDecision()
        XCTAssertFalse(hidden.isIncluded)
        XCTAssertTrue(hidden.isInferredHidden)
        var history = ConfirmedSwitcherWindowIdentities()
        _ = history.update(generations: [10: now], currentIDs: [10: [99]], approvedIDs: [:])
        history.recordHiddenDecision(pid: 10, windowID: 99, isOnScreen: false, decision: hidden)
        XCTAssertEqual(history.inferredHiddenWindows[10], [99])

        // A cold start in the other Space has no prior strong evidence and
        // must retain the possibly legitimate window.
        XCTAssertTrue(hiddenDecision(memberships: [1], currentIDs: [2]).isIncluded)
        let afterSpaceChange = AppSwitcher.evaluateMembership(
            windowInfo: row(title: "Welcome"), inspection: inspection(),
            previouslyInferredHidden: history.inferredHiddenWindows[10]?.contains(99) == true,
            workspace: WindowWorkspaceSnapshot(
                memberships: [WorkspaceIdentity(spaceID: 1, displayIdentifier: nil, kind: .user)],
                currentSpaceIDs: [2], stageManagerState: .offCurrentSpace,
                capability: .available
            ), now: now
        )
        XCTAssertFalse(afterSpaceChange.isIncluded)
        XCTAssertTrue(afterSpaceChange.isInferredHidden)
        XCTAssertTrue(AppSwitcher.evaluateMembership(
            windowInfo: row(title: "Welcome"), inspection: nil,
            previouslyInferredHidden: true, now: now
        ).isIncluded, "A lost Accessibility grant must not turn historical inference into proof")

        let exact = AppSwitcher.AXAppInspection(
            approvedIDs: [99], positivelyDisallowedIDs: [], identityFailures: 0,
            enumerationComplete: true, isTrusted: true, completedAt: now, observedAt: now
        )
        let reopened = AppSwitcher.evaluateMembership(
            windowInfo: row(title: "Welcome"), inspection: exact,
            previouslyInferredHidden: true, now: now
        )
        XCTAssertTrue(reopened.isIncluded)
        history.recordHiddenDecision(pid: 10, windowID: 99, isOnScreen: false, decision: reopened)
        XCTAssertEqual(history.inferredHiddenWindows[10], [])
        history.recordHiddenDecision(pid: 10, windowID: 99, isOnScreen: false, decision: hidden)
        history.recordHiddenDecision(pid: 10, windowID: 99, isOnScreen: true, decision: hiddenDecision(onScreen: true))
        XCTAssertEqual(history.inferredHiddenWindows[10], [])
    }

    func testHiddenFindingExpiresWithWindowAndProcessGeneration() {
        var history = ConfirmedSwitcherWindowIdentities()
        _ = history.update(generations: [10: now], currentIDs: [10: [99]], approvedIDs: [:])
        history.recordHiddenDecision(pid: 10, windowID: 99, isOnScreen: false, decision: hiddenDecision())
        _ = history.update(generations: [10: now], currentIDs: [10: []], approvedIDs: [:])
        XCTAssertEqual(history.inferredHiddenWindows[10], [])
        history.recordHiddenDecision(pid: 10, windowID: 99, isOnScreen: false, decision: hiddenDecision())
        _ = history.update(generations: [10: now.addingTimeInterval(1)], currentIDs: [10: [99]], approvedIDs: [:])
        XCTAssertEqual(history.inferredHiddenWindows[10], [])
    }

    func testHiddenSurfacePolicyPreservesIncompleteAndExactAXWindows() {
        for evidence in [inspection(trusted: false), inspection(complete: false),
                         inspection(failures: 1), inspection(age: 1.01), inspection(approved: [])] {
            XCTAssertTrue(hiddenDecision(evidence: evidence).isIncluded)
        }
        for observedAge in [-1.0, 1.01] {
            var oldObservation = inspection()
            oldObservation.observedAt = now.addingTimeInterval(-observedAge)
            XCTAssertTrue(hiddenDecision(evidence: oldObservation).isIncluded)
        }
        let exact = AppSwitcher.AXAppInspection(
            approvedIDs: [99], positivelyDisallowedIDs: [], identityFailures: 0,
            enumerationComplete: true, isTrusted: true, completedAt: now, observedAt: now,
            standardWindowIDs: [99], minimizedIDs: [99]
        )
        XCTAssertTrue(hiddenDecision(evidence: exact).isIncluded)
    }

    func testMinimizedHistorySurvivesOmissionAndClearsAfterRestoreOrPIDReuse() {
        var history = ConfirmedSwitcherWindowIdentities()
        _ = history.update(generations: [10: now], currentIDs: [10: [99]],
                           approvedIDs: [10: [99]], observedIDs: [10: [99]], minimizedIDs: [10: [99]])
        _ = history.update(generations: [10: now], currentIDs: [10: [99]], approvedIDs: [:])
        XCTAssertEqual(history.minimizedWindows[10], [99])
        XCTAssertTrue(hiddenDecision(previouslyMinimized: true).isIncluded)
        XCTAssertTrue(AppSwitcher.evaluateMembership(
            windowInfo: row(), inspection: inspection(), previouslyConfirmed: false,
            previouslyMinimized: true, now: now
        ).isIncluded)
        _ = history.update(generations: [10: now], currentIDs: [10: [99]],
                           approvedIDs: [10: [99]], observedIDs: [10: [99]])
        XCTAssertEqual(history.minimizedWindows[10], [])
        XCTAssertFalse(hiddenDecision(previouslyMinimized: false).isIncluded)
        _ = history.update(generations: [10: now], currentIDs: [10: [99]],
                           approvedIDs: [10: [99]], minimizedIDs: [10: [99]])
        _ = history.update(generations: [10: now.addingTimeInterval(1)], currentIDs: [10: [99]], approvedIDs: [:])
        XCTAssertEqual(history.minimizedWindows[10], [])
        _ = history.update(generations: [:], currentIDs: [:], approvedIDs: [:])
        XCTAssertTrue(history.minimizedWindows.isEmpty)
    }

    private func hiddenDecision(
        memberships: [UInt64] = [1], currentIDs: [UInt64] = [1],
        capability: CapabilityStatus = .available,
        stage: StageManagerWindowState = .disabled,
        applicationHidden: Bool = false, onScreen: Bool = false, previouslyMinimized: Bool = false,
        evidence: AppSwitcher.AXAppInspection? = nil
    ) -> AppSwitcher.WindowMembershipDecision {
        AppSwitcher.evaluateMembership(
            windowInfo: row(title: "Document", onScreen: onScreen),
            inspection: evidence ?? {
                var fresh = inspection()
                fresh.observedAt = now
                return fresh
            }(), previouslyConfirmed: true, previouslyMinimized: previouslyMinimized,
            applicationIsHidden: applicationHidden,
            workspace: WindowWorkspaceSnapshot(
                memberships: memberships.map { WorkspaceIdentity(spaceID: $0, displayIdentifier: nil, kind: .user) },
                currentSpaceIDs: currentIDs, stageManagerState: stage, capability: capability
            ), now: now
        )
    }

    private func item(_ id: CGWindowID) -> SwitcherItem {
        SwitcherItem(title: "Editor", subtitle: "", icon: nil, previewImage: nil,
                     historyIdentity: .appWindow(pid: 10, windowID: id), sourceAppIdentifier: "editor", activate: {})
    }

    private func row(title: String? = "", onScreen: Bool = false) -> [String: Any] {
        var row: [String: Any] = [kCGWindowNumber as String: NSNumber(value: 99),
                                  kCGWindowLayer as String: NSNumber(value: 0)]
        if let title { row[kCGWindowName as String] = title }
        if onScreen { row[kCGWindowIsOnscreen as String] = NSNumber(value: true) }
        return row
    }

    private func inspection(
        approved: Set<CGWindowID> = [1], trusted: Bool = true, complete: Bool = true,
        failures: Int = 0, age: TimeInterval = 0
    ) -> AppSwitcher.AXAppInspection {
        AppSwitcher.AXAppInspection(
            approvedIDs: approved, positivelyDisallowedIDs: [], identityFailures: failures,
            enumerationComplete: complete, isTrusted: trusted, completedAt: now.addingTimeInterval(-age),
            observedAt: now.addingTimeInterval(-age)
        )
    }

    private func decision(_ row: [String: Any], inspection: AppSwitcher.AXAppInspection? = nil) -> AppSwitcher.WindowMembershipDecision {
        AppSwitcher.evaluateMembership(windowInfo: row, inspection: inspection ?? self.inspection(), now: now)
    }
}
