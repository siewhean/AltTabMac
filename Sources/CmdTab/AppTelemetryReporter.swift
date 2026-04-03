import Foundation

struct TrialClaimResponse: Decodable {
    let ok: Bool
    let alreadyRegistered: Bool?
    let claim: TrialClaimDTO?
    let code: String?
    let message: String?
}

struct TrialClaimDTO: Decodable {
    let id: String
    let email: String
    let installId: String
    let startedAt: String
    let endsAt: String
    let appVersion: String?
    let osVersion: String?
}

protocol CmdTabServerClient {
    func startTrial(email: String, installID: String, appVersion: String, osVersion: String) async throws -> TrialClaimRecord
    func sendAppTelemetry(
        installID: String,
        eventName: String,
        licenseState: String,
        licenseID: String?,
        appVersion: String,
        osVersion: String
    ) async
}

enum CmdTabServerClientError: LocalizedError {
    case invalidResponse
    case blocked(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server response was invalid."
        case let .blocked(message):
            return message
        }
    }
}

final class LiveCmdTabServerClient: CmdTabServerClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func startTrial(email: String, installID: String, appVersion: String, osVersion: String) async throws -> TrialClaimRecord {
        var request = URLRequest(url: LicensingConfiguration.trialStartAPIURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "installId": installID,
            "appVersion": appVersion,
            "osVersion": osVersion,
        ])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CmdTabServerClientError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(TrialClaimResponse.self, from: data)
        guard httpResponse.statusCode < 400, decoded.ok, let claim = decoded.claim else {
            throw CmdTabServerClientError.blocked(decoded.message ?? "The trial could not be started.")
        }

        return TrialClaimRecord(
            id: claim.id,
            email: claim.email,
            installID: claim.installId,
            startedAt: claim.startedAt,
            endsAt: claim.endsAt,
            appVersion: claim.appVersion,
            osVersion: claim.osVersion
        )
    }

    func sendAppTelemetry(
        installID: String,
        eventName: String,
        licenseState: String,
        licenseID: String?,
        appVersion: String,
        osVersion: String
    ) async {
        var request = URLRequest(url: LicensingConfiguration.appTelemetryAPIURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "installId": installID,
            "eventName": eventName,
            "licenseState": licenseState,
            "licenseId": licenseID as Any,
            "appVersion": appVersion,
            "osVersion": osVersion,
            "occurredAt": ISO8601DateFormatter().string(from: Date()),
        ])

        do {
            _ = try await session.data(for: request)
        } catch {
            // Best-effort only.
        }
    }
}

@MainActor
final class AppTelemetryReporter {
    static let shared = AppTelemetryReporter()

    private let installIDStore: AppInstallIDStore
    private let client: CmdTabServerClient
    private var heartbeatTask: Task<Void, Never>?

    init(
        installIDStore: AppInstallIDStore = UserDefaultsAppInstallIDStore(),
        client: CmdTabServerClient = LiveCmdTabServerClient()
    ) {
        self.installIDStore = installIDStore
        self.client = client
    }

    func installID() -> String {
        if let existing = installIDStore.loadInstallID(), !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString.lowercased()
        installIDStore.saveInstallID(generated)
        return generated
    }

    func startSession(licensingController: LicensingController) {
        let installID = installID()
        Task {
            await client.sendAppTelemetry(
                installID: installID,
                eventName: "app_activation",
                licenseState: licensingController.telemetryLicenseState,
                licenseID: licensingController.currentLicenseID,
                appVersion: licensingController.appVersion,
                osVersion: licensingController.osVersion
            )
        }

        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 60 * 1_000_000_000)
                if Task.isCancelled { break }
                await client.sendAppTelemetry(
                    installID: installID,
                    eventName: "app_heartbeat",
                    licenseState: licensingController.telemetryLicenseState,
                    licenseID: licensingController.currentLicenseID,
                    appVersion: licensingController.appVersion,
                    osVersion: licensingController.osVersion
                )
            }
        }
    }

    func trackLicenseActivation(licensingController: LicensingController) {
        let installID = installID()
        Task {
            await client.sendAppTelemetry(
                installID: installID,
                eventName: "license_activated",
                licenseState: licensingController.telemetryLicenseState,
                licenseID: licensingController.currentLicenseID,
                appVersion: licensingController.appVersion,
                osVersion: licensingController.osVersion
            )
        }
    }

    func trackTrialStarted(licensingController: LicensingController) {
        let installID = installID()
        Task {
            await client.sendAppTelemetry(
                installID: installID,
                eventName: "trial_started",
                licenseState: licensingController.telemetryLicenseState,
                licenseID: licensingController.currentLicenseID,
                appVersion: licensingController.appVersion,
                osVersion: licensingController.osVersion
            )
        }
    }
}
