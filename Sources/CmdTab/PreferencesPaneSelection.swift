import Foundation

enum PreferencesPaneSelection: String, CaseIterable, Identifiable {
    case general
    case switcher
    case shortcuts
    case licensing
    case developer
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
        case .developer:
            return "Developer"
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
        case .developer:
            return "hammer"
        case .system:
            return "lock.shield"
        }
    }
}
