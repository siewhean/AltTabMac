import AppKit
import CoreGraphics
import XCTest
@testable import CmdTab

/// Regressions for the MRU, panel latency, CPU and activation fixes.
/// Each test names the user-visible symptom it guards against.
final class SwitcherReliabilityRegressionTests: XCTestCase {

    // MARK: - MRU: application-level history entries

    /// A -> B (focused window not resolved in time, recorded at app level) -> C.
    /// Command-Tab from C must offer B, not A.
    func testAppLevelActivationStillRanksThatAppsWindow() {
        let a = SwitcherHistoryIdentity.appWindow(pid: 10, windowID: 1)
        let b = SwitcherHistoryIdentity.appWindow(pid: 20, windowID: 2)
        let c = SwitcherHistoryIdentity.appWindow(pid: 30, windowID: 3)
        let items = [item("A", "com.a", a), item("B", "com.b", b), item("C", "com.c", c)]

        let ordered = SwitcherOrdering.orderedItems(
            items,
            historyEntries: [c, .appFallback(bundleID: "com.b", pid: 20), a],
            currentFrontmost: c
        )

        XCTAssertEqual(ordered.map(\.title), ["B", "A", "C"])
    }

    func testAppLevelActivationThroughHistoryStoreOrdersMostRecentFirst() {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = SwitcherHistoryStore(durableStore: DurableSwitcherHistoryStore(fileURL: url))
        let a = SwitcherHistoryIdentity.appWindow(pid: 10, windowID: 1)
        let b = SwitcherHistoryIdentity.appWindow(pid: 20, windowID: 2)
        let c = SwitcherHistoryIdentity.appWindow(pid: 30, windowID: 3)
        store.noteActivation(a)
        store.noteActivation(.appFallback(bundleID: "com.b", pid: 20))
        store.noteActivation(c)

        let ordered = SwitcherOrdering.orderedItems(
            [item("A", "com.a", a), item("B", "com.b", b), item("C", "com.c", c)],
            history: store,
            currentFrontmost: c
        )

        XCTAssertEqual(ordered.map(\.title), ["B", "A", "C"])
    }

    /// Only one window inherits an app-level rank: the app's most recent one.
    /// Its other windows keep their own position, so apps are never grouped.
    func testAppLevelRankGoesToTheAppsMostRecentWindowOnly() {
        let a = SwitcherHistoryIdentity.appWindow(pid: 10, windowID: 1)
        let b1 = SwitcherHistoryIdentity.appWindow(pid: 20, windowID: 21)
        let b2 = SwitcherHistoryIdentity.appWindow(pid: 20, windowID: 22)
        let items = [item("B1", "com.b", b1), item("A", "com.a", a), item("B2", "com.b", b2)]

        let ordered = SwitcherOrdering.orderedItems(
            items,
            historyEntries: [.appFallback(bundleID: "com.b", pid: 20), a, b2],
            currentFrontmost: nil
        )

        XCTAssertEqual(ordered.map(\.title), ["B2", "A", "B1"])
        XCTAssertEqual(
            SwitcherOrdering.effectiveRanks(
                items: items,
                historyEntries: [.appFallback(bundleID: "com.b", pid: 20), a, b2]
            ),
            [nil, 1, 0]
        )
    }

    func testOlderAppLevelEntryNeverDemotesANewerExactWindow() {
        let a = SwitcherHistoryIdentity.appWindow(pid: 10, windowID: 1)
        let b = SwitcherHistoryIdentity.appWindow(pid: 20, windowID: 2)
        let items = [item("A", "com.a", a), item("B", "com.b", b)]

        XCTAssertEqual(
            SwitcherOrdering.effectiveRanks(
                items: items,
                historyEntries: [b, a, .appFallback(bundleID: "com.b", pid: 20)]
            ),
            [1, 0]
        )
    }

