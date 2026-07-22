import Foundation
import LocalAuthentication
import Security

enum CmdTabBundleIdentity {
    static let currentIdentifier = "net.cmdtab.CmdTab"
    static let legacyIdentifier = "com.user.CmdTab"

    /// Keep the existing Keychain account stable across the bundle-identifier migration.
    /// This string is storage identity, not the current application bundle identifier.
    static let legacyLicenseKeychainAccount = legacyIdentifier
}

enum LicenseKeychainMigrationResult: Equatable {
    case copied
    case currentItemExists
    case legacyItemMissing
    case failed(OSStatus)
}

enum BundleIdentityMigrationResult: Equatable {
    case notApplicable
    case alreadyCompleted
    case completed(defaultsCopied: Int, keychain: LicenseKeychainMigrationResult)
    case deferred(defaultsCopied: Int, keychainStatus: OSStatus)
}

struct BundleIdentityMigration {
    static let markerKey = "CmdTab.migration.bundleIdentifier.v1"

    static let migratableDefaultsKeys: Set<String> = [
        "includeBackgroundWindows",
        "windowVisibilityScope",
        "launchAtLogin",
        "maxWindowsPerApp",
        "enableVibrancy",
        "showSelectedPreviewBackdrop",
        "switcherStyle",
        "displayPlacement",
        "alternateTrigger",
        "excludedAppsText",
        "ignoredWindowTitlesText",
        "paletteSearchMemory",
        "CmdTab.licensing.trialStartedAt",
        "CmdTab.licensing.trialClaim",
        "CmdTab.installID",
        "CmdTab.licensing.activatedAt",
        "CmdTab.licensing.cachedPayload",
        "CmdTab.developer.releaseChannel",
        "CmdTab.developer.licensingScenario",
    ]

    typealias KeychainMigrator = () -> LicenseKeychainMigrationResult

    @discardableResult
    static func migrateIfNeeded(
        currentBundleIdentifier: String? = Bundle.main.bundleIdentifier,
        currentDefaults: UserDefaults = .standard,
        legacyDomain: [String: Any]? = nil,
        keychainMigrator: KeychainMigrator = migrateLicenseKeychainItemIfNeeded
    ) -> BundleIdentityMigrationResult {
        guard currentBundleIdentifier == CmdTabBundleIdentity.currentIdentifier else {
            return .notApplicable
        }

        guard !currentDefaults.bool(forKey: markerKey) else {
            return .alreadyCompleted
        }

        let source = legacyDomain
            ?? currentDefaults.persistentDomain(forName: CmdTabBundleIdentity.legacyIdentifier)
            ?? [:]
        var copiedCount = 0

        for key in migratableDefaultsKeys.sorted() {
            guard currentDefaults.object(forKey: key) == nil,
                  let value = source[key] else {
                continue
            }
            currentDefaults.set(value, forKey: key)
            copiedCount += 1
        }

        let keychainResult = keychainMigrator()
        if case let .failed(status) = keychainResult {
            // Leave the marker unset so a temporary Keychain failure can retry next launch.
            return .deferred(defaultsCopied: copiedCount, keychainStatus: status)
        }

        currentDefaults.set(true, forKey: markerKey)
        return .completed(defaultsCopied: copiedCount, keychain: keychainResult)
    }

    static func migrateLicenseKeychainItemIfNeeded() -> LicenseKeychainMigrationResult {
        let service = "CmdTab.licensing.licenseKey"
        let currentAccount = CmdTabBundleIdentity.currentIdentifier
        let legacyAccount = CmdTabBundleIdentity.legacyLicenseKeychainAccount

        let currentStatus = keychainItemStatus(service: service, account: currentAccount)
        switch currentStatus {
        case errSecSuccess:
            return .currentItemExists
        case errSecItemNotFound:
            break
        default:
            return .failed(currentStatus)
        }

        var legacyResult: CFTypeRef?
        let legacyContext = nonInteractiveAuthenticationContext()
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: legacyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: legacyContext,
        ]
        let legacyStatus = SecItemCopyMatching(legacyQuery as CFDictionary, &legacyResult)
        switch legacyStatus {
        case errSecItemNotFound:
            return .legacyItemMissing
        case errSecSuccess:
            break
        default:
            return .failed(legacyStatus)
        }

        guard let data = legacyResult as? Data else {
            return .failed(errSecDecode)
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: currentAccount,
            kSecValueData as String: data,
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            return .copied
        case errSecDuplicateItem:
            return .currentItemExists
        default:
            return .failed(addStatus)
        }
    }

    private static func keychainItemStatus(service: String, account: String) -> OSStatus {
        let context = nonInteractiveAuthenticationContext()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil)
    }

    private static func nonInteractiveAuthenticationContext() -> LAContext {
        let context = LAContext()
        context.interactionNotAllowed = true
        return context
    }
}
