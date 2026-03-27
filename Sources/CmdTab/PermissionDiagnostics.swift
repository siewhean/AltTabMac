import ApplicationServices
import Carbon.HIToolbox
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