    func testBundleOnlyAppLevelEntryMatchesCaseInsensitively() {
        let a = SwitcherHistoryIdentity.appWindow(pid: 10, windowID: 1)
        let b = SwitcherHistoryIdentity.appWindow(pid: 20, windowID: 2)

        let ordered = SwitcherOrdering.orderedItems(
            [item("A", "com.a", a), item("B", "com.Example.B", b)],
            historyEntries: [.appFallback(bundleID: "com.example.b", pid: nil), a],
            currentFrontmost: nil
        )

        XCTAssertEqual(ordered.map(\.title), ["B", "A"])
    }

    func testAppLevelEntryForAnotherProcessIsIgnored() {
        let a = SwitcherHistoryIdentity.appWindow(pid: 10, windowID: 1)
        let b = SwitcherHistoryIdentity.appWindow(pid: 20, windowID: 2)

        XCTAssertEqual(
            SwitcherOrdering.effectiveRanks(
                items: [item("A", "com.a", a), item("B", "com.b", b)],
                historyEntries: [.appFallback(bundleID: "com.other", pid: 99), a]
            ),
            [1, nil]
        )
    }

    // MARK: - Mid-session order stability

    func testRefreshDuringSessionKeepsVisibleOrderAndCurrentWindowLast() {
        let a = SwitcherHistoryIdentity.appWindow(pid: 10, windowID: 1)
        let b = SwitcherHistoryIdentity.appWindow(pid: 20, windowID: 2)
        let c = SwitcherHistoryIdentity.appWindow(pid: 30, windowID: 3)
        let late = SwitcherHistoryIdentity.appWindow(pid: 40, windowID: 4)
        let current = [item("B", "com.b", b), item("A", "com.a", a), item("C", "com.c", c)]
        // Enrichment re-sorted, found a late minimized window and refreshed A.
        let refreshed = [
            item("Late", "com.late", late),
            item("A (renamed)", "com.a", a),
            item("B", "com.b", b),
            item("C", "com.c", c),
        ]

        let stable = SwitcherOrdering.stableSessionOrder(
            current: current,
            refreshed: refreshed,
            currentFrontmost: c
        )

        XCTAssertEqual(stable.map(\.title), ["B", "A (renamed)", "Late", "C"])
    }

    func testRefreshDuringSessionDropsClosedWindows() {
        let a = SwitcherHistoryIdentity.appWindow(pid: 10, windowID: 1)
        let b = SwitcherHistoryIdentity.appWindow(pid: 20, windowID: 2)
        let c = SwitcherHistoryIdentity.appWindow(pid: 30, windowID: 3)

        let stable = SwitcherOrdering.stableSessionOrder(
            current: [item("B", "com.b", b), item("A", "com.a", a), item("C", "com.c", c)],
            refreshed: [item("C", "com.c", c), item("B", "com.b", b)],
            currentFrontmost: c
        )

        XCTAssertEqual(stable.map(\.title), ["B", "C"])
    }

    func testFirstPublicationUsesRefreshedOrderWithCurrentWindowLast() {
        let a = SwitcherHistoryIdentity.appWindow(pid: 10, windowID: 1)
        let b = SwitcherHistoryIdentity.appWindow(pid: 20, windowID: 2)

        let stable = SwitcherOrdering.stableSessionOrder(
            current: [],
            refreshed: [item("A", "com.a", a), item("B", "com.b", b)],
            currentFrontmost: a
        )

        XCTAssertEqual(stable.map(\.title), ["B", "A"])
    }

    // MARK: - CPU: incremental capture and cheaper trimming

    func testRecentCaptureIsReusedOnlyWithinItsAge() {
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(AppSwitcher.mayReuseCapturedPreview(
            capturedAt: now.addingTimeInterval(-5), now: now, maximumAge: 20
        ))
        XCTAssertFalse(AppSwitcher.mayReuseCapturedPreview(
            capturedAt: now.addingTimeInterval(-25), now: now, maximumAge: 20
        ))
        XCTAssertFalse(AppSwitcher.mayReuseCapturedPreview(
            capturedAt: now.addingTimeInterval(-0.1), now: now, maximumAge: 0
        ), "A zero age means always capture.")
        XCTAssertFalse(AppSwitcher.mayReuseCapturedPreview(
            capturedAt: now.addingTimeInterval(5), now: now, maximumAge: 20
        ), "A clock that moved backwards never counts as fresh.")
    }

