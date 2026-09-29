import AppKit
import ScreenCaptureKit
import XCTest
@testable import CmdTab

final class PreviewStatePublicationTests: XCTestCase {
    override func tearDown() {
        SwitcherPreviewContinuityStore.resetForTesting()
        SnapshotDiagnosticsTracker.shared.record(SnapshotDiagnosticMetrics())
        super.tearDown()
    }

    func testRecoveredPreviewPublicationChangesOnlyMatchingWindowWithoutNewCapture() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let firstID: CGWindowID = 811_001
        let secondID: CGWindowID = 811_002
        let firstIdentity = SwitcherHistoryIdentity.appWindow(pid: pid, windowID: firstID)
        let secondIdentity = SwitcherHistoryIdentity.appWindow(pid: pid, windowID: secondID)
        let firstKey = SwitcherItem.previewContinuityIdentityKey(
            historyIdentity: firstIdentity, sourceAppIdentifier: nil
        )
        let old = NSImage(size: NSSize(width: 120, height: 90))
        let latest = NSImage(size: NSSize(width: 160, height: 100))
        let first = SwitcherItem(title: "First", subtitle: "Fixture", icon: nil,
            previewImage: old, allowsPreviewRecovery: false, previewCacheKey: "first",
            historyIdentity: firstIdentity, activate: {})
        let second = SwitcherItem(title: "Second", subtitle: "Fixture", icon: nil,
            previewImage: old, allowsPreviewRecovery: false, previewCacheKey: "second",
            historyIdentity: secondIdentity, activate: {})
        _ = SwitcherPreviewContinuityStore.resolve(key: "first", identityKey: firstKey,
            preview: latest, backdrop: latest, captureAccessAllowed: true,
            ownerPID: pid, windowID: firstID)

