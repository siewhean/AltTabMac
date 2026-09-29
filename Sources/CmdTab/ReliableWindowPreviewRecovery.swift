import AppKit
import CoreGraphics
import VideoToolbox
@preconcurrency import ScreenCaptureKit
import os.log

private let previewRecoveryLog = OSLog(
    subsystem: "CmdTab",
    category: "PreviewRecovery"
)

/// Request admission is shared by initial captures and refreshes of cached frames.
/// A successful recovery also needs a cooldown: its notification rebuilds items.
struct PreviewRecoveryRequestState {
    private struct Entry {
        var token: UUID?
        var inFlight = false
        var retryAfter = Date.distantPast
        var attempts = 0
        var outcome: SwitcherPreviewState = .pending
        var publishedFailure: SwitcherPreviewState?
        var touched = Date.distantPast
    }
    private var entries: [String: Entry] = [:]
    // Give newly created and GPU-backed windows time to publish a drawable
    // without requiring application activation. The chain remains bounded.
    static let transientRetryDelays: [TimeInterval] = [0.15, 0.35, 1, 2]
    static let maximumSettledEntries = 4096
    var retainedEntryCount: Int { entries.count }

    func previewState(identityKey: String) -> SwitcherPreviewState {
        guard let entry = entries[identityKey] else { return .pending }
        return entry.outcome == .pending ? (entry.publishedFailure ?? .pending) : entry.outcome
    }

    mutating func begin(identityKey: String, now: Date, token: UUID? = nil, autonomousRetry: Bool = false) -> Bool {
        var entry = entries[identityKey] ?? Entry(token: token)
        if entry.token != token { entry = Entry(token: token) }
        guard !entry.inFlight, entry.retryAfter <= now else { return false }
        // A later independent refresh deserves a new bounded burst. Scheduled
        // retries must keep their counter, and denial still needs permission
        // reconciliation. Keep the published failure stable until real recovery.
        if !autonomousRetry, entry.outcome == .unavailable { entry.attempts = 0 }
        entry.inFlight = true
        entry.outcome = .pending
        entry.touched = now
        entries[identityKey] = entry
        trimSettled()
        return true
    }

    mutating func cancel(identityKey: String, token: UUID) {
        guard entries[identityKey]?.token == token else { return }
        entries.removeValue(forKey: identityKey)
    }

    mutating func shouldPublishFailure(identityKey: String) -> Bool {
        guard var entry = entries[identityKey], entry.outcome != .pending,
              entry.publishedFailure != entry.outcome else { return false }
        entry.publishedFailure = entry.outcome
        entries[identityKey] = entry
        return true
    }

    @discardableResult
    mutating func finish(identityKey: String, succeeded: Bool, now: Date, retryAllowed: Bool = true,
                         permissionDenied: Bool = false, token: UUID? = nil) -> TimeInterval? {
        guard var entry = entries[identityKey], entry.token == token else { return nil }
        entry.inFlight = false
        entry.touched = now
        let delay: TimeInterval?
        if succeeded {
            entry.attempts = 0
            entry.publishedFailure = nil
            entry.outcome = .unavailable // The recovered frame supplies live/cached state.
            delay = nil
        } else {
            entry.attempts = min(entry.attempts + 1, Self.transientRetryDelays.count + 1)
            let willRetry = retryAllowed && !permissionDenied && entry.attempts <= Self.transientRetryDelays.count
            entry.outcome = permissionDenied ? .permissionDenied : (willRetry ? .pending : .unavailable)
            delay = willRetry ? Self.transientRetryDelays[entry.attempts - 1] : nil
        }
        entry.retryAfter = now.addingTimeInterval(delay ?? 2)
        entries[identityKey] = entry
        trimSettled()
        return delay
    }

