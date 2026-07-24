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
    private static let failureBackoff: TimeInterval = 2.0
    private static let maximumDimension = 1_800

    static func schedule(
        windowID: CGWindowID,
        exactKey: String,
        identityKey: String,
        now: Date = Date()
    ) {
        guard windowID != 0 else { return }

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
        stateLock.unlock()

        guard #available(macOS 14.0, *) else {
            finish(
                image: nil,
                exactKey: exactKey,
                identityKey: identityKey,
                windowID: windowID
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
                    windowID: windowID
                )
                return
            }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let configuration = SCStreamConfiguration()
            configuration.width = max(
                80,
                min(maximumDimension, Int(window.frame.width.rounded(.up)))
            )
            configuration.height = max(
                60,
                min(maximumDimension, Int(window.frame.height.rounded(.up)))
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
                    windowID: windowID
                )
            }
        }
    }

    static func resetForTesting() {
        stateLock.lock()
        inFlightIdentityKeys.removeAll()
        retryAfterByIdentityKey.removeAll()
        stateLock.unlock()
    }

    private static func finish(
        image: CGImage?,
        exactKey: String,
        identityKey: String,
        windowID: CGWindowID
    ) {
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
        inFlightIdentityKeys.remove(identityKey)
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

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: didRecoverPreviewNotification,
                object: nil,
                userInfo: ["windowID": windowID]
            )
        }
    }

    private static func usableImage(_ image: CGImage) -> CGImage? {
        guard image.width >= 40, image.height >= 30,
              let provider = image.dataProvider,
              let data = provider.data else {
            return nil
        }

        let bytesPerPixel = image.bitsPerPixel / 8
        guard bytesPerPixel >= 4 else { return image }
        let pointer = CFDataGetBytePtr(data)!
        let length = CFDataGetLength(data)
        let bytesPerRow = image.bytesPerRow
        var visibleSamples = 0

        for row in 1...3 {
            for column in 1...3 {
                let x = min(image.width - 1, column * image.width / 4)
                let y = min(image.height - 1, row * image.height / 4)
                let base = y * bytesPerRow + x * bytesPerPixel
                let alphaIndex: Int
                switch image.alphaInfo {
                case .premultipliedFirst, .first, .noneSkipFirst:
                    alphaIndex = base
                default:
                    alphaIndex = base + bytesPerPixel - 1
                }
                if alphaIndex >= 0,
                   alphaIndex < length,
                   pointer[alphaIndex] > 10 {
                    visibleSamples += 1
                }
            }
        }

        return visibleSamples >= 2 ? image : nil
    }
}