    func testCapturePolicyConstantsKeepPresentationFresherThanBackground() {
        XCTAssertLessThan(AppSwitcher.presentationPreviewReuseAge, AppSwitcher.backgroundPreviewReuseAge)
        XCTAssertGreaterThan(AppSwitcher.backgroundRefreshDelay, 0)
        XCTAssertLessThanOrEqual(AppSwitcher.backgroundRefreshDelay, 0.5)
    }

    /// The strip-based trim must crop exactly the transparent border on each
    /// side, including asymmetric top and bottom borders.
    func testTrimRemovesAsymmetricTransparentBordersOnEverySide() throws {
        let width = 200, height = 120
        let top = 12, bottom = 4, left = 9, right = 2
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        // Bitmap contexts draw from the bottom-left; image rows count from the top.
        context.fill(CGRect(
            x: left, y: bottom,
            width: width - left - right, height: height - top - bottom
        ))
        let image = try XCTUnwrap(context.makeImage())

        let trimmed = AppSwitcher.trimmedWindowCapture(image)

        XCTAssertEqual(trimmed.width, width - left - right)
        XCTAssertEqual(trimmed.height, height - top - bottom)
        let corners = try alphaAtCorners(of: trimmed)
        XCTAssertTrue(corners.allSatisfy { $0 == 255 }, "Every corner of the crop must be opaque: \(corners)")
    }

    func testTrimLeavesOpaqueImageUntouched() throws {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        let image = try XCTUnwrap(context.makeImage())

        let trimmed = AppSwitcher.trimmedWindowCapture(image)

        XCTAssertEqual(trimmed.width, 64)
        XCTAssertEqual(trimmed.height, 64)
    }

    // MARK: - Enrichment publication and caches

    func testFinishedEnrichmentIsPublishedUnlessExplicitlyInvalidated() {
        let config = configuration(name: "A")
        XCTAssertTrue(ProductionAppSwitcher.mayPublishEnrichment(
            epoch: 3, currentEpoch: 3, configuration: config, activeConfiguration: config
        ))
        XCTAssertFalse(ProductionAppSwitcher.mayPublishEnrichment(
            epoch: 3, currentEpoch: 4, configuration: config, activeConfiguration: config
        ), "A window closed by a switcher action invalidates in-flight results.")
        XCTAssertFalse(ProductionAppSwitcher.mayPublishEnrichment(
            epoch: 3, currentEpoch: 3, configuration: config, activeConfiguration: configuration(name: "B")
        ), "Results built for another profile are never published.")
    }

    func testCatalogWalkIsReusedOnlyWhenMembershipIsUnchanged() {
        XCTAssertEqual(ProductionAppSwitcher.catalogMaximumAge(
            forcedRefresh: true, membershipKeys: ["a"], lastEnrichedMembershipKeys: ["a"], defaultMaximumAge: 0.35
        ), 0)
        XCTAssertEqual(ProductionAppSwitcher.catalogMaximumAge(
            forcedRefresh: false, membershipKeys: ["a", "b"], lastEnrichedMembershipKeys: ["a"], defaultMaximumAge: 0.35
        ), 0.35)
        XCTAssertEqual(ProductionAppSwitcher.catalogMaximumAge(
            forcedRefresh: false, membershipKeys: ["a"], lastEnrichedMembershipKeys: nil, defaultMaximumAge: 0.35
        ), 0.35)
        XCTAssertEqual(ProductionAppSwitcher.catalogMaximumAge(
            forcedRefresh: false, membershipKeys: ["a", "b"], lastEnrichedMembershipKeys: ["a", "b"], defaultMaximumAge: 0.35
        ), ProductionAppSwitcher.previewOnlyCatalogMaximumAge)
    }

