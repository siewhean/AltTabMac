import AppKit
import ScreenCaptureKit
import XCTest
@testable import CmdTab

final class PreviewRecoveryRefreshTests: XCTestCase {
    func testSettledRecoveryMetadataIsBoundedWithoutEvictingActiveRequest() {
        var state = PreviewRecoveryRequestState()
        let start = Date(timeIntervalSince1970: 100)
        XCTAssertTrue(state.begin(identityKey: "active", now: start))
        for index in 0..<(PreviewRecoveryRequestState.maximumSettledEntries + 8) {
            let key = "closed-\(index)"
            let now = start.addingTimeInterval(Double(index))
            XCTAssertTrue(state.begin(identityKey: key, now: now))
            state.finish(identityKey: key, succeeded: false, now: now, retryAllowed: false)
        }
        XCTAssertEqual(state.retainedEntryCount, PreviewRecoveryRequestState.maximumSettledEntries + 1)
        XCTAssertFalse(state.begin(identityKey: "active", now: start.addingTimeInterval(10000)))
    }

    func testNewLifecycleTokenResetsFailureAndStaleCancellationCannotRemoveNewRequest() {
        var state = PreviewRecoveryRequestState()
        let old = UUID(), new = UUID()
        let now = Date(timeIntervalSince1970: 100)
        XCTAssertTrue(state.begin(identityKey: "window", now: now, token: old))
        state.finish(identityKey: "window", succeeded: false, now: now,
                     retryAllowed: false, permissionDenied: true, token: old)
        XCTAssertEqual(state.previewState(identityKey: "window"), .permissionDenied)
        XCTAssertTrue(state.begin(identityKey: "window", now: now, token: new))
        state.cancel(identityKey: "window", token: old)
        XCTAssertEqual(state.retainedEntryCount, 1)
        XCTAssertEqual(state.previewState(identityKey: "window"), .pending)
        state.cancel(identityKey: "window", token: new)
        XCTAssertEqual(state.retainedEntryCount, 0)
    }

    func testRecoveryRejectsRecycledOrUnknownOwnerGeneration() {
        let launch = Date(timeIntervalSince1970: 100)
        XCTAssertTrue(ReliableWindowPreviewRecovery.ownerMatches(expectedLaunchDate: launch, currentLaunchDate: launch))
        XCTAssertFalse(ReliableWindowPreviewRecovery.ownerMatches(expectedLaunchDate: launch,
                                                                  currentLaunchDate: launch.addingTimeInterval(1)))
        XCTAssertFalse(ReliableWindowPreviewRecovery.ownerMatches(expectedLaunchDate: nil, currentLaunchDate: nil))
        XCTAssertFalse(ReliableWindowPreviewRecovery.ownerMatches(expectedLaunchDate: launch, currentLaunchDate: nil))
    }

    func testTransientFailureRetriesAcrossSlowWindowRenderingThenStops() {
        var state = PreviewRecoveryRequestState()
        var now = Date(timeIntervalSince1970: 100)
        for expectedDelay: TimeInterval? in [0.15, 0.35, 1, 2, nil] {
            XCTAssertTrue(state.begin(identityKey: "window", now: now, autonomousRetry: true))
            let delay = state.finish(identityKey: "window", succeeded: false, now: now)
            XCTAssertEqual(delay, expectedDelay)
            XCTAssertFalse(state.begin(identityKey: "window", now: now), "No immediate duplicate retry")
            now = now.addingTimeInterval(delay ?? 2)
        }
        // Automatic attempts cannot turn an exhausted chain into a new burst.
        XCTAssertTrue(state.begin(identityKey: "window", now: now, autonomousRetry: true))
        XCTAssertNil(state.finish(identityKey: "window", succeeded: false, now: now))
        now = now.addingTimeInterval(2)
        XCTAssertTrue(state.begin(identityKey: "window", now: now))
        XCTAssertNil(state.finish(identityKey: "window", succeeded: true, now: now))
        now = now.addingTimeInterval(2)
        XCTAssertTrue(state.begin(identityKey: "window", now: now))
        XCTAssertEqual(state.finish(identityKey: "window", succeeded: false, now: now), 0.15)
    }

