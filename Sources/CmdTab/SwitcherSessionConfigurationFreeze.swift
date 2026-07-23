import Foundation

/// Prevents live preference/profile edits from changing membership or style in
/// the middle of an already-visible switcher session. The hotkey router begins
/// and ends the lifecycle; `SwitcherProfileStore.configuration` resolves the
/// first configuration once and then returns that immutable value until the
/// session ends or another profile starts.
final class SwitcherSessionConfigurationFreeze {
    static let shared = SwitcherSessionConfigurationFreeze()

    private let lock = NSLock()
    private var activeProfileID: UUID?
    private var frozenConfiguration: SwitcherSessionConfiguration?

    func begin(profileID: UUID, preserveExisting: Bool) {
        lock.lock()
        defer { lock.unlock() }

        if preserveExisting, activeProfileID == profileID {
            return
        }
        activeProfileID = profileID
        frozenConfiguration = nil
    }

    func resolve(
        profileID: UUID,
        proposed: SwitcherSessionConfiguration
    ) -> SwitcherSessionConfiguration {
        lock.lock()
        defer { lock.unlock() }

        guard activeProfileID == profileID else {
            return proposed
        }
        if let frozenConfiguration {
            return frozenConfiguration
        }
        frozenConfiguration = proposed
        return proposed
    }

    func end() {
        lock.lock()
        activeProfileID = nil
        frozenConfiguration = nil
        lock.unlock()
    }

    var isActive: Bool {
        lock.lock()
        let value = activeProfileID != nil
        lock.unlock()
        return value
    }

    func snapshotForTesting() -> SwitcherSessionConfiguration? {
        lock.lock()
        let value = frozenConfiguration
        lock.unlock()
        return value
    }
}