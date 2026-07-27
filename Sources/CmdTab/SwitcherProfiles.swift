import AppKit
import CoreGraphics
import Foundation

struct ShortcutModifierMask: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt64

    static let command = ShortcutModifierMask(rawValue: 1 << 0)
    static let option = ShortcutModifierMask(rawValue: 1 << 1)
    static let control = ShortcutModifierMask(rawValue: 1 << 2)
    static let shift = ShortcutModifierMask(rawValue: 1 << 3)

    init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    init(eventFlags: CGEventFlags) {
        var value: ShortcutModifierMask = []
        if eventFlags.contains(.maskCommand) { value.insert(.command) }
        if eventFlags.contains(.maskAlternate) { value.insert(.option) }
        if eventFlags.contains(.maskControl) { value.insert(.control) }
        if eventFlags.contains(.maskShift) { value.insert(.shift) }
        self = value
    }

    init(eventFlags: NSEvent.ModifierFlags) {
        var value: ShortcutModifierMask = []
        if eventFlags.contains(.command) { value.insert(.command) }
        if eventFlags.contains(.option) { value.insert(.option) }
        if eventFlags.contains(.control) { value.insert(.control) }
        if eventFlags.contains(.shift) { value.insert(.shift) }
        self = value
    }

    var primaryReleaseModifier: HotkeyModifier? {
        if contains(.command) { return .command }
        if contains(.option) { return .option }
        return nil
    }

    var displayLabel: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }
}

struct RecordedShortcut: Codable, Equatable, Hashable, Sendable {
    let keyCode: Int64
    let modifiers: ShortcutModifierMask
    let keyLabel: String

    init(keyCode: Int64, modifiers: ShortcutModifierMask, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = String(keyLabel.prefix(24))
    }

    static let commandTab = RecordedShortcut(
        keyCode: 48,
        modifiers: [.command],
        keyLabel: "Tab"
    )

    static let optionTab = RecordedShortcut(
        keyCode: 48,
        modifiers: [.option],
        keyLabel: "Tab"
    )

    var displayLabel: String {
        modifiers.displayLabel + keyLabel
    }

    func matches(keyCode: Int64, flags: CGEventFlags) -> Bool {
        self.keyCode == keyCode && ShortcutModifierMask(eventFlags: flags) == modifiers
    }

    func matches(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        self.keyCode == Int64(keyCode) && ShortcutModifierMask(eventFlags: flags) == modifiers
    }
}

enum SwitcherReleaseBehavior: String, Codable, CaseIterable, Sendable {
    case holdPrimaryModifier
    case pressToToggle

    var title: String {
        switch self {
        case .holdPrimaryModifier: return "Hold Modifier, Release to Select"
        case .pressToToggle: return "Press to Open, Return to Select"
        }
    }
}

enum ProfileFilterMode: String, Codable, CaseIterable, Sendable {
    case allApplications
    case includeOnly
    case exclude
}

struct SwitcherProfileAppFilter: Codable, Equatable, Hashable, Sendable {
    var mode: ProfileFilterMode
    var bundleIdentifiers: [String]

    static let all = SwitcherProfileAppFilter(
        mode: .allApplications,
        bundleIdentifiers: []
    )

    func includes(bundleIdentifier: String) -> Bool {
        let normalized = bundleIdentifier.lowercased()
        let entries = Set(bundleIdentifiers.map { $0.lowercased() })
        switch mode {
        case .allApplications:
            return true
        case .includeOnly:
            return entries.contains(normalized)
        case .exclude:
            return !entries.contains(normalized)
        }
    }

    mutating func normalize() {
        var seen = Set<String>()
        bundleIdentifiers = bundleIdentifiers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .sorted()
        if mode == .allApplications {
            bundleIdentifiers = []
        }
    }
}

