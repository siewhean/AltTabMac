import AppKit
import CoreGraphics

// MARK: - Mode

enum SwitcherMode: String {
    case app

    var title: String {
        return "Applications"
    }

    var systemImage: String {
        return "square.stack.3d.up.fill"
    }
}

enum SwitcherItemKind: String {
    case appWindow
    case appFallback
}

/// Debounces transient false Screen Recording preflight results.
///
/// TCC state can briefly lag a successful or recently revoked capture. A single
/// false sample must not erase every last-known-good Arc or Telegram thumbnail,
/// but a sustained denial must clear previews promptly. A cached preview is never
/// evidence that TCC remains granted: it may be the very content that must be
/// removed after revocation. Only a current preflight grant resets the denial
/// window. New capture work is blocked as soon as preflight denies access; the
/// one-second window applies solely to rendering already-cached continuity.
enum SwitcherPreviewPermissionState {
    private static let lock = NSLock()
    private static var denialBeganAt: Date?
    private static let denialConfirmationInterval: TimeInterval = 1.0

    static func effectiveAccess(
        hasCurrentCapture: Bool,
        preflightGranted: Bool,
        now: Date = Date()
    ) -> Bool {
        _ = hasCurrentCapture
        lock.lock()
        defer { lock.unlock() }

        if preflightGranted {
            denialBeganAt = nil
            return true
        }

        guard let denialBeganAt else {
            self.denialBeganAt = now
            return true
        }
        return now.timeIntervalSince(denialBeganAt) < denialConfirmationInterval
    }

    /// Current TCC denial must stop fresh capture immediately. This intentionally
    /// differs from `effectiveAccess`, which allows a short continuity-only grace
    /// period for a single stale preflight sample.
    static func allowsNewCapture(preflightGranted: Bool) -> Bool {
        preflightGranted
    }

    static func noteSuccessfulCapture() {
        lock.lock()
        denialBeganAt = nil
        lock.unlock()
    }

    static func resetForTesting() {
        lock.lock()
        denialBeganAt = nil
        lock.unlock()
    }
}

/// In-memory continuity for a real window's last known good preview.
///
/// GPU-backed applications such as Arc and Telegram can intermittently return no
/// capture even though the exact same window produced a valid image moments
/// earlier. Exact preview metadata may also change with a tab title or a tiny frame
/// adjustment, so a process-generation-scoped identity record bridges those misses
/// without borrowing from another exact window. The cache is bounded, never written
/// to disk, and is cleared for the affected identity when Screen Recording denial is
/// stable rather than on one transient preflight sample.
enum SwitcherPreviewContinuityStore {
    struct ResolvedImages {
        let preview: NSImage?
        let backdrop: NSImage?
    }

    private struct Entry {
        let preview: NSImage?
        let backdrop: NSImage?
        let capturedAt: Date
    }

    private static let lock = NSLock()
    private static var entriesByExactKey: [String: Entry] = [:]
    private static var entriesByIdentity: [String: Entry] = [:]
    private static let exactKeyMaximumAge: TimeInterval = 120
    private static let identityMaximumAge: TimeInterval = 600
    private static let maximumEntries = 512

    static func resolve(
        key: String,
        identityKey: String,
        preview: NSImage?,
        backdrop: NSImage?,
        captureAccessAllowed: Bool,
        now: Date = Date()
    ) -> ResolvedImages {
        lock.lock()
        defer { lock.unlock() }

        let exactIdentityKey = scopedExactKey(
            exactKey: key,
            identityKey: identityKey
        )

        guard captureAccessAllowed else {
            removeExactEntry(forKey: exactIdentityKey)
            entriesByIdentity.removeValue(forKey: identityKey)
            return ResolvedImages(preview: nil, backdrop: nil)
        }

        pruneLocked(now: now)
        if preview != nil || backdrop != nil {
            let entry = Entry(
                preview: preview,
                backdrop: backdrop,
                capturedAt: now
            )
            entriesByExactKey[exactIdentityKey] = entry
            entriesByIdentity[identityKey] = entry
            trimLocked()
            return ResolvedImages(preview: preview, backdrop: backdrop)
        }

        if let exact = entriesByExactKey[exactIdentityKey],
           now.timeIntervalSince(exact.capturedAt) <= exactKeyMaximumAge {
            return ResolvedImages(
                preview: exact.preview,
                backdrop: exact.backdrop
            )
        }

        if let identity = entriesByIdentity[identityKey],
           now.timeIntervalSince(identity.capturedAt) <= identityMaximumAge {
            return ResolvedImages(
                preview: identity.preview,
                backdrop: identity.backdrop
            )
        }

        return ResolvedImages(preview: nil, backdrop: nil)
    }

