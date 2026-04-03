import CryptoKit
import Foundation
import XCTest
@testable import CmdTab

@MainActor
final class LicensingControllerTests: XCTestCase {
    func testUnregisteredWithoutServerTrialClaim() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let trialStore = MemoryTrialStartDateStore(date: Calendar.current.date(byAdding: .day, value: -2, to: now))
        let controller = makeController(
            trialStore: trialStore,
            currentDate: { now },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )

        guard case .unregistered = controller.status else {
            return XCTFail("Expected unregistered state")
        }
        XCTAssertFalse(controller.hasUnlockedAccess)
    }

    func testExpiredTrialBlocksAccess() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let trialStore = MemoryTrialStartDateStore(date: Calendar.current.date(byAdding: .day, value: -20, to: now))
        let controller = makeController(
            trialStore: trialStore,
            currentDate: { now },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )

        XCTAssertFalse(controller.hasUnlockedAccess)
        guard case .unregistered = controller.status else {
            return XCTFail("Expected unregistered state")
        }
        XCTAssertFalse(controller.shouldHandleCustomSwitcherShortcut())
    }

    func testSignedLicenseActivatesApp() throws {
        let materials = makeSigningMaterials()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let trialStore = MemoryTrialStartDateStore(date: now)
        let licenseStore = MemoryLicenseKeyStore()
        let activationStore = MemoryLicenseActivationMetadataStore()
        let payloadCacheStore = MemoryLicensedPayloadCacheStore()
        let controller = makeController(
            trialStore: trialStore,
            licenseStore: licenseStore,
            activationMetadataStore: activationStore,
            payloadCacheStore: payloadCacheStore,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64
        )

        let token = try signedToken(
            email: "user@example.com",
            name: "Test User",
            licenseID: "LIC-123",
            privateKey: materials.privateKey,
            issuedAt: now
        )

        XCTAssertTrue(controller.activateLicense(token))

        guard case let .licensed(payload, activatedAt) = controller.status else {
            return XCTFail("Expected licensed state")
        }

        XCTAssertEqual(payload.email, "user@example.com")
        XCTAssertEqual(payload.licenseID, "LIC-123")
        XCTAssertEqual(licenseStore.value, token)
        XCTAssertEqual(activatedAt, now)
        XCTAssertEqual(payloadCacheStore.payload?.licenseID, "LIC-123")
    }

    func testInvalidLicenseIsRejected() {
        let materials = makeSigningMaterials()
        let controller = makeController(publicKeyBase64: materials.publicKeyBase64)

        XCTAssertFalse(controller.activateLicense("CMDTAB1.invalid.payload"))
        XCTAssertFalse(controller.hasUnlockedAccess)
    }

    func testActiveTrialStillHandlesCustomSwitcherShortcut() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let claimStore = MemoryTrialClaimStore(claim: makeTrialClaim(email: "trial@example.com", installID: "install-1", startedAt: now))
        let controller = makeController(
            trialClaimStore: claimStore,
            currentDate: { now },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )

        XCTAssertTrue(controller.shouldHandleCustomSwitcherShortcut())
    }

    func testDeveloperExpiredTrialOverrideInTestChannel() {
        let materials = makeSigningMaterials()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let developerSettings = DeveloperSettings(defaults: defaults, keyPrefix: "CmdTab.test")
        developerSettings.releaseChannel = .test
        developerSettings.licensingScenario = .expiredTrial

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let controller = makeController(
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64,
            developerSettings: developerSettings
        )

        XCTAssertTrue(controller.status.isExpired)
        XCTAssertFalse(controller.hasUnlockedAccess)
    }

    func testDeveloperSimulatedLicenseOverrideInTestChannel() {
        let materials = makeSigningMaterials()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let developerSettings = DeveloperSettings(defaults: defaults, keyPrefix: "CmdTab.test")
        developerSettings.releaseChannel = .test
        developerSettings.licensingScenario = .simulatedLicensed

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let controller = makeController(
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64,
            developerSettings: developerSettings
        )

        guard case let .licensed(payload, activatedAt) = controller.status else {
            return XCTFail("Expected simulated licensed state")
        }

        XCTAssertEqual(payload.email, "developer@cmdtab.local")
        XCTAssertEqual(payload.licenseID, "DEV-SIMULATED")
        XCTAssertEqual(activatedAt, now)
    }

    func testCachedRealLicenseWinsOverDeveloperOverride() {
        let materials = makeSigningMaterials()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let developerSettings = DeveloperSettings(defaults: defaults, keyPrefix: "CmdTab.test")
        developerSettings.releaseChannel = .test
        developerSettings.licensingScenario = .expiredTrial

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload = SignedLicensePayload(
            version: 1,
            product: "cmdtab",
            email: "real@example.com",
            licenseID: "LIC-REAL",
            issuedAt: ISO8601DateFormatter().string(from: now),
            purchaserName: "Real License"
        )

        let controller = makeController(
            payloadCacheStore: MemoryLicensedPayloadCacheStore(payload: payload),
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64,
            developerSettings: developerSettings
        )

        guard case let .licensed(licensedPayload, _) = controller.status else {
            return XCTFail("Expected cached real license to win over developer override")
        }

        XCTAssertEqual(licensedPayload.licenseID, "LIC-REAL")
    }

    func testStableChannelIgnoresDeveloperScenarioOverride() {
        let materials = makeSigningMaterials()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let developerSettings = DeveloperSettings(defaults: defaults, keyPrefix: "CmdTab.test")
        developerSettings.releaseChannel = .stable
        developerSettings.licensingScenario = .expiredTrial

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let claimStore = MemoryTrialClaimStore(
            claim: makeTrialClaim(
                email: "stable@example.com",
                installID: "install-stable",
                startedAt: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
            )
        )
        let controller = makeController(
            trialClaimStore: claimStore,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64,
            developerSettings: developerSettings
        )

        guard case let .activeTrial(_, _, daysRemaining) = controller.status else {
            return XCTFail("Expected live active trial state")
        }

        XCTAssertEqual(daysRemaining, 13)
    }

    func testCachedPayloadPreventsSilentFallbackPromptPath() throws {
        let materials = makeSigningMaterials()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload = SignedLicensePayload(
            version: 1,
            product: "cmdtab",
            email: "cached@example.com",
            licenseID: "LIC-CACHED",
            issuedAt: ISO8601DateFormatter().string(from: now),
            purchaserName: "Cached User"
        )
        let payloadCacheStore = MemoryLicensedPayloadCacheStore(payload: payload)
        let licenseStore = MemoryLicenseKeyStore()
        let activationStore = MemoryLicenseActivationMetadataStore(date: now)

        let controller = makeController(
            licenseStore: licenseStore,
            activationMetadataStore: activationStore,
            payloadCacheStore: payloadCacheStore,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64
        )

        guard case let .licensed(cachedPayload, activatedAt) = controller.status else {
            return XCTFail("Expected cached licensed state")
        }

        XCTAssertEqual(cachedPayload.licenseID, "LIC-CACHED")
        XCTAssertEqual(activatedAt, now)
        XCTAssertEqual(licenseStore.silentLoadCount, 0)
    }

    func testNoCachedPayloadDoesNotTouchKeychainDuringPassiveRefresh() {
        let materials = makeSigningMaterials()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let trialStore = MemoryTrialStartDateStore(date: now)
        let licenseStore = MemoryLicenseKeyStore()

        let controller = makeController(
            trialStore: trialStore,
            licenseStore: licenseStore,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64
        )

        guard case .unregistered = controller.status else {
            return XCTFail("Expected unregistered state")
        }

        XCTAssertEqual(licenseStore.silentLoadCount, 0)
    }

    func testStartTrialRegistrationActivatesTrialState() async {
        let materials = makeSigningMaterials()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let claimStore = MemoryTrialClaimStore()
        let installIDStore = MemoryAppInstallIDStore(value: "install-registration-1")
        let serverClient = MockCmdTabServerClient()
        serverClient.trialResult = .success(
            makeTrialClaim(email: "trial@example.com", installID: "install-registration-1", startedAt: now)
        )

        let controller = makeController(
            trialClaimStore: claimStore,
            installIDStore: installIDStore,
            serverClient: serverClient,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64
        )

        controller.enteredTrialEmail = "trial@example.com"
        let started = await controller.startTrialRegistration()

        XCTAssertTrue(started)
        XCTAssertEqual(serverClient.startTrialCalls.count, 1)
        XCTAssertEqual(serverClient.startTrialCalls.first?.email, "trial@example.com")
        XCTAssertEqual(claimStore.claim?.email, "trial@example.com")

        guard case let .activeTrial(_, _, daysRemaining) = controller.status else {
            return XCTFail("Expected active trial state")
        }

        XCTAssertEqual(daysRemaining, 15)
    }

    func testStartTrialRegistrationShowsBlockedMessage() async {
        let materials = makeSigningMaterials()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let serverClient = MockCmdTabServerClient()
        serverClient.trialResult = .failure(CmdTabServerClientError.blocked("This email has already started a CmdTab trial."))

        let controller = makeController(
            serverClient: serverClient,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64
        )

        controller.enteredTrialEmail = "used@example.com"
        let started = await controller.startTrialRegistration()

        XCTAssertFalse(started)
        XCTAssertEqual(controller.trialMessage?.text, "This email has already started a CmdTab trial.")
        guard case .unregistered = controller.status else {
            return XCTFail("Expected unregistered state after blocked trial registration")
        }
    }

    func testActivatingRealLicenseInTestModeSwitchesScenarioToLive() throws {
        let materials = makeSigningMaterials()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let developerSettings = DeveloperSettings(defaults: defaults, keyPrefix: "CmdTab.test")
        developerSettings.releaseChannel = .test
        developerSettings.licensingScenario = .expiredTrial

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let licenseStore = MemoryLicenseKeyStore()
        let payloadCacheStore = MemoryLicensedPayloadCacheStore()
        let controller = makeController(
            licenseStore: licenseStore,
            payloadCacheStore: payloadCacheStore,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64,
            developerSettings: developerSettings
        )

        let token = try signedToken(
            email: "user@example.com",
            name: "Test User",
            licenseID: "LIC-123",
            privateKey: materials.privateKey,
            issuedAt: now
        )

        XCTAssertTrue(controller.activateLicense(token))
        XCTAssertEqual(developerSettings.licensingScenario, .live)

        guard case let .licensed(payload, _) = controller.status else {
            return XCTFail("Expected licensed state")
        }

        XCTAssertEqual(payload.licenseID, "LIC-123")
    }

    private func makeController(
        trialStore: TrialStartDateStore = MemoryTrialStartDateStore(),
        trialClaimStore: TrialClaimStore = MemoryTrialClaimStore(),
        licenseStore: LicenseKeyStore = MemoryLicenseKeyStore(),
        activationMetadataStore: LicenseActivationMetadataStore = MemoryLicenseActivationMetadataStore(),
        payloadCacheStore: LicensedPayloadCacheStore = MemoryLicensedPayloadCacheStore(),
        installIDStore: AppInstallIDStore = MemoryAppInstallIDStore(),
        serverClient: CmdTabServerClient = MockCmdTabServerClient(),
        currentDate: @escaping () -> Date = Date.init,
        publicKeyBase64: String,
        developerSettings: DeveloperSettings? = nil
    ) -> LicensingController {
        LicensingController(
            trialStore: trialStore,
            trialClaimStore: trialClaimStore,
            licenseStore: licenseStore,
            activationMetadataStore: activationMetadataStore,
            payloadCacheStore: payloadCacheStore,
            installIDStore: installIDStore,
            serverClient: serverClient,
            currentDate: currentDate,
            publicKeyDERBase64: publicKeyBase64,
            developerSettings: developerSettings ?? DeveloperSettings(
                defaults: UserDefaults(suiteName: UUID().uuidString)!,
                keyPrefix: UUID().uuidString
            )
        )
    }

    private func makeSigningMaterials() -> (privateKey: P256.Signing.PrivateKey, publicKeyBase64: String) {
        let privateKey = P256.Signing.PrivateKey()
        let publicKeyBase64 = privateKey.publicKey.derRepresentation.base64EncodedString()
        return (privateKey, publicKeyBase64)
    }

    private func signedToken(
        email: String,
        name: String?,
        licenseID: String,
        privateKey: P256.Signing.PrivateKey,
        issuedAt: Date
    ) throws -> String {
        let payload = SignedLicensePayload(
            version: 1,
            product: "cmdtab",
            email: email,
            licenseID: licenseID,
            issuedAt: ISO8601DateFormatter().string(from: issuedAt),
            purchaserName: name
        )
        let payloadData = try JSONEncoder().encode(payload)
        let signature = try privateKey.signature(for: payloadData)
        return [
            "CMDTAB1",
            payloadData.base64URLEncodedString(),
            signature.derRepresentation.base64URLEncodedString(),
        ].joined(separator: ".")
    }

    private func makeTrialClaim(email: String, installID: String, startedAt: Date) -> TrialClaimRecord {
        let endsAt = Calendar.current.date(byAdding: .day, value: LicensingConfiguration.trialLengthDays, to: startedAt) ?? startedAt
        return TrialClaimRecord(
            id: UUID().uuidString,
            email: email,
            installID: installID,
            startedAt: ISO8601DateFormatter().string(from: startedAt),
            endsAt: ISO8601DateFormatter().string(from: endsAt),
            appVersion: "1.0.0",
            osVersion: "14.0.0"
        )
    }
}

private final class MemoryTrialStartDateStore: TrialStartDateStore {
    var date: Date?

    init(date: Date? = nil) {
        self.date = date
    }

    func loadTrialStartDate() -> Date? {
        date
    }

    func saveTrialStartDate(_ date: Date) {
        self.date = date
    }
}

private final class MemoryLicenseKeyStore: LicenseKeyStore {
    var value: String?
    var silentLoadCount = 0

    func loadLicenseKey() -> String? {
        value
    }

    func loadLicenseKeySilently() -> String? {
        silentLoadCount += 1
        return value
    }

    func saveLicenseKey(_ value: String) throws {
        self.value = value
    }

    func clearLicenseKey() throws {
        value = nil
    }
}

private final class MemoryTrialClaimStore: TrialClaimStore {
    var claim: TrialClaimRecord?

    init(claim: TrialClaimRecord? = nil) {
        self.claim = claim
    }

    func loadClaim() -> TrialClaimRecord? {
        claim
    }

    func saveClaim(_ claim: TrialClaimRecord) {
        self.claim = claim
    }

    func clearClaim() {
        claim = nil
    }
}

private final class MemoryAppInstallIDStore: AppInstallIDStore {
    var value: String?

    init(value: String? = nil) {
        self.value = value
    }

    func loadInstallID() -> String? {
        value
    }

    func saveInstallID(_ value: String) {
        self.value = value
    }
}

private final class MemoryLicenseActivationMetadataStore: LicenseActivationMetadataStore {
    var date: Date?

    init(date: Date? = nil) {
        self.date = date
    }

    func loadActivationDate() -> Date? {
        date
    }

    func saveActivationDate(_ date: Date) {
        self.date = date
    }

    func clearActivationDate() {
        date = nil
    }
}

private final class MemoryLicensedPayloadCacheStore: LicensedPayloadCacheStore {
    var payload: SignedLicensePayload?

    init(payload: SignedLicensePayload? = nil) {
        self.payload = payload
    }

    func loadPayload() -> SignedLicensePayload? {
        payload
    }

    func savePayload(_ payload: SignedLicensePayload) {
        self.payload = payload
    }

    func clearPayload() {
        payload = nil
    }
}

private final class MockCmdTabServerClient: CmdTabServerClient {
    struct StartTrialCall: Equatable {
        let email: String
        let installID: String
        let appVersion: String
        let osVersion: String
    }

    var trialResult: Result<TrialClaimRecord, Error>?
    var startTrialCalls: [StartTrialCall] = []
    var telemetryEventNames: [String] = []

    func startTrial(email: String, installID: String, appVersion: String, osVersion: String) async throws -> TrialClaimRecord {
        startTrialCalls.append(
            StartTrialCall(
                email: email,
                installID: installID,
                appVersion: appVersion,
                osVersion: osVersion
            )
        )
        guard let trialResult else {
            throw CmdTabServerClientError.invalidResponse
        }
        return try trialResult.get()
    }

    func sendAppTelemetry(
        installID: String,
        eventName: String,
        licenseState: String,
        licenseID: String?,
        appVersion: String,
        osVersion: String
    ) async {
        telemetryEventNames.append(eventName)
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
