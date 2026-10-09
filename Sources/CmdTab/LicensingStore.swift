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

enum BoundedKeychainReadRegistry {
    static let didCompleteNotification = Notification.Name(
        "CmdTab.BoundedKeychainReadDidComplete"
    )
    private static let lock = NSLock()
    private static var pending = 0
    private static var validationInProgress = false

    static var hasPendingReads: Bool {
        lock.lock()
        defer { lock.unlock() }
        return pending > 0
    }

    static var retainsCompletedReads: Bool {
        lock.lock()
        defer { lock.unlock() }
        return validationInProgress
    }

    static func began() {
        lock.lock()
        pending += 1
        validationInProgress = true
        lock.unlock()
    }

    static func validationCompletedIfIdle() {
        lock.lock()
        if pending == 0 { validationInProgress = false }
        lock.unlock()
    }

    static func finished() {
        lock.lock()
        pending = max(0, pending - 1)
        lock.unlock()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: didCompleteNotification, object: nil)
        }
    }
}

/// A silent Keychain read can wait indefinitely for securityd after an ad-hoc
/// signature change. Keep at most one request in flight and let the UI deny
/// access while that request is unresolved. Completed results remain available
/// throughout a validation pass, even if later Keychain reads are slow.
final class BoundedSilentKeychainRead<Value> {
    private let lock = NSLock()
    private var inFlight = false
    private var generation: UInt64 = 0
    private var cached: (value: Value?, expiresAt: Date)?

    func load(
        timeout: TimeInterval = 0.05,
        cacheDuration: TimeInterval = 1.0,
        operation: @escaping () -> Value?
    ) -> Value? {
        lock.lock()
        if let cached,
           cached.expiresAt > Date() || BoundedKeychainReadRegistry.retainsCompletedReads {
            lock.unlock()
            return cached.value
        }
        guard !inFlight else {
            lock.unlock()
            return nil
        }
        inFlight = true
        let requestGeneration = generation
        let finished = DispatchSemaphore(value: 0)
        BoundedKeychainReadRegistry.began()
        lock.unlock()

        DispatchQueue.global(qos: .utility).async { [self] in
            let value = operation()
            lock.lock()
            if generation == requestGeneration {
                cached = (value, Date().addingTimeInterval(cacheDuration))
            }
            inFlight = false
            lock.unlock()
            finished.signal()
            BoundedKeychainReadRegistry.finished()
        }

        _ = finished.wait(timeout: .now() + timeout)
        lock.lock()
        let value: Value?
        if let cached,
           cached.expiresAt > Date() || BoundedKeychainReadRegistry.retainsCompletedReads {
            value = cached.value
        } else {
            value = nil
        }
        lock.unlock()
        return value
    }

    func invalidate() {
        lock.lock()
        generation &+= 1
        cached = nil
        lock.unlock()
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
    private let silentRead = BoundedSilentKeychainRead<TrialClaimRecord>()

    init(
        service: String = "CmdTab.licensing.trialEntitlement",
        account: String = Bundle.main.bundleIdentifier ?? "net.cmdtab.CmdTab"
    ) {
        self.service = service
        self.account = account
    }

    func loadClaim() -> TrialClaimRecord? {
        guard Thread.isMainThread else { return loadClaimDirectly() }
        return silentRead.load { [self] in loadClaimDirectly() }
    }

    private func loadClaimDirectly() -> TrialClaimRecord? {
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
            silentRead.invalidate()
            return
        }
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] =
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        _ = SecItemAdd(addQuery as CFDictionary, nil)
        silentRead.invalidate()
    }

    func clearClaim() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        _ = SecItemDelete(query as CFDictionary)
        silentRead.invalidate()
    }
}

final class KeychainSecureTrialClockStore: SecureTrialClockStore {
    private let store: LicenseKeyStore
    private let persistenceQueue: DispatchQueue
    private let stateLock = NSLock()
    private var highWaterDate: Date?
    private var generation: UInt64 = 0
    private var pendingClears = 0

    init(
        service: String = "CmdTab.licensing.trialLastSeen",
        account: String = Bundle.main.bundleIdentifier ?? "net.cmdtab.CmdTab"
    ) {
        store = KeychainLicenseKeyStore(
            service: service,
            account: account,
            accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        )
        persistenceQueue = DispatchQueue(label: "CmdTab.secureTrialClock.persistence", qos: .utility)
    }

    init(store: LicenseKeyStore, persistenceQueue: DispatchQueue) {
        self.store = store
        self.persistenceQueue = persistenceQueue
    }

    func loadLastSeenDate() -> Date? {
        stateLock.lock()
        let readGeneration = generation
        if pendingClears > 0 {
            let value = highWaterDate
            stateLock.unlock()
            return value
        }
        stateLock.unlock()

        // Keep the existing bounded silent read: unresolved securityd reads
        // still set the registry that makes licensing fail closed.
        let persisted = persistedDate()
        stateLock.lock()
        defer { stateLock.unlock() }
        if readGeneration == generation, pendingClears == 0, let persisted {
            highWaterDate = max(highWaterDate ?? persisted, persisted)
        }
        return highWaterDate
    }

    func saveLastSeenDate(_ value: Date) {
        stateLock.lock()
        let requested = max(highWaterDate ?? value, value)
        highWaterDate = requested
        let writeGeneration = generation
        // Enqueue while holding the state lock so concurrent save/clear calls
        // have the same order in memory and in persistent storage.
        persistenceQueue.async { [self] in
            let persisted = persistedDate()
            let merged = max(requested, persisted ?? requested)
            try? store.saveLicenseKey(String(format: "%.3f", merged.timeIntervalSince1970))
            stateLock.lock()
            if writeGeneration == generation {
                highWaterDate = max(highWaterDate ?? merged, merged)
            }
            stateLock.unlock()
        }
        stateLock.unlock()
    }

    func clearLastSeenDate() {
        stateLock.lock()
        generation &+= 1
        highWaterDate = nil
        pendingClears += 1
        persistenceQueue.async { [self] in
            try? store.clearLicenseKey()
            stateLock.lock()
            pendingClears -= 1
            stateLock.unlock()
        }
        stateLock.unlock()
    }

    private func persistedDate() -> Date? {
        guard let value = store.loadLicenseKeySilently(),
              let interval = TimeInterval(value), interval.isFinite else { return nil }
        return Date(timeIntervalSince1970: interval)
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
    private let silentRead = BoundedSilentKeychainRead<Data>()

    init(
        service: String = "CmdTab.licensing.deviceIdentity.v2",
        account: String = Bundle.main.bundleIdentifier ?? "net.cmdtab.CmdTab"
    ) {
        self.service = service
        self.account = account
    }

    func loadOrCreateSecret() throws -> Data {
        guard Thread.isMainThread else { return try loadOrCreateSecretDirectly() }
        if let value = silentRead.load(operation: { [self] in
            try? loadOrCreateSecretDirectly()
        }) {
            return value
        }
        throw LicenseKeyStoreError.unexpectedStatus(errSecInteractionNotAllowed)
    }

    private func loadOrCreateSecretDirectly() throws -> Data {
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
            return try loadOrCreateSecretDirectly()
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
    private let silentRead = BoundedSilentKeychainRead<String>()

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
        guard Thread.isMainThread else {
            return loadLicenseKey(allowsAuthenticationUI: false)
        }
        return silentRead.load { [self] in
            loadLicenseKey(allowsAuthenticationUI: false)
        }
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
            silentRead.invalidate()
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
        silentRead.invalidate()
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
        silentRead.invalidate()
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