    private mutating func trimSettled() {
        guard entries.count > Self.maximumSettledEntries else { return }
        // Active SDK requests and scheduled retries retain admission state.
        let settled = entries.filter { !$0.value.inFlight && $0.value.outcome != .pending }
        let overflow = settled.count - Self.maximumSettledEntries
        guard overflow > 0 else { return }
        for entry in settled.sorted(by: { $0.value.touched < $1.value.touched }).prefix(overflow) {
            entries.removeValue(forKey: entry.key)
        }
    }
}

/// Asynchronous last-resort capture for windows whose SkyLight and Core Graphics
/// captures both fail transiently. ScreenCaptureKit is particularly useful for
/// GPU-backed apps such as Arc and Telegram.
///
/// Recovery never blocks the event tap or the main thread. Requests are deduped by
/// exact process/window identity, failures are rate-limited, and successful images
/// are kept only in the bounded in-memory continuity store.
enum ReliableWindowPreviewRecovery {
    enum CaptureRoute: Equatable {
        case legacyImage
        case screenshot
        case fullscreenSampleBuffer
    }

    static func captureRoute(supportsModernScreenshot: Bool, isFullscreen: Bool) -> CaptureRoute {
        guard supportsModernScreenshot else { return .legacyImage }
        return isFullscreen ? .fullscreenSampleBuffer : .screenshot
    }

    static let didRecoverPreviewNotification = Notification.Name(
        "CmdTab.ReliableWindowPreviewRecovery.didRecover"
    )

    private static let stateLock = NSLock()
    private static var requestState = PreviewRecoveryRequestState()
    private static let maximumDimension = 1_800

