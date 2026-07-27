import Darwin

/// Reads the system Secure Event Input state without hard-linking Carbon.
/// When the symbol is unavailable, CmdTab relies on the system event-tap
/// disable behaviour and reports `false`; no private user content is inspected.
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
}