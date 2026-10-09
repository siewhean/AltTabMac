import Foundation

/// Identifies the user's latest switch request. Activation retry chains run
/// for up to a few seconds; every step checks its token so that choosing a
/// different window cancels the earlier chain instead of letting it steal focus
/// back. Thread-safe: steps run on the main thread and the activation queue.
final class ActivationRequestLedger: @unchecked Sendable {
    struct Token: Equatable {
        let generation: UInt64
        let pid: pid_t
    }

    private let lock = NSLock()
    private var latest = Token(generation: 0, pid: 0)

    func begin(pid: pid_t) -> Token {
        lock.lock()
        defer { lock.unlock() }
        latest = Token(generation: latest.generation &+ 1, pid: pid)
        return latest
    }

    func isCurrent(_ token: Token) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return token == latest
    }

    /// Process targeted by the latest request, used so a superseded chain
    /// does not clear pending state that a newer request for the same
    /// process still owns.
    var currentPID: pid_t {
        lock.lock()
        defer { lock.unlock() }
        return latest.pid
    }
}