    /// A newer scheduled pass used to discard every finished one, so steady
    /// base publications could starve the switcher of its inventory.
    func testFinishedEnrichmentPublishesEvenWhenANewerPassIsQueued() {
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var calls = 0
        let historyURL = temporaryFile()
        defer { try? FileManager.default.removeItem(at: historyURL) }
        let production = ProductionAppSwitcher(
            base: AppSwitcher(observeWorkspace: false),
            history: SwitcherHistoryStore(durableStore: DurableSwitcherHistoryStore(fileURL: historyURL)),
            initialConfiguration: configuration(name: "A"),
            inventoryProvider: { candidates, _ in
                lock.lock()
                calls += 1
                let call = calls
                lock.unlock()
                if call == 1 {
                    entered.signal()
                    _ = release.wait(timeout: .now() + 5)
                }
                return candidates
            }
        )
        let first = item("First", "com.a", .appWindow(pid: 10, windowID: 1))
        let second = item("Second", "com.b", .appWindow(pid: 20, windowID: 2))
        var published: [[String]] = []
        let both = expectation(description: "both passes published")
        both.expectedFulfillmentCount = 2
        production.onItemsChanged = { items in
            published.append(items.map(\.title))
            both.fulfill()
        }

        production.scheduleEnrichment(from: [first], forceCatalogRefresh: true)
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        production.scheduleEnrichment(from: [first, second], forceCatalogRefresh: true)
        release.signal()

        wait(for: [both], timeout: 5)
        XCTAssertEqual(published, [["First"], ["First", "Second"]])
        production.onItemsChanged = nil
    }

    func testInventoryCacheRestoresOnlyRecentEntriesForTheSameProfile() {
        var cache = ProductionInventoryCache()
        let a = configuration(name: "A")
        let b = configuration(name: "B")
        let window = item("W", "com.a", .appWindow(pid: 10, windowID: 1))
        cache.store(.init(configuration: a, items: [window], descriptors: [:], suppressed: [], publishedAt: 100))

        XCTAssertEqual(cache.entry(for: a, now: 130)?.items.map(\.title), ["W"])
        XCTAssertNil(cache.entry(for: b, now: 130), "Never expose items enriched for another profile.")
        XCTAssertNil(cache.entry(for: a, now: 100 + ProductionInventoryCache.maximumAge + 1))
        XCTAssertNil(cache.entry(for: a, now: 50), "An uptime that moved backwards is not fresh.")

        cache.store(.init(configuration: a, items: [], descriptors: [:], suppressed: [], publishedAt: 140))
        XCTAssertEqual(cache.entries.count, 1, "A newer publication replaces the profile's entry.")
        XCTAssertEqual(cache.entry(for: a, now: 141)?.items.count, 0)
    }

    func testInventoryCacheIsBounded() {
        var cache = ProductionInventoryCache()
        let configurations = (0..<(ProductionInventoryCache.capacity + 2)).map { configuration(name: "P\($0)") }
        for (offset, config) in configurations.enumerated() {
            cache.store(.init(configuration: config, items: [], descriptors: [:], suppressed: [],
                              publishedAt: TimeInterval(offset)))
        }

        XCTAssertEqual(cache.entries.count, ProductionInventoryCache.capacity)
        XCTAssertNil(cache.entry(for: configurations[0], now: 10), "The least recently published entry is evicted.")
        XCTAssertNotNil(cache.entry(for: configurations.last!, now: 10))
    }

