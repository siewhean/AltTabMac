import CoreGraphics
import Foundation

/// Truthful result of one user-requested activation. Only `exactVerified` is
/// evidence that a selected window, rather than merely its application, won
/// focus and may therefore advance exact-window MRU.
enum ActivationOutcome: String, CaseIterable, Equatable, Sendable {
    case exactVerified
    case applicationFallbackUnverified
    case targetDisappeared
    case accessibilityUnavailable
    case failure
}

struct ActivationOutcomeMetrics: Codable, Equatable, Sendable {
    var requested = 0
    var exactVerified = 0
    var applicationFallbackUnverified = 0
    var targetDisappeared = 0
    var accessibilityUnavailable = 0
    var verificationFailure = 0
}

final class ActivationOutcomeTracker: @unchecked Sendable {
    static let shared = ActivationOutcomeTracker(defaults: .standard)
    private enum Key {
        static let requested = "activationOutcome.requested"
        static let exactVerified = "activationOutcome.exactVerified"
        static let applicationFallback = "activationOutcome.applicationFallback"
        static let targetDisappeared = "activationOutcome.targetDisappeared"
        static let accessibilityUnavailable = "activationOutcome.accessibilityUnavailable"
        static let verificationFailure = "activationOutcome.verificationFailure"
    }
    private let lock = NSLock()
    private let defaults: UserDefaults?
    private var metrics: ActivationOutcomeMetrics

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        metrics = ActivationOutcomeMetrics(
            requested: defaults?.integer(forKey: Key.requested) ?? 0,
            exactVerified: defaults?.integer(forKey: Key.exactVerified) ?? 0,
            applicationFallbackUnverified: defaults?.integer(forKey: Key.applicationFallback) ?? 0,
            targetDisappeared: defaults?.integer(forKey: Key.targetDisappeared) ?? 0,
            accessibilityUnavailable: defaults?.integer(forKey: Key.accessibilityUnavailable) ?? 0,
            verificationFailure: defaults?.integer(forKey: Key.verificationFailure) ?? 0
        )
    }

    func recordRequested() {
        lock.lock(); defer { lock.unlock() }
        metrics.requested += 1
        persist()
    }

    func record(_ outcome: ActivationOutcome) {
        lock.lock(); defer { lock.unlock() }
        switch outcome {
        case .exactVerified: metrics.exactVerified += 1
        case .applicationFallbackUnverified: metrics.applicationFallbackUnverified += 1
        case .targetDisappeared: metrics.targetDisappeared += 1
        case .accessibilityUnavailable: metrics.accessibilityUnavailable += 1
        case .failure: metrics.verificationFailure += 1
        }
        persist()
    }

    func snapshot() -> ActivationOutcomeMetrics {
        lock.lock(); defer { lock.unlock() }
        return metrics
    }

    private func persist() {
        defaults?.set(metrics.requested, forKey: Key.requested)
        defaults?.set(metrics.exactVerified, forKey: Key.exactVerified)
        defaults?.set(metrics.applicationFallbackUnverified, forKey: Key.applicationFallback)
        defaults?.set(metrics.targetDisappeared, forKey: Key.targetDisappeared)
        defaults?.set(metrics.accessibilityUnavailable, forKey: Key.accessibilityUnavailable)
        defaults?.set(metrics.verificationFailure, forKey: Key.verificationFailure)
    }
}

enum ActivationOutcomePolicy {
    static func recordsExactWindowMRU(_ outcome: ActivationOutcome) -> Bool {
        outcome == .exactVerified
    }
}

/// Exact-window activation is deliberately identity-only.  A selected window
/// may be raised only when Accessibility resolves that same WindowServer ID;
/// similar titles, frames, or another key sibling are never a substitute.
enum ExactWindowActivationPolicy {
    static func selectedWindowIndex(
        selectedWindowID: UInt32,
        mappedWindowIDs: [UInt32?]
    ) -> Int? {
        mappedWindowIDs.firstIndex { $0 == selectedWindowID }
    }

    /// AX focus can point to a window on another Space. Treat selection as
    /// complete only when the exact CG window is visible to the user too.
    static func mayConfirm(
        frontmostPID: pid_t?,
        focusedWindowID: CGWindowID?,
        targetPID: pid_t,
        targetWindowID: CGWindowID,
        isOnScreen: Bool
    ) -> Bool {
        frontmostPID == targetPID &&
            focusedWindowID == targetWindowID &&
            isOnScreen
    }

    static func isTargetOnScreen(ownerPID: pid_t, windowID: CGWindowID) -> Bool {
        let info = CGWindowListCopyWindowInfo(
            [.optionIncludingWindow, .excludeDesktopElements],
            windowID
        ) as? [[String: Any]]
        guard let row = info?.first,
              (row[kCGWindowNumber as String] as? NSNumber)?.uint32Value == windowID,
              (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == ownerPID,
              let value = row[kCGWindowIsOnscreen as String] as? NSNumber else {
            return false
        }
        return value.boolValue
    }
}
