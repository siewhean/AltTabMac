import Foundation
import LocalAuthentication
import Security

protocol TrialStartDateStore {
    func loadTrialStartDate() -> Date?
    func saveTrialStartDate(_ date: Date)
}

struct TrialClaimRecord: Codable, Equatable {
    let id: String
    let email: String
    let installID: String
    let startedAt: String
    let endsAt: String
    let appVersion: String?
    let osVersion: String?
    let entitlementToken: String?
    let validatedAt: String?

    init(
        id: String,
        email: String,
        installID: String,
        startedAt: String,
        endsAt: String,
        appVersion: String?,
        osVersion: String?,
        entitlementToken: String? = nil,
        validatedAt: String? = nil
    ) {
        self.id = id
        self.email = email
        self.installID = installID
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.entitlementToken = entitlementToken
        self.validatedAt = validatedAt
    }

    var startedDate: Date? {
        Self.parseISO8601Date(startedAt)
    }

    var endsDate: Date? {
        Self.parseISO8601Date(endsAt)
    }

    var validatedDate: Date? {
        validatedAt.flatMap(Self.parseISO8601Date)
    }

    private static func parseISO8601Date(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }
}

protocol TrialClaimStore {
    func loadClaim() -> TrialClaimRecord?
    func saveClaim(_ claim: TrialClaimRecord)
    func clearClaim()
}

protocol AppInstallIDStore {
    func loadInstallID() -> String?
    func saveInstallID(_ value: String)
}

protocol LicenseDeviceIdentityStore {
    func loadOrCreateSecret() throws -> Data
}

protocol LicenseKeyStore {
    func loadLicenseKey() -> String?
    func loadLicenseKeySilently() -> String?
    func saveLicenseKey(_ value: String) throws
    func clearLicenseKey() throws
}

protocol DeviceLicenseEntitlementStore {
    func loadEntitlement() -> String?
    func saveEntitlement(_ value: String) throws
    func clearEntitlement() throws
}

protocol SecureTrialClockStore {
    func loadLastSeenDate() -> Date?
    func saveLastSeenDate(_ value: Date)
    func clearLastSeenDate()
}

protocol LicenseRevocationStore {
    func isRevoked(licenseID: String) -> Bool
    func saveRevocation(licenseID: String) throws
}

extension LicenseKeyStore {
    func loadLicenseKeySilently() -> String? {
        loadLicenseKey()
    }
}

protocol LicenseActivationMetadataStore {
    func loadActivationDate() -> Date?
    func saveActivationDate(_ date: Date)
    func clearActivationDate()
}

protocol LicensedPayloadCacheStore {
    func loadPayload() -> SignedLicensePayload?
    func savePayload(_ payload: SignedLicensePayload)
    func clearPayload()
}

final class UserDefaultsTrialStartDateStore: TrialStartDateStore {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "CmdTab.licensing.trialStartedAt"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadTrialStartDate() -> Date? {
        defaults.object(forKey: key) as? Date
    }

    func saveTrialStartDate(_ date: Date) {
        defaults.set(date, forKey: key)
    }
}

final class UserDefaultsTrialClaimStore: TrialClaimStore {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        key: String = "CmdTab.licensing.trialClaim"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadClaim() -> TrialClaimRecord? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(TrialClaimRecord.self, from: data)
    }

    func saveClaim(_ claim: TrialClaimRecord) {
        guard let data = try? encoder.encode(claim) else { return }
        defaults.set(data, forKey: key)
    }

    func clearClaim() {
        defaults.removeObject(forKey: key)
    }
}

