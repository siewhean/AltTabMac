import Foundation

enum PreferencesPaneSelection: String, CaseIterable, Identifiable {
    case general
    case switcher
    case shortcuts
    case licensing
#if DEBUG
    case developer
#endif
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .switcher:
            return "Switcher"
        case .shortcuts:
            return "Shortcuts"
        case .licensing:
            return "Licensing"
#if DEBUG
        case .developer:
            return "Developer"
#endif
        case .system:
            return "System"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "slider.horizontal.3"
        case .switcher:
            return "square.grid.2x2"
        case .shortcuts:
            return "command"
        case .licensing:
            return "lock.open.display"
#if DEBUG
        case .developer:
            return "hammer"
#endif
        case .system:
            return "lock.shield"
        }
    }
}
