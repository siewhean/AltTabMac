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

enum LicensingMessageTone {
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
    static let shared = LicensingController()

    @Published private(set) var status: LicensingStatus
    @Published var enteredLicenseKey = ""
    @Published var enteredTrialEmail = ""
    @Published private(set) var isStartingTrial = false
    @Published private(set) var trialMessage: LicensingMessage?
    @Published private(set) var licenseMessage: LicensingMessage?

    private let trialStore: TrialStartDateStore
    private let trialClaimStore: TrialClaimStore
    private let licenseStore: LicenseKeyStore
    private let activationMetadataStore: LicenseActivationMetadataStore
    private let payloadCacheStore: LicensedPayloadCacheStore
    private let installIDStore: AppInstallIDStore
    private let serverClient: CmdTabServerClient
    private let currentDate: () -> Date
    private let publicKeyDERBase64: String
    private let developerSettings: DeveloperSettings
    private let iso8601 = ISO8601DateFormatter()

    init(
        trialStore: TrialStartDateStore = UserDefaultsTrialStartDateStore(),
        trialClaimStore: TrialClaimStore = UserDefaultsTrialClaimStore(),
        licenseStore: LicenseKeyStore = KeychainLicenseKeyStore(),
        activationMetadataStore: LicenseActivationMetadataStore = UserDefaultsLicenseActivationMetadataStore(),
        payloadCacheStore: LicensedPayloadCacheStore = UserDefaultsLicensedPayloadCacheStore(),
        installIDStore: AppInstallIDStore = UserDefaultsAppInstallIDStore(),
        serverClient: CmdTabServerClient = LiveCmdTabServerClient(),
        currentDate: @escaping () -> Date = Date.init,
        publicKeyDERBase64: String = LicensingConfiguration.publicKeyDERBase64,
        developerSettings: DeveloperSettings? = nil
    ) {
        self.trialStore = trialStore
        self.trialClaimStore = trialClaimStore
        self.licenseStore = licenseStore
        self.activationMetadataStore = activationMetadataStore
        self.payloadCacheStore = payloadCacheStore
        self.installIDStore = installIDStore
        self.serverClient = serverClient
        self.currentDate = currentDate
        self.publicKeyDERBase64 = publicKeyDERBase64
        self.developerSettings = developerSettings ?? .shared

        self.status = .unregistered

        refreshStatus()
    }

    var hasUnlockedAccess: Bool {
        !status.isExpired && !status.requiresTrialRegistration
    }

