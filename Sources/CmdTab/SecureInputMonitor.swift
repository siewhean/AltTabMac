import Darwin

/// Reads the system Secure Event Input state without hard-linking Carbon.
/// When the symbol is unavailable, CmdTab relies on the system event-tap
/// disable behaviour and reports that limitation without inspecting private
/// user content.
enum SecureInputMonitor {
    private typealias IsEnabledFunction = @convention(c) () -> UInt8

    private static let function: IsEnabledFunction? = {
        let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2)
        guard let symbol = dlsym(defaultHandle, "IsSecureEventInputEnabled") else {
            return nil
        }
        return unsafeBitCast(symbol, to: IsEnabledFunction.self)
    }()

    static var isEnabled: Bool {
        function?() != 0
    }

    /// A sanitized status suitable for local Diagnostics. The private API only
    /// exposes whether secure input is active; CmdTab never reads input content.
    static var status: CapabilityStatus {
        evaluation(
            symbolAvailable: function != nil,
            isEnabled: isEnabled
        )
    }

    static func evaluation(
        symbolAvailable: Bool,
        isEnabled: Bool
    ) -> CapabilityStatus {
        guard symbolAvailable else {
            return .unavailable(
                "Secure Event Input state is unavailable on this macOS build; CmdTab relies on event-tap disable behaviour."
            )
        }
        guard isEnabled else {
            return CapabilityStatus(
                level: .available,
                reason: "Secure Event Input is inactive."
            )
        }
        return .degraded(
            "Secure Event Input is active; CmdTab bypasses shortcut interception."
        )
    }
}
