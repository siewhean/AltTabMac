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
    private static let failureBackoff: TimeInterval = 2.0
    private static let maximumDimension = 1_800

    static func schedule(
        windowID: CGWindowID,
        exactKey: String,
        identityKey: String,
        now: Date = Date()
    ) {
        guard windowID != 0 else { return }
        let preflightGranted: Bool
        if #available(macOS 10.15, *) {
            preflightGranted = CGPreflightScreenCaptureAccess()
        } else {
            preflightGranted = true
        }
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

        guard #available(macOS 14.0, *) else {
            finish(
                image: nil,
                exactKey: exactKey,
                identityKey: identityKey,
                windowID: windowID,
                scheduledGeneration: scheduledGeneration
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
                    scheduledGeneration: scheduledGeneration
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
                    scheduledGeneration: scheduledGeneration
                )
            }
        }
    }

    static func resetForTesting() {
        cancelAll()
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
        scheduledGeneration: UInt
    ) {
        let preflightGranted: Bool
        if #available(macOS 10.15, *) {
            preflightGranted = CGPreflightScreenCaptureAccess()
        } else {
            preflightGranted = true
        }
        stateLock.lock()
        let isCurrentGeneration = scheduledGeneration == generation
        inFlightIdentityKeys.remove(identityKey)
        stateLock.unlock()

        guard isCurrentGeneration,
              SwitcherPreviewPermissionState.allowsNewCapture(
                preflightGranted: preflightGranted
              ) else {
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
}