    static func resetForTesting() {
        clearProtectedContent()
        SwitcherPreviewPermissionState.resetForTesting()
    }

    /// Removes every protected image, including entries for windows that are not
    /// in the current switcher snapshot. A confirmed Screen Recording revocation
    /// must not leave a title/frame variant or deferred recovery result visible.
    static func clearProtectedContent() {
        lock.lock()
        entriesByExactKey.removeAll()
        entriesByIdentity.removeAll()
        lock.unlock()
        ReliableWindowPreviewRecovery.cancelAll()
    }

    private static func scopedExactKey(
        exactKey: String,
        identityKey: String
    ) -> String {
        "\(identityKey)||\(exactKey)"
    }

    private static func removeExactEntry(forKey key: String) {
        entriesByExactKey.removeValue(forKey: key)
    }

    private static func pruneLocked(now: Date) {
        entriesByExactKey = entriesByExactKey.filter {
            now.timeIntervalSince($0.value.capturedAt) <= exactKeyMaximumAge
        }
        entriesByIdentity = entriesByIdentity.filter {
            now.timeIntervalSince($0.value.capturedAt) <= identityMaximumAge
        }
    }

    private static func trimLocked() {
        trimLocked(&entriesByExactKey)
        trimLocked(&entriesByIdentity)
    }

    private static func trimLocked(_ values: inout [String: Entry]) {
        guard values.count > maximumEntries else { return }
        let overflow = values.count - maximumEntries
        for key in values
            .sorted(by: { $0.value.capturedAt < $1.value.capturedAt })
            .prefix(overflow)
            .map(\.key) {
            values.removeValue(forKey: key)
        }
    }
}

// MARK: - Item

struct SwitcherItem: Identifiable {
    private static let previewIdentityLock = NSLock()
    // A first lookup can occur while LaunchServices has not yet supplied a launch
    // date. Keep that process-generation token sticky: changing it later would
    // turn one window into a different continuity identity and discard its cache.
    private static var previewProcessGenerationTokens: [pid_t: String] = [:]
    let id: String
    let title: String
    let subtitle: String
    let icon: NSImage?
    let previewImage: NSImage?
    let backdropImage: NSImage?
    let backdropFrame: CGRect?
    let backdropSourceScreenFrame: CGRect?
    let previewCacheKey: String
    let sourceAppIdentifier: String?
    let historyIdentity: SwitcherHistoryIdentity
    let kind: SwitcherItemKind
    let dedupeKey: String
    let isMinimized: Bool
    let isFullscreen: Bool
    let workspaceSnapshot: WindowWorkspaceSnapshot?
    let historyDescriptor: LiveWindowHistoryDescriptor?
    let activate: () -> Void

    var ownerPID: pid_t? { historyIdentity.ownerPID }
    var windowID: CGWindowID? { historyIdentity.windowID }

