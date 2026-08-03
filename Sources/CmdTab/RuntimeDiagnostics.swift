import Foundation

/// Fixed, process-local aggregate counters for support diagnostics.
///
/// This store intentionally retains no window, application, account, document,
/// preview, process, or timing data. It is not persisted and has no transport.
enum RuntimeDiagnosticsCounter: String, CaseIterable, Sendable {
    case enrichedSnapshotMerge
    case forcedRefreshReplay
    case accessibilityIdentityLookupFailure
    case previewCaptureFailure
    case previewRecoveryScheduled
    case previewRecoveryRetry
    case previewRecoverySuccess
    case previewFallbackPresentation

    var displayName: String {
        switch self {
        case .enrichedSnapshotMerge:
            return "Enriched snapshot merges"
        case .forcedRefreshReplay:
            return "Forced refresh replays"
        case .accessibilityIdentityLookupFailure:
            return "Accessibility identity lookup failures"
        case .previewCaptureFailure:
            return "Preview capture failures"
        case .previewRecoveryScheduled:
            return "Preview recovery requests"
        case .previewRecoveryRetry:
            return "Preview recovery retries"
        case .previewRecoverySuccess:
            return "Preview recovery successes"
        case .previewFallbackPresentation:
            return "Preview fallback presentations"
        }
    }
}

struct RuntimeDiagnosticsSnapshot: Equatable, Sendable {
    private let counts: [RuntimeDiagnosticsCounter: Int]

    init(counts: [RuntimeDiagnosticsCounter: Int]) {
        self.counts = counts
    }

    func count(for counter: RuntimeDiagnosticsCounter) -> Int {
        counts[counter, default: 0]
    }

    var sanitizedReport: String {
        RuntimeDiagnosticsCounter.allCases
            .map { "runtime.\($0.rawValue)=\(count(for: $0))" }
            .joined(separator: "\n")
    }
}

/// Thread-safe in-memory diagnostic aggregates. The singleton is read by the
/// production diagnostics window; isolated instances make the data contract
/// testable without sharing application state.
final class RuntimeDiagnostics: @unchecked Sendable {
    static let shared = RuntimeDiagnostics()

    private let lock = NSLock()
    private var counts = Dictionary(
        uniqueKeysWithValues: RuntimeDiagnosticsCounter.allCases.map { ($0, 0) }
    )

    func increment(_ counter: RuntimeDiagnosticsCounter) {
        lock.lock()
        counts[counter, default: 0] += 1
        lock.unlock()
    }

    func snapshot() -> RuntimeDiagnosticsSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return RuntimeDiagnosticsSnapshot(counts: counts)
    }

    func reset() {
        lock.lock()
        counts = Dictionary(
            uniqueKeysWithValues: RuntimeDiagnosticsCounter.allCases.map { ($0, 0) }
        )
        lock.unlock()
    }
}
