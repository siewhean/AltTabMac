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
    let isSkeletonOnly: Bool
    let backdropImage: NSImage?
    let backdropFrame: CGRect?
    let backdropSourceScreenFrame: CGRect?
    let previewCacheKey: String
    let sourceAppIdentifier: String?
    let historyIdentity: SwitcherHistoryIdentity
    let kind: SwitcherItemKind
    let dedupeKey: String
    let activate: () -> Void

    var displayAppName: String {
        let appName = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !appName.isEmpty { return appName }

        let windowTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return windowTitle.isEmpty ? "Application" : windowTitle
    }

    init(
        title: String,
        subtitle: String,
        icon: NSImage?,
        previewImage: NSImage?,
        isSkeletonOnly: Bool = false,
        backdropImage: NSImage? = nil,
        backdropFrame: CGRect? = nil,
        backdropSourceScreenFrame: CGRect? = nil,
        previewCacheKey: String? = nil,
        historyIdentity: SwitcherHistoryIdentity,
        sourceAppIdentifier: String? = nil,
        kind: SwitcherItemKind = .appWindow,
        dedupeKey: String? = nil,
        activate: @escaping () -> Void
    ) {
        let resolvedDedupeKey = dedupeKey ?? historyIdentity.stableKey
        self.id = resolvedDedupeKey
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.previewImage = previewImage
        self.isSkeletonOnly = isSkeletonOnly
        self.backdropImage = backdropImage
        self.backdropFrame = backdropFrame
        self.backdropSourceScreenFrame = backdropSourceScreenFrame
        self.previewCacheKey = previewCacheKey ?? historyIdentity.stableKey
        self.sourceAppIdentifier = sourceAppIdentifier
        self.historyIdentity = historyIdentity
        self.kind = kind
        self.dedupeKey = resolvedDedupeKey
        self.activate = activate
    }
}
