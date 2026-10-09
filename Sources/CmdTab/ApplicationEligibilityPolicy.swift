import AppKit
import Foundation

/// Centralized application eligibility policy for CmdTab.
///
/// By default, CmdTab displays eligible windows belonging to regular foreground macOS applications
/// (`activationPolicy == .regular`). Accessory applications (menu-bar items, daemons, background agents)
/// and CmdTab itself are intentionally excluded to keep the switcher predictable and focused.
public enum ApplicationEligibilityPolicy {
    /// Evaluates whether a running application is eligible to appear in the switcher.
    public static func isEligibleApplication(_ app: NSRunningApplication) -> Bool {
        guard app.activationPolicy == .regular else { return false }
        guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return false }
        return true
    }

    /// Evaluates whether an application identified by PID is eligible.
    public static func isEligibleProcess(pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return false }
        return isEligibleApplication(app)
    }
}

/// Privacy-safe snapshot diagnostic counters covering candidate discovery,
/// AX identification, fallbacks, and rejections.
///
/// Contains strictly numeric counters and durations. No application names,
/// window titles, filenames, or document paths are recorded.
public struct SnapshotDiagnosticMetrics: Equatable, Sendable {
    public var regularApplicationsDetected: Int = 0
    public var processesRepresented: Int = 0
    /// Every Core Graphics row returned by the snapshot query, before CmdTab
    /// applies candidate eligibility. This deliberately includes rows that do
    /// not belong to an eligible application or are otherwise unusable.
    public var cgWindowsEnumerated: Int = 0
    /// Core Graphics rows that passed CmdTab's ordinary candidate checks. AX
    /// has not had an opportunity to remove these rows when this is counted.
    public var cgCandidateWindows: Int = 0
    public var positivelyRejectedWindows: Int = 0
    public var unknownAXIdentityWindows: Int = 0
    public var exactAXMatchedWindows: Int = 0
    public var exactWindowsPublished: Int = 0
    public var appFallbacksPublished: Int = 0
    public var previewAvailable: Int = 0
    public var previewUnavailable: Int = 0
    public var previewLive: Int = 0
    public var previewSaved: Int = 0
    public var previewPending: Int = 0
    public var previewPermissionDenied: Int = 0
    public var previewCaptureUnavailable: Int = 0
    public var axIdentityFailures: Int = 0
    public var processesMissing: Int = 0
    public var phase1Duration: TimeInterval = 0
    public var phase2Duration: TimeInterval = 0

    public init() {}
}

/// Pure accounting for one switcher snapshot. Keeping this separate from the
/// window enumerator prevents a broad Core Graphics filter failure from being
/// reported as an AX rejection, and makes the membership matrix testable
/// without macOS permissions or WindowServer state.
struct SnapshotMembershipMetricsBuilder {
    private(set) var metrics: SnapshotDiagnosticMetrics

    init(cgWindowsEnumerated: Int) {
        var metrics = SnapshotDiagnosticMetrics()
        metrics.cgWindowsEnumerated = cgWindowsEnumerated
        self.metrics = metrics
    }

    init(metrics: SnapshotDiagnosticMetrics) {
        self.metrics = metrics
    }

    mutating func recordCGCandidate(
        exactAXMatched: Bool,
        positivelyRejected: Bool,
        unknownAXIdentity: Bool
    ) {
        metrics.cgCandidateWindows += 1
        if exactAXMatched { metrics.exactAXMatchedWindows += 1 }
        if positivelyRejected { metrics.positivelyRejectedWindows += 1 }
        if unknownAXIdentity { metrics.unknownAXIdentityWindows += 1 }
    }

    mutating func recordPublishedWindow(previewAvailable: Bool) {
        metrics.exactWindowsPublished += 1
        if previewAvailable {
            metrics.previewAvailable += 1
        } else {
            metrics.previewUnavailable += 1
        }
    }

    mutating func recordPublishedFallback() {
        metrics.appFallbacksPublished += 1
    }

    mutating func finish(
        regularApplicationsDetected: Int,
        processesRepresented: Int,
        axIdentityFailures: Int,
        phase1Duration: TimeInterval
    ) -> SnapshotDiagnosticMetrics {
        metrics.regularApplicationsDetected = regularApplicationsDetected
        metrics.processesRepresented = processesRepresented
        metrics.processesMissing = max(0, regularApplicationsDetected - processesRepresented)
        metrics.axIdentityFailures = axIdentityFailures
        metrics.phase1Duration = phase1Duration
        return metrics
    }
}

/// Thread-safe tracker maintaining the latest snapshot diagnostic metrics.
public final class SnapshotDiagnosticsTracker: @unchecked Sendable {
    public static let shared = SnapshotDiagnosticsTracker()

    private let lock = NSLock()
    private var currentMetrics = SnapshotDiagnosticMetrics()

    private init() {}

    public func record(_ metrics: SnapshotDiagnosticMetrics) {
        lock.lock()
        currentMetrics = metrics
        lock.unlock()
    }

    /// Accounts for the final enriched publication rather than only CG candidates.
    func recordPublishedPreviewStates(_ items: [SwitcherItem]) {
        lock.lock()
        defer { lock.unlock() }
        currentMetrics.exactWindowsPublished = items.filter { $0.kind == .appWindow }.count
        currentMetrics.appFallbacksPublished = items.filter { $0.kind == .appFallback }.count
        currentMetrics.processesRepresented = Set(items.compactMap(\.ownerPID)).count
        currentMetrics.processesMissing = max(0, currentMetrics.regularApplicationsDetected - currentMetrics.processesRepresented)
        currentMetrics.previewLive = 0
        currentMetrics.previewSaved = 0
        currentMetrics.previewPending = 0
        currentMetrics.previewPermissionDenied = 0
        currentMetrics.previewCaptureUnavailable = 0
        for item in items where item.kind == .appWindow {
            switch item.previewState {
            case .live: currentMetrics.previewLive += 1
            case .cached: currentMetrics.previewSaved += 1
            case .pending: currentMetrics.previewPending += 1
            case .permissionDenied: currentMetrics.previewPermissionDenied += 1
            case .unavailable: currentMetrics.previewCaptureUnavailable += 1
            case .applicationOnly: break
            }
        }
        currentMetrics.previewAvailable = currentMetrics.previewLive + currentMetrics.previewSaved
        currentMetrics.previewUnavailable = currentMetrics.previewPending + currentMetrics.previewPermissionDenied + currentMetrics.previewCaptureUnavailable
    }

    public func snapshot() -> SnapshotDiagnosticMetrics {
        lock.lock()
        defer { lock.unlock() }
        return currentMetrics
    }
}
