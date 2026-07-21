import Foundation

enum LegacyAppIdentityMigration {
    static let completionKey = "CmdTab.identityMigration.com.user.CmdTab.v1"
    static let legacyDomainName = "com.user.CmdTab"

    static let migratedKeys: Set<String> = [
        "includeBackgroundWindows",
        "windowVisibilityScope",
        "maxWindowsPerApp",
        "enableVibrancy",
        "showSelectedPreviewBackdrop",
        "switcherStyle",
        "displayPlacement",
        "alternateTrigger",
        "excludedAppsText",
        "ignoredWindowTitlesText",
        "paletteSearchMemory",
        "CmdTab.installID",
        "CmdTab.licensing.trialStartedAt",
        "CmdTab.licensing.trialClaim",
        "CmdTab.licensing.activatedAt",
        "CmdTab.licensing.cachedPayload",
        "CmdTab.licensing.cachedSignedToken",
        "CmdTab.developer.releaseChannel",
        "CmdTab.developer.licensingScenario",
        "CmdTab.telemetry.enabled"
    ]

    static func valuesToMigrate(
        legacyValues: [String: Any],
        currentValues: [String: Any]
    ) -> [String: Any] {
        var result: [String: Any] = [:]
        for key in migratedKeys where currentValues[key] == nil {
            result[key] = legacyValues[key]
        }
        return result
    }

    static func runIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: completionKey) else { return }

        let legacyValues = defaults.persistentDomain(forName: legacyDomainName) ?? [:]
        let currentValues = Dictionary(uniqueKeysWithValues: migratedKeys.compactMap { key in
            defaults.object(forKey: key).map { (key, $0) }
        })
        for (key, value) in valuesToMigrate(
            legacyValues: legacyValues,
            currentValues: currentValues
        ) {
            defaults.set(value, forKey: key)
        }
        defaults.set(true, forKey: completionKey)
    }
}
