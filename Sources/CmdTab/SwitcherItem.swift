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
        self.id = resolvedDedupeKey
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.previewImage = previewImage
        self.backdropImage = backdropImage
        self.backdropFrame = backdropFrame
        self.backdropSourceScreenFrame = backdropSourceScreenFrame
        self.previewCacheKey = previewCacheKey ?? historyIdentity.stableKey
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