    func testIndependentRefreshRestartsBoundedBurstWithoutRepublishingFailure() {
        var state = PreviewRecoveryRequestState()
        var now = Date(timeIntervalSince1970: 100)
        for _ in 0..<5 {
            XCTAssertTrue(state.begin(identityKey: "window", now: now, autonomousRetry: true))
            let delay = state.finish(identityKey: "window", succeeded: false, now: now)
            now = now.addingTimeInterval(delay ?? 2)
        }
        XCTAssertTrue(state.shouldPublishFailure(identityKey: "window"))
        XCTAssertFalse(state.begin(identityKey: "window", now: now.addingTimeInterval(-0.1)))
        for attempt in 0..<5 {
            XCTAssertTrue(state.begin(identityKey: "window", now: now, autonomousRetry: attempt > 0))
            XCTAssertEqual(state.previewState(identityKey: "window"), .unavailable)
            let delay = state.finish(identityKey: "window", succeeded: false, now: now)
            XCTAssertEqual(delay, attempt == 4 ? nil : PreviewRecoveryRequestState.transientRetryDelays[attempt])
            now = now.addingTimeInterval(delay ?? 2)
        }
        XCTAssertFalse(state.shouldPublishFailure(identityKey: "window"),
                       "A repeated unavailable outcome must not trigger another refresh notification")
        XCTAssertTrue(state.begin(identityKey: "denied", now: now))
        XCTAssertNil(state.finish(identityKey: "denied", succeeded: false, now: now, permissionDenied: true))
        now = now.addingTimeInterval(2)
        XCTAssertTrue(state.begin(identityKey: "denied", now: now))
        XCTAssertNil(state.finish(identityKey: "denied", succeeded: false, now: now, permissionDenied: true))
        XCTAssertEqual(state.previewState(identityKey: "denied"), .permissionDenied)
    }

    func testPermissionDenialDoesNotRequestAutonomousCaptureRetry() {
        XCTAssertFalse(ReliableWindowPreviewRecovery.shouldRetryCapture(error: NSError(
            domain: SCStreamErrorDomain, code: SCStreamError.Code.userDeclined.rawValue
        )))
        XCTAssertTrue(ReliableWindowPreviewRecovery.shouldRetryCapture(error: NSError(
            domain: SCStreamErrorDomain, code: SCStreamError.Code.failedToStart.rawValue
        )))
        XCTAssertTrue(ReliableWindowPreviewRecovery.shouldRetryCapture(error: nil),
                      "An unusable or absent frame can recover without another user action")
    }

    func testReusedItemImageDoesNotOverwriteNewerRecoveredFrame() {
        defer { SwitcherPreviewContinuityStore.resetForTesting() }
        let identity = SwitcherHistoryIdentity.appWindow(pid: ProcessInfo.processInfo.processIdentifier, windowID: 0)
        let old = NSImage(size: NSSize(width: 120, height: 90))
        let fresh = NSImage(size: NSSize(width: 120, height: 90))
        _ = SwitcherItem(
            title: "Before", subtitle: "App", icon: nil, previewImage: old,
            previewCacheKey: "before", historyIdentity: identity, activate: {}
        )
        _ = SwitcherItem(
            title: "After", subtitle: "App", icon: nil, previewImage: fresh,
            previewCacheKey: "after", historyIdentity: identity, activate: {}
        )
        // This is the base-cache -> item -> enriched-clone path. Reused
        // non-nil images must remain distinguishable from a new capture.
        let reused = SwitcherItem(
            title: "Before", subtitle: "App", icon: nil, previewImage: old,
            previewCaptureIsFresh: false, allowsPreviewRecovery: false, previewCacheKey: "before",
            historyIdentity: identity, isFullscreen: true, activate: {}
        )
        let clone = SwitcherItem(
            title: reused.title, subtitle: reused.subtitle, icon: nil,
            previewImage: reused.previewImage,
            previewCaptureIsFresh: reused.previewCaptureIsFresh,
            allowsPreviewRecovery: reused.allowsPreviewRecovery,
            previewCacheKey: reused.previewCacheKey, historyIdentity: identity,
            isFullscreen: reused.isFullscreen, activate: {}
        )
        XCTAssertTrue(reused.previewImage === fresh)
        XCTAssertTrue(clone.previewImage === fresh)
        XCTAssertFalse(clone.previewCaptureIsFresh)
        XCTAssertFalse(clone.allowsPreviewRecovery)
        XCTAssertTrue(clone.isFullscreen)
    }

