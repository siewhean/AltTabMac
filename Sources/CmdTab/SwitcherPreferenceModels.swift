import Foundation

enum WindowVisibilityScope: String, CaseIterable, Codable, Sendable {
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
            return "Limit the list to the managed space you are actively using when exact workspace information is available."
        case .visibleSpaces:
            return "Show windows that are currently visible across your displays."
        case .allSpaces:
            return "Include hidden and off-space windows when macOS exposes them."
        }
    }
}

enum SwitcherDisplayPreference: String, CaseIterable, Codable, Sendable {
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

enum AlternateTriggerMode: String, CaseIterable, Codable, Sendable {
    case disabled = "disabled"
    case rightCommandTap = "rightCommandTap"
    case rightCommandDoubleTap = "rightCommandDoubleTap"
    case rightOptionTap = "rightOptionTap"
    case rightOptionDoubleTap = "rightOptionDoubleTap"
    case leftCommandDoubleTap = "leftCommandDoubleTap"
    case leftOptionDoubleTap = "leftOptionDoubleTap"

    var title: String {
        switch self {
        case .disabled:
            return "Standard Only"
        case .rightCommandTap:
            return "Right Command Tap"
        case .rightCommandDoubleTap:
            return "Hot Swap: Right ⌘ ×2"
        case .rightOptionTap:
            return "Right Option Tap"
        case .rightOptionDoubleTap:
            return "Hot Swap: Right ⌘ + Right ⌥"
        case .leftCommandDoubleTap:
            return "Hot Swap: Left ⌘ ×2"
        case .leftOptionDoubleTap:
            return "Hot Swap: Left ⌘ + Left ⌥"
        }
    }

    var subtitle: String {
        switch self {
        case .disabled:
            return "Keep CmdTab on the standard Cmd+Tab and Option+Tab triggers only."
        case .rightCommandTap:
            return "Tap the right Command key once to open a standalone CmdTab session."
        case .rightCommandDoubleTap:
            return "Quickly press the right Command key twice to switch immediately to the most recent item without opening the switcher."
        case .rightOptionTap:
            return "Tap the right Option key once to open a standalone CmdTab session."
        case .rightOptionDoubleTap:
            return "Press the right Command and right Option keys together to switch immediately to the most recent item without opening the switcher."
        case .leftCommandDoubleTap:
            return "Quickly press the left Command key twice to switch immediately to the most recent item without opening the switcher."
        case .leftOptionDoubleTap:
            return "Press the left Command and left Option keys together to switch immediately to the most recent item without opening the switcher."
        }
    }

    var shortcutLabel: String {
        switch self {
        case .disabled:
            return "Off"
        case .rightCommandTap:
            return "Right ⌘"
        case .rightCommandDoubleTap:
            return "Right ⌘ ×2"
        case .rightOptionTap:
            return "Right ⌥"
        case .rightOptionDoubleTap:
            return "Right ⌘ + Right ⌥"
        case .leftCommandDoubleTap:
            return "Left ⌘ ×2"
        case .leftOptionDoubleTap:
            return "Left ⌘ + Left ⌥"
        }
    }

    var usesDoubleTap: Bool {
        switch self {
        case .rightCommandDoubleTap, .leftCommandDoubleTap:
            return true
        case .disabled, .rightCommandTap, .rightOptionTap, .rightOptionDoubleTap, .leftOptionDoubleTap:
            return false
        }
    }
}

enum SwitcherQuickAction: String, CaseIterable, Codable, Sendable {
    case hideApp = "hideApp"
    case minimizeWindow = "minimizeWindow"
    case closeWindow = "closeWindow"
    case quitApp = "quitApp"

    static func action(
        forKeyCode keyCode: Int64,
        keyEquivalent: String? = nil,
        commandHeld: Bool,
        acceptsBareShortcut: Bool
    ) -> SwitcherQuickAction? {
        guard commandHeld || acceptsBareShortcut else { return nil }

        if let keyEquivalent,
           let action = action(forKeyEquivalent: keyEquivalent) {
            return action
        }

        switch keyCode {
        case 4:
            return .hideApp
        case 12:
            return .quitApp
        case 13:
            return .closeWindow
        case 46:
            return .minimizeWindow
        default:
            return nil
        }
    }

    static func action(forKeyEquivalent keyEquivalent: String) -> SwitcherQuickAction? {
        guard let scalar = keyEquivalent
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .first else {
            return nil
        }

        switch scalar {
        case "h":
            return .hideApp
        case "m":
            return .minimizeWindow
        case "w":
            return .closeWindow
        case "q":
            return .quitApp
        default:
            return nil
        }
    }

    func execution(for itemKind: SwitcherItemKind) -> SwitcherQuickActionExecution {
        switch self {
        case .hideApp:
            return .hideApp
        case .minimizeWindow:
            return .minimizeWindow
        case .closeWindow:
            return .closeWindow
        case .quitApp:
            return .terminateApplication
        }
    }

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
            return "Quit the application that owns the selected tile."
        }
    }
}

enum SwitcherQuickActionExecution: Equatable, Sendable {
    case hideApp
    case minimizeWindow
    case closeWindow
    case terminateApplication

    var removesSelectedItem: Bool {
        switch self {
        case .closeWindow, .terminateApplication:
            return true
        case .hideApp, .minimizeWindow:
            return false
        }
    }

    func suppressionTarget(for item: SwitcherItem) -> SwitcherItemSuppressionTarget? {
        switch self {
        case .closeWindow:
            return .item(id: item.id)
        case .terminateApplication:
            return .application(
                pid: item.historyIdentity.ownerPID,
                sourceAppIdentifier: item.sourceAppIdentifier
            )
        case .hideApp, .minimizeWindow:
            return nil
        }
    }
}

enum SwitcherItemSuppressionTarget: Equatable {
    case item(id: String)
    case application(pid: pid_t?, sourceAppIdentifier: String?)

    func matches(_ item: SwitcherItem) -> Bool {
        switch self {
        case let .item(id):
            return item.id == id
        case let .application(pid, sourceAppIdentifier):
            if let pid, item.historyIdentity.ownerPID == pid {
                return true
            }
            if let sourceAppIdentifier, let itemSourceAppIdentifier = item.sourceAppIdentifier {
                return sourceAppIdentifier.caseInsensitiveCompare(itemSourceAppIdentifier) == .orderedSame
            }
            return false
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
