import AppKit
import XCTest
@testable import CmdTab

final class ProductionWindowReconciliationTests: XCTestCase {
    func testAXOmissionDoesNotRemoveEligibleCGSibling() {
        let first = window(1)
        let omitted = window(2)
        let result = finalize([first, omitted], metadata: [metadata(1)])
        XCTAssertEqual(result.map(\.historyIdentity), [first.historyIdentity, omitted.historyIdentity])
    }

    func testFinalFilteringReplacesOnlyMinimizedWindowWithApplicationFallback() {
        let result = finalize([window(1)], metadata: [metadata(1, minimized: true)])
        XCTAssertEqual(result.map(\.historyIdentity), [fallback().historyIdentity])
        XCTAssertEqual(result.first?.kind, .appFallback)
    }

    func testPositiveRoleRejectionReplacesWindowWithFallback() {
        let result = finalize([window(1)], metadata: [metadata(1, subrole: "AXDialog")])
        XCTAssertEqual(result.map(\.historyIdentity), [fallback().historyIdentity])
    }

    func testIncludedMinimizedWindowSuppressesFallback() {
        let selected = window(1, minimized: true)
        let result = finalize([selected], metadata: [metadata(1, minimized: true)], minimized: true)
        XCTAssertEqual(result.map(\.historyIdentity), [selected.historyIdentity])
    }

    func testEveryEligibleProcessGetsOneFallbackIncludingSharedBundleProcesses() {
        let one = fallback(pid: 10)
        let two = fallback(pid: 20)
        let result = finalize([], fallbacks: [one, two, one])
        XCTAssertEqual(result.map(\.historyIdentity), [one.historyIdentity, two.historyIdentity])
    }

    func testGloballyExcludedProcessCannotReappearAsWindowOrFallback() {
        // Production's fallback factory omits globally excluded applications.
        let result = finalize([window(1, pid: 10)], fallbacks: [fallback(pid: 20)])
        XCTAssertEqual(result.map(\.ownerPID), [20])
    }

    func testProfileExclusionAppliesToExactAndFallbackItems() {
        let result = finalize(
            [window(1)],
            filter: SwitcherProfileAppFilter(mode: .exclude, bundleIdentifiers: ["com.example.editor"])
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testNarrowProfileDoesNotGainUnscopedFallbackOrUnknownWindow() {
        for scope: WindowVisibilityScope in [.visibleSpaces, .currentSpaceOnly] {
            XCTAssertTrue(finalize([window(1), fallback()], visibility: scope).isEmpty)
            XCTAssertTrue(finalize([window(1)], metadata: [metadata(1, onScreen: false)], visibility: scope).isEmpty)
            XCTAssertEqual(
                finalize([window(1)], metadata: [metadata(1)], visibility: scope).map(\.kind),
                [.appWindow]
            )
        }
    }

    func testNarrowProvisionalSnapshotCannotReintroduceUnscopedFallback() {
        for scope: WindowVisibilityScope in [.visibleSpaces, .currentSpaceOnly] {
            let provisional = ProvisionalSwitcherPolicy.filteredItems(
                [fallback()], configuration: configuration(visibility: scope),
                globalVisibility: scope, globalIncludesMinimized: false
            )
            XCTAssertTrue(ProductionAppSwitcher.mergingCachedItems(
                [], baseItems: provisional, suppressedIdentities: []
            ).isEmpty)
        }
    }

    func testCachedMergeRemovesFallbackWhenExactWindowArrives() {
        let selected = window(1)
        let result = ProductionAppSwitcher.mergingCachedItems(
            [fallback()], baseItems: [selected], suppressedIdentities: []
        )
        XCTAssertEqual(result.map(\.historyIdentity), [selected.historyIdentity])
    }

    func testCachedExactWindowSuppressesNewBaseFallback() {
        let selected = window(1)
        let result = ProductionAppSwitcher.mergingCachedItems(
            [selected], baseItems: [fallback()], suppressedIdentities: []
        )
        XCTAssertEqual(result.map(\.historyIdentity), [selected.historyIdentity])
    }

    func testFilteredWindowIsNotReintroducedIntoEmptyOrFallbackSnapshot() {
        let rejected = window(1)
        for cached in [[], [fallback()]] {
            let result = ProductionAppSwitcher.mergingCachedItems(
                cached, baseItems: [rejected], suppressedIdentities: [rejected.historyIdentity]
            )
            XCTAssertEqual(result.map(\.historyIdentity), cached.map(\.historyIdentity))
        }
    }

    func testUnchangedInputRefreshesAfterMetadataAgeButNotOnImmediatePublication() {
        var gate = ProductionEnrichmentGate()
        let signature = ProductionEnrichmentInputSignature(configuration: configuration(), itemKeys: ["same"])
        let start = Date(timeIntervalSince1970: 100)
        XCTAssertTrue(gate.shouldSchedule(signature, force: false, now: start))
        XCTAssertFalse(gate.shouldSchedule(signature, force: false, now: start.addingTimeInterval(0.2)))
        XCTAssertTrue(gate.shouldSchedule(signature, force: false, now: start.addingTimeInterval(0.36)))
        XCTAssertFalse(gate.shouldSchedule(signature, force: false, now: start.addingTimeInterval(0.37)))
    }

    func testFallbackRetainsFactoryActivationClosure() {
        var activationCount = 0
        let app = SwitcherItem(
            title: "Editor", subtitle: "", icon: nil, previewImage: nil,
            historyIdentity: .appFallback(bundleID: "com.example.editor", pid: 10),
            sourceAppIdentifier: "com.example.editor", kind: .appFallback,
            activate: { activationCount += 1 }
        )
        let result = finalize([window(1)], metadata: [metadata(1, minimized: true)], fallbacks: [app])
        XCTAssertEqual(result.count, 1)
        result.first?.activate()
        XCTAssertEqual(activationCount, 1)
    }

    func testCompleteInventoryPublishesAll24WindowsAndAsyncPreviewBeyondEight() {
        let initial = (1...24).map { window(CGWindowID($0)) }
        let first = finalize(initial)
        XCTAssertEqual(first.count, 24)
        XCTAssertFalse(first.contains { $0.kind == .appFallback })
        let refreshed = expectation(description: "whole inventory preview update")
        DispatchQueue.main.async {
            let image = NSImage(size: NSSize(width: 20, height: 20))
            let replacement = SwitcherItem(
                title: "Window", subtitle: "Editor", icon: nil, previewImage: image,
                historyIdentity: .appWindow(pid: 10, windowID: 24),
                sourceAppIdentifier: "com.example.editor", activate: {}
            )
            let next = self.finalize(Array(initial.dropLast()) + [replacement])
            let published = ProductionAppSwitcher.publishedItems(
                next, hasPublishedInventory: true,
                provisionalItems: [self.fallback(), self.window(99)], suppressedIdentities: []
            )
            XCTAssertEqual(published.map(\.historyIdentity), first.map(\.historyIdentity))
            XCTAssertTrue(published[23].previewImage === image)
            XCTAssertEqual(published.count, 24)
            refreshed.fulfill()
        }
        wait(for: [refreshed], timeout: 2)
    }

    func testCompleteEmptyInventoryDoesNotReintroduceProvisionalWindows() {
        XCTAssertTrue(ProductionAppSwitcher.publishedItems(
            [], hasPublishedInventory: true, provisionalItems: [window(1), fallback()], suppressedIdentities: []
        ).isEmpty)
    }

    func testColdMinimizedSiblingsPublishWithoutFallbackOrPreviews() {
        let result = finalize(
            [window(1, minimized: true), window(2, minimized: true)],
            metadata: [metadata(1, minimized: true), metadata(2, minimized: true)], minimized: true
        )
        XCTAssertEqual(result.map(\.windowID), [1, 2])
        XCTAssertTrue(result.allSatisfy { $0.previewImage == nil })
    }

    func testLifecycleSnapshotDistinguishesIncompleteAndEmptyProcessInventories() {
        let snapshot = AXWindowCatalogSnapshot(
            byPID: [:], enumeratedPIDs: [10, 20], unresolvedIdentityPIDs: [20],
            capability: .available, processGenerations: [10: Date(), 20: Date(), 30: Date()]
        )
        XCTAssertEqual(snapshot.completeIdentityPIDs, [10])
        XCTAssertEqual(Set(snapshot.processGenerations.keys), [10, 20, 30])
        XCTAssertTrue(snapshot.allWindows.isEmpty)
    }

    func testColdPublicationWaitsForWholeInventory() {
        XCTAssertTrue(ProductionAppSwitcher.publishedItems(
            [], hasPublishedInventory: false,
            provisionalItems: [fallback(), window(1)], suppressedIdentities: []
        ).isEmpty)
    }

    func test24WindowsAcrossApplicationsPreserveSiblingsAndExplicitMinimizedProfile() {
        var candidates: [SwitcherItem] = []
        var fallbacks: [SwitcherItem] = []
        for pid: pid_t in [10, 20, 30] {
            fallbacks.append(fallback(pid: pid))
            for id in 1...8 {
                candidates.append(window(CGWindowID(id), pid: pid, minimized: id == 8))
            }
        }
        let included = finalize(candidates, fallbacks: fallbacks, minimized: true)
        XCTAssertEqual(included.count, 24)
        XCTAssertEqual(Set(included.map(\.historyIdentity)).count, 24)
        XCTAssertFalse(included.contains { $0.kind == .appFallback })
        let excluded = finalize(candidates, fallbacks: fallbacks, minimized: false)
        XCTAssertEqual(excluded.count, 21)
        XCTAssertFalse(excluded.contains( where: { $0.isMinimized }))
        for pid: pid_t in [10, 20, 30] {
            XCTAssertEqual(excluded.filter { $0.ownerPID == pid }.count, 7)
        }
    }

    func testRealAsyncProductionPublicationUpdates24thWindow() {
        var initial: [SwitcherItem] = []
        for index in 1...24 {
            let owner = pid_t(((index - 1) / 8 + 1) * 10)
            initial.append(window(CGWindowID(index), pid: owner))
        }
        let apps = [fallback(pid: 10), fallback(pid: 20), fallback(pid: 30)]
        let config = configuration(minimized: true)
        let historyURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: historyURL) }
        let production = ProductionAppSwitcher(
            base: AppSwitcher(observeWorkspace: false),
            history: SwitcherHistoryStore(durableStore: DurableSwitcherHistoryStore(fileURL: historyURL)),
            initialConfiguration: config,
            inventoryProvider: { candidates, configuration in
                ProductionMembershipFinalizer.items(
                    candidates, fallbackItems: apps, metadataByIdentity: [:],
                    configuration: configuration, globalVisibility: .allSpaces, globalIncludesMinimized: true
                )
            }
        )
        XCTAssertFalse(production.hasCompleteInventory)
        let first = expectation(description: "complete initial production callback")
        production.onItemsChanged = { items in
            XCTAssertEqual(items.count, 24)
            XCTAssertTrue(production.hasCompleteInventory)
            XCTAssertEqual(Set(items.map(\.historyIdentity)).count, 24)
            first.fulfill()
        }
        production.scheduleEnrichment(from: initial + apps, forceCatalogRefresh: true)
        wait(for: [first], timeout: 3)
        let image = NSImage(size: NSSize(width: 20, height: 20))
        let last = SwitcherItem(
            title: "Window", subtitle: "Editor", icon: nil, previewImage: image,
            historyIdentity: .appWindow(pid: 30, windowID: 24),
            sourceAppIdentifier: "com.example.editor", activate: {}
        )
        let refreshed = expectation(description: "real production callback for preview after slot8")
        production.onItemsChanged = { items in
            XCTAssertEqual(items.map(\.historyIdentity), initial.map(\.historyIdentity))
            XCTAssertTrue(items[23].previewImage === image)
            XCTAssertFalse(items.contains { $0.kind == .appFallback })
            refreshed.fulfill()
        }
        production.scheduleEnrichment(from: Array(initial.dropLast()) + [last] + apps, forceCatalogRefresh: true)
        wait(for: [refreshed], timeout: 3)
        production.onItemsChanged = nil
    }