    init(
        title: String,
        subtitle: String,
        icon: NSImage?,
        previewImage: NSImage?,
        backdropImage: NSImage? = nil,
        backdropFrame: CGRect? = nil,
        backdropSourceScreenFrame: CGRect? = nil,
        previewCacheKey: String? = nil,
        historyIdentity: SwitcherHistoryIdentity,
        sourceAppIdentifier: String? = nil,
        kind: SwitcherItemKind = .appWindow,
        dedupeKey: String? = nil,
        isMinimized: Bool = false,
        isFullscreen: Bool = false,
        workspaceSnapshot: WindowWorkspaceSnapshot? = nil,
        historyDescriptor: LiveWindowHistoryDescriptor? = nil,
        activate: @escaping () -> Void
    ) {
        let resolvedDedupeKey = dedupeKey ?? historyIdentity.stableKey
        let resolvedPreviewKey = previewCacheKey ?? historyIdentity.stableKey
        let resolvedImages: SwitcherPreviewContinuityStore.ResolvedImages
        var recoveryIdentityKey: String?
        var effectiveCaptureAccess = true

        if previewCacheKey != nil, kind == .appWindow {
            let hasCurrentCapture = previewImage != nil || backdropImage != nil
            let preflightGranted: Bool
            if #available(macOS 10.15, *) {
                preflightGranted = CGPreflightScreenCaptureAccess()
            } else {
                preflightGranted = true
            }
            effectiveCaptureAccess = SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: hasCurrentCapture,
                preflightGranted: preflightGranted
            )
            let identityPreviewKey = Self.previewContinuityIdentityKey(
                historyIdentity: historyIdentity,
                sourceAppIdentifier: sourceAppIdentifier
            )
            recoveryIdentityKey = identityPreviewKey
            resolvedImages = SwitcherPreviewContinuityStore.resolve(
                key: resolvedPreviewKey,
                identityKey: identityPreviewKey,
                preview: previewImage,
                backdrop: backdropImage,
                captureAccessAllowed: effectiveCaptureAccess
            )
        } else {
            resolvedImages = .init(
                preview: previewImage,
                backdrop: backdropImage
            )
        }

        self.id = resolvedDedupeKey
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.previewImage = resolvedImages.preview
        self.backdropImage = resolvedImages.backdrop
        self.backdropFrame = backdropFrame
        self.backdropSourceScreenFrame = backdropSourceScreenFrame
        self.previewCacheKey = resolvedPreviewKey
        self.sourceAppIdentifier = sourceAppIdentifier
        self.historyIdentity = historyIdentity
        self.kind = kind
        self.dedupeKey = resolvedDedupeKey
        self.isMinimized = isMinimized
        self.isFullscreen = isFullscreen
        self.workspaceSnapshot = workspaceSnapshot
        self.historyDescriptor = historyDescriptor
        self.activate = activate

        if previewImage == nil,
           backdropImage == nil,
           resolvedImages.preview != nil || resolvedImages.backdrop != nil {
            RuntimeDiagnostics.shared.increment(.previewFallbackPresentation)
        }

        if resolvedImages.preview == nil,
           resolvedImages.backdrop == nil,
           effectiveCaptureAccess,
           let recoveryIdentityKey,
           let windowID = historyIdentity.windowID {
            ReliableWindowPreviewRecovery.schedule(
                windowID: windowID,
                exactKey: resolvedPreviewKey,
                identityKey: recoveryIdentityKey
            )
        }
    }

    static func previewContinuityIdentityKey(
        historyIdentity: SwitcherHistoryIdentity,
        sourceAppIdentifier: String?,
        processLaunchDate: Date? = nil
    ) -> String {
        let resolvedLaunchDate = processLaunchDate ?? historyIdentity.ownerPID.flatMap {
            NSRunningApplication(processIdentifier: $0)?.launchDate
        }
        let launchToken = processGenerationToken(
            ownerPID: historyIdentity.ownerPID,
            launchDate: resolvedLaunchDate
        )
        return [
            historyIdentity.stableKey,
            sourceAppIdentifier?.lowercased() ?? "",
            launchToken,
        ].joined(separator: "|")
    }

    static func resetPreviewContinuityIdentityForTesting() {
        previewIdentityLock.lock()
        previewProcessGenerationTokens.removeAll()
        previewIdentityLock.unlock()
    }

    private static func processGenerationToken(
        ownerPID: pid_t?,
        launchDate: Date?
    ) -> String {
        guard let ownerPID else { return "unknown-launch" }

        previewIdentityLock.lock()
        defer { previewIdentityLock.unlock() }
        if let existing = previewProcessGenerationTokens[ownerPID] {
            if existing != "unknown-launch",
               let launchDate {
                let currentToken = String(
                    Int64((launchDate.timeIntervalSince1970 * 1_000).rounded())
                )
                if currentToken != existing {
                    previewProcessGenerationTokens[ownerPID] = currentToken
                    return currentToken
                }
            }
            return existing
        }
        let token: String
        if let launchDate {
            token = String(Int64((launchDate.timeIntervalSince1970 * 1_000).rounded()))
        } else {
            token = "unknown-launch"
        }
        previewProcessGenerationTokens[ownerPID] = token
        return token
    }
}
