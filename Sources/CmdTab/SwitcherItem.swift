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

/// In-memory continuity for a real window's last known good preview.
///
/// GPU-backed applications such as Arc and Telegram can intermittently return no
/// capture even though the exact same window produced a valid image moments
/// earlier. Exact preview metadata may also change with a tab title or a tiny frame
/// adjustment, so a second short-lived identity record bridges those misses without
/// borrowing from another exact window. The cache is bounded, never written to disk,
/// and is cleared for the affected identity when Screen Recording is unavailable.
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
    private static let identityMaximumAge: TimeInterval = 15
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

        guard captureAccessAllowed else {
            entriesByExactKey.removeValue(forKey: key)
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
            entriesByExactKey[key] = entry
            entriesByIdentity[identityKey] = entry
            trimLocked()
            return ResolvedImages(preview: preview, backdrop: backdrop)
        }

        if let exact = entriesByExactKey[key],
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
        lock.lock()
        entriesByExactKey.removeAll()
        entriesByIdentity.removeAll()
        lock.unlock()
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
        if previewCacheKey != nil, kind == .appWindow {
            let captureAccessAllowed: Bool
            if #available(macOS 10.15, *) {
                captureAccessAllowed = CGPreflightScreenCaptureAccess()
            } else {
                captureAccessAllowed = true
            }
            let identityPreviewKey = [
                historyIdentity.stableKey,
                sourceAppIdentifier?.lowercased() ?? "",
            ].joined(separator: "|")
            resolvedImages = SwitcherPreviewContinuityStore.resolve(
                key: resolvedPreviewKey,
                identityKey: identityPreviewKey,
                preview: previewImage,
                backdrop: backdropImage,
                captureAccessAllowed: captureAccessAllowed
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
    }
}