    func shouldHandleCustomSwitcherShortcut() -> Bool {
        refreshStatus()
        return !status.isExpired && !status.requiresTrialRegistration
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
            return "Use your email to register this Mac and start the 14-day trial. This helps prevent repeated trial abuse."
        case let .licensed(payload, activatedAt):
            let issuedAt = payload.issuedDate.map { Self.displayFormatter.string(from: $0) } ?? payload.issuedAt
            let activatedCopy = activatedAt.map { "Activated \(Self.displayFormatter.string(from: $0))." } ?? "Activated on this Mac."
            return "License \(payload.licenseID) for \(payload.email). Issued \(issuedAt). \(activatedCopy)"
        case let .activeTrial(startedAt, endsAt, _):
            return "Started \(Self.displayFormatter.string(from: startedAt)). Ends \(Self.displayFormatter.string(from: endsAt))."
        case let .expired(_, endedAt, daysOverdue):
            let overdueCopy = daysOverdue <= 1 ? "The trial expired yesterday." : "The trial expired \(daysOverdue) days ago."
            return "\(overdueCopy) Buy CmdTab or enter a valid license to keep using the switcher. Trial ended \(Self.displayFormatter.string(from: endedAt))."
        }
    }

    nonisolated static let didChangeNotification = Notification.Name("LicensingController.didChange")

    func refreshStatus() {
        let oldStatus = status
        let now = currentDate()

        if let cachedPayload = payloadCacheStore.loadPayload() {
            status = .licensed(payload: cachedPayload, activatedAt: activationMetadataStore.loadActivationDate())
            if status != oldStatus {
                NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
            }
            return
        }

        if let overrideStatus = developerOverrideStatus(now: now) {
            status = overrideStatus
            if status != oldStatus {
                NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
            }
            return
        }

        if let claim = trialClaimStore.loadClaim(),
           let startedAt = claim.startedDate,
           let endsAt = claim.endsDate {
            enteredTrialEmail = claim.email
            if now < endsAt {
                status = .activeTrial(
                    startedAt: startedAt,
                    endsAt: endsAt,
                    daysRemaining: Self.daysRemaining(until: endsAt, now: now)
                )
            } else {
                let overdue = max(1, Calendar.current.dateComponents([.day], from: endsAt, to: now).day ?? 1)
                status = .expired(startedAt: startedAt, endedAt: endsAt, daysOverdue: overdue)
            }
            if status != oldStatus {
                NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
            }
            return
        }

        status = .unregistered
        if status != oldStatus {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        }
    }

    @discardableResult
    func startTrialRegistration() async -> Bool {
        let normalizedEmail = enteredTrialEmail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
            trialMessage = LicensingMessage(tone: .error, text: "Enter a valid email to start the trial.")
            return false
        }

        isStartingTrial = true
        defer { isStartingTrial = false }

        do {
            let claim = try await serverClient.startTrial(
                email: normalizedEmail,
                installID: installID,
                appVersion: appVersion,
                osVersion: osVersion
            )
            trialClaimStore.saveClaim(claim)
            enteredTrialEmail = claim.email
            trialMessage = LicensingMessage(
                tone: .success,
                text: "Your 14-day trial is active on this Mac."
            )
            refreshStatus()
            AppTelemetryReporter.shared.trackTrialStarted(licensingController: self)
            return true
        } catch {
            if case let CmdTabServerClientError.blocked(message) = error {
                trialMessage = LicensingMessage(tone: .error, text: message)
                refreshStatus()
                return false
            }

            let startedDate = currentDate()
            let endsDate = Calendar.current.date(byAdding: .day, value: 14, to: startedDate) ?? startedDate.addingTimeInterval(14 * 86400)
            let provisionalClaim = TrialClaimRecord(
                id: "local_offline_\(UUID().uuidString.lowercased())",
                email: normalizedEmail,
                installID: installID,
                startedAt: iso8601.string(from: startedDate),
                endsAt: iso8601.string(from: endsDate),
                appVersion: appVersion,
                osVersion: osVersion
            )
            trialClaimStore.saveClaim(provisionalClaim)
            enteredTrialEmail = normalizedEmail
            trialMessage = LicensingMessage(
                tone: .warning,
                text: "Offline: Started local 14-day trial. Registration will sync when online."
            )
            refreshStatus()
            return true
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
        enteredTrialEmail = ""
        refreshStatus()
    }

    func resetLiveTrialFromToday(clearSavedLicense: Bool) {
        trialClaimStore.clearClaim()
        trialStore.saveTrialStartDate(.distantPast)
        enteredTrialEmail = ""
        if clearSavedLicense {
            try? licenseStore.clearLicenseKey()
            activationMetadataStore.clearActivationDate()
            payloadCacheStore.clearPayload()
            enteredLicenseKey = ""
        }

        if developerSettings.releaseChannel == .test {
            developerSettings.licensingScenario = .live
        }

        refreshStatus()
        trialMessage = LicensingMessage(
            tone: .success,
            text: clearSavedLicense
                ? "The saved license and trial registration were cleared on this Mac."
                : "The saved trial registration was cleared on this Mac."
        )
    }

    @discardableResult
    func activateEnteredLicenseKey() -> Bool {
        activateLicense(enteredLicenseKey)
    }

    static func isValidKeyFormat(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8, trimmed.count <= 2048 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./+=:"))
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    @discardableResult
    func activateLicense(_ value: String) -> Bool {
        do {
            let normalized = normalizeToken(value)
            guard Self.isValidKeyFormat(normalized) else {
                licenseMessage = LicensingMessage(tone: .error, text: "Enter a valid license key format.")
                refreshStatus()
                return false
            }
            let payload = try validateLicenseKey(normalized)
            try licenseStore.saveLicenseKey(normalized)
            activationMetadataStore.saveActivationDate(currentDate())
            payloadCacheStore.savePayload(payload)
            if developerSettings.releaseChannel == .test {
                developerSettings.licensingScenario = .live
            }
            enteredLicenseKey = normalized
            status = .licensed(payload: payload, activatedAt: activationMetadataStore.loadActivationDate())
            licenseMessage = LicensingMessage(
                tone: .success,
                text: "CmdTab is now activated for \(payload.email)."
            )
            AppTelemetryReporter.shared.trackLicenseActivation(licensingController: self)
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
    func ensureUsageAllowed(openLicensing: () -> Void) -> Bool {
        refreshStatus()
        guard !status.isExpired, !status.requiresTrialRegistration else {
            if status.requiresTrialRegistration {
                trialMessage = LicensingMessage(
                    tone: .warning,
                    text: "Start the trial with your email before using CmdTab on this Mac."
                )
            } else {
                licenseMessage = LicensingMessage(
                    tone: .warning,
                    text: "The trial ended. Buy CmdTab or enter a valid license to keep using the switcher."
                )
            }
            openLicensing()
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

    private func normalizeToken(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
    }

    private func developerOverrideStatus(now: Date) -> LicensingStatus? {
        #if DEBUG
        guard developerSettings.releaseChannel == .test else { return nil }

        switch developerSettings.licensingScenario {
        case .live:
            return nil
        case .freshTrial:
            let startedAt = now
            let endsAt = Calendar.current.date(byAdding: .day, value: LicensingConfiguration.trialLengthDays, to: startedAt) ?? startedAt
            return .activeTrial(
                startedAt: startedAt,
                endsAt: endsAt,
                daysRemaining: LicensingConfiguration.trialLengthDays
            )
        case .oneDayLeft:
            let endsAt = now.addingTimeInterval(12 * 60 * 60)
            let startedAt = Calendar.current.date(byAdding: .day, value: -LicensingConfiguration.trialLengthDays, to: endsAt) ?? now
            return .activeTrial(
                startedAt: startedAt,
                endsAt: endsAt,
                daysRemaining: 1
            )
        case .expiredTrial:
            let endedAt = now.addingTimeInterval(-(2 * 60 * 60))
            let startedAt = Calendar.current.date(byAdding: .day, value: -LicensingConfiguration.trialLengthDays, to: endedAt) ?? endedAt
            return .expired(
                startedAt: startedAt,
                endedAt: endedAt,
                daysOverdue: 1
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
        #else
        return nil
        #endif
    }

    private static func daysRemaining(until endDate: Date, now: Date) -> Int {
        let components = Calendar.current.dateComponents([.day], from: now, to: endDate)
        return max(1, (components.day ?? 0) + 1)
    }

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
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
