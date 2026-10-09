import AppKit
import CryptoKit
import Foundation

struct SignedLicensePayload: Codable, Equatable {
    let version: Int
    let product: String
    let email: String
    let licenseID: String
    let issuedAt: String
    let purchaserName: String?

    var issuedDate: Date? {
        ISO8601DateFormatter().date(from: issuedAt)
    }
}

enum LicensingStatus: Equatable {
    case unregistered
    case activeTrial(startedAt: Date, endsAt: Date, daysRemaining: Int)
    case expired(startedAt: Date, endedAt: Date, daysOverdue: Int)
    case licensed(payload: SignedLicensePayload, activatedAt: Date?)

    var isExpired: Bool {
        if case .expired = self {
            return true
        }
        return false
    }

    var requiresTrialRegistration: Bool {
        if case .unregistered = self {
            return true
        }
        return false
    }
}

enum LicensingMessageTone: Equatable {
    case success
    case warning
    case error
}

struct LicensingMessage: Equatable {
    let tone: LicensingMessageTone
    let text: String
}

enum LicenseValidationError: LocalizedError, Equatable {
    case empty
    case malformed
    case badPrefix
    case invalidEncoding
    case invalidSignature
    case wrongProduct

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Paste a license key first."
        case .malformed:
            return "This license key format is not valid."
        case .badPrefix:
            return "This key does not belong to CmdTab."
        case .invalidEncoding:
            return "This license key could not be decoded."
        case .invalidSignature:
            return "This license key could not be verified."
        case .wrongProduct:
            return "This license key was not issued for CmdTab."
        }
    }
}

@MainActor
final class LicensingController: ObservableObject {
    static let shared = LicensingController(telemetryReporter: AppTelemetryReporter.shared)

    @Published private(set) var status: LicensingStatus {
        didSet { publishEventTapGate() }
    }
    /// Thread-safe licensing snapshot for the keyboard event tap thread.
    nonisolated let eventTapGate: EventTapLicensingGate
    @Published var enteredLicenseKey = ""
    @Published var enteredTrialEmail = ""
    @Published private(set) var isStartingTrial = false
    @Published private(set) var isManagingLicense = false
    @Published private(set) var licensedDevices: [LicensedDeviceDTO] = []
    @Published private(set) var trialMessage: LicensingMessage?
    @Published private(set) var licenseMessage: LicensingMessage?

    private let trialStore: TrialStartDateStore
    private let trialClaimStore: TrialClaimStore
    private let licenseStore: LicenseKeyStore
    private let deviceEntitlementStore: DeviceLicenseEntitlementStore
    private let activationMetadataStore: LicenseActivationMetadataStore
    private let payloadCacheStore: LicensedPayloadCacheStore
    private let installIDStore: AppInstallIDStore
    private let deviceIdentityStore: LicenseDeviceIdentityStore
    private let trialClaimAuthenticator: TrialClaimAuthenticating
    private let secureTrialClockStore: SecureTrialClockStore
    private let revocationStore: LicenseRevocationStore
    private let paidEntitlementVerifier: LicenseTokenVerifier
    private let serverClient: CmdTabServerClient
    private let telemetryReporter: AppTelemetryReporting?
    private let currentDate: () -> Date
    private let currentUptime: () -> TimeInterval
    private let publicKeyDERBase64: String
    private var keychainReadObserver: NSObjectProtocol?
    private var shortcutRefreshWorkItem: DispatchWorkItem?
    private var shortcutRefreshIsImmediate = false
    private var shortcutValidatedAt: Date? {
        didSet { publishEventTapGate() }
    }
    private var shortcutValidatedUptime: TimeInterval? {
        didSet { publishEventTapGate() }
    }
    private static let shortcutRefreshInterval: TimeInterval = 5
    #if DEBUG
    private let developerSettings: DeveloperSettings
    #endif
    private let iso8601 = ISO8601DateFormatter()

