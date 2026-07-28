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

    var startedDate: Date? {
        ISO8601DateFormatter().date(from: startedAt)
    }

    var endsDate: Date? {
        ISO8601DateFormatter().date(from: endsAt)
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

protocol LicenseKeyStore {
    func loadLicenseKey() -> String?
    func loadLicenseKeySilently() -> String?
    func saveLicenseKey(_ value: String) throws
    func clearLicenseKey() throws
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
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }
        if let hardwareID = Self.hardwareUUID() {
            defaults.set(hardwareID, forKey: key)
            return hardwareID
        }
        return nil
    }

    func saveInstallID(_ value: String) {
        defaults.set(value, forKey: key)
    }

    static func hardwareUUID() -> String? {
        let matching = IOServiceMatching("IOPlatformExpertDevice")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let property = IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String else {
            return nil
        }
        let uuid = property.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return uuid.isEmpty ? nil : uuid
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

    init(
        service: String = "CmdTab.licensing.licenseKey",
        account: String = Bundle.main.bundleIdentifier ?? "com.user.CmdTab"
    ) {
        self.service = service
        self.account = account
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
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
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
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
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
