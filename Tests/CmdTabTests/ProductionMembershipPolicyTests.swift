import AppKit
import XCTest
@testable import CmdTab

final class ProductionMembershipPolicyTests: XCTestCase {
    func testExactWindowSuppressesFallbackForSameProcess() {
        let window = item(
            identity: .appWindow(pid: 10, windowID: 1),
            bundle: "com.example.Editor",
            title: "Document"
        )
        let fallback = item(
            identity: .appFallback(bundleID: "com.example.Editor", pid: 10),
            bundle: "com.example.Editor",
            title: "Editor",
            kind: .appFallback
        )

        let result = SwitcherMembershipPolicy
            .deduplicatedWithoutRepresentedFallbacks([fallback, window])

        XCTAssertEqual(result.map(\.id), [window.id])
    }

    func testFallbackRemainsWhenNoExactWindowExists() {
        let fallback = item(
            identity: .appFallback(bundleID: "com.example.Editor", pid: 10),
            bundle: "com.example.Editor",
            title: "Editor",
            kind: .appFallback
        )

        XCTAssertEqual(
            SwitcherMembershipPolicy
                .deduplicatedWithoutRepresentedFallbacks([fallback])
                .map(\.id),
            [fallback.id]
        )
    }

    func testPerAppLimitRetainsFrontmostExactWindow() {
        let first = item(
            identity: .appWindow(pid: 10, windowID: 1),
            bundle: "com.example.Editor",
            title: "First"
        )
        let second = item(
            identity: .appWindow(pid: 10, windowID: 2),
            bundle: "com.example.Editor",
            title: "Second"
        )
        let active = item(
            identity: .appWindow(pid: 10, windowID: 3),
            bundle: "com.example.Editor",
            title: "Active"
        )

        let result = SwitcherMembershipPolicy.applyingPerApplicationLimit(
            [first, second, active],
            limit: 2,
            currentFrontmost: active.historyIdentity
        )

        XCTAssertEqual(result.map(\.title), ["First", "Active"])
    }

    func testDeduplicationKeepsFirstStableIdentity() {
        let first = item(
            identity: .appWindow(pid: 10, windowID: 1),
            bundle: "com.example.Editor",
            title: "First"
        )
        let duplicate = item(
            identity: .appWindow(pid: 10, windowID: 1),
            bundle: "com.example.Editor",
            title: "Duplicate"
        )

        let result = SwitcherMembershipPolicy
            .deduplicatedWithoutRepresentedFallbacks([first, duplicate])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "First")

        let allSpaces = configuration(
            visibility: .allSpaces,
            includeMinimized: true
        )
        let currentSpace = configuration(
            visibility: .currentSpaceOnly,
            includeMinimized: false
        )

        var gate = ProductionEnrichmentGate()
        let firstSignature = ProductionEnrichmentInputSignature(
            configuration: allSpaces,
            itemKeys: ["first"]
        )
        XCTAssertTrue(gate.shouldSchedule(firstSignature, force: false))
        XCTAssertFalse(
            gate.shouldSchedule(firstSignature, force: false),
            "Publishing an unchanged snapshot must not recursively schedule another enrichment pass."
        )
        XCTAssertTrue(gate.shouldSchedule(firstSignature, force: true))
        XCTAssertTrue(
            gate.shouldSchedule(
                ProductionEnrichmentInputSignature(
                    configuration: allSpaces,
                    itemKeys: ["second"]
                ),
                force: false
            )
        )

        XCTAssertFalse(
            ProvisionalSwitcherPolicy.permitsBaseSnapshot(
                profileVisibility: .currentSpaceOnly,
                globalVisibility: .allSpaces,
                profileIncludesMinimized: false,
                globalIncludesMinimized: true
            ),
            "A narrower profile must fail closed until exact scope enrichment is ready."
        )
        XCTAssertTrue(
            ProvisionalSwitcherPolicy.permitsBaseSnapshot(
                profileVisibility: .allSpaces,
                globalVisibility: .currentSpaceOnly,
                profileIncludesMinimized: true,
                globalIncludesMinimized: false
            )
        )
        XCTAssertTrue(
            ProvisionalSwitcherPolicy.filteredItems(
                [first],
                configuration: currentSpace,
                globalVisibility: .allSpaces,
                globalIncludesMinimized: true
            ).isEmpty
        )