    init(
        trialStore: TrialStartDateStore = UserDefaultsTrialStartDateStore(),
        trialClaimStore: TrialClaimStore = KeychainTrialClaimStore(),
        licenseStore: LicenseKeyStore = KeychainLicenseKeyStore(),
        deviceEntitlementStore: DeviceLicenseEntitlementStore =
            KeychainDeviceLicenseEntitlementStore(),
        activationMetadataStore: LicenseActivationMetadataStore = UserDefaultsLicenseActivationMetadataStore(),
        payloadCacheStore: LicensedPayloadCacheStore = UserDefaultsLicensedPayloadCacheStore(),
        installIDStore: AppInstallIDStore = UserDefaultsAppInstallIDStore(),
        deviceIdentityStore: LicenseDeviceIdentityStore = KeychainLicenseDeviceIdentityStore(),
        trialClaimAuthenticator: TrialClaimAuthenticating = SignedTrialClaimAuthenticator(),
        secureTrialClockStore: SecureTrialClockStore =
            KeychainSecureTrialClockStore(),
        revocationStore: LicenseRevocationStore =
            KeychainLicenseRevocationStore(),
        licenseV2PublicKeysDERBase64: [String: String] =
            LicensingConfiguration.licensePublicKeyringDERBase64,
        serverClient: CmdTabServerClient = LiveCmdTabServerClient(),
        telemetryReporter: AppTelemetryReporting? = nil,
        currentDate: @escaping () -> Date = Date.init,
        currentUptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        publicKeyDERBase64: String = LicensingConfiguration.publicKeyDERBase64,
        // This compatibility argument is inert in release builds; DEBUG alone
        // casts it to the internal scenario state used by tests.
        debugCompatibility: Any? = nil
    ) {
        self.trialStore = trialStore
        self.trialClaimStore = trialClaimStore
        self.licenseStore = licenseStore
        self.deviceEntitlementStore = deviceEntitlementStore
        self.activationMetadataStore = activationMetadataStore
        self.payloadCacheStore = payloadCacheStore
        self.installIDStore = installIDStore
        self.deviceIdentityStore = deviceIdentityStore
        self.trialClaimAuthenticator = trialClaimAuthenticator
        self.secureTrialClockStore = secureTrialClockStore
        self.revocationStore = revocationStore
        self.paidEntitlementVerifier = LicenseTokenVerifier(
            keyring: LicenseTokenKeyring(
                legacyV1PublicKeyDERBase64: publicKeyDERBase64,
                v2PublicKeysDERBase64: licenseV2PublicKeysDERBase64
            )
        )
        self.serverClient = serverClient
        self.telemetryReporter = telemetryReporter
        self.currentDate = currentDate
        self.currentUptime = currentUptime
        self.eventTapGate = EventTapLicensingGate(
            refreshInterval: Self.shortcutRefreshInterval,
            clockRollbackTolerance: Self.clockRollbackTolerance,
            currentDate: currentDate,
            currentUptime: currentUptime
        )
        self.publicKeyDERBase64 = publicKeyDERBase64
        #if DEBUG
        self.developerSettings = (debugCompatibility as? DeveloperSettings) ?? .shared
        #endif

        self.status = .unregistered

        keychainReadObserver = NotificationCenter.default.addObserver(
            forName: BoundedKeychainReadRegistry.didCompleteNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshStatus() }
        }