struct SwitcherShortcutProfile: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var isEnabled: Bool
    var forwardShortcut: RecordedShortcut
    var reverseShortcut: RecordedShortcut?
    var releaseBehavior: SwitcherReleaseBehavior
    var inheritsGlobalSettings: Bool
    var style: SwitcherStyle
    var visibilityScope: WindowVisibilityScope
    var includeMinimizedWindows: Bool
    var displayPlacement: SwitcherDisplayPreference
    var appFilter: SwitcherProfileAppFilter

    mutating func normalize() {
        name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(48))
        if name.isEmpty { name = "Switcher" }
        appFilter.normalize()
    }
}

struct SwitcherSessionConfiguration: Equatable, Sendable {
    let profileID: UUID
    let profileName: String
    let style: SwitcherStyle
    let visibilityScope: WindowVisibilityScope
    let includeMinimizedWindows: Bool
    let displayPlacement: SwitcherDisplayPreference
    let appFilter: SwitcherProfileAppFilter
    let releaseBehavior: SwitcherReleaseBehavior

    func includes(bundleIdentifier: String) -> Bool {
        appFilter.includes(bundleIdentifier: bundleIdentifier)
    }
}

struct ShortcutProfileMatch: Equatable, Sendable {
    let profileID: UUID
    let reverse: Bool
    let releaseBehavior: SwitcherReleaseBehavior
    let primaryModifier: HotkeyModifier?
}

enum SwitcherProfileValidationIssue: Error, Equatable, CustomStringConvertible, LocalizedError {
    case noProfiles
    case noEnabledProfiles
    case duplicateProfileID(UUID)
    case emptyName(UUID)
    case invalidShortcut(profileID: UUID, message: String)
    case invalidFilter(profileID: UUID, message: String)
    case duplicateShortcut(profileID: UUID, conflictingProfileID: UUID, shortcut: String)
    case unsupportedSchema(Int)

    var description: String {
        switch self {
        case .noProfiles:
            return "At least one shortcut profile is required."
        case .noEnabledProfiles:
            return "At least one shortcut profile must remain enabled."
        case let .duplicateProfileID(id):
            return "The profile identifier \(id) is duplicated."
        case let .emptyName(id):
            return "Profile \(id) has no name."
        case let .invalidShortcut(_, message), let .invalidFilter(_, message):
            return message
        case let .duplicateShortcut(_, _, shortcut):
            return "The shortcut \(shortcut) is assigned to more than one profile."
        case let .unsupportedSchema(version):
            return "Profile document schema \(version) is not supported by this CmdTab version."
        }
    }

    var errorDescription: String? { description }
}

struct SwitcherProfileDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    var profiles: [SwitcherShortcutProfile]

    init(profiles: [SwitcherShortcutProfile]) {
        schemaVersion = Self.currentSchemaVersion
        self.profiles = profiles
    }
}

enum SwitcherProfileValidator {
    static func issues(in profiles: [SwitcherShortcutProfile]) -> [SwitcherProfileValidationIssue] {
        guard !profiles.isEmpty else { return [.noProfiles] }
        var issues: [SwitcherProfileValidationIssue] = []
        var seenIDs = Set<UUID>()
        var assigned: [RecordedShortcut: UUID] = [:]
        var enabledCount = 0

        for profile in profiles {
            if !seenIDs.insert(profile.id).inserted {
                issues.append(.duplicateProfileID(profile.id))
            }
            if profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.emptyName(profile.id))
            }
            guard profile.isEnabled else { continue }
            enabledCount += 1

            if profile.appFilter.mode == .includeOnly,
               profile.appFilter.bundleIdentifiers.isEmpty {
                issues.append(
                    .invalidFilter(
                        profileID: profile.id,
                        message: "An enabled Include Only profile must contain at least one bundle identifier."
                    )
                )
            }