    func testModernCaptureUsesSampleBuffersOnlyForFullscreenWindows() {
        XCTAssertEqual(
            ReliableWindowPreviewRecovery.captureRoute(supportsModernScreenshot: true, isFullscreen: false),
            .screenshot
        )
        XCTAssertEqual(
            ReliableWindowPreviewRecovery.captureRoute(supportsModernScreenshot: true, isFullscreen: true),
            .fullscreenSampleBuffer
        )
        for fullscreen in [false, true] {
            XCTAssertEqual(
                ReliableWindowPreviewRecovery.captureRoute(supportsModernScreenshot: false, isFullscreen: fullscreen),
                .legacyImage
            )
        }
    }

    func testSuccessfulCaptureDeduplicatesNotificationRefreshButAllowsLaterRefresh() {
        var state = PreviewRecoveryRequestState()
        let start = Date(timeIntervalSince1970: 100)
        XCTAssertTrue(state.begin(identityKey: "window-a", now: start))
        XCTAssertFalse(state.begin(identityKey: "window-a", now: start.addingTimeInterval(0.1)))
        XCTAssertTrue(state.begin(identityKey: "window-b", now: start))
        state.finish(identityKey: "window-a", succeeded: true, now: start)
        XCTAssertFalse(state.begin(identityKey: "window-a", now: start.addingTimeInterval(0.1)),
                       "The recovery notification must not immediately start another capture.")
        XCTAssertFalse(state.begin(identityKey: "window-a", now: start.addingTimeInterval(1.9)))
        XCTAssertTrue(state.begin(identityKey: "window-a", now: start.addingTimeInterval(2)))
    }

    func testRepeatedFailuresBackOffAndSuccessResetsFailureCount() {
        var state = PreviewRecoveryRequestState()
        var now = Date(timeIntervalSince1970: 100)
        for attempt in 1...5 {
            XCTAssertTrue(state.begin(identityKey: "window", now: now))
            let retryDelay = state.finish(identityKey: "window", succeeded: false, now: now)
            XCTAssertFalse(state.begin(identityKey: "window", now: now.addingTimeInterval(0.1)))
            if attempt == 3 {
                XCTAssertFalse(state.begin(identityKey: "window", now: now.addingTimeInterval(0.2)))
            }
            now = now.addingTimeInterval(retryDelay ?? 2)
        }
        XCTAssertTrue(state.begin(identityKey: "window", now: now))
        state.finish(identityKey: "window", succeeded: true, now: now)
        now = now.addingTimeInterval(2)
        XCTAssertTrue(state.begin(identityKey: "window", now: now))
        state.finish(identityKey: "window", succeeded: false, now: now)
        XCTAssertTrue(state.begin(identityKey: "window", now: now.addingTimeInterval(0.2)))
    }

    func testCaptureDimensionsPreserveWideAndPortraitAspectRatios() {
        let wide = ReliableWindowPreviewRecovery.captureDimensions(
            for: CGSize(width: 2000, height: 1000), scale: 2
        )
        XCTAssertEqual(wide.width, 1800)
        XCTAssertEqual(wide.height, 900)
        let portrait = ReliableWindowPreviewRecovery.captureDimensions(
            for: CGSize(width: 1000, height: 2000), scale: 2
        )
        XCTAssertEqual(portrait.width, 900)
        XCTAssertEqual(portrait.height, 1800)
        let small = ReliableWindowPreviewRecovery.captureDimensions(
            for: CGSize(width: 400, height: 300), scale: 2
        )
        XCTAssertEqual(small.width, 800)
        XCTAssertEqual(small.height, 600)
    }

    func testNewerIdentityFrameWinsOverStaleExactMetadataFrame() {
        defer { SwitcherPreviewContinuityStore.resetForTesting() }
        let old = NSImage(size: NSSize(width: 120, height: 90))
        let fresh = NSImage(size: NSSize(width: 120, height: 90))
        let start = Date(timeIntervalSince1970: 100)
        _ = SwitcherPreviewContinuityStore.resolve(
            key: "title-before", identityKey: "same-window", preview: old, backdrop: old,
            captureAccessAllowed: true, now: start
        )
        _ = SwitcherPreviewContinuityStore.resolve(
            key: "title-after", identityKey: "same-window", preview: fresh, backdrop: fresh,
            captureAccessAllowed: true, now: start.addingTimeInterval(1)
        )
        let result = SwitcherPreviewContinuityStore.resolve(
            key: "title-before", identityKey: "same-window", preview: nil, backdrop: nil,
            captureAccessAllowed: true, now: start.addingTimeInterval(2)
        )
        XCTAssertTrue(result.preview === fresh)
        XCTAssertNil(result.backdrop, "Continuity retains thumbnails only, not a full-resolution backdrop")
    }
}
