import ApplicationServices
import Carbon.HIToolbox
import AppKit
import Foundation

enum PermissionHealthState {
    case ready
    case warning
    case blocked

    var title: String {
        switch self {
        case .ready:
            return "Ready"
        case .warning:
            return "Warning"
        case .blocked:
            return "Required"
        }
    }
}

struct PermissionStatusDescriptor {
    let name: String
    let detail: String
    let state: PermissionHealthState
}

enum PermissionDiagnostics {
    static func requestScreenRecordingAccess() -> Bool {
        guard #available(macOS 10.15, *) else { return true }
        return CGRequestScreenCaptureAccess()
    }

    static func accessibilityStatus() -> PermissionStatusDescriptor {
        let granted = AXIsProcessTrusted()
        return PermissionStatusDescriptor(
            name: "Accessibility",
            detail: granted
                ? "CmdTab can intercept the global switcher shortcut."
                : "Grant Accessibility so CmdTab can replace the native switcher reliably.",
            state: granted ? .ready : .blocked
        )
    }

    static func screenRecordingStatus() -> PermissionStatusDescriptor {
        let granted: Bool
        if #available(macOS 10.15, *) {
            granted = CGPreflightScreenCaptureAccess()
        } else {
            granted = true
        }

        return PermissionStatusDescriptor(
            name: "Screen Recording",
            detail: granted
                ? "Real window previews are available."
                : "Grant Screen Recording so CmdTab can capture live window previews.",
            state: granted ? .ready : .blocked
        )
    }

    static func secureInputStatus() -> PermissionStatusDescriptor {
        let enabled = IsSecureEventInputEnabled()
        return PermissionStatusDescriptor(
            name: "Secure Input",
            detail: enabled
                ? "A secure text field is active. Global shortcuts may pause until it is closed."
                : "No secure-input blocker is active right now.",
            state: enabled ? .warning : .ready
        )
    }

    static func allStatuses() -> [PermissionStatusDescriptor] {
        [
            accessibilityStatus(),
            screenRecordingStatus(),
            secureInputStatus()
        ]
    }
}

enum PermissionOnboardingPolicy {
    enum Action: Equatable {
        case none
        case openAccessibilitySettings
        case openScreenRecordingSettings
    }

    static func action(
        hasPresentedAccessibility: Bool,
        hasPresentedScreenRecording: Bool,
        accessibilityGranted: Bool,
        screenRecordingGranted: Bool
    ) -> Action {
        if !accessibilityGranted {
            return hasPresentedAccessibility ? .none : .openAccessibilitySettings
        }
        if !screenRecordingGranted {
            return hasPresentedScreenRecording ? .none : .openScreenRecordingSettings
        }
        return .none
    }

    static func shouldPresent(
        hasPresentedAccessibility: Bool,
        hasPresentedScreenRecording: Bool,
        accessibilityGranted: Bool,
        screenRecordingGranted: Bool
    ) -> Bool {
        action(
            hasPresentedAccessibility: hasPresentedAccessibility,
            hasPresentedScreenRecording: hasPresentedScreenRecording,
            accessibilityGranted: accessibilityGranted,
            screenRecordingGranted: screenRecordingGranted
        ) != .none
    }
}

@MainActor
enum PermissionOnboardingController {
    private static let accessibilityPresentedKey = "CmdTab.permissionOnboarding.accessibility.presented.v3"
    private static let screenRecordingPresentedKey = "CmdTab.permissionOnboarding.screenRecording.presented.v3"

    static func presentIfNeeded(defaults: UserDefaults = .standard) {
        let accessibilityGranted = AXIsProcessTrusted()
        let screenRecordingGranted: Bool
        if #available(macOS 10.15, *) {
            screenRecordingGranted = CGPreflightScreenCaptureAccess()
        } else {
            screenRecordingGranted = true
        }

        let action = PermissionOnboardingPolicy.action(
            hasPresentedAccessibility: defaults.bool(forKey: accessibilityPresentedKey),
            hasPresentedScreenRecording: defaults.bool(forKey: screenRecordingPresentedKey),
            accessibilityGranted: accessibilityGranted,
            screenRecordingGranted: screenRecordingGranted
        )

        guard action != .none else { return }

        // Persist before presenting so dismissal or termination cannot loop.
        switch action {
        case .openAccessibilitySettings:
            defaults.set(true, forKey: accessibilityPresentedKey)
        case .openScreenRecordingSettings:
            defaults.set(true, forKey: screenRecordingPresentedKey)
        case .none:
            break
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Set up CmdTab permissions"
        alert.informativeText = "CmdTab will open System Settings for the first missing permission. It will not repeatedly request access. You can complete any remaining permission from CmdTab Settings."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let settingsURL: URL?
        switch action {
        case .openAccessibilitySettings:
            settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .openScreenRecordingSettings:
            let granted = PermissionDiagnostics.requestScreenRecordingAccess()
            settingsURL = granted
                ? nil
                : URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        case .none:
            settingsURL = nil
        }
        if let settingsURL { NSWorkspace.shared.open(settingsURL) }
    }
}