final class KeychainTrialClaimStore: TrialClaimStore {
    private let service: String
    private let account: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        service: String = "CmdTab.licensing.trialEntitlement",
        account: String = Bundle.main.bundleIdentifier ?? "net.cmdtab.CmdTab"
    ) {
        self.service = service
        self.account = account
    }

    func loadClaim() -> TrialClaimRecord? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return try? decoder.decode(TrialClaimRecord.self, from: data)
    }

    func saveClaim(_ claim: TrialClaimRecord) {
        guard claim.entitlementToken?.isEmpty == false,
              let data = try? encoder.encode(claim) else {
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String:
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecSuccess {
            return
        }
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] =
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        _ = SecItemAdd(addQuery as CFDictionary, nil)
    }

    func clearClaim() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        _ = SecItemDelete(query as CFDictionary)
    }
}

final class KeychainSecureTrialClockStore: SecureTrialClockStore {
    private let store: KeychainLicenseKeyStore

    init(
        service: String = "CmdTab.licensing.trialLastSeen",
        account: String = Bundle.main.bundleIdentifier ?? "net.cmdtab.CmdTab"
    ) {
        store = KeychainLicenseKeyStore(
            service: service,
            account: account,
            accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        )
    }

    func loadLastSeenDate() -> Date? {
        guard let value = store.loadLicenseKeySilently(),
              let interval = TimeInterval(value) else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }

    func saveLastSeenDate(_ value: Date) {
        try? store.saveLicenseKey(
            String(format: "%.3f", value.timeIntervalSince1970)
        )
    }

    func clearLastSeenDate() {
        try? store.clearLicenseKey()
    }
}

final class KeychainLicenseRevocationStore: LicenseRevocationStore {
    private let store: LicenseKeyStore
    private let defaults: UserDefaults
    private let fallbackKey: String
    private var sessionRevocations: Set<String> = []

    init(
        service: String = "CmdTab.licensing.revocationTombstone",
        account: String = Bundle.main.bundleIdentifier ?? "net.cmdtab.CmdTab",
        defaults: UserDefaults = .standard
    ) {
        store = KeychainLicenseKeyStore(service: service, account: account)
        self.defaults = defaults
        fallbackKey = "\(service).\(account).fallback"
    }

    init(
        store: LicenseKeyStore,
        defaults: UserDefaults,
        fallbackKey: String
    ) {
        self.store = store
        self.defaults = defaults
        self.fallbackKey = fallbackKey
    }

    func isRevoked(licenseID: String) -> Bool {
        sessionRevocations.contains(licenseID)
            || fallbackIdentifiers().contains(licenseID)
            || revokedIdentifiers().contains(licenseID)
    }

    func saveRevocation(licenseID: String) throws {
        sessionRevocations.insert(licenseID)
        var fallback = fallbackIdentifiers()
        fallback.insert(licenseID)
        defaults.set(Array(fallback).sorted(), forKey: fallbackKey)

        var values = revokedIdentifiers()
        values.insert(licenseID)
        guard let data = try? JSONEncoder().encode(values.sorted()),
              let encoded = String(data: data, encoding: .utf8) else {
            throw LicenseKeyStoreError.invalidData
        }
        try store.saveLicenseKey(encoded)
    }

    private func fallbackIdentifiers() -> Set<String> {
        Set(defaults.stringArray(forKey: fallbackKey) ?? [])
    }

    private func revokedIdentifiers() -> Set<String> {
        guard let stored = store.loadLicenseKeySilently(), !stored.isEmpty else {
            return []
        }
        if let data = stored.data(using: .utf8),
           let values = try? JSONDecoder().decode([String].self, from: data) {
            return Set(values)
        }
        // Migrate the original single-value tombstone format lazily.
        return [stored]
    }
}

final class UserDefaultsAppInstallIDStore: AppInstallIDStore {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "CmdTab.installID"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadInstallID() -> String? {
        defaults.string(forKey: key)
    }

    func saveInstallID(_ value: String) {
        defaults.set(value, forKey: key)
    }
}

final class KeychainLicenseDeviceIdentityStore: LicenseDeviceIdentityStore {
    private let service: String
    private let account: String

    init(
        service: String = "CmdTab.licensing.deviceIdentity.v2",
        account: String = Bundle.main.bundleIdentifier ?? "net.cmdtab.CmdTab"
    ) {
        self.service = service
        self.account = account
    }