            let shortcuts = [profile.forwardShortcut, profile.reverseShortcut].compactMap { $0 }
            for shortcut in shortcuts {
                if let problem = invalidReason(for: shortcut) {
                    issues.append(
                        .invalidShortcut(profileID: profile.id, message: problem)
                    )
                }
                if profile.releaseBehavior == .holdPrimaryModifier,
                   shortcut.modifiers.primaryReleaseModifier == nil {
                    issues.append(
                        .invalidShortcut(
                            profileID: profile.id,
                            message: "Hold-to-release profiles require Command or Option in every assigned shortcut."
                        )
                    )
                }
                if let existing = assigned[shortcut], existing != profile.id {
                    issues.append(
                        .duplicateShortcut(
                            profileID: profile.id,
                            conflictingProfileID: existing,
                            shortcut: shortcut.displayLabel
                        )
                    )
                } else {
                    assigned[shortcut] = profile.id
                }
            }
            if profile.reverseShortcut == profile.forwardShortcut {
                issues.append(
                    .invalidShortcut(
                        profileID: profile.id,
                        message: "Forward and reverse shortcuts must differ."
                    )
                )
            }
        }

        if enabledCount == 0 {
            issues.append(.noEnabledProfiles)
        }
        return issues
    }

    static func invalidReason(for shortcut: RecordedShortcut) -> String? {
        guard (0...127).contains(shortcut.keyCode) else {
            return "Shortcut key code \(shortcut.keyCode) is outside the supported keyboard range."
        }
        guard shortcut.keyCode != 53 else {
            return "Escape is reserved for cancelling a switcher session."
        }
        guard shortcut.keyCode != 36 && shortcut.keyCode != 76 else {
            return "Return and Enter are reserved for committing a switcher session."
        }
        if shortcut.modifiers.isEmpty && !isFunctionKeyCode(shortcut.keyCode) {
            return "Global character shortcuts require Command, Option, Control, or Shift."
        }

        let commandOnly = shortcut.modifiers == [.command]
        let protectedCommandKeyCodes: Set<Int64> = [4, 12, 13, 43, 46, 49]
        if commandOnly, protectedCommandKeyCodes.contains(shortcut.keyCode) {
            return "That shortcut is reserved for a standard macOS application or system command."
        }
        return nil
    }

    private static func isFunctionKeyCode(_ keyCode: Int64) -> Bool {
        let functionKeyCodes: Set<Int64> = [
            122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
            105, 107, 113, 106, 64, 79, 80, 90,
        ]
        return functionKeyCodes.contains(keyCode)
    }
}

final class SwitcherProfileStore: ObservableObject {
    static let shared = SwitcherProfileStore()
    static let didChangeNotification = Notification.Name("SwitcherProfileStore.didChange")

    private let defaults: UserDefaults
    private let storageKey = "switcherProfiles.document.v1"
    private let snapshotLock = NSLock()
    private var snapshotProfiles: [SwitcherShortcutProfile] = []

