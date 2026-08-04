import AppKit
import CoreGraphics
@preconcurrency import ScreenCaptureKit
import os.log

private let previewRecoveryLog = OSLog(
    subsystem: "CmdTab",
    category: "PreviewRecovery"
)

/// Asynchronous last-resort capture for windows whose SkyLight and Core Graphics
/// captures both fail transiently. ScreenCaptureKit is particularly useful for
/// GPU-backed apps such as Arc and Telegram.
///
/// Recovery never blocks the event tap or the main thread. Requests are deduped by
/// exact process/window identity, failures are rate-limited, and successful images
/// are kept only in the bounded in-memory continuity store.
enum ReliableWindowPreviewRecovery {
    static let didRecoverPreviewNotification = Notification.Name(
        "CmdTab.ReliableWindowPreviewRecovery.didRecover"
    )

    private static let stateLock = NSLock()
    private static var inFlightIdentityKeys = Set<String>()
    private static var retryAfterByIdentityKey: [String: Date] = [:]
    private static var generation: UInt = 0
    private static var preflightGrantedOverrideForTesting: Bool?
    private static var captureResultForTesting: (@Sendable (Int) -> CGImage?)?
    private static let failureBackoff: TimeInterval = 2.0
    private static let immediateRetryDelays: [TimeInterval] = [0.12, 0.45]
    private static let maximumDimension = 1_800

    static func schedule(
        windowID: CGWindowID,
        exactKey: String,
        identityKey: String,
        now: Date = Date()
    ) {
        guard windowID != 0 else { return }
        let preflightGranted = currentPreflightGranted()
        guard SwitcherPreviewPermissionState.allowsNewCapture(
            preflightGranted: preflightGranted
        ) else { return }

        stateLock.lock()
        if inFlightIdentityKeys.contains(identityKey) {
            stateLock.unlock()
            return
        }
        if let retryAfter = retryAfterByIdentityKey[identityKey], retryAfter > now {
            stateLock.unlock()
            return
        }
        inFlightIdentityKeys.insert(identityKey)
        let scheduledGeneration = generation
        stateLock.unlock()
        RuntimeDiagnostics.shared.increment(.previewRecoveryScheduled)

        capture(
            windowID: windowID,
            exactKey: exactKey,
            identityKey: identityKey,
            scheduledGeneration: scheduledGeneration,
            attempt: 0
        )
    }

    static func immediateRetryDelay(afterFailedAttempt attempt: Int) -> TimeInterval? {
        guard immediateRetryDelays.indices.contains(attempt) else { return nil }
        return immediateRetryDelays[attempt]
    }

    private static func capture(
        windowID: CGWindowID,
        exactKey: String,
        identityKey: String,
        scheduledGeneration: UInt,
        attempt: Int
    ) {
        stateLock.lock()
        let isCurrentRequest = scheduledGeneration == generation
            && inFlightIdentityKeys.contains(identityKey)
        let testCaptureResult = captureResultForTesting
        stateLock.unlock()
        guard isCurrentRequest else { return }

        let preflightGranted = currentPreflightGranted()
        guard SwitcherPreviewPermissionState.allowsNewCapture(
            preflightGranted: preflightGranted
        ) else {
            finish(
                image: nil,
                exactKey: exactKey,
                identityKey: identityKey,
                windowID: windowID,
                scheduledGeneration: scheduledGeneration,
                attempt: attempt
            )
            return
        }

        if let testCaptureResult {
            finish(
                image: testCaptureResult(attempt),
                exactKey: exactKey,
                identityKey: identityKey,
                windowID: windowID,
                scheduledGeneration: scheduledGeneration,
                attempt: attempt
            )
            return
        }

        guard #available(macOS 14.0, *) else {
            finish(
                image: nil,
                exactKey: exactKey,
                identityKey: identityKey,
                windowID: windowID,
                scheduledGeneration: scheduledGeneration,
                attempt: attempt
            )
            return
        }