    func testSyntheticPreviewCacheReusesMinimizedLongerThanVisible() {
        var cache = SyntheticPreviewCache()
        let minimized = SwitcherHistoryIdentity.appWindow(pid: 10, windowID: 1)
        let offSpace = SwitcherHistoryIdentity.appWindow(pid: 10, windowID: 2)
        let frame = CGRect(x: 0, y: 0, width: 300, height: 200)
        let captured = Date(timeIntervalSince1970: 1_000)
        let assets = AppSwitcher.PreviewAssets(thumbnail: NSImage(size: frame.size), backdrop: NSImage(size: frame.size))
        cache.store(.init(assets: assets, capturedAt: captured, frame: frame, isMinimized: true), for: minimized)
        cache.store(.init(assets: assets, capturedAt: captured, frame: frame, isMinimized: false), for: offSpace)

        let later = captured.addingTimeInterval(SyntheticPreviewCache.visibleMaximumAge + 1)
        XCTAssertNotNil(cache.reusableAssets(for: minimized, frame: frame, isMinimized: true, now: later))
        XCTAssertNil(cache.reusableAssets(for: offSpace, frame: frame, isMinimized: false, now: later))
        XCTAssertNil(cache.reusableAssets(
            for: minimized, frame: frame, isMinimized: true,
            now: captured.addingTimeInterval(SyntheticPreviewCache.minimizedMaximumAge + 1)
        ))
        XCTAssertNil(cache.reusableAssets(
            for: minimized, frame: frame.offsetBy(dx: 10, dy: 0), isMinimized: true, now: later
        ), "A moved or resized window is recaptured.")
        XCTAssertNil(cache.reusableAssets(for: minimized, frame: frame, isMinimized: false, now: later),
                     "A restored window is recaptured.")

        cache.retain(only: [minimized])
        XCTAssertEqual(cache.count, 1)
    }

    // MARK: - Multi-display placement

    func testWindowOnDisplayAboveMainResolvesToThatScreen() {
        let main = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let above = CGRect(x: 0, y: 900, width: 1920, height: 1080)
        let below = CGRect(x: 0, y: -1080, width: 1920, height: 1080)
        let screens = [main, above, below]

        XCTAssertEqual(DisplayGeometry.screenIndex(
            containingCGRect: CGRect(x: 100, y: 100, width: 400, height: 300),
            appKitScreenFrames: screens, mainDisplayHeight: 900
        ), 0)
        XCTAssertEqual(DisplayGeometry.screenIndex(
            containingCGRect: CGRect(x: 100, y: -800, width: 400, height: 300),
            appKitScreenFrames: screens, mainDisplayHeight: 900
        ), 1, "CG y above the main display is negative.")
        XCTAssertEqual(DisplayGeometry.screenIndex(
            containingCGRect: CGRect(x: 100, y: 1000, width: 400, height: 300),
            appKitScreenFrames: screens, mainDisplayHeight: 900
        ), 2)
        XCTAssertNil(DisplayGeometry.screenIndex(
            containingCGRect: CGRect(x: 5_000, y: 5_000, width: 10, height: 10),
            appKitScreenFrames: screens, mainDisplayHeight: 900
        ))
    }

    func testCGToAppKitRectConversionFlipsAroundMainDisplay() {
        XCTAssertEqual(
            DisplayGeometry.appKitRect(fromCG: CGRect(x: 10, y: 20, width: 100, height: 50), mainDisplayHeight: 900),
            CGRect(x: 10, y: 830, width: 100, height: 50)
        )
    }

    // MARK: - Focused-window observation

    func testFocusedWindowRetriesOutlastTheAccessibilityTimeout() {
        XCTAssertEqual(FocusedWindowHistoryObserver.retryDelay(afterAttempt: 0), 0)
        let total = (0..<FocusedWindowHistoryObserver.focusedWindowAttempts)
            .map(FocusedWindowHistoryObserver.retryDelay(afterAttempt:))
            .reduce(0, +)
        XCTAssertGreaterThan(total, 0.25, "Retries must outlast one 0.25 s AX timeout.")
        XCTAssertLessThan(total, 1.0, "Retries must still settle within a second.")
    }

