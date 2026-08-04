import Foundation

struct TrialClaimResponse: Decodable {
    let ok: Bool
    let alreadyRegistered: Bool?
    let claim: TrialClaimDTO?
    let code: String?
    let message: String?
    let entitlementToken: String?
    let serverTime: String?
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

struct LicensedDeviceDTO: Decodable, Equatable {
    let deviceId: String
    let deviceName: String
    let activatedAt: String
    let isCurrent: Bool?

    init(
        deviceId: String,
        deviceName: String,
        activatedAt: String,
        isCurrent: Bool? = nil
    ) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.activatedAt = activatedAt
        self.isCurrent = isCurrent
    }
}

struct LicenseDeviceResponse: Decodable {
    let ok: Bool
    let code: String?
    let message: String?
    let devices: [LicensedDeviceDTO]?
    let entitlementToken: String?
    let currentActivationActive: Bool?
}

struct LicenseActivationResult: Equatable {
    let devices: [LicensedDeviceDTO]
    let entitlementToken: String
}

struct LicenseDeviceListResult: Equatable {
    let devices: [LicensedDeviceDTO]
    let currentActivationActive: Bool?
}

protocol CmdTabServerClient {
    func startTrial(email: String, installID: String, appVersion: String, osVersion: String) async throws -> TrialClaimRecord
    func activateLicense(
        licenseKey: String,
        deviceID: String,
        deviceName: String
    ) async throws -> LicenseActivationResult
    func deactivateLicense(
        licenseKey: String,
        deviceID: String
    ) async throws -> [LicensedDeviceDTO]
    func listDevices(licenseKey: String) async throws -> [LicensedDeviceDTO]
    func listDevices(
        licenseKey: String,
        deviceID: String
    ) async throws -> [LicensedDeviceDTO]
    func listDeviceStatus(
        licenseKey: String,
        deviceID: String
    ) async throws -> LicenseDeviceListResult
}

extension CmdTabServerClient {
    func activateLicense(
        licenseKey: String,
        deviceID: String,
        deviceName: String
    ) async throws -> LicenseActivationResult {
        throw CmdTabServerClientError.invalidResponse
    }

    func deactivateLicense(
        licenseKey: String,
        deviceID: String
    ) async throws -> [LicensedDeviceDTO] {
        throw CmdTabServerClientError.invalidResponse
    }

    func listDevices(licenseKey: String) async throws -> [LicensedDeviceDTO] {
        throw CmdTabServerClientError.invalidResponse
    }

    func listDevices(
        licenseKey: String,
        deviceID: String
    ) async throws -> [LicensedDeviceDTO] {
        try await listDevices(licenseKey: licenseKey)
    }

    func listDeviceStatus(
        licenseKey: String,
        deviceID: String
    ) async throws -> LicenseDeviceListResult {
        LicenseDeviceListResult(
            devices: try await listDevices(
                licenseKey: licenseKey,
                deviceID: deviceID
            ),
            currentActivationActive: nil
        )
    }
}

enum AppTelemetryEventName: String, CaseIterable, Codable, Sendable {
    case appActivation = "app_activation"
    case appHeartbeat = "app_heartbeat"
    case licenseActivated = "license_activated"
    case trialStarted = "trial_started"
}

enum AppTelemetryLicenseState: String, CaseIterable, Codable, Sendable {
    case unregistered
    case trialActive = "trial_active"
    case trialExpired = "trial_expired"
    case licensed
}

/// The complete, intentionally fixed native telemetry wire contract. It has no
/// extensibility bag and no stable identifier, so local window data, device
/// identifiers, tokens, and secrets cannot enter the serialized request.
struct AppTelemetryPayload: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case eventName
        case licenseState
        case appVersion
        case osVersion
        case occurredAt
    }

    let eventName: AppTelemetryEventName
    let licenseState: AppTelemetryLicenseState
    let appVersion: String
    let osVersion: String
    let occurredAt: Date

    func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

