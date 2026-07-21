import ApplicationServices
import Carbon.HIToolbox
import Foundation
import os.signpost

struct DiagnosticSnapshot: Codable, Equatable {
    struct Permissions: Codable, Equatable {
        let accessibilityGranted: Bool
        let screenRecordingGranted: Bool
        let secureInputEnabled: Bool
    }

    let schemaVersion: Int
    let appVersion: String
    let buildNumber: String
    let bundleIdentifier: String
    let macOSVersion: String
    let architecture: String
    let eventTapHealthy: Bool
    let eventTapHealthSource: String
    let permissions: Permissions

    static func current(bundle: Bundle = .main, processInfo: ProcessInfo = .processInfo) -> DiagnosticSnapshot {
        let screenRecordingGranted: Bool
        if #available(macOS 10.15, *) {
            screenRecordingGranted = CGPreflightScreenCaptureAccess()
        } else {
            screenRecordingGranted = true
        }

        return DiagnosticSnapshot(
            schemaVersion: 1,
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            bundleIdentifier: bundle.bundleIdentifier ?? "unknown",
            macOSVersion: processInfo.operatingSystemVersionString,
            architecture: runtimeArchitecture(),
            eventTapHealthy: EventTapHealthProbe.current(),
            eventTapHealthSource: "activeProbe",
            permissions: Permissions(
                accessibilityGranted: AXIsProcessTrusted(),
                screenRecordingGranted: screenRecordingGranted,
                secureInputEnabled: IsSecureEventInputEnabled()
            )
        )
    }

    static func encodedCurrentSnapshot() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(current())
    }

    private static func runtimeArchitecture() -> String {
        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else { return "unknown" }
        var machine = systemInfo.machine
        let capacity = MemoryLayout.size(ofValue: machine)
        return withUnsafePointer(to: &machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: capacity) {
                String(cString: $0)
            }
        }
    }
}

enum EventTapHealthProbe {
    private static let callback: CGEventTapCallBack = { _, _, event, _ in
        Unmanaged.passUnretained(event)
    }

    static func current() -> Bool {
        evaluate(
            accessGranted: AXIsProcessTrusted(),
            createTap: {
                CGEvent.tapCreate(
                    tap: .cghidEventTap,
                    place: .headInsertEventTap,
                    options: .defaultTap,
                    eventsOfInterest: CGEventMask(1) << CGEventType.flagsChanged.rawValue,
                    callback: callback,
                    userInfo: nil
                )
            },
            enable: { CGEvent.tapEnable(tap: $0, enable: true) },
            isEnabled: CGEvent.tapIsEnabled,
            invalidate: CFMachPortInvalidate
        )
    }

    static func evaluate<T>(
        accessGranted: Bool,
        createTap: () -> T?,
        enable: (T) -> Void,
        isEnabled: (T) -> Bool,
        invalidate: (T) -> Void
    ) -> Bool {
        guard accessGranted, let tap = createTap() else { return false }
        enable(tap)
        let healthy = isEnabled(tap)
        invalidate(tap)
        return healthy
    }
}

enum ProductionSignpost {
    private static let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "net.cmdtab.app",
        category: .pointsOfInterest
    )

    static func prepare() {
        _ = log
    }

    static func hotkeyReceived() {
        os_signpost(.event, log: log, name: "Hotkey Received")
    }

    static func overlayPresented() {
        os_signpost(.event, log: log, name: "Overlay Presented")
    }

    static func overlayDismissed() {
        os_signpost(.event, log: log, name: "Overlay Dismissed")
    }

    static func captureStarted() -> OSSignpostID {
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "Window Capture", signpostID: signpostID)
        return signpostID
    }

    static func captureFinished(_ signpostID: OSSignpostID) {
        os_signpost(.end, log: log, name: "Window Capture", signpostID: signpostID)
    }

    static func activationRequested() {
        os_signpost(.event, log: log, name: "Activation Requested")
    }

    static func activationConfirmed() {
        os_signpost(.event, log: log, name: "Activation Confirmed")
    }
}