        SCShareableContent.getExcludingDesktopWindows(
            true,
            onScreenWindowsOnly: false
        ) { content, _ in
            guard let window = content?.windows.first(where: {
                $0.windowID == windowID
            }) else {
                finish(
                    image: nil,
                    exactKey: exactKey,
                    identityKey: identityKey,
                    windowID: windowID,
                    scheduledGeneration: scheduledGeneration,
                    attempt: attempt
                )
                return
            }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let configuration = SCStreamConfiguration()
            let scale = max(1, CGFloat(filter.pointPixelScale))
            configuration.width = max(
                80,
                min(
                    maximumDimension,
                    Int((window.frame.width * scale).rounded(.up))
                )
            )
            configuration.height = max(
                60,
                min(
                    maximumDimension,
                    Int((window.frame.height * scale).rounded(.up))
                )
            )
            configuration.showsCursor = false

            SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            ) { image, _ in
                finish(
                    image: image.flatMap { usableImage($0) },
                    exactKey: exactKey,
                    identityKey: identityKey,
                    windowID: windowID,
                    scheduledGeneration: scheduledGeneration,
                    attempt: attempt
                )
            }
        }
    }

    static func resetForTesting() {
        cancelAll()
        stateLock.lock()
        preflightGrantedOverrideForTesting = nil
        captureResultForTesting = nil
        stateLock.unlock()
    }

    static func configureForTesting(
        preflightGranted: Bool,
        captureResult: @escaping @Sendable (Int) -> CGImage?
    ) {
        stateLock.lock()
        preflightGrantedOverrideForTesting = preflightGranted
        captureResultForTesting = captureResult
        stateLock.unlock()
    }

    /// Invalidates deferred captures that were requested before TCC revocation.
    /// ScreenCaptureKit callbacks cannot be synchronously cancelled, so generation
    /// fencing prevents a late callback from repopulating cleared continuity.
    static func cancelAll() {
        stateLock.lock()
        inFlightIdentityKeys.removeAll()
        retryAfterByIdentityKey.removeAll()
        generation &+= 1
        stateLock.unlock()
    }

    private static func finish(
        image: CGImage?,
        exactKey: String,
        identityKey: String,
        windowID: CGWindowID,
        scheduledGeneration: UInt,
        attempt: Int
    ) {
        let preflightGranted = currentPreflightGranted()
        stateLock.lock()
        let isCurrentGeneration = scheduledGeneration == generation
        let retryDelay = image == nil && preflightGranted && isCurrentGeneration
            ? immediateRetryDelay(afterFailedAttempt: attempt)
            : nil
        // A callback from a request cancelled by a newer generation must never
        // clear that newer request's in-flight marker for the same identity.
        // Otherwise the next snapshot can start a duplicate ScreenCaptureKit
        // capture while the newer request is still active.
        if retryDelay == nil, isCurrentGeneration {
            inFlightIdentityKeys.remove(identityKey)
        }
        stateLock.unlock()

        guard isCurrentGeneration,
              SwitcherPreviewPermissionState.allowsNewCapture(
                preflightGranted: preflightGranted
              ) else {
            return
        }

        if let retryDelay {
            RuntimeDiagnostics.shared.increment(.previewRecoveryRetry)
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + retryDelay) {
                capture(
                    windowID: windowID,
                    exactKey: exactKey,
                    identityKey: identityKey,
                    scheduledGeneration: scheduledGeneration,
                    attempt: attempt + 1
                )
            }
            return
        }

        if let image {
            RuntimeDiagnostics.shared.increment(.previewRecoverySuccess)
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
                captureAccessAllowed: true
            )
        }

        stateLock.lock()
        if image == nil {
            retryAfterByIdentityKey[identityKey] = Date().addingTimeInterval(
                failureBackoff
            )
        } else {
            retryAfterByIdentityKey.removeValue(forKey: identityKey)
        }
        stateLock.unlock()

        guard image != nil else {
            RuntimeDiagnostics.shared.increment(.previewCaptureFailure)
            os_log(
                .debug,
                log: previewRecoveryLog,
                "Deferred preview recovery did not produce a frame for window %{public}u",
                windowID
            )
            return
        }

        os_log(
            .info,
            log: previewRecoveryLog,
            "Recovered exact-window preview for window %{public}u",
            windowID
        )
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: didRecoverPreviewNotification,
                object: nil,
                userInfo: ["windowID": windowID]
            )
        }
    }

    private static func usableImage(_ image: CGImage) -> CGImage? {
        guard image.width >= 40, image.height >= 30 else { return nil }
        let prepared = AppSwitcher.presentationPreparedWindowCapture(image)
        guard AppSwitcher.isPresentationUsefulWindowCapture(prepared) else {
            return nil
        }
        return prepared
    }

    private static func currentPreflightGranted() -> Bool {
        stateLock.lock()
        let override = preflightGrantedOverrideForTesting
        stateLock.unlock()
        if let override { return override }
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }
}