protocol AppTelemetryTransport {
    func sendAppTelemetry(_ payload: AppTelemetryPayload) async
}

@MainActor
protocol AppTelemetryReporting: AnyObject {
    func trackLicenseActivation(licensingController: LicensingController)
    func trackTrialStarted(licensingController: LicensingController)
}

enum CmdTabServerClientError: LocalizedError {
    case invalidResponse
    case blocked(String)
    case licenseRevoked

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server response was invalid."
        case let .blocked(message):
            return message
        case .licenseRevoked:
            return "This license has been revoked."
        }
    }
}

final class LiveCmdTabServerClient: CmdTabServerClient, AppTelemetryTransport {
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
            osVersion: claim.osVersion,
            entitlementToken: decoded.entitlementToken,
            validatedAt: decoded.serverTime
        )
    }

    func activateLicense(
        licenseKey: String,
        deviceID: String,
        deviceName: String
    ) async throws -> LicenseActivationResult {
        let response = try await sendLicenseDeviceRequest(
            url: LicensingConfiguration.licenseActivationAPIURL,
            body: [
                "licenseKey": licenseKey,
                "deviceId": deviceID,
                "deviceName": deviceName,
            ]
        )
        guard let entitlementToken = response.entitlementToken, !entitlementToken.isEmpty else {
            throw CmdTabServerClientError.invalidResponse
        }
        return LicenseActivationResult(
            devices: response.devices ?? [],
            entitlementToken: entitlementToken
        )
    }

    func deactivateLicense(
        licenseKey: String,
        deviceID: String
    ) async throws -> [LicensedDeviceDTO] {
        let response = try await sendLicenseDeviceRequest(
            url: LicensingConfiguration.licenseDeactivationAPIURL,
            body: [
                "licenseKey": licenseKey,
                "deviceId": deviceID,
            ]
        )
        return response.devices ?? []
    }

    func listDevices(licenseKey: String) async throws -> [LicensedDeviceDTO] {
        try await listDevices(licenseKey: licenseKey, deviceID: "")
    }

    func listDevices(
        licenseKey: String,
        deviceID: String
    ) async throws -> [LicensedDeviceDTO] {
        var request = URLRequest(url: LicensingConfiguration.licenseDevicesAPIURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(licenseKey)", forHTTPHeaderField: "Authorization")
        if !deviceID.isEmpty {
            request.setValue(deviceID, forHTTPHeaderField: "X-CmdTab-Device-ID")
        }
        return try await decodeLicenseDeviceResponse(request).devices ?? []
    }

    func listDeviceStatus(
        licenseKey: String,
        deviceID: String
    ) async throws -> LicenseDeviceListResult {
        var request = URLRequest(url: LicensingConfiguration.licenseDevicesAPIURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(licenseKey)", forHTTPHeaderField: "Authorization")
        request.setValue(deviceID, forHTTPHeaderField: "X-CmdTab-Device-ID")
        let response = try await decodeLicenseDeviceResponse(request)
        return LicenseDeviceListResult(
            devices: response.devices ?? [],
            currentActivationActive: response.currentActivationActive
        )
    }

    private func sendLicenseDeviceRequest(
        url: URL,
        body: [String: String]
    ) async throws -> LicenseDeviceResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await decodeLicenseDeviceResponse(request)
    }

    private func decodeLicenseDeviceResponse(
        _ request: URLRequest
    ) async throws -> LicenseDeviceResponse {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              let decoded = try? JSONDecoder().decode(LicenseDeviceResponse.self, from: data) else {
            throw CmdTabServerClientError.invalidResponse
        }
        guard httpResponse.statusCode < 400, decoded.ok else {
            if decoded.code == "license_revoked" {
                throw CmdTabServerClientError.licenseRevoked
            }
            throw CmdTabServerClientError.blocked(
                decoded.message ?? "The license request could not be completed."
            )
        }
        return decoded
    }

    func sendAppTelemetry(_ payload: AppTelemetryPayload) async {
        var request = URLRequest(url: LicensingConfiguration.appTelemetryAPIURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let body = try? payload.encodedJSON() else {
            return
        }
        request.httpBody = body

        do {
            _ = try await session.data(for: request)
        } catch {
            // Best-effort only.
        }
    }
}

@MainActor
final class AppTelemetryReporter: AppTelemetryReporting {
    static let shared = AppTelemetryReporter()

    typealias HeartbeatSleep = @Sendable () async throws -> Void

    private let preferences: TelemetryPreferences
    private let transport: AppTelemetryTransport
    private let heartbeatSleep: HeartbeatSleep
    private var heartbeatTask: Task<Void, Never>?
    private var sessionActivationTask: Task<Void, Never>?
    private var actionTasks: [UUID: Task<Void, Never>] = [:]
    private(set) var hasActiveSession = false
    var pendingActionTaskCount: Int { actionTasks.count }

    init(
        preferences: TelemetryPreferences? = nil,
        transport: AppTelemetryTransport = LiveCmdTabServerClient(),
        heartbeatSleep: @escaping HeartbeatSleep = {
            try await Task.sleep(nanoseconds: 60 * 60 * 1_000_000_000)
        }
    ) {
        self.preferences = preferences ?? .shared
        self.transport = transport
        self.heartbeatSleep = heartbeatSleep
    }

    private func payload(
        eventName: AppTelemetryEventName,
        licensingController: LicensingController
    ) -> AppTelemetryPayload {
        AppTelemetryPayload(
            eventName: eventName,
            licenseState: licensingController.telemetryLicenseState,
            appVersion: licensingController.appVersion,
            osVersion: licensingController.osVersion,
            occurredAt: Date()
        )
    }

    func startSession(licensingController: LicensingController) {
        guard preferences.isEnabled, !hasActiveSession else { return }

        hasActiveSession = true
        sessionActivationTask = Task { [weak self] in
            guard let self, self.preferences.isEnabled else { return }
            await transport.sendAppTelemetry(
                self.payload(eventName: .appActivation, licensingController: licensingController)
            )
        }

        heartbeatTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await heartbeatSleep()
                } catch {
                    break
                }
                guard !Task.isCancelled, preferences.isEnabled else { break }
                await transport.sendAppTelemetry(
                    self.payload(eventName: .appHeartbeat, licensingController: licensingController)
                )
            }
        }
    }

    func setEnabled(_ isEnabled: Bool, licensingController: LicensingController) {
        preferences.setEnabled(isEnabled)
        if isEnabled {
            startSession(licensingController: licensingController)
        } else {
            stopSession()
        }
    }

    func stopSession() {
        sessionActivationTask?.cancel()
        sessionActivationTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        actionTasks.values.forEach { $0.cancel() }
        actionTasks.removeAll()
        hasActiveSession = false
    }

    func trackLicenseActivation(licensingController: LicensingController) {
        trackAction(.licenseActivated, licensingController: licensingController)
    }

    func trackTrialStarted(licensingController: LicensingController) {
        trackAction(.trialStarted, licensingController: licensingController)
    }

    private func trackAction(
        _ eventName: AppTelemetryEventName,
        licensingController: LicensingController
    ) {
        guard preferences.isEnabled else { return }
        let taskID = UUID()
        let task = Task { [weak self] in
            guard let self else { return }
            guard self.preferences.isEnabled, !Task.isCancelled else {
                self.actionTaskDidComplete(taskID)
                return
            }
            await transport.sendAppTelemetry(
                self.payload(eventName: eventName, licensingController: licensingController)
            )
            self.actionTaskDidComplete(taskID)
        }
        actionTasks[taskID] = task
    }

    private func actionTaskDidComplete(_ taskID: UUID) {
        actionTasks.removeValue(forKey: taskID)
    }
}