        let published = AppSwitcher.itemsPublishingRecoveredPreview([first, second], windowID: firstID)
        XCTAssertTrue(published[0].previewImage === latest)
        XCTAssertEqual(published[0].title, first.title)
        XCTAssertEqual(published[0].historyIdentity, firstIdentity)
        XCTAssertFalse(published[0].allowsPreviewRecovery)
        XCTAssertTrue(published[1].previewImage === second.previewImage)
        XCTAssertEqual(published[1].historyIdentity, secondIdentity)
    }

    func testFailureStatesLeavePendingAfterBoundedRetries() {
        var state = PreviewRecoveryRequestState()
        let start = Date(timeIntervalSince1970: 100)
        for attempt in 0..<5 {
            let now = start.addingTimeInterval(Double(attempt) * 3)
            XCTAssertTrue(state.begin(identityKey: "window", now: now))
            XCTAssertEqual(state.previewState(identityKey: "window"), .pending)
            let delay = state.finish(identityKey: "window", succeeded: false, now: now)
            XCTAssertEqual(state.previewState(identityKey: "window"), attempt == 4 ? .unavailable : .pending)
            XCTAssertEqual(delay, attempt == 4 ? nil : PreviewRecoveryRequestState.transientRetryDelays[attempt])
        }
        XCTAssertTrue(state.begin(identityKey: "denied", now: start))
        XCTAssertNil(state.finish(identityKey: "denied", succeeded: false, now: start,
                                  retryAllowed: false, permissionDenied: true))
        XCTAssertEqual(state.previewState(identityKey: "denied"), .permissionDenied)
    }

    func testTerminalFailuresPublishWithoutSuccessAndPermissionDenialDoesNotRetry() {
        let unavailable = expectation(description: "Exhausted attempts publish unavailable")
        let denied = expectation(description: "Permission denial publishes immediately")
        let lock = NSLock()
        var attempts: [CGWindowID: Int] = [:]
        let observer = NotificationCenter.default.addObserver(
            forName: ReliableWindowPreviewRecovery.didRecoverPreviewNotification, object: nil, queue: .main
        ) { notification in
            guard let id = notification.userInfo?["windowID"] as? CGWindowID else { return }
            if id == 800_001 { unavailable.fulfill() }
            if id == 800_002 { denied.fulfill() }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        for id: CGWindowID in [800_001, 800_002] {
            ReliableWindowPreviewRecovery.schedule(windowID: id, ownerPID: 99, isFullscreen: false,
                exactKey: "failure-\(id)", identityKey: "failure-\(id)", capture: { windowID, completion in
                    lock.lock()
                    attempts[windowID, default: 0] += 1
                    lock.unlock()
                    completion(nil, windowID == 800_002
                        ? NSError(domain: SCStreamErrorDomain, code: SCStreamError.Code.userDeclined.rawValue)
                        : nil)
                }, ownerValidation: { true })
        }
        wait(for: [unavailable, denied], timeout: 6)
        lock.lock()
        let completedAttempts = attempts
        lock.unlock()
        XCTAssertEqual(completedAttempts[800_001], 5)
        XCTAssertEqual(completedAttempts[800_002], 1)
        XCTAssertEqual(ReliableWindowPreviewRecovery.previewState(identityKey: "failure-800001"), .unavailable)
        XCTAssertEqual(ReliableWindowPreviewRecovery.previewState(identityKey: "failure-800002"), .permissionDenied)
        var finishRetry: ((CGImage?, Error?) -> Void)?
        ReliableWindowPreviewRecovery.schedule(windowID: 800_001, ownerPID: 99, isFullscreen: false,
            exactKey: "failure-800001", identityKey: "failure-800001", now: Date().addingTimeInterval(3),
            capture: { _, completion in finishRetry = completion }, ownerValidation: { true })
        XCTAssertNotNil(finishRetry)
        XCTAssertEqual(ReliableWindowPreviewRecovery.previewState(identityKey: "failure-800001"), .unavailable,
                       "Opportunistic retries retain the settled state until a real preview recovers")
        finishRetry?(nil, nil)
    }

    func testSlowBackgroundWindowRecoversWithoutActivationAndKeepsSavedFrameWhileRetrying() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let id: CGWindowID = 810_001
        let identity = SwitcherHistoryIdentity.appWindow(pid: pid, windowID: id)
        let identityKey = SwitcherItem.previewContinuityIdentityKey(historyIdentity: identity, sourceAppIdentifier: nil)
        let saved = NSImage(size: NSSize(width: 120, height: 90))
        let initial = SwitcherItem(title: "Window", subtitle: "", icon: nil, previewImage: saved,
                                  allowsPreviewRecovery: false, previewCacheKey: "slow-window",
                                  historyIdentity: identity, activate: { XCTFail("Capture must not activate the app") })
        let context = try XCTUnwrap(CGContext(data: nil, width: 120, height: 90, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 120, height: 90))
        context.setFillColor(CGColor(red: 0.1, green: 0.5, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 30, y: 20, width: 60, height: 50))
        let frame = try XCTUnwrap(context.makeImage())
        let recovered = expectation(description: "Fourth attempt republishes after slow rendering")
        var finalItem: SwitcherItem?
        let observer = NotificationCenter.default.addObserver(
            forName: ReliableWindowPreviewRecovery.didRecoverPreviewNotification, object: nil, queue: .main
        ) { notification in
            guard notification.userInfo?["windowID"] as? CGWindowID == id else { return }
            finalItem = SwitcherItem(title: "Window", subtitle: "", icon: nil, previewImage: nil,
                allowsPreviewRecovery: false, previewCacheKey: "slow-window", historyIdentity: identity,
                activate: { XCTFail("Publication must not activate the app") })
            recovered.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        let lock = NSLock()
        var attempts = 0
        let start = Date()
        ReliableWindowPreviewRecovery.schedule(windowID: id, ownerPID: pid, isFullscreen: false,
            exactKey: "slow-window", identityKey: identityKey, capture: { _, completion in
                lock.lock()
                attempts += 1
                let currentAttempt = attempts
                lock.unlock()
                if currentAttempt < 4 {
                    let retained = SwitcherItem(title: "Window", subtitle: "", icon: nil, previewImage: nil,
                        allowsPreviewRecovery: false, previewCacheKey: "slow-window", historyIdentity: identity,
                        activate: { XCTFail("Retry must not activate the app") })
                    XCTAssertTrue(retained.previewImage === initial.previewImage)
                    completion(nil, nil)
                } else {
                    XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 1)
                    completion(frame, nil)
                }
            }, ownerValidation: { true })
        wait(for: [recovered], timeout: 5)
        lock.lock()
        let completedAttempts = attempts
        lock.unlock()
        XCTAssertEqual(completedAttempts, 4)
        XCTAssertNotNil(finalItem?.previewImage)
        XCTAssertFalse(finalItem?.previewImage === initial.previewImage)
    }

    func testApplicationFallbackIsNeverAnnouncedAsNormalWindow() {
        let fallback = SwitcherItem(title: "Application", subtitle: "", icon: nil, previewImage: nil,
                                    historyIdentity: .appFallback(bundleID: "test.app", pid: 1),
                                    kind: .appFallback, activate: {})
        XCTAssertEqual(productionAccessibilityState(for: fallback), "Application only")
        let original = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(productionPreviewStateLabel(.cached(capturedAt: original)),
                       "Saved preview, captured " + original.formatted(date: .abbreviated, time: .standard))
    }

    func testTwentyFourAsynchronousRecoveriesPublishBeyondFirstEight() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let bundle = "test.preview.pipeline"
        let ids = (1...24).map { CGWindowID(900_000 + $0) }
        let image = try XCTUnwrap(CGContext(data: nil, width: 120, height: 90, bitsPerComponent: 8,
                                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        image.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        image.fill(CGRect(x: 0, y: 0, width: 120, height: 90))
        image.setFillColor(CGColor(red: 0.1, green: 0.5, blue: 0.9, alpha: 1))
        image.fill(CGRect(x: 30, y: 20, width: 60, height: 50))
        let frame = try XCTUnwrap(image.makeImage())
        let configuration = SwitcherSessionConfiguration(profileID: UUID(), profileName: "All",
            style: .classicGrid, visibilityScope: .allSpaces, includeMinimizedWindows: true,
            displayPlacement: .activeWindowDisplay, appFilter: .all, releaseBehavior: .holdPrimaryModifier)
        let fallback = SwitcherItem(title: "Application", subtitle: "", icon: nil, previewImage: nil,
            historyIdentity: .appFallback(bundleID: bundle, pid: pid), sourceAppIdentifier: bundle,
            kind: .appFallback, activate: {})
        func publishedItems() -> [SwitcherItem] {
            let candidates = ids.map { id in
                SwitcherItem(title: "Window", subtitle: "", icon: nil, previewImage: nil,
                    previewCaptureIsFresh: false, allowsPreviewRecovery: false, previewCacheKey: "key-\(id)",
                    historyIdentity: .appWindow(pid: pid, windowID: id), sourceAppIdentifier: bundle,
                    isMinimized: true, activate: {})
            }
            return ProductionMembershipFinalizer.items(candidates, fallbackItems: [fallback],
                metadataByIdentity: [:], configuration: configuration, globalVisibility: .allSpaces,
                globalIncludesMinimized: true)
        }
        let completed = expectation(description: "All 24 completion notifications republish frames")
        completed.expectedFulfillmentCount = 24
        var finalPublication: [SwitcherItem] = []
        let observer = NotificationCenter.default.addObserver(
            forName: ReliableWindowPreviewRecovery.didRecoverPreviewNotification, object: nil, queue: .main
        ) { notification in
            guard let id = notification.userInfo?["windowID"] as? CGWindowID, ids.contains(id) else { return }
            finalPublication = publishedItems()
            completed.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        for id in ids {
            let identity = SwitcherItem.previewContinuityIdentityKey(
                historyIdentity: .appWindow(pid: pid, windowID: id), sourceAppIdentifier: bundle)
            ReliableWindowPreviewRecovery.schedule(windowID: id, ownerPID: pid, isFullscreen: false,
                exactKey: "key-\(id)", identityKey: identity, capture: { _, completion in
                    DispatchQueue.global().async { completion(frame, nil) }
                }, ownerValidation: { true })
        }
        wait(for: [completed], timeout: 10)
        XCTAssertEqual(finalPublication.count, 24)
        XCTAssertEqual(Set(finalPublication.map(\.id)).count, 24)
        XCTAssertTrue(finalPublication.allSatisfy { $0.previewImage != nil })
        XCTAssertTrue(finalPublication.dropFirst(8).allSatisfy { $0.previewImage != nil })
        XCTAssertFalse(finalPublication.contains { $0.kind == .appFallback })
        SnapshotDiagnosticsTracker.shared.recordPublishedPreviewStates(finalPublication)
        let metrics = SnapshotDiagnosticsTracker.shared.snapshot()
        XCTAssertEqual(metrics.exactWindowsPublished, 24)
        XCTAssertEqual(metrics.previewSaved, 24)
        XCTAssertEqual(metrics.previewUnavailable, 0)
    }
}