        // The gate may be asked from the event tap thread; revalidation always
        // runs on the main actor. On main, schedule directly so the refresh
        // still coalesces onto the next main-queue turn.
        eventTapGate.setRefreshHandler { [weak self] in
            if Thread.isMainThread {
                MainActor.assumeIsolated { self?.scheduleShortcutRefresh() }
            } else {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.scheduleShortcutRefresh() }
                }
            }
        }

        refreshStatus()
        publishEventTapGate()
    }

    deinit {
        shortcutRefreshWorkItem?.cancel()
        if let keychainReadObserver {
            NotificationCenter.default.removeObserver(keychainReadObserver)
        }
    }

    var hasUnlockedAccess: Bool {
        !status.isExpired && !status.requiresTrialRegistration
    }

    func shouldHandleCustomSwitcherShortcut() -> Bool {
        refreshStatus()
        return !status.isExpired && !status.requiresTrialRegistration
    }

    /// Event taps must never wait for securityd or verify a signed token. Use
    /// the last status verified in this process and coalesce revalidation onto
    /// the main queue after the callback has returned. A stale snapshot or a
    /// pending Keychain read is not a revocation: definitive results (expiry,
    /// revocation, an invalid token) replace the status when they complete,
    /// and trial expiry and clock rollback are checked against `now` here.
    func shouldHandleEventTapShortcut() -> Bool {
        eventTapGate.allowsShortcut()
    }

    /// Mirrors the verified status into the thread-safe gate read by the
    /// event tap thread.
    private func publishEventTapGate() {
        let entitlement: EventTapLicensingGate.Entitlement
        switch status {
        case .licensed: entitlement = .licensed
        case let .activeTrial(_, endsAt, _): entitlement = .trial(endsAt: endsAt)
        case .unregistered, .expired: entitlement = .none
        }
        eventTapGate.update(EventTapLicensingGate.Snapshot(
            entitlement: entitlement,
            validatedAt: shortcutValidatedAt,
            validatedUptime: shortcutValidatedUptime
        ))
    }

    private func scheduleShortcutRefresh(after delay: TimeInterval = 0) {
        if shortcutRefreshWorkItem != nil {
            guard delay == 0, !shortcutRefreshIsImmediate else { return }
            shortcutRefreshWorkItem?.cancel()
        }
        shortcutRefreshIsImmediate = delay == 0
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.shortcutRefreshWorkItem = nil
            self.refreshStatus()
        }
        shortcutRefreshWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    var licenseSummaryTitle: String {
        switch status {
        case .unregistered:
            return "Start your 14-day trial"
        case let .licensed(payload, _):
            return payload.purchaserName?.isEmpty == false ? payload.purchaserName! : payload.email
        case let .activeTrial(_, _, daysRemaining):
            return daysRemaining == 1 ? "1 day left in trial" : "\(daysRemaining) days left in trial"
        case .expired:
            return "Trial ended"
        }
    }

    var licenseSummaryDetail: String {
        switch status {
        case .unregistered:
            return "Start the trial on this Mac. Email is optional and is used only for trial reminders."
        case let .licensed(payload, activatedAt):
            let issuedAt = payload.issuedDate.map { Self.displayFormatter.string(from: $0) } ?? payload.issuedAt
            let activatedCopy = activatedAt.map { "Activated \(Self.displayFormatter.string(from: $0))." } ?? "Activated on this Mac."
            return "License \(payload.licenseID) for \(payload.email). Issued \(issuedAt). \(activatedCopy)"
        case let .activeTrial(startedAt, endsAt, _):
            return "Started \(Self.displayFormatter.string(from: startedAt)). Ends \(Self.displayFormatter.string(from: endsAt))."
        case let .expired(_, endedAt, daysOverdue):
            let overdueCopy: String
            switch daysOverdue {
            case 0:
                overdueCopy = "The trial just expired."
            case 1:
                overdueCopy = "The trial expired 1 day ago."
            default:
                overdueCopy = "The trial expired \(daysOverdue) days ago."
            }
            return "\(overdueCopy) Buy CmdTab or enter a valid license to keep using the switcher. Trial ended \(Self.displayFormatter.string(from: endedAt))."
        }
    }

    var trialWarningMessage: LicensingMessage? {
        switch status {
        case let .activeTrial(_, endsAt, daysRemaining) where daysRemaining <= 3:
            let remainingCopy = daysRemaining == 1
                ? "1 day remains"
                : "\(daysRemaining) days remain"
            return LicensingMessage(
                tone: .warning,
                text: "\(remainingCopy) in your trial. Access ends exactly \(Self.boundaryFormatter.string(from: endsAt))."
            )
        case let .expired(_, endedAt, _):
            return LicensingMessage(
                tone: .error,
                text: "Your trial ended \(Self.displayFormatter.string(from: endedAt)). CmdTab now leaves the native macOS switcher shortcut available."
            )
        default:
            return nil
        }
    }

    var menuBarTrialStatusTitle: String? {
        switch status {
        case let .activeTrial(_, _, daysRemaining) where daysRemaining <= 3:
            return daysRemaining == 1
                ? "Trial: 1 Day Remaining"
                : "Trial: \(daysRemaining) Days Remaining"
        case .expired:
            return "Trial Expired"
        default:
            return nil
        }
    }

    func refreshStatus() {
        defer {
            BoundedKeychainReadRegistry.validationCompletedIfIdle()
            // A pending read keeps the last verified snapshot; only a
            // completed pass may replace it.
            if !BoundedKeychainReadRegistry.hasPendingReads {
                shortcutValidatedAt = currentDate()
                shortcutValidatedUptime = currentUptime()
            }
            // Keep an authorized snapshot fresh during idle time, so the first
            // shortcut after a pause does not fall back merely due to its age.
            if hasUnlockedAccess {
                scheduleShortcutRefresh(after: Self.shortcutRefreshInterval)
            }
        }
        let now = currentDate()

        // A timed-out securityd read is unknown: never proof of an entitlement
        // or of a revocation. Keep the last verified status until it resolves,
        // so a slow Keychain cannot turn Command-Tab off mid-session.
        guard !BoundedKeychainReadRegistry.hasPendingReads else {
            return
        }

        let paidEntitlement = deviceEntitlementStore.loadEntitlement()
        guard !BoundedKeychainReadRegistry.hasPendingReads else {
            return
        }
        if let paidEntitlement {
            if let verifiedPayload = try? validatePaidDeviceEntitlement(paidEntitlement) {
                guard !isRevoked(
                    payload: verifiedPayload,
                    entitlementToken: paidEntitlement
                ) else {
                    try? deviceEntitlementStore.clearEntitlement()
                    try? licenseStore.clearLicenseKey()
                    payloadCacheStore.clearPayload()
                    status = .unregistered
                    return
                }
                guard !BoundedKeychainReadRegistry.hasPendingReads else {
                    return
                }
                payloadCacheStore.savePayload(verifiedPayload)
                status = .licensed(
                    payload: verifiedPayload,
                    activatedAt: activationMetadataStore.loadActivationDate()
                )
                return
            }
            // A missing or temporarily unavailable Keychain read is not proof
            // that a stored paid entitlement is invalid. Clear only a token
            // that was actually returned and failed signature validation.
            try? deviceEntitlementStore.clearEntitlement()
        }

        let storedToken = licenseStore.loadLicenseKeySilently()
        guard !BoundedKeychainReadRegistry.hasPendingReads else {
            return
        }
        if let storedToken,
           let verifiedPayload = try? validateLicenseKey(normalizeToken(storedToken)) {
            guard !isLicenseRevoked(verifiedPayload.licenseID) else {
                try? licenseStore.clearLicenseKey()
                payloadCacheStore.clearPayload()
                status = .unregistered
                return
            }
            guard !BoundedKeychainReadRegistry.hasPendingReads else {
                return
            }
            payloadCacheStore.savePayload(verifiedPayload)
            status = .licensed(
                payload: verifiedPayload,
                activatedAt: activationMetadataStore.loadActivationDate()
            )
            return
        }
        // A decoded UserDefaults cache is display metadata only. It must never
        // grant paid access without re-verifying the signed Keychain token.
        payloadCacheStore.clearPayload()

        #if DEBUG
        if let overrideStatus = developerOverrideStatus(now: now) {
            status = overrideStatus
            return
        }
        #endif

        if let claim = trialClaimStore.loadClaim(),
           let trialInstallBinding = try? deviceIdentifier(),
           trialClaimAuthenticator.validates(
            claim,
            installID: trialInstallBinding
           ),
           let startedAt = claim.startedDate,
           let claimedEndsAt = claim.endsDate {
            let lastSeen = secureTrialClockStore.loadLastSeenDate()
            guard !BoundedKeychainReadRegistry.hasPendingReads else {
                return
            }
            if let lastSeen,
               now.addingTimeInterval(Self.clockRollbackTolerance) < lastSeen {
                enteredTrialEmail = Self.visibleTrialEmail(claim.email)
                status = .unregistered
                trialMessage = LicensingMessage(
                    tone: .warning,
                    text: "The system clock moved backwards. Connect to the internet and revalidate the trial."
                )
                return
            }
            let endsAt = Self.trialEndDate(startedAt: startedAt)
            guard abs(claimedEndsAt.timeIntervalSince(endsAt)) <=
                    Self.trialClaimSerializationTolerance else {
                trialClaimStore.clearClaim()
                enteredTrialEmail = ""
                status = .unregistered
                return
            }
            enteredTrialEmail = Self.visibleTrialEmail(claim.email)
            secureTrialClockStore.saveLastSeenDate(now)
            if now < endsAt {
                status = .activeTrial(
                    startedAt: startedAt,
                    endsAt: endsAt,
                    daysRemaining: Self.daysRemaining(until: endsAt, now: now)
                )
            } else {
                let overdue = Self.daysOverdue(since: endsAt, now: now)
                status = .expired(startedAt: startedAt, endedAt: endsAt, daysOverdue: overdue)
            }
            return
        }

        status = .unregistered
    }

    @discardableResult
    func startTrialRegistration() async -> Bool {
        let normalizedEmail = enteredTrialEmail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if !normalizedEmail.isEmpty,
           (!normalizedEmail.contains("@") || !normalizedEmail.contains(".")) {
            trialMessage = LicensingMessage(
                tone: .error,
                text: "Enter a valid email or leave the field blank."
            )
            return false
        }

        isStartingTrial = true
        defer { isStartingTrial = false }

        do {
            let claim = try await serverClient.startTrial(
                email: normalizedEmail,
                installID: try deviceIdentifier(),
                appVersion: appVersion,
                osVersion: osVersion
            )
            trialClaimStore.saveClaim(claim)
            let authoritativeDate = claim.validatedDate ?? currentDate()
            secureTrialClockStore.saveLastSeenDate(
                max(
                    secureTrialClockStore.loadLastSeenDate()
                        ?? authoritativeDate,
                    authoritativeDate
                )
            )
            enteredTrialEmail = Self.visibleTrialEmail(claim.email)
            refreshStatus()
            guard case .activeTrial = status else {
                trialMessage = LicensingMessage(
                    tone: .error,
                    text: "The trial response could not be verified. Please try again."
                )
                return false
            }
            trialMessage = LicensingMessage(
                tone: .success,
                text: normalizedEmail.isEmpty
                    ? "Your 14-day trial is active on this Mac. Email reminders are off."
                    : "Your 14-day trial is active on this Mac."
            )
            telemetryReporter?.trackTrialStarted(licensingController: self)
            return true
        } catch {
            trialMessage = LicensingMessage(
                tone: .error,
                text: (error as? LocalizedError)?.errorDescription ?? "We could not start the trial right now."
            )
            refreshStatus()
            return false
        }
    }

    var installID: String {
        if let existing = installIDStore.loadInstallID(), !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString.lowercased()
        installIDStore.saveInstallID(generated)
        return generated
    }

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    var osVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    var telemetryLicenseState: String {
        switch status {
        case .unregistered:
            return "unregistered"
        case .activeTrial:
            return "trial_active"
        case .expired:
            return "trial_expired"
        case .licensed:
            return "licensed"
        }
    }

    var currentLicenseID: String? {
        guard case let .licensed(payload, _) = status else { return nil }
        return payload.licenseID
    }

    func clearTrialClaim() {
        trialClaimStore.clearClaim()
        secureTrialClockStore.clearLastSeenDate()
        enteredTrialEmail = ""
        refreshStatus()
    }

    func resetLiveTrialFromToday(clearSavedLicense: Bool) {
        trialClaimStore.clearClaim()
        secureTrialClockStore.clearLastSeenDate()
        trialStore.saveTrialStartDate(.distantPast)
        enteredTrialEmail = ""
        if clearSavedLicense {
            try? licenseStore.clearLicenseKey()
            try? deviceEntitlementStore.clearEntitlement()
            activationMetadataStore.clearActivationDate()
            payloadCacheStore.clearPayload()
            enteredLicenseKey = ""
        }

        #if DEBUG
        if developerSettings.releaseChannel == .test {
            developerSettings.licensingScenario = .live
        }
        #endif

        refreshStatus()
        trialMessage = LicensingMessage(
            tone: .success,
            text: clearSavedLicense
                ? "The saved license and trial registration were cleared on this Mac."
                : "The saved trial registration was cleared on this Mac."
        )
    }

    /// Fills in a code from a `cmdtab://activate` link without activating.
    func prefillActivationCode(_ code: String) {
        enteredLicenseKey = code
        licenseMessage = LicensingMessage(
            tone: .warning,
            text: currentLicenseID == nil
                ? "Check that this activation code came from your CmdTab purchase email, then click Activate."
                : "This link would replace the license on this Mac. Click Activate only if you requested it."
        )
    }

    @discardableResult
    func activateEnteredLicenseKey() -> Bool {
        activateLicense(enteredLicenseKey)
    }

    @discardableResult
    func activateEnteredLicenseKeyOnline() async -> Bool {
        guard !isManagingLicense else { return false }
        isManagingLicense = true
        defer { isManagingLicense = false }

        do {
            let normalized = normalizeToken(enteredLicenseKey)
            guard !normalized.isEmpty else {
                throw LicenseValidationError.empty
            }
            let activation = try await serverClient.activateLicense(
                licenseKey: normalized,
                deviceID: try deviceIdentifier(),
                deviceName: Host.current().localizedName ?? "Mac"
            )
            let paidPayload = try validatePaidDeviceEntitlement(
                activation.entitlementToken
            )
            try deviceEntitlementStore.saveEntitlement(
                activation.entitlementToken
            )
            try licenseStore.saveLicenseKey(normalized)
            activationMetadataStore.saveActivationDate(currentDate())
            payloadCacheStore.savePayload(paidPayload)
            enteredLicenseKey = normalized
            status = .licensed(
                payload: paidPayload,
                activatedAt: activationMetadataStore.loadActivationDate()
            )
            licensedDevices = activation.devices
            licenseMessage = LicensingMessage(
                tone: .success,
                text: "CmdTab is now activated on this Mac."
            )
            telemetryReporter?.trackLicenseActivation(
                licensingController: self
            )
            return true
        } catch {
            let description = (error as? LocalizedError)?.errorDescription
                ?? "This Mac could not be activated right now."
            licenseMessage = LicensingMessage(tone: .error, text: description)
            refreshStatus()
            return false
        }
    }

    func refreshLicensedDevices() async {
        guard let storedToken = serverActivationCredential() else {
            licensedDevices = []
            return
        }
        do {
            let result = try await serverClient.listDeviceStatus(
                licenseKey: storedToken,
                deviceID: try deviceIdentifier()
            )
            licensedDevices = result.devices
            if result.currentActivationActive == false,
               let entitlement = deviceEntitlementStore.loadEntitlement() {
                try? revocationStore.saveRevocation(
                    licenseID: tokenRevocationIdentifier(entitlement)
                )
                try? deviceEntitlementStore.clearEntitlement()
                try? licenseStore.clearLicenseKey()
                payloadCacheStore.clearPayload()
                licensedDevices = []
                refreshStatus()
            }
        } catch {
            if case CmdTabServerClientError.licenseRevoked = error {
                if let currentLicenseID {
                    try? revocationStore.saveRevocation(
                        licenseID: licenseRevocationIdentifier(currentLicenseID)
                    )
                }
                try? deviceEntitlementStore.clearEntitlement()
                try? licenseStore.clearLicenseKey()
                payloadCacheStore.clearPayload()
                licensedDevices = []
                refreshStatus()
                return
            }
            // Paid authorization remains available offline indefinitely.
            // A transient listing failure must not change local access.
        }
    }

    @discardableResult
    func deactivateCurrentDevice() async -> Bool {
        guard !isManagingLicense else { return false }
        guard let storedToken = serverActivationCredential() else {
            clearLicense()
            return true
        }
        isManagingLicense = true
        defer { isManagingLicense = false }
        do {
            let entitlement = deviceEntitlementStore.loadEntitlement()
            licensedDevices = try await serverClient.deactivateLicense(
                licenseKey: storedToken,
                deviceID: try deviceIdentifier()
            )
            if let entitlement {
                try? revocationStore.saveRevocation(
                    licenseID: tokenRevocationIdentifier(entitlement)
                )
            }
            clearLicense()
            return true
        } catch {
            licenseMessage = LicensingMessage(
                tone: .error,
                text: (error as? LocalizedError)?.errorDescription
                    ?? "This Mac could not be deactivated right now."
            )
            return false
        }
    }

    @discardableResult
    func activateLicense(_ value: String) -> Bool {
        do {
            let normalized = normalizeToken(value)
            let payload = try validateLicenseKey(normalized)
            try licenseStore.saveLicenseKey(normalized)
            activationMetadataStore.saveActivationDate(currentDate())
            payloadCacheStore.savePayload(payload)
            #if DEBUG
            if developerSettings.releaseChannel == .test {
                developerSettings.licensingScenario = .live
            }
            #endif
            enteredLicenseKey = normalized
            status = .licensed(payload: payload, activatedAt: activationMetadataStore.loadActivationDate())
            licenseMessage = LicensingMessage(
                tone: .success,
                text: "CmdTab is now activated for \(payload.email)."
            )
            telemetryReporter?.trackLicenseActivation(licensingController: self)
            return true
        } catch {
            let description = (error as? LocalizedError)?.errorDescription ?? "This license key could not be verified."
            licenseMessage = LicensingMessage(tone: .error, text: description)
            refreshStatus()
            return false
        }
    }

    func clearLicense() {
        try? licenseStore.clearLicenseKey()
        try? deviceEntitlementStore.clearEntitlement()
        activationMetadataStore.clearActivationDate()
        payloadCacheStore.clearPayload()
        enteredLicenseKey = ""
        refreshStatus()
        licenseMessage = LicensingMessage(
            tone: .warning,
            text: "Saved license removed from this Mac."
        )
    }

    @discardableResult
    func ensureUsageAllowed(presentLicensing: Bool = true, openLicensing: () -> Void) -> Bool {
        refreshStatus()
        guard !status.isExpired, !status.requiresTrialRegistration else {
            if status.requiresTrialRegistration {
                trialMessage = LicensingMessage(
                    tone: .warning,
                    text: "Start the trial before using CmdTab on this Mac. Email is optional."
                )
            } else {
                licenseMessage = LicensingMessage(
                    tone: .warning,
                    text: "The trial ended. Buy CmdTab or enter a valid license to keep using the switcher."
                )
            }
            if presentLicensing { openLicensing() }
            return false
        }
        return true
    }

    func openBuyPage() {
        NSWorkspace.shared.open(LicensingConfiguration.buyURL)
    }

    func openHelpPage() {
        NSWorkspace.shared.open(LicensingConfiguration.helpURL)
    }

    func openTrialPage() {
        NSWorkspace.shared.open(LicensingConfiguration.trialURL)
    }

    func clearMessage() {
        trialMessage = nil
        licenseMessage = nil
    }

    private func validateLicenseKey(_ value: String) throws -> SignedLicensePayload {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { throw LicenseValidationError.malformed }
        guard parts[0] == LicensingConfiguration.tokenPrefix else { throw LicenseValidationError.badPrefix }

        guard let payloadData = Data(base64URLEncoded: String(parts[1])),
              let signatureData = Data(base64URLEncoded: String(parts[2])) else {
            throw LicenseValidationError.invalidEncoding
        }

        guard let publicKeyData = Data(base64Encoded: publicKeyDERBase64) else {
            throw LicenseValidationError.invalidEncoding
        }

        let publicKey = try P256.Signing.PublicKey(derRepresentation: publicKeyData)
        let signature = try P256.Signing.ECDSASignature(derRepresentation: signatureData)

        guard publicKey.isValidSignature(signature, for: payloadData) else {
            throw LicenseValidationError.invalidSignature
        }

        let payload = try JSONDecoder().decode(SignedLicensePayload.self, from: payloadData)
        guard payload.product.lowercased() == LicensingConfiguration.productIdentifier else {
            throw LicenseValidationError.wrongProduct
        }
        return payload
    }

    private func validatePaidDeviceEntitlement(
        _ value: String
    ) throws -> SignedLicensePayload {
        let verified = try paidEntitlementVerifier.verify(
            value,
            context: LicenseTokenVerificationContext(
                expectedType: .license,
                expectedBinding: (.activation, try deviceIdentifier()),
                now: currentDate()
            )
        )
        guard case let .tokenV2(payload) = verified else {
            throw LicenseValidationError.invalidSignature
        }
        return SignedLicensePayload(
            version: payload.v,
            product: LicensingConfiguration.productIdentifier,
            email: "Licensed CmdTab owner",
            licenseID: payload.order,
            issuedAt: ISO8601DateFormatter().string(
                from: Date(timeIntervalSince1970: TimeInterval(payload.iat))
            ),
            purchaserName: nil
        )
    }

    private func normalizeToken(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
    }

    private func serverActivationCredential() -> String? {
        guard let stored = licenseStore.loadLicenseKeySilently() else {
            return nil
        }
        let normalized = normalizeToken(stored)
        if normalized.range(
            of: "^CMDTAB-ACT-[A-Za-z0-9_-]{43}$",
            options: .regularExpression
        ) != nil {
            return normalized
        }
        return (try? validateLicenseKey(normalized)) == nil
            ? nil
            : normalized
    }

    private func deviceIdentifier() throws -> String {
        SHA256.hash(data: try deviceIdentityStore.loadOrCreateSecret())
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func isRevoked(
        payload: SignedLicensePayload,
        entitlementToken: String
    ) -> Bool {
        isLicenseRevoked(payload.licenseID)
            || revocationStore.isRevoked(
                licenseID: tokenRevocationIdentifier(entitlementToken)
            )
    }

    private func isLicenseRevoked(_ licenseID: String) -> Bool {
        // The unprefixed lookup preserves the original one-value tombstone.
        revocationStore.isRevoked(licenseID: licenseID)
            || revocationStore.isRevoked(
                licenseID: licenseRevocationIdentifier(licenseID)
            )
    }

    private func licenseRevocationIdentifier(_ licenseID: String) -> String {
        "license:\(licenseID)"
    }

    private func tokenRevocationIdentifier(_ token: String) -> String {
        let digest = SHA256.hash(data: Data(token.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return "token:\(digest)"
    }

    #if DEBUG
    private func developerOverrideStatus(now: Date) -> LicensingStatus? {
        guard developerSettings.releaseChannel == .test else { return nil }

        switch developerSettings.licensingScenario {
        case .live:
            return nil
        case .freshTrial:
            let startedAt = now
            let endsAt = Self.trialEndDate(startedAt: startedAt)
            return .activeTrial(
                startedAt: startedAt,
                endsAt: endsAt,
                daysRemaining: LicensingConfiguration.trialLengthDays
            )
        case .oneDayLeft:
            let endsAt = now.addingTimeInterval(12 * 60 * 60)
            let startedAt = endsAt.addingTimeInterval(-Self.trialDuration)
            return .activeTrial(
                startedAt: startedAt,
                endsAt: endsAt,
                daysRemaining: 1
            )
        case .expiredTrial:
            let endedAt = now.addingTimeInterval(-(2 * 60 * 60))
            let startedAt = endedAt.addingTimeInterval(-Self.trialDuration)
            return .expired(
                startedAt: startedAt,
                endedAt: endedAt,
                daysOverdue: Self.daysOverdue(since: endedAt, now: now)
            )
        case .simulatedLicensed:
            return .licensed(
                payload: SignedLicensePayload(
                    version: 1,
                    product: LicensingConfiguration.productIdentifier,
                    email: "developer@cmdtab.local",
                    licenseID: "DEV-SIMULATED",
                    issuedAt: iso8601.string(from: now),
                    purchaserName: "Developer Test License"
                ),
                activatedAt: now
            )
        }
    }
    #endif

    private static let anonymousTrialEmailSuffix = "@trial.cmdtab.invalid"
    private static let secondsPerDay: TimeInterval = 24 * 60 * 60
    private static let trialDuration =
        TimeInterval(LicensingConfiguration.trialLengthDays) * secondsPerDay
    private static let trialClaimSerializationTolerance: TimeInterval = 1
    private static let clockRollbackTolerance: TimeInterval = 5 * 60

    private static func visibleTrialEmail(_ claimEmail: String) -> String {
        claimEmail.hasSuffix(anonymousTrialEmailSuffix) ? "" : claimEmail
    }

    private static func trialEndDate(startedAt: Date) -> Date {
        startedAt.addingTimeInterval(trialDuration)
    }

    private static func daysRemaining(until endDate: Date, now: Date) -> Int {
        let remaining = endDate.timeIntervalSince(now)
        return min(
            LicensingConfiguration.trialLengthDays,
            max(1, Int(ceil(remaining / secondsPerDay)))
        )
    }

    private static func daysOverdue(since endDate: Date, now: Date) -> Int {
        max(0, Int(floor(now.timeIntervalSince(endDate) / secondsPerDay)))
    }

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let boundaryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d, yyyy 'at' HH:mm 'UTC'"
        return formatter
    }()
}

private extension Data {
    init?(base64URLEncoded value: String) {
        let remainder = value.count % 4
        let paddingCount = remainder == 0 ? 0 : 4 - remainder
        let padded = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/") + String(repeating: "=", count: paddingCount)
        self.init(base64Encoded: padded)
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
