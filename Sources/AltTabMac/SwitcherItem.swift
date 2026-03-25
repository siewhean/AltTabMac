import AppKit

// MARK: - Mode

enum SwitcherMode: String {
    case app
    case tab

    var title: String {
        switch self {
        case .app: return "Applications"
        case .tab: return "Browser Tabs"
        }
    }

    var systemImage: String {
        switch self {
        case .app: return "square.stack.3d.up.fill"
        case .tab: return "globe"
        }
    }
}

enum SwitcherItemKind: String {
    case appWindow
    case appFallback
    case browserTab
}

// MARK: - Item

struct SwitcherItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: NSImage?
    let previewImage: NSImage?
    let sourceAppIdentifier: String?
    let historyIdentity: SwitcherHistoryIdentity
    let kind: SwitcherItemKind
    let dedupeKey: String
    let activate: () -> Void

    init(
        title: String,
        subtitle: String,
        icon: NSImage?,
        previewImage: NSImage?,
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
        self.sourceAppIdentifier = sourceAppIdentifier
        self.historyIdentity = historyIdentity
        self.kind = kind
        self.dedupeKey = resolvedDedupeKey
        self.activate = activate
    }
}