        // Arc and Telegram can intermittently return no GPU-backed capture. The
        // exact key may reuse its last local image, and a title/frame key change may
        // fall back by the same process-generation-scoped exact window identity.
        // Another identity must never inherit it, and stable permission denial
        // clears both records.
        SwitcherPreviewContinuityStore.resetForTesting()
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let capturedAt = Date(timeIntervalSince1970: 100)
        let identityKey = "app-window:77:700|com.example.gpu|launch-1"
        let captured = SwitcherPreviewContinuityStore.resolve(
            key: "exact-gpu-window-v1",
            identityKey: identityKey,
            preview: image,
            backdrop: image,
            captureAccessAllowed: true,
            now: capturedAt
        )
        XCTAssertTrue(captured.preview === image)

        let transientMiss = SwitcherPreviewContinuityStore.resolve(
            key: "exact-gpu-window-v1",
            identityKey: identityKey,
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 101)
        )
        XCTAssertTrue(transientMiss.preview === image)
        XCTAssertNil(transientMiss.backdrop, "Continuity retains only a downscaled thumbnail")

        let metadataChanged = SwitcherPreviewContinuityStore.resolve(
            key: "exact-gpu-window-v2",
            identityKey: identityKey,
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 105)
        )
        XCTAssertTrue(metadataChanged.preview === image)

        let longLivedMetadataChange = SwitcherPreviewContinuityStore.resolve(
            key: "exact-gpu-window-v3",
            identityKey: identityKey,
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 699)
        )
        XCTAssertTrue(
            longLivedMetadataChange.preview === image,
            "The same process generation and CGWindowID should survive prolonged title/frame churn."
        )

        let expiredIdentity = SwitcherPreviewContinuityStore.resolve(
            key: "exact-gpu-window-v4",
            identityKey: identityKey,
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 701)
        )
        XCTAssertNil(expiredIdentity.preview)

        let differentWindow = SwitcherPreviewContinuityStore.resolve(
            key: "exact-gpu-window-v2",
            identityKey: "app-window:77:701|com.example.gpu|launch-1",
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 105)
        )
        XCTAssertNil(differentWindow.preview)

        SwitcherPreviewPermissionState.resetForTesting()
        let denialStart = Date(timeIntervalSince1970: 800)
        XCTAssertTrue(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: false,
                preflightGranted: false,
                now: denialStart
            ),
            "One transient false TCC preflight must not erase stable previews."
        )
        XCTAssertTrue(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: false,
                preflightGranted: false,
                now: Date(timeIntervalSince1970: 800.5)
            )
        )
        XCTAssertFalse(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: false,
                preflightGranted: false,
                now: Date(timeIntervalSince1970: 801.1)
            ),
            "Sustained permission denial must still clear protected content."
        )
        XCTAssertTrue(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: false,
                preflightGranted: true,
                now: Date(timeIntervalSince1970: 801.2)
            )
        )

        let denied = SwitcherPreviewContinuityStore.resolve(
            key: "exact-gpu-window-v1",
            identityKey: identityKey,
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: false,
            now: Date(timeIntervalSince1970: 106)
        )
        XCTAssertNil(denied.preview)
        let afterDenial = SwitcherPreviewContinuityStore.resolve(
            key: "exact-gpu-window-v1",
            identityKey: identityKey,
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 107)
        )
        XCTAssertNil(afterDenial.preview)
        SwitcherPreviewContinuityStore.resetForTesting()
    }

    private func configuration(
        visibility: WindowVisibilityScope,
        includeMinimized: Bool
    ) -> SwitcherSessionConfiguration {
        SwitcherSessionConfiguration(
            profileID: UUID(),
            profileName: "Test",
            style: .classicGrid,
            visibilityScope: visibility,
            includeMinimizedWindows: includeMinimized,
            displayPlacement: .activeWindowDisplay,
            appFilter: .all,
            releaseBehavior: .holdPrimaryModifier
        )
    }

    private func item(
        identity: SwitcherHistoryIdentity,
        bundle: String,
        title: String,
        kind: SwitcherItemKind = .appWindow
    ) -> SwitcherItem {
        SwitcherItem(
            title: title,
            subtitle: bundle,
            icon: nil,
            previewImage: nil,
            historyIdentity: identity,
            sourceAppIdentifier: bundle,
            kind: kind,
            activate: {}
        )
    }
}