    func testFailedObserverRegistrationIsRetriedWithBackoff() {
        XCTAssertTrue(FocusedWindowHistoryObserver.mayRetryRegistration(lastFailureUptime: nil, now: 10))
        XCTAssertFalse(FocusedWindowHistoryObserver.mayRetryRegistration(lastFailureUptime: 10, now: 11))
        XCTAssertTrue(FocusedWindowHistoryObserver.mayRetryRegistration(
            lastFailureUptime: 10, now: 10 + FocusedWindowHistoryObserver.failedRegistrationRetryInterval
        ))
        XCTAssertTrue(FocusedWindowHistoryObserver.mayRetryRegistration(lastFailureUptime: 10, now: 5))
    }

    // MARK: - Durable history writes

    func testReconciliationPersistsOnlyOnChangeOrAfterInterval() {
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(DurableSwitcherHistoryStore.shouldPersistReconciliation(
            recordsChanged: true, lastPersistedAt: now, now: now
        ))
        XCTAssertTrue(DurableSwitcherHistoryStore.shouldPersistReconciliation(
            recordsChanged: false, lastPersistedAt: nil, now: now
        ))
        XCTAssertFalse(DurableSwitcherHistoryStore.shouldPersistReconciliation(
            recordsChanged: false, lastPersistedAt: now.addingTimeInterval(-10), now: now
        ))
        XCTAssertTrue(DurableSwitcherHistoryStore.shouldPersistReconciliation(
            recordsChanged: false,
            lastPersistedAt: now.addingTimeInterval(-DurableSwitcherHistoryStore.lastSeenPersistInterval),
            now: now
        ))
    }

    func testReconcilingUnchangedWindowsDoesNotRewriteTheFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DurableReconcileTests-\(UUID().uuidString)", isDirectory: true)
        let file = directory.appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DurableSwitcherHistoryStore(fileURL: file, maximumRecords: 10, expirationInterval: 100_000)
        let start = Date(timeIntervalSince1970: 10_000)
        let window = descriptor(.appWindow(pid: 11, windowID: 12))
        store.noteActivation(descriptor: window, now: start)
        store.waitForPendingWrites()
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        try FileManager.default.removeItem(at: file)

        XCTAssertEqual(store.restoredIdentities(for: [window], now: start.addingTimeInterval(10)), [window.identity])
        store.waitForPendingWrites()
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path),
                       "A lastSeen-only refresh must not rewrite the file on every switch.")

        _ = store.restoredIdentities(
            for: [window],
            now: start.addingTimeInterval(DurableSwitcherHistoryStore.lastSeenPersistInterval + 11)
        )
        store.waitForPendingWrites()
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path),
                      "lastSeen refreshes are still saved periodically.")
    }

    // MARK: - Helpers

    private func item(_ title: String, _ appID: String, _ identity: SwitcherHistoryIdentity) -> SwitcherItem {
        SwitcherItem(
            title: title, subtitle: appID, icon: nil, previewImage: nil,
            historyIdentity: identity, sourceAppIdentifier: appID, kind: .appWindow
        ) {}
    }

    private func configuration(name: String) -> SwitcherSessionConfiguration {
        SwitcherSessionConfiguration(
            profileID: UUID(), profileName: name, style: .classicGrid,
            visibilityScope: .allSpaces, includeMinimizedWindows: false,
            displayPlacement: .activeWindowDisplay, appFilter: .all,
            releaseBehavior: .holdPrimaryModifier
        )
    }

    private func descriptor(_ identity: SwitcherHistoryIdentity) -> LiveWindowHistoryDescriptor {
        LiveWindowHistoryDescriptor(
            identity: identity,
            bundleIdentifier: "com.example.Editor",
            title: "Notes",
            documentURL: URL(fileURLWithPath: "/tmp/notes.txt"),
            role: "AXWindow",
            subrole: "AXStandardWindow",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            displayIdentifier: "display-1",
            workspaceKey: "workspace:display-1:1:user"
        )
    }

    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("history-\(UUID().uuidString).json")
    }

    private func alphaAtCorners(of image: CGImage) throws -> [UInt8] {
        let width = image.width, height = image.height
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let stride = context.bytesPerRow
        return [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)].map { x, y in
            bytes[y * stride + x * 4 + 3]
        }
    }
}
