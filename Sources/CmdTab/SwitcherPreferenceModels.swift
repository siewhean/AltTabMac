import Foundation

enum WindowVisibilityScope: String, CaseIterable {
    case currentSpaceOnly = "currentSpaceOnly"
    case visibleSpaces = "visibleSpaces"
    case allSpaces = "allSpaces"

    var title: String {
        switch self {
        case .currentSpaceOnly:
            return "Current Space"
        case .visibleSpaces:
            return "Visible Spaces"
        case .allSpaces:
            return "All Spaces"
        }
    }

    var subtitle: String {
        switch self {
        case .currentSpaceOnly:
            return "Limit the list to the screen and space you are actively using."
        case .visibleSpaces:
            return "Show windows that are currently visible across your displays."
        case .allSpaces:
            return "Include hidden, minimized, and off-space windows when available."
        }
    }
}

enum SwitcherDisplayPreference: String, CaseIterable {
    case activeWindowDisplay = "activeWindowDisplay"
    case cursorDisplay = "cursorDisplay"
    case allDisplays = "allDisplays"

    var title: String {
        switch self {
        case .activeWindowDisplay:
            return "Active Window Display"
        case .cursorDisplay:
            return "Cursor Display"
        case .allDisplays:
            return "All Displays"
        }
    }

    var subtitle: String {
        switch self {
        case .activeWindowDisplay:
            return "Open over the display that already has your current window."
        case .cursorDisplay:
            return "Open on the display under the mouse cursor."
        case .allDisplays:
            return "Mirror the switcher to every display while keeping one active panel."
        }
    }
}

enum SwitcherQuickAction: String, CaseIterable {
    case hideApp = "hideApp"
    case minimizeWindow = "minimizeWindow"
    case closeWindow = "closeWindow"
    case quitApp = "quitApp"

    var title: String {
        switch self {
        case .hideApp:
            return "Hide App"
        case .minimizeWindow:
            return "Minimize Window"
        case .closeWindow:
            return "Close Window"
        case .quitApp:
            return "Quit App"
        }
    }

    var shortcut: String {
        switch self {
        case .hideApp:
            return "⌘ H"
        case .minimizeWindow:
            return "⌘ M"
        case .closeWindow:
            return "⌘ W"
        case .quitApp:
            return "⌘ Q"
        }
    }

    var subtitle: String {
        switch self {
        case .hideApp:
            return "Hide the selected app without leaving the switcher."
        case .minimizeWindow:
            return "Minimize the selected window if macOS exposes it."
        case .closeWindow:
            return "Close the selected window directly from the switcher."
        case .quitApp:
            return "Quit the selected app without switching into it first."
        }
    }
}

enum WindowExclusionRules {
    static func normalizedEntries(from rawValue: String) -> [String] {
        var seen = Set<String>()

        return rawValue
            .split { $0 == "," || $0 == "\n" || $0 == "\t" || $0 == ";" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    static func matchesApp(identifier: String, appName: String, entries: [String]) -> Bool {
        guard !entries.isEmpty else { return false }

        let normalizedIdentifier = identifier.lowercased()
        let normalizedAppName = normalizeLooseText(appName)
        let identifierTail = normalizedIdentifier.split(separator: ".").last.map(String.init) ?? normalizedIdentifier

        return entries.contains { entry in
            entry == normalizedIdentifier ||
            entry == identifierTail ||
            normalizeLooseText(entry) == normalizedAppName
        }
    }

    static func matchesWindowTitle(_ title: String, entries: [String]) -> Bool {
        guard !entries.isEmpty else { return false }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        let normalizedTitle = normalizeLooseText(title)
        return entries.contains { normalizedTitle.contains(normalizeLooseText($0)) }
    }

    private static func normalizeLooseText(_ text: String) -> String {
        let lowered = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(scalars)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