    static func previewState(identityKey: String) -> SwitcherPreviewState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return requestState.previewState(identityKey: identityKey)
    }

    static func schedule(
        windowID: CGWindowID,
        ownerPID: pid_t,
        isFullscreen: Bool,
        exactKey: String,
        identityKey: String,
        now: Date = Date(),
        captureToken: UUID? = nil,
        capture: ((CGWindowID, @escaping (CGImage?, Error?) -> Void) -> Void)? = nil,
        ownerValidation: (() -> Bool)? = nil,
        autonomousRetry: Bool = false
    ) {
        guard windowID != 0 else { return }
        let continuityToken = captureToken ?? SwitcherPreviewContinuityStore.captureToken(identityKey: identityKey)
        guard SwitcherPreviewContinuityStore.isCurrentCapture(identityKey: identityKey, token: continuityToken) else { return }

        stateLock.lock()
        let admitted = requestState.begin(identityKey: identityKey, now: now, token: continuityToken, autonomousRetry: autonomousRetry)
        stateLock.unlock()
        guard admitted else { return }

        let ownerLaunchDate = NSRunningApplication(processIdentifier: ownerPID)?.launchDate
        let ownerIsCurrent = {
            guard SwitcherPreviewContinuityStore.isCurrentCapture(identityKey: identityKey, token: continuityToken) else { return false }
            if let ownerValidation { return ownerValidation() }
            guard let app = NSRunningApplication(processIdentifier: ownerPID), !app.isTerminated else { return false }
            return ownerMatches(expectedLaunchDate: ownerLaunchDate, currentLaunchDate: app.launchDate)
        }
        let retry = {
            guard ownerIsCurrent() else {
                stateLock.lock()
                requestState.cancel(identityKey: identityKey, token: continuityToken)
                stateLock.unlock()
                return
            }
            schedule(windowID: windowID, ownerPID: ownerPID, isFullscreen: isFullscreen,
                     exactKey: exactKey, identityKey: identityKey, captureToken: continuityToken, capture: capture, ownerValidation: ownerValidation, autonomousRetry: true)
        }

        // Injectable transport exercises the same admission, owner validation,
        // cache write, bounded retry and publication notification as the SDK.
        if let capture {
            capture(windowID) { image, error in
                let prepared = ownerIsCurrent() ? image.flatMap { usableImage($0) } : nil
                finish(image: prepared, exactKey: exactKey, identityKey: identityKey,
                       windowID: windowID, captureToken: continuityToken,
                       retry: ownerIsCurrent() && shouldRetryCapture(error: error) ? retry : nil,
                       permissionDenied: !shouldRetryCapture(error: error))
            }
            return
        }

        guard #available(macOS 14.0, *) else {
            finish(
                image: nil,
                exactKey: exactKey,
                identityKey: identityKey,
                windowID: windowID,
                captureToken: continuityToken
            )
            return
        }

        SCShareableContent.getExcludingDesktopWindows(
            true,
            onScreenWindowsOnly: false
        ) { content, error in
            logCaptureError(error, stage: "shareable-content", windowID: windowID)
            guard ownerIsCurrent(), let window = content?.windows.first(where: {
                $0.windowID == windowID && $0.owningApplication?.processID == ownerPID
            }) else {
                if error == nil {
                    os_log(.info, log: previewRecoveryLog,
                           "Preview recovery exact window %{public}u is absent from shareable content", windowID)
                }
                finish(
                    image: nil,
                    exactKey: exactKey,
                    identityKey: identityKey,
                    windowID: windowID,
                    captureToken: continuityToken,
                    retry: ownerIsCurrent() && shouldRetryCapture(error: error) ? retry : nil,
                    permissionDenied: !shouldRetryCapture(error: error)
                )
                return
            }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let configuration = SCStreamConfiguration()
            let scale = max(1, CGFloat(filter.pointPixelScale))
            let dimensions = captureDimensions(for: window.frame.size, scale: scale)
            configuration.width = dimensions.width
            configuration.height = dimensions.height
            configuration.showsCursor = false

            let completion: (CGImage?, Error?) -> Void = { image, error in
                logCaptureError(error, stage: "screenshot", windowID: windowID)
                let prepared = ownerIsCurrent() ? image.flatMap { usableImage($0) } : nil
                if error == nil, prepared == nil {
                    os_log(.info, log: previewRecoveryLog,
                           "Preview recovery window %{public}u returned %{public}@", windowID,
                           image == nil ? "no image" : "an unusable image")
                }
                finish(
                    image: prepared,
                    exactKey: exactKey,
                    identityKey: identityKey,
                    windowID: windowID,
                    captureToken: continuityToken,
                    retry: ownerIsCurrent() && shouldRetryCapture(error: error) ? retry : nil,
                    permissionDenied: !shouldRetryCapture(error: error)
                )
            }

            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                switch captureRoute(supportsModernScreenshot: true, isFullscreen: isFullscreen) {
                case .screenshot:
                    let screenshot = SCScreenshotConfiguration()
                    screenshot.width = dimensions.width
                    screenshot.height = dimensions.height
                    screenshot.showsCursor = false
                    screenshot.dynamicRange = .sdr
                    // Leave fileURL unset: thumbnails remain in memory only.
                    SCScreenshotManager.captureScreenshot(
                        contentFilter: filter, configuration: screenshot
                    ) { output, error in
                        completion(output?.sdrImage, error)
                    }
                case .fullscreenSampleBuffer:
                    // The screenshot API can reject fullscreen windows on an
                    // inactive Space. Limit the sample-buffer route to these
                    // windows rather than creating a stream for every tile.
                    SCScreenshotManager.captureSampleBuffer(
                        contentFilter: filter, configuration: configuration
                    ) { sampleBuffer, error in
                        var image: CGImage?
                        if let sampleBuffer,
                           let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                            VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image)
                        }
                        completion(image, error)
                    }
                case .legacyImage:
                    SCScreenshotManager.captureImage(
                        contentFilter: filter, configuration: configuration,
                        completionHandler: completion
                    )
                }
                return
            }
            #endif
            SCScreenshotManager.captureImage(
                contentFilter: filter, configuration: configuration,
                completionHandler: completion
            )
        }
    }

    static func resetForTesting() {
        stateLock.lock()
        requestState = PreviewRecoveryRequestState()
        stateLock.unlock()
    }

    static func captureDimensions(for size: CGSize, scale: CGFloat) -> (width: Int, height: Int) {
        let width = max(1, size.width * scale)
        let height = max(1, size.height * scale)
        let ratio = min(1, CGFloat(maximumDimension) / max(width, height))
        return (max(1, Int((width * ratio).rounded())), max(1, Int((height * ratio).rounded())))
    }

    static func shouldRetryCapture(error: Error?) -> Bool {
        guard let error = error as NSError? else { return true }
        // A denial needs permission reconciliation, not repeated capture calls.
        return !(error.domain == SCStreamErrorDomain && error.code == SCStreamError.Code.userDeclined.rawValue)
    }

    static func ownerMatches(expectedLaunchDate: Date?, currentLaunchDate: Date?) -> Bool {
        // Without a process generation we cannot safely retry a captured PID:
        // it could have been recycled while the asynchronous request was pending.
        guard let expectedLaunchDate, let currentLaunchDate else { return false }
        return expectedLaunchDate == currentLaunchDate
    }

    private static func finish(
        image: CGImage?,
        exactKey: String,
        identityKey: String,
        windowID: CGWindowID,
        captureToken: UUID,
        retry: (() -> Void)? = nil,
        permissionDenied: Bool = false
    ) {
        guard SwitcherPreviewContinuityStore.isCurrentCapture(identityKey: identityKey, token: captureToken) else {
            stateLock.lock()
            requestState.cancel(identityKey: identityKey, token: captureToken)
            stateLock.unlock()
            return
        }
        if let image {
            SwitcherPreviewPermissionState.noteSuccessfulCapture()
            let preview = NSImage(
                cgImage: image,
                size: NSSize(
                    width: CGFloat(image.width),
                    height: CGFloat(image.height)
                )
            )
            _ = SwitcherPreviewContinuityStore.resolve(
                key: exactKey,
                identityKey: identityKey,
                preview: preview,
                backdrop: preview,
                captureAccessAllowed: true,
                captureToken: captureToken
            )
        }

        stateLock.lock()
        let retryDelay = requestState.finish(identityKey: identityKey, succeeded: image != nil, now: Date(),
                                            retryAllowed: retry != nil, permissionDenied: permissionDenied, token: captureToken)
        let publishFailure = image == nil && retryDelay == nil && requestState.shouldPublishFailure(identityKey: identityKey)
        stateLock.unlock()

        if let retryDelay, let retry {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + retryDelay, execute: retry)
        }

        if image == nil {
            os_log(
                .debug,
                log: previewRecoveryLog,
                "Deferred preview recovery did not produce a frame for window %{public}u",
                windowID
            )
            if !publishFailure { return }
        }

        if image != nil {
            os_log(.info, log: previewRecoveryLog,
                   "Recovered exact-window preview for window %{public}u", windowID)
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: didRecoverPreviewNotification,
                object: nil,
                userInfo: ["windowID": windowID]
            )
        }
    }

    private static func logCaptureError(_ error: Error?, stage: String, windowID: CGWindowID) {
        guard let error = error as NSError? else { return }
        // Domain/code identify permission and capture failures without logging
        // localized descriptions, userInfo, titles, or document paths.
        os_log(
            .error, log: previewRecoveryLog,
            "Preview recovery %{public}@ failed for window %{public}u: domain=%{public}@ code=%{public}ld",
            stage, windowID, error.domain, error.code
        )
    }

    private static func usableImage(_ image: CGImage) -> CGImage? {
        guard image.width >= 40, image.height >= 30 else { return nil }
        let prepared = AppSwitcher.presentationPreparedWindowCapture(image)
        guard AppSwitcher.isPresentationUsefulWindowCapture(prepared) else {
            return nil
        }
        return prepared
    }
}
