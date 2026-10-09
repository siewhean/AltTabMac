import Foundation

/// Thread-safe cache of the frontmost window's history identity.
///
/// Every activation or focus change starts a new generation. A background
/// result is stored only if no newer generation began while it was computed,
/// and a lookup succeeds only when the stored result belongs to the latest
/// generation and the process that is frontmost now. Anything else is a miss,
/// so callers fall back to the exact synchronous lookup.
final class FrontmostIdentityCache: @unchecked Sendable {
    struct Entry: Equatable {
        let pid: pid_t
        let identity: SwitcherHistoryIdentity?
        let generation: UInt64
    }

    private let lock = NSLock()
    private var latestGeneration: UInt64 = 0
    private var entry: Entry?

    /// Marks the cache stale and returns the generation of the new refresh.
    func beginRefresh() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        latestGeneration &+= 1
        return latestGeneration
    }

    func finishRefresh(generation: UInt64, pid: pid_t, identity: SwitcherHistoryIdentity?) {
        lock.lock()
        defer { lock.unlock() }
        guard generation == latestGeneration else { return }
        entry = Entry(pid: pid, identity: identity, generation: generation)
    }

    func validIdentity(for pid: pid_t) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry, entry.pid == pid, entry.generation == latestGeneration else {
            return nil
        }
        return entry
    }
}
