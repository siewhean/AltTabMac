import AppKit

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
/// earlier. The window-specific preview key includes its exact identity and
/// presentation metadata, so a transient miss can safely reuse the prior local
/// image without borrowing from another window. The cache is bounded and never
/// written to disk.
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
    private static var entries: [String: Entry] = [:]
    private static let maximumAge: TimeInterval = 120
    private static let maximumEntries = 512

    static func resolve(
        key: String,
        preview: NSImage?,
        backdrop: NSImage?,
        now: Date = Date()
    ) -> ResolvedImages {
        lock.lock()
        defer { lock.unlock() }

        pruneLocked(now: now)
        if preview != nil || backdrop != nil {
            entries[key] = Entry(
                preview: preview,
                backdrop: backdrop,
                capturedAt: now
            )
            trimLocked()
            return ResolvedImages(preview: preview, backdrop: backdrop)
        }

        guard let entry = entries[key],
              now.timeIntervalSince(entry.capturedAt) <= maximumAge else {
            return ResolvedImages(preview: nil, backdrop: nil)
        }
        return ResolvedImages(
            preview: entry.preview,
            backdrop: entry.backdrop
        )
    }

    static func resetForTesting() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }

    private static func pruneLocked(now: Date) {
        entries = entries.filter {
            now.timeIntervalSince($0.value.capturedAt) <= maximumAge
        }
    }

    private static func trimLocked() {
        guard entries.count > maximumEntries else { return }
        let overflow = entries.count - maximumEntries
        for key in entries
            .sorted(by: { $0.value.capturedAt < $1.value.capturedAt })
            .prefix(overflow)
            .map(\.key) {
            entries.removeValue(forKey: key)
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
            resolvedImages = SwitcherPreviewContinuityStore.resolve(
                key: resolvedPreviewKey,
                preview: previewImage,
                backdrop: backdropImage
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