    func loadOrCreateSecret() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let loadStatus = SecItemCopyMatching(query as CFDictionary, &result)
        if loadStatus == errSecSuccess, let data = result as? Data, data.count == 32 {
            return data
        }
        guard loadStatus == errSecItemNotFound else {
            throw LicenseKeyStoreError.unexpectedStatus(loadStatus)
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        let randomStatus = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard randomStatus == errSecSuccess else {
            throw LicenseKeyStoreError.unexpectedStatus(randomStatus)
        }
        let data = Data(bytes)
        var addQuery = query
        addQuery.removeValue(forKey: kSecReturnData as String)
        addQuery.removeValue(forKey: kSecMatchLimit as String)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] =
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            return try loadOrCreateSecret()
        }
        guard addStatus == errSecSuccess else {
            throw LicenseKeyStoreError.unexpectedStatus(addStatus)
        }
        return data
    }
}

final class UserDefaultsLicenseActivationMetadataStore: LicenseActivationMetadataStore {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "CmdTab.licensing.activatedAt"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadActivationDate() -> Date? {
        defaults.object(forKey: key) as? Date
    }

    func saveActivationDate(_ date: Date) {
        defaults.set(date, forKey: key)
    }

    func clearActivationDate() {
        defaults.removeObject(forKey: key)
    }
}

final class UserDefaultsLicensedPayloadCacheStore: LicensedPayloadCacheStore {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        key: String = "CmdTab.licensing.cachedPayload"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadPayload() -> SignedLicensePayload? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(SignedLicensePayload.self, from: data)
    }

    func savePayload(_ payload: SignedLicensePayload) {
        guard let data = try? encoder.encode(payload) else { return }
        defaults.set(data, forKey: key)
    }

    func clearPayload() {
        defaults.removeObject(forKey: key)
    }
}

enum LicenseKeyStoreError: Error {
    case unexpectedStatus(OSStatus)
    case invalidData
}

final class KeychainLicenseKeyStore: LicenseKeyStore {
    private let service: String
    private let account: String
    private let accessibility: CFString?

    init(
        service: String = "CmdTab.licensing.licenseKey",
        account: String = Bundle.main.bundleIdentifier ?? "com.user.CmdTab",
        accessibility: CFString? = nil
    ) {
        self.service = service
        self.account = account
        self.accessibility = accessibility
    }

    func loadLicenseKey() -> String? {
        loadLicenseKey(allowsAuthenticationUI: true)
    }

    func loadLicenseKeySilently() -> String? {
        loadLicenseKey(allowsAuthenticationUI: false)
    }

    private func loadLicenseKey(allowsAuthenticationUI: Bool) -> String? {
        let context = LAContext()
        context.interactionNotAllowed = !allowsAuthenticationUI

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveLicenseKey(_ value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw LicenseKeyStoreError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String:
                accessibility ?? kSecAttrAccessibleWhenUnlocked,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw LicenseKeyStoreError.unexpectedStatus(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] =
            accessibility ?? kSecAttrAccessibleWhenUnlocked
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw LicenseKeyStoreError.unexpectedStatus(addStatus)
        }
    }

    func clearLicenseKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw LicenseKeyStoreError.unexpectedStatus(status)
        }
    }
}

final class KeychainDeviceLicenseEntitlementStore: DeviceLicenseEntitlementStore {
    private let store: KeychainLicenseKeyStore

    init(
        service: String = "CmdTab.licensing.deviceEntitlement",
        account: String = Bundle.main.bundleIdentifier ?? "net.cmdtab.CmdTab"
    ) {
        store = KeychainLicenseKeyStore(
            service: service,
            account: account,
            accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        )
    }

    func loadEntitlement() -> String? {
        store.loadLicenseKeySilently()
    }

    func saveEntitlement(_ value: String) throws {
        try store.saveLicenseKey(value)
    }

    func clearEntitlement() throws {
        try store.clearLicenseKey()
    }
}
