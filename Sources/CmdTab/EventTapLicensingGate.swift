import Foundation

/// Thread-safe copy of the licensing facts the keyboard event tap needs.
///
/// The tap runs on its own thread and must never touch the main-actor
/// `LicensingController`, the Keychain, or token verification. The controller
/// publishes the last status verified in this process here; the gate decides
/// from that snapshot and asks the controller to revalidate when it is stale.
final class EventTapLicensingGate: @unchecked Sendable {
    enum Entitlement: Equatable {
        case licensed
        case trial(endsAt: Date)
        case none
    }

    struct Snapshot: Equatable {
        var entitlement: Entitlement = .none
        var validatedAt: Date?
        var validatedUptime: TimeInterval?
    }

    private let lock = NSLock()
    private var snapshot = Snapshot()
    private var refreshHandler: (() -> Void)?
    private let refreshInterval: TimeInterval
    private let clockRollbackTolerance: TimeInterval
    private let currentDate: () -> Date
    private let currentUptime: () -> TimeInterval

    init(
        refreshInterval: TimeInterval,
        clockRollbackTolerance: TimeInterval,
        currentDate: @escaping () -> Date,
        currentUptime: @escaping () -> TimeInterval
    ) {
        self.refreshInterval = refreshInterval
        self.clockRollbackTolerance = clockRollbackTolerance
        self.currentDate = currentDate
        self.currentUptime = currentUptime
    }

    func update(_ snapshot: Snapshot) {
        lock.lock()
        self.snapshot = snapshot
        lock.unlock()
    }

    /// Called on whichever thread asked; the handler hops to the main actor.
    func setRefreshHandler(_ handler: @escaping () -> Void) {
        lock.lock()
        refreshHandler = handler
        lock.unlock()
    }

    /// Safe on any thread. A stale snapshot or a pending Keychain read is not a
    /// revocation: it schedules revalidation and keeps the last verified answer.
    func allowsShortcut() -> Bool {
        lock.lock()
        let current = snapshot
        let handler = refreshHandler
        lock.unlock()

        let now = currentDate()
        let age = current.validatedUptime.map { currentUptime() - $0 }
        if (age.map({ $0 < 0 || $0 >= refreshInterval }) ?? true) ||
            BoundedKeychainReadRegistry.hasPendingReads {
            handler?()
        }
        return Self.allows(current, now: now, clockRollbackTolerance: clockRollbackTolerance)
    }

    static func allows(
        _ snapshot: Snapshot,
        now: Date,
        clockRollbackTolerance: TimeInterval
    ) -> Bool {
        guard let validatedAt = snapshot.validatedAt,
              now.addingTimeInterval(clockRollbackTolerance) >= validatedAt else {
            return false
        }
        switch snapshot.entitlement {
        case .licensed:
            // Paid device entitlements are perpetual: the verifier requires
            // their exp field to be absent. Refresh rechecks revocation.
            return true
        case let .trial(endsAt):
            return now < endsAt
        case .none:
            return false
        }
    }
}