    @Published private(set) var profiles: [SwitcherShortcutProfile]
    @Published private(set) var validationIssues: [SwitcherProfileValidationIssue] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loaded = Self.load(defaults: defaults, key: storageKey)
        profiles = loaded ?? Self.defaultProfiles(preferences: SwitcherPreferences.shared)
        normalizeValidateAndPublish(persist: loaded == nil)
    }

    func profilesSnapshot() -> [SwitcherShortcutProfile] {
        snapshotLock.lock()
        let value = snapshotProfiles
        snapshotLock.unlock()
        return value
    }

    func profile(id: UUID) -> SwitcherShortcutProfile? {
        profilesSnapshot().first { $0.id == id }
    }

    func configuration(
        for profileID: UUID,
        preferences: SwitcherPreferences = .shared
    ) -> SwitcherSessionConfiguration? {
        guard let profile = profile(id: profileID), profile.isEnabled else { return nil }
        let proposed = SwitcherSessionConfiguration(
            profileID: profile.id,
            profileName: profile.name,
            style: profile.inheritsGlobalSettings ? preferences.switcherStyle : profile.style,
            visibilityScope: profile.inheritsGlobalSettings
                ? preferences.windowVisibilityScope
                : profile.visibilityScope,
            includeMinimizedWindows: profile.inheritsGlobalSettings
                ? preferences.includeMinimizedWindows
                : profile.includeMinimizedWindows,
            displayPlacement: profile.inheritsGlobalSettings
                ? preferences.displayPlacement
                : profile.displayPlacement,
            appFilter: profile.appFilter,
            releaseBehavior: profile.releaseBehavior
        )
        return SwitcherSessionConfigurationFreeze.shared.resolve(
            profileID: profileID,
            proposed: proposed
        )
    }

    func match(keyCode: Int64, flags: CGEventFlags) -> ShortcutProfileMatch? {
        for profile in profilesSnapshot() where profile.isEnabled {
            if profile.forwardShortcut.matches(keyCode: keyCode, flags: flags) {
                return ShortcutProfileMatch(
                    profileID: profile.id,
                    reverse: false,
                    releaseBehavior: profile.releaseBehavior,
                    primaryModifier: profile.forwardShortcut.modifiers.primaryReleaseModifier
                )
            }
            if let reverse = profile.reverseShortcut,
               reverse.matches(keyCode: keyCode, flags: flags) {
                return ShortcutProfileMatch(
                    profileID: profile.id,
                    reverse: true,
                    releaseBehavior: profile.releaseBehavior,
                    primaryModifier: reverse.modifiers.primaryReleaseModifier
                )
            }
        }
        return nil
    }

    @discardableResult
    func update(_ profile: SwitcherShortcutProfile) -> Bool {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            return false
        }
        var normalized = profile
        normalized.normalize()
        var candidate = profiles
        candidate[index] = normalized
        let issues = SwitcherProfileValidator.issues(in: candidate)
        guard issues.isEmpty else {
            validationIssues = issues
            return false
        }
        profiles = candidate
        normalizeValidateAndPublish(persist: true)
        return true
    }

    @discardableResult
    func add(_ profile: SwitcherShortcutProfile) -> Bool {
        var normalized = profile
        normalized.normalize()
        let candidate = profiles + [normalized]
        let issues = SwitcherProfileValidator.issues(in: candidate)
        guard issues.isEmpty else {
            validationIssues = issues
            return false
        }
        profiles = candidate
        normalizeValidateAndPublish(persist: true)
        return true
    }

    @discardableResult
    func duplicate(profileID: UUID) -> SwitcherShortcutProfile? {
        guard var copy = profiles.first(where: { $0.id == profileID }) else { return nil }
        copy.id = UUID()
        copy.name = "\(copy.name) Copy"
        copy.isEnabled = false
        profiles.append(copy)
        normalizeValidateAndPublish(persist: true)
        return copy
    }

    @discardableResult
    func remove(profileID: UUID) -> Bool {
        guard profiles.count > 1 else {
            validationIssues = [.noProfiles]
            return false
        }
        let candidate = profiles.filter { $0.id != profileID }
        guard candidate.count != profiles.count else { return false }
        let issues = SwitcherProfileValidator.issues(in: candidate)
        guard issues.isEmpty else {
            validationIssues = issues
            return false
        }
        profiles = candidate
        normalizeValidateAndPublish(persist: true)
        return true
    }

    func resetToDefaults(preferences: SwitcherPreferences = .shared) {
        profiles = Self.defaultProfiles(preferences: preferences)
        normalizeValidateAndPublish(persist: true)
    }

    func exportDocument() throws -> Data {
        let document = SwitcherProfileDocument(profiles: profilesSnapshot())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    func importDocument(_ data: Data) throws {
        let decoder = JSONDecoder()
        let document = try decoder.decode(SwitcherProfileDocument.self, from: data)
        guard document.schemaVersion == SwitcherProfileDocument.currentSchemaVersion else {
            throw SwitcherProfileValidationIssue.unsupportedSchema(document.schemaVersion)
        }
        var imported = document.profiles
        imported.indices.forEach { imported[$0].normalize() }
        let issues = SwitcherProfileValidator.issues(in: imported)
        guard issues.isEmpty else { throw issues[0] }

        // Atomic replacement: do not mutate published/snapshot state until the
        // entire document has decoded, normalized, and validated.
        profiles = imported
        normalizeValidateAndPublish(persist: true)
    }

    private func normalizeValidateAndPublish(persist: Bool) {
        profiles.indices.forEach { profiles[$0].normalize() }
        validationIssues = SwitcherProfileValidator.issues(in: profiles)

        snapshotLock.lock()
        snapshotProfiles = validationIssues.isEmpty ? profiles : []
        snapshotLock.unlock()

        if persist, validationIssues.isEmpty {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            if let data = try? encoder.encode(SwitcherProfileDocument(profiles: profiles)) {
                defaults.set(data, forKey: storageKey)
            }
        }
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    private static func load(defaults: UserDefaults, key: String) -> [SwitcherShortcutProfile]? {
        guard let data = defaults.data(forKey: key),
              let document = try? JSONDecoder().decode(SwitcherProfileDocument.self, from: data),
              document.schemaVersion == SwitcherProfileDocument.currentSchemaVersion,
              SwitcherProfileValidator.issues(in: document.profiles).isEmpty else {
            return nil
        }
        return document.profiles
    }

    private static func defaultProfiles(
        preferences: SwitcherPreferences
    ) -> [SwitcherShortcutProfile] {
        let commandID = UUID(uuidString: "B237F664-9010-4A62-9F35-31E745B77A90")!
        let optionID = UUID(uuidString: "48F394B0-BD1D-4A1D-A50B-A8AD51849C38")!

        // Preserve the unambiguous bundle-identifier subset of the legacy global
        // exclusion list inside newly created profile documents. Name-based or
        // unresolved legacy entries remain active through the existing global
        // exclusion path and are deliberately not guessed into bundle IDs.
        var migratedFilter = SwitcherProfileAppFilter(
            mode: .exclude,
            bundleIdentifiers: preferences.excludedAppEntries.filter(looksLikeBundleIdentifier)
        )
        migratedFilter.normalize()
        let defaultFilter = migratedFilter.bundleIdentifiers.isEmpty ? .all : migratedFilter

        return [
            SwitcherShortcutProfile(
                id: commandID,
                name: "Command-Tab",
                isEnabled: true,
                forwardShortcut: .commandTab,
                reverseShortcut: RecordedShortcut(
                    keyCode: 48,
                    modifiers: [.command, .shift],
                    keyLabel: "Tab"
                ),
                releaseBehavior: .holdPrimaryModifier,
                inheritsGlobalSettings: true,
                style: preferences.switcherStyle,
                visibilityScope: preferences.windowVisibilityScope,
                includeMinimizedWindows: preferences.includeMinimizedWindows,
                displayPlacement: preferences.displayPlacement,
                appFilter: defaultFilter
            ),
            SwitcherShortcutProfile(
                id: optionID,
                name: "Option-Tab",
                isEnabled: true,
                forwardShortcut: .optionTab,
                reverseShortcut: RecordedShortcut(
                    keyCode: 48,
                    modifiers: [.option, .shift],
                    keyLabel: "Tab"
                ),
                releaseBehavior: .holdPrimaryModifier,
                inheritsGlobalSettings: true,
                style: preferences.switcherStyle,
                visibilityScope: preferences.windowVisibilityScope,
                includeMinimizedWindows: preferences.includeMinimizedWindows,
                displayPlacement: preferences.displayPlacement,
                appFilter: defaultFilter
            ),
        ]
    }

    private static func looksLikeBundleIdentifier(_ value: String) -> Bool {
        value.contains(".") && !value.contains(where: \.isWhitespace)
    }
}