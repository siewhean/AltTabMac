import XCTest
@testable import CmdTab

@MainActor
final class AppTelemetryReporterTests: XCTestCase {
    func testPreferencesDefaultToDisabledAndPersistChoice() {
        let defaults = makeDefaults()
        let preferences = TelemetryPreferences(defaults: defaults, key: "telemetry")

        XCTAssertFalse(preferences.isEnabled)

        preferences.setEnabled(true)

        XCTAssertTrue(TelemetryPreferences(defaults: defaults, key: "telemetry").isEnabled)
    }

    func testDisabledReporterDoesNotReadInstallIDOrSendAnyEvents() async {
        let preferences = TelemetryPreferences(defaults: makeDefaults(), key: "telemetry")
        let installIDStore = CountingInstallIDStore()
        let transport = RecordingTelemetryTransport()
        let reporter = AppTelemetryReporter(
            preferences: preferences,
            installIDStore: installIDStore,
            transport: transport
        )
        let controller = makeLicensingController()

        reporter.startSession(licensingController: controller)
        reporter.trackTrialStarted(licensingController: controller)
        reporter.trackLicenseActivation(licensingController: controller)
        await Task.yield()

        XCTAssertEqual(installIDStore.loadCount, 0)
        XCTAssertEqual(installIDStore.saveCount, 0)
        let eventNames = await transport.eventNames()
        XCTAssertEqual(eventNames, [])
        XCTAssertFalse(reporter.hasActiveSession)
    }

    func testEnablingStartsOnlyOneSessionAndDisablingCancelsIt() async {
        let preferences = TelemetryPreferences(defaults: makeDefaults(), key: "telemetry")
        let installIDStore = CountingInstallIDStore()
        let transport = RecordingTelemetryTransport()
        let reporter = AppTelemetryReporter(
            preferences: preferences,
            installIDStore: installIDStore,
            transport: transport,
            heartbeatSleep: {
                try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            }
        )
        let controller = makeLicensingController()

        reporter.setEnabled(true, licensingController: controller)
        reporter.startSession(licensingController: controller)
        await waitUntil { await transport.eventNames() == ["app_activation"] }

        XCTAssertTrue(reporter.hasActiveSession)
        XCTAssertEqual(installIDStore.saveCount, 1)
        let enabledEventNames = await transport.eventNames()
        XCTAssertEqual(enabledEventNames, ["app_activation"])

        reporter.setEnabled(false, licensingController: controller)

        XCTAssertFalse(reporter.hasActiveSession)
        XCTAssertFalse(preferences.isEnabled)
        let disabledEventNames = await transport.eventNames()
        XCTAssertEqual(disabledEventNames, ["app_activation"])
    }

    func testTelemetryEventsUseInjectedTransportOnlyAfterConsent() async {
        let preferences = TelemetryPreferences(defaults: makeDefaults(), key: "telemetry")
        let transport = RecordingTelemetryTransport()
        let reporter = AppTelemetryReporter(
            preferences: preferences,
            installIDStore: CountingInstallIDStore(),
            transport: transport
        )
        let controller = makeLicensingController()

        reporter.setEnabled(true, licensingController: controller)
        reporter.trackTrialStarted(licensingController: controller)
        reporter.trackLicenseActivation(licensingController: controller)
        await waitUntil {
            Set(await transport.eventNames()) == Set([
                "app_activation",
                "trial_started",
                "license_activated",
            ])
        }
        await waitUntil { reporter.pendingActionTaskCount == 0 }

        let eventNames = await transport.eventNames()
        XCTAssertEqual(Set(eventNames), Set(["app_activation", "trial_started", "license_activated"]))
        reporter.stopSession()
    }

    func testWithdrawalCancelsPendingActionTelemetry() async {
        let preferences = TelemetryPreferences(defaults: makeDefaults(), key: "telemetry")
        let transport = SuspendingActionTelemetryTransport()
        let reporter = AppTelemetryReporter(
            preferences: preferences,
            installIDStore: CountingInstallIDStore(),
            transport: transport,
            heartbeatSleep: {
                try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            }
        )
        let controller = makeLicensingController()

        reporter.setEnabled(true, licensingController: controller)
        reporter.trackLicenseActivation(licensingController: controller)
        await waitUntil {
            await transport.startedEventNames().contains("license_activated")
        }

        reporter.setEnabled(false, licensingController: controller)
        await waitUntil {
            await transport.cancelledEventNames().contains("license_activated")
        }

        XCTAssertEqual(reporter.pendingActionTaskCount, 0)
        let completedEventNames = await transport.completedEventNames()
        XCTAssertFalse(
            completedEventNames.contains("license_activated"),
            "Withdrawing consent must cancel an in-flight action before its send completes."
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppTelemetryReporterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeLicensingController() -> LicensingController {
        LicensingController(
            trialStore: TelemetryMemoryTrialStartDateStore(),
            trialClaimStore: TelemetryMemoryTrialClaimStore(),
            licenseStore: TelemetryMemoryLicenseKeyStore(),
            activationMetadataStore: TelemetryMemoryActivationStore(),
            payloadCacheStore: TelemetryMemoryPayloadCacheStore(),
            installIDStore: CountingInstallIDStore(),
            serverClient: TelemetryNoopServerClient()
        )
    }

    private func waitUntil(
        _ predicate: @escaping () async -> Bool
    ) async {
        for _ in 0..<100 {
            if await predicate() {
                return
            }
            await Task.yield()
        }
        XCTFail("Timed out waiting for telemetry event.")
    }
}

private final class CountingInstallIDStore: AppInstallIDStore {
    private(set) var loadCount = 0
    private(set) var saveCount = 0
    private var value: String?

    func loadInstallID() -> String? {
        loadCount += 1
        return value
    }

    func saveInstallID(_ value: String) {
        saveCount += 1
        self.value = value
    }
}

private actor RecordingTelemetryTransport: AppTelemetryTransport {
    private var names: [String] = []

    func sendAppTelemetry(
        installID: String,
        eventName: String,
        licenseState: String,
        licenseID: String?,
        appVersion: String,
        osVersion: String
    ) async {
        names.append(eventName)
    }

    func eventNames() -> [String] {
        names
    }
}

private actor SuspendingActionTelemetryTransport: AppTelemetryTransport {
    private var started: [String] = []
    private var completed: [String] = []
    private var cancelled: [String] = []

    func sendAppTelemetry(
        installID: String,
        eventName: String,
        licenseState: String,
        licenseID: String?,
        appVersion: String,
        osVersion: String
    ) async {
        started.append(eventName)
        guard eventName == "license_activated" else {
            completed.append(eventName)
            return
        }

        do {
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            completed.append(eventName)
        } catch {
            cancelled.append(eventName)
        }
    }

    func startedEventNames() -> [String] {
        started
    }

    func completedEventNames() -> [String] {
        completed
    }

    func cancelledEventNames() -> [String] {
        cancelled
    }
}

private final class TelemetryMemoryTrialStartDateStore: TrialStartDateStore {
    func loadTrialStartDate() -> Date? { nil }
    func saveTrialStartDate(_ date: Date) {}
}

private final class TelemetryMemoryTrialClaimStore: TrialClaimStore {
    func loadClaim() -> TrialClaimRecord? { nil }
    func saveClaim(_ claim: TrialClaimRecord) {}
    func clearClaim() {}
}

private final class TelemetryMemoryLicenseKeyStore: LicenseKeyStore {
    func loadLicenseKey() -> String? { nil }
    func saveLicenseKey(_ value: String) throws {}
    func clearLicenseKey() throws {}
}

private final class TelemetryMemoryActivationStore: LicenseActivationMetadataStore {
    func loadActivationDate() -> Date? { nil }
    func saveActivationDate(_ date: Date) {}
    func clearActivationDate() {}
}

private final class TelemetryMemoryPayloadCacheStore: LicensedPayloadCacheStore {
    func loadPayload() -> SignedLicensePayload? { nil }
    func savePayload(_ payload: SignedLicensePayload) {}
    func clearPayload() {}
}

private final class TelemetryNoopServerClient: CmdTabServerClient {
    func startTrial(
        email: String,
        installID: String,
        appVersion: String,
        osVersion: String
    ) async throws -> TrialClaimRecord {
        throw CmdTabServerClientError.invalidResponse
    }
}