    func testAXOnlyMinimizedWindowPublishesExactCaptureOffMainThread() {
        let app = NSRunningApplication.current
        let pid = app.processIdentifier
        let id: CGWindowID = 987654
        let frame = CGRect(x: 20, y: 30, width: 300, height: 200)
        let metadata = AXWindowMetadata(
            ownerPID: pid, windowID: id, title: "AX-only", role: "AXWindow",
            subrole: "AXStandardWindow", parentRole: "AXApplication", documentURL: nil,
            frame: frame, isMinimized: true, isFullscreen: false, isOnScreen: false,
            workspace: .fallback(isOnScreen: false, reason: "Synthetic test")
        )
        let snapshot = AXWindowCatalogSnapshot(
            byPID: [pid: [id: metadata]], enumeratedPIDs: [pid],
            unresolvedIdentityPIDs: [], capability: .available
        )
        let context = CGContext(data: nil, width: 300, height: 200, bitsPerComponent: 8,
                                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
        let image = NSImage(cgImage: context.makeImage()!, size: frame.size)
        let publication = expectation(description: "AX-only captured preview published")
        let production = ProductionAppSwitcher(
            base: AppSwitcher(observeWorkspace: false),
            initialConfiguration: configuration(minimized: true),
            windowInventoryProvider: { ([app], snapshot) },
            previewCapture: { owner, window, bounds in
                XCTAssertFalse(Thread.isMainThread)
                XCTAssertEqual(owner, pid)
                XCTAssertEqual(window, id)
                XCTAssertEqual(bounds, frame)
                return AppSwitcher.PreviewAssets(thumbnail: image, backdrop: image)
            }
        )
        production.onItemsChanged = { items in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(items.count, 1)
            XCTAssertEqual(items.first?.windowID, id)
            XCTAssertEqual(items.first?.isMinimized, true)
            XCTAssertNotNil(items.first?.previewImage)
            XCTAssertEqual(items.first?.previewCaptureIsFresh, true)
            XCTAssertEqual(items.first?.previewState, .live)
            publication.fulfill()
        }
        production.scheduleEnrichment(from: [], forceCatalogRefresh: true)
        wait(for: [publication], timeout: 3)
        production.onItemsChanged = nil
        SwitcherPreviewContinuityStore.purge(ownerPID: pid)
    }

    private func finalize(
        _ candidates: [SwitcherItem],
        metadata: [AXWindowMetadata] = [],
        fallbacks: [SwitcherItem]? = nil,
        visibility: WindowVisibilityScope = .allSpaces,
        minimized: Bool = false,
        filter: SwitcherProfileAppFilter = .all
    ) -> [SwitcherItem] {
        ProductionMembershipFinalizer.items(
            candidates,
            fallbackItems: fallbacks ?? [fallback()],
            metadataByIdentity: Dictionary(uniqueKeysWithValues: metadata.map {
                (.appWindow(pid: $0.ownerPID, windowID: $0.windowID), $0)
            }),
            configuration: configuration(visibility: visibility, minimized: minimized, filter: filter),
            globalVisibility: .allSpaces,
            globalIncludesMinimized: false
        )
    }

    private func configuration(
        visibility: WindowVisibilityScope = .allSpaces,
        minimized: Bool = false,
        filter: SwitcherProfileAppFilter = .all
    ) -> SwitcherSessionConfiguration {
        SwitcherSessionConfiguration(
            profileID: UUID(), profileName: "Test", style: .classicGrid,
            visibilityScope: visibility, includeMinimizedWindows: minimized,
            displayPlacement: .activeWindowDisplay, appFilter: filter,
            releaseBehavior: .holdPrimaryModifier
        )
    }

    private func window(_ id: CGWindowID, pid: pid_t = 10, minimized: Bool = false) -> SwitcherItem {
        SwitcherItem(
            title: "Window", subtitle: "Editor", icon: nil, previewImage: nil,
            historyIdentity: .appWindow(pid: pid, windowID: id),
            sourceAppIdentifier: "com.example.editor", kind: .appWindow,
            isMinimized: minimized, activate: {}
        )
    }

    private func fallback(pid: pid_t = 10) -> SwitcherItem {
        SwitcherItem(
            title: "Editor", subtitle: "", icon: nil, previewImage: nil,
            historyIdentity: .appFallback(bundleID: "com.example.editor", pid: pid),
            sourceAppIdentifier: "com.example.editor", kind: .appFallback, activate: {}
        )
    }

    private func metadata(
        _ id: CGWindowID,
        minimized: Bool = false,
        subrole: String = "AXStandardWindow",
        onScreen: Bool = true
    ) -> AXWindowMetadata {
        AXWindowMetadata(
            ownerPID: 10, windowID: id, title: "Window", role: "AXWindow", subrole: subrole,
            parentRole: "AXApplication", documentURL: nil, frame: nil,
            isMinimized: minimized, isFullscreen: false, isOnScreen: onScreen,
            workspace: .fallback(isOnScreen: onScreen, reason: "Test fixture")
        )
    }
}
