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
        // exact preview key may reuse the last local image, but a different window
        // key must never inherit it.
        SwitcherPreviewContinuityStore.resetForTesting()
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let previewIdentity = SwitcherHistoryIdentity.appWindow(
            pid: 77,
            windowID: 700
        )
        _ = SwitcherItem(
            title: "GPU Window",
            subtitle: "com.example.GPU",
            icon: nil,
            previewImage: image,
            backdropImage: image,
            previewCacheKey: "exact-gpu-window-v1",
            historyIdentity: previewIdentity,
            sourceAppIdentifier: "com.example.GPU"
        ) {}
        let transientMiss = SwitcherItem(
            title: "GPU Window",
            subtitle: "com.example.GPU",
            icon: nil,
            previewImage: nil,
            backdropImage: nil,
            previewCacheKey: "exact-gpu-window-v1",
            historyIdentity: previewIdentity,
            sourceAppIdentifier: "com.example.GPU"
        ) {}
        XCTAssertTrue(transientMiss.previewImage === image)
        XCTAssertTrue(transientMiss.backdropImage === image)

        let differentWindow = SwitcherItem(
            title: "Other GPU Window",
            subtitle: "com.example.GPU",
            icon: nil,
            previewImage: nil,
            previewCacheKey: "exact-gpu-window-v2",
            historyIdentity: .appWindow(pid: 77, windowID: 701),
            sourceAppIdentifier: "com.example.GPU"
        ) {}
        XCTAssertNil(differentWindow.previewImage)
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
