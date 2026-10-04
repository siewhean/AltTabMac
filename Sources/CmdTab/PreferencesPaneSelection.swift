import Foundation

enum PreferencesPaneSelection: String, CaseIterable, Identifiable {
    case appearance
    case windows
    case shortcuts
    case general
    case licensing
    #if DEBUG
    case developer
    #endif

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance:
            return "Appearance"
        case .windows:
            return "Windows"
        case .shortcuts:
            return "Shortcuts"
        case .general:
            return "General"
        case .licensing:
            return "License"
        #if DEBUG
        case .developer:
            return "Developer"
        #endif
        }
    }

    var systemImage: String {
        switch self {
        case .appearance:
            return "paintbrush"
        case .windows:
            return "square.grid.2x2"
        case .shortcuts:
            return "command"
        case .general:
            return "gearshape"
        case .licensing:
            return "lock.open.display"
        #if DEBUG
        case .developer:
            return "hammer"
        #endif
        }
    }
}
