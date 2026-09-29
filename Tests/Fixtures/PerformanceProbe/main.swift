import AppKit
import ApplicationServices
import CoreGraphics
import CryptoKit
import Darwin
import Foundation
import ScreenCaptureKit

private struct Arguments {
    let cmdTabApp: URL
    let windowLabApp: URL
    let windowCount: Int
    let sessions: Int
    let sourceSHA: String
    let runKind: String
    let output: URL

    static func parse() throws -> Arguments {
        let values = Array(CommandLine.arguments.dropFirst())
        func value(_ name: String) throws -> String {
            guard let index = values.firstIndex(of: name),
                  values.indices.contains(index + 1) else {
                throw ProbeError.invalidArgument("Missing \(name)")
            }
            return values[index + 1]
        }

        guard let windowCount = Int(try value("--window-count")),
              [10, 25, 50].contains(windowCount) else {
            throw ProbeError.invalidArgument("--window-count must be 10, 25, or 50")
        }
        guard let sessions = Int(try value("--sessions")), sessions > 0 else {
            throw ProbeError.invalidArgument("--sessions must be positive")
        }
        let runKind = try value("--run-kind")
        guard ["readiness", "acceptance"].contains(runKind) else {
            throw ProbeError.invalidArgument("--run-kind must be readiness or acceptance")
        }
        let sourceSHA = try value("--source-sha")
        guard sourceSHA.range(
            of: #"^[0-9a-f]{40}$"#,
            options: .regularExpression
        ) != nil else {
            throw ProbeError.invalidArgument("--source-sha must be a full Git SHA")
        }

        return Arguments(
            cmdTabApp: URL(fileURLWithPath: try value("--cmdtab-app")),
            windowLabApp: URL(fileURLWithPath: try value("--windowlab-app")),
            windowCount: windowCount,
            sessions: sessions,
            sourceSHA: sourceSHA,
            runKind: runKind,
            output: URL(fileURLWithPath: try value("--output"))
        )
    }
}

private enum ProbeError: Error, CustomStringConvertible {
    case invalidArgument(String)
    case launch(String)
    case serialization(String)

    var description: String {
        switch self {
        case .invalidArgument(let message), .launch(let message), .serialization(let message):
            return message
        }
    }
}

private struct ProcessUsage: Codable {
    let residentBytes: UInt64
    let userNanoseconds: UInt64
    let systemNanoseconds: UInt64
}

private struct SessionMeasurement: Codable {
    let index: Int
    let revealMilliseconds: Double?
    let selectionMilliseconds: Double?
    let observationCaptureMilliseconds: Double?
    let cpuMilliseconds: Double?
    let residentBytes: UInt64?
    let eventTapState: String
    let interruptionCode: String?
    let interruptionDetail: String?
    let previewIntegrity: String
    let activationOutcome: String
    let cmdTabRunningAfterSession: Bool
}

private struct Preconditions: Codable {
    let accessibilityTrusted: Bool
    let screenCaptureAuthorized: Bool
    let secureInputObservation: String
    let eventTapHIDObservation: String
    let candidateLaunchStatus: String
    let candidateFrontmostStatus: String
    let cmdTabProcessRunning: Bool
    let fixtureWindowCountExpected: Int
    let fixtureWindowCountObserved: Int
}

private struct RunMetadata: Codable {
    let schemaVersion: Int
    let sourceSHA: String
    let runKind: String
    let capturedAt: String
    let hostOS: String
    let hostArchitecture: String
    let cmdTabExecutableSHA256: String?
    let windowLabExecutableSHA256: String?
}

private struct ProbeResult: Codable {
    let metadata: RunMetadata
    let preconditions: Preconditions
    let measurements: [SessionMeasurement]
    let idleCPUPercent: Double?
    let evidenceState: String
    let evidenceStateReason: String
    let prerequisiteInterruptions: [String]
    let activationOutcomeMetrics: ActivationOutcomeMetrics
    let eventTapObservationMethod: String
}

private struct ActivationOutcomeMetrics: Codable {
    let requested: Int
    let exactVerified: Int
    let applicationFallbackUnverified: Int
    let targetDisappeared: Int
    let accessibilityUnavailable: Int
    let verificationFailure: Int

    static func snapshot() -> ActivationOutcomeMetrics {
        let defaults = UserDefaults(suiteName: "net.cmdtab.CmdTab")
        return ActivationOutcomeMetrics(
            requested: defaults?.integer(forKey: "activationOutcome.requested") ?? 0,
            exactVerified: defaults?.integer(forKey: "activationOutcome.exactVerified") ?? 0,
            applicationFallbackUnverified: defaults?.integer(forKey: "activationOutcome.applicationFallback") ?? 0,
            targetDisappeared: defaults?.integer(forKey: "activationOutcome.targetDisappeared") ?? 0,
            accessibilityUnavailable: defaults?.integer(forKey: "activationOutcome.accessibilityUnavailable") ?? 0,
            verificationFailure: defaults?.integer(forKey: "activationOutcome.verificationFailure") ?? 0
        )
    }

    func delta(since baseline: ActivationOutcomeMetrics) -> ActivationOutcomeMetrics {
        ActivationOutcomeMetrics(
            requested: max(0, requested - baseline.requested),
            exactVerified: max(0, exactVerified - baseline.exactVerified),
            applicationFallbackUnverified: max(0, applicationFallbackUnverified - baseline.applicationFallbackUnverified),
            targetDisappeared: max(0, targetDisappeared - baseline.targetDisappeared),
            accessibilityUnavailable: max(0, accessibilityUnavailable - baseline.accessibilityUnavailable),
            verificationFailure: max(0, verificationFailure - baseline.verificationFailure)
        )
    }
}

private struct WindowIdentity {
    let id: CGWindowID
    let area: Double
}

private typealias CreateWindowImageFunction = @convention(c) (
    CGRect,
    UInt32,
    CGWindowID,
    UInt32
) -> Unmanaged<CGImage>?

private let createWindowImage: CreateWindowImageFunction? = {
    guard let symbol = dlsym(
        UnsafeMutableRawPointer(bitPattern: -2),
        "CGWindowListCreateImage"
    ) else {
        return nil
    }
    return unsafeBitCast(symbol, to: CreateWindowImageFunction.self)
}()

private final class WindowCaptureSampler {
    private var windowCache: [CGWindowID: SCWindow] = [:]

    @available(macOS 14.0, *)
    private func screenCaptureKitImage(windowID: CGWindowID) -> CGImage? {
        let matchedWindow: SCWindow
        if let cached = windowCache[windowID] {
            matchedWindow = cached
        } else {
            let contentSemaphore = DispatchSemaphore(value: 0)
            var discoveredWindow: SCWindow?
            SCShareableContent.getExcludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            ) { content, _ in
                discoveredWindow = content?.windows.first { $0.windowID == windowID }
                contentSemaphore.signal()
            }
            guard contentSemaphore.wait(timeout: .now() + 3) == .success,
                  let discoveredWindow else {
                return nil
            }
            windowCache[windowID] = discoveredWindow
            matchedWindow = discoveredWindow
        }

        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(matchedWindow.frame.width))
        configuration.height = max(1, Int(matchedWindow.frame.height))
        configuration.showsCursor = false
        let filter = SCContentFilter(desktopIndependentWindow: matchedWindow)
        let imageSemaphore = DispatchSemaphore(value: 0)
        var capturedImage: CGImage?
        SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        ) { image, _ in
            capturedImage = image
            imageSemaphore.signal()
        }
        guard imageSemaphore.wait(timeout: .now() + 3) == .success else {
            return nil
        }
        return capturedImage
    }

    func hashAndLatency(windowID: CGWindowID) -> (String, Double)? {
        let started = DispatchTime.now().uptimeNanoseconds
        let image: CGImage?
        if #available(macOS 14.0, *) {
            image = screenCaptureKitImage(windowID: windowID)
        } else {
            image = createWindowImage?(
                .null,
                CGWindowListOption.optionIncludingWindow.rawValue,
                windowID,
                CGWindowImageOption.boundsIgnoreFraming.rawValue
            )?.takeRetainedValue()
        }
        guard let image, let data = image.dataProvider?.data as Data? else {
            return nil
        }
        let elapsed = milliseconds(since: started)
        let hash = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        return (hash, elapsed)
    }
}

private func milliseconds(since started: UInt64) -> Double {
    Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
}

private func processUsage(pid: pid_t) -> ProcessUsage? {
    var info = proc_taskinfo()
    let size = MemoryLayout<proc_taskinfo>.size
    let copied = withUnsafeMutablePointer(to: &info) {
        proc_pidinfo(pid, PROC_PIDTASKINFO, 0, $0, Int32(size))
    }
    guard copied == size else { return nil }
    return ProcessUsage(
        residentBytes: info.pti_resident_size,
        userNanoseconds: info.pti_total_user,
        systemNanoseconds: info.pti_total_system
    )
}

private func sha256(_ url: URL) -> String? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func executableURL(for app: URL) -> URL? {
    guard let bundle = Bundle(url: app),
          let executable = bundle.executableURL else {
        return nil
    }
    return executable
}

private func visibleWindows(pid: pid_t) -> [WindowIdentity] {
    let rows = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
    ) as? [[String: Any]] ?? []
    return rows.compactMap { row in
        guard (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
              let id = (row[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
              let bounds = row[kCGWindowBounds as String] as? NSDictionary,
              let frame = CGRect(dictionaryRepresentation: bounds),
              frame.width >= 120,
              frame.height >= 80 else {
            return nil
        }
        return WindowIdentity(id: id, area: frame.width * frame.height)
    }
}

private func newlyVisibleSwitcherWindow(
    pid: pid_t,
    excluding baseline: Set<CGWindowID>
) -> WindowIdentity? {
    visibleWindows(pid: pid)
        .filter { !baseline.contains($0.id) }
        .min { $0.area < $1.area }
}

private func postKey(_ keyCode: CGKeyCode, down: Bool, flags: CGEventFlags) {
    guard let event = CGEvent(
        keyboardEventSource: nil,
        virtualKey: keyCode,
        keyDown: down
    ) else {
        return
    }
    event.flags = flags
    event.post(tap: .cghidEventTap)
}

private func beginSwitcherChord() {
    postKey(55, down: true, flags: .maskCommand)
    postKey(48, down: true, flags: .maskCommand)
    postKey(48, down: false, flags: .maskCommand)
}

private func advanceSelection() {
    postKey(48, down: true, flags: .maskCommand)
    postKey(48, down: false, flags: .maskCommand)
}

private func releaseSwitcherChord() {
    postKey(55, down: false, flags: [])
}

private func dismissSwitcher() {
    postKey(53, down: true, flags: [])
    postKey(53, down: false, flags: [])
}

private func waitFor<T>(
    timeout: TimeInterval,
    pollInterval: TimeInterval = 0.002,
    _ operation: () -> T?
) -> T? {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        if let value = operation() { return value }
        RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
    } while Date() < deadline
    return nil
}

private func launch(
    app: URL,
    arguments: [String]
) throws -> NSRunningApplication {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.arguments = arguments
    configuration.activates = true
    let semaphore = DispatchSemaphore(value: 0)
    var launched: NSRunningApplication?
    var launchError: Error?
    NSWorkspace.shared.openApplication(
        at: app,
        configuration: configuration
    ) { application, error in
        launched = application
        launchError = error
        semaphore.signal()
    }
    while semaphore.wait(timeout: .now() + 0.02) == .timedOut {
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    }
    if let launchError {
        throw ProbeError.launch("Could not launch \(app.path): \(launchError)")
    }
    guard let launched else {
        throw ProbeError.launch("No running application returned for \(app.path)")
    }
    return launched
}

private func terminateApplications(bundleIdentifier: String) throws {
    let existing = NSRunningApplication.runningApplications(
        withBundleIdentifier: bundleIdentifier
    )
    for application in existing {
        _ = application.terminate()
    }
    var stopped = waitFor(timeout: 2) {
        NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).isEmpty ? true : nil
    }
    if stopped != true {
        for application in NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ) {
            _ = application.forceTerminate()
        }
        stopped = waitFor(timeout: 3) {
            NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleIdentifier
            ).isEmpty ? true : nil
        }
    }
    guard stopped == true else {
        throw ProbeError.launch(
            "Could not stop the existing \(bundleIdentifier) process; no candidate was measured"
        )
    }
}

private func measureSession(
    index: Int,
    cmdTabPID: pid_t,
    fixture: NSRunningApplication
) -> SessionMeasurement {
    dismissSwitcher()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    _ = fixture.activate(options: [])
    RunLoop.current.run(until: Date().addingTimeInterval(0.02))

    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == fixture.processIdentifier else {
        return SessionMeasurement(
            index: index,
            revealMilliseconds: nil,
            selectionMilliseconds: nil,
            observationCaptureMilliseconds: nil,
            cpuMilliseconds: nil,
            residentBytes: processUsage(pid: cmdTabPID)?.residentBytes,
            eventTapState: "not_observed",
            interruptionCode: "fixture_frontmost_mismatch",
            interruptionDetail: "The fixture was not frontmost before the shortcut.",
            previewIntegrity: "unavailable",
            activationOutcome: "not_observed",
            cmdTabRunningAfterSession: NSRunningApplication(processIdentifier: cmdTabPID) != nil
        )
    }

    let baselineWindowIDs = Set(visibleWindows(pid: cmdTabPID).map(\.id))
    let usageBefore = processUsage(pid: cmdTabPID)
    let sessionStarted = DispatchTime.now().uptimeNanoseconds
    beginSwitcherChord()

    guard let overlay = waitFor(timeout: 1.5, {
        newlyVisibleSwitcherWindow(pid: cmdTabPID, excluding: baselineWindowIDs)
    }) else {
        releaseSwitcherChord()
        dismissSwitcher()
        return SessionMeasurement(
            index: index,
            revealMilliseconds: nil,
            selectionMilliseconds: nil,
            observationCaptureMilliseconds: nil,
            cpuMilliseconds: nil,
            residentBytes: processUsage(pid: cmdTabPID)?.residentBytes,
            eventTapState: "unresponsive",
            interruptionCode: "reveal_timeout",
            interruptionDetail: "No CmdTab overlay became externally visible after the shortcut.",
            previewIntegrity: "unavailable",
            activationOutcome: "not_observed",
            cmdTabRunningAfterSession: NSRunningApplication(processIdentifier: cmdTabPID) != nil
        )
    }

    let revealMilliseconds = milliseconds(since: sessionStarted)
    RunLoop.current.run(until: Date().addingTimeInterval(0.03))
    let captureSampler = WindowCaptureSampler()
    guard let initialCapture = captureSampler.hashAndLatency(windowID: overlay.id) else {
        releaseSwitcherChord()
        dismissSwitcher()
        return SessionMeasurement(
            index: index,
            revealMilliseconds: revealMilliseconds,
            selectionMilliseconds: nil,
            observationCaptureMilliseconds: nil,
            cpuMilliseconds: nil,
            residentBytes: processUsage(pid: cmdTabPID)?.residentBytes,
            eventTapState: "responsive",
            interruptionCode: "observation_capture_unavailable",
            interruptionDetail: "The visible overlay could not be captured.",
            previewIntegrity: "unavailable",
            activationOutcome: "not_observed",
            cmdTabRunningAfterSession: NSRunningApplication(processIdentifier: cmdTabPID) != nil
        )
    }

    let selectionStarted = DispatchTime.now().uptimeNanoseconds
    advanceSelection()
    let changedCapture: (String, Double)? = waitFor(timeout: 0.75) {
        guard let capture = captureSampler.hashAndLatency(windowID: overlay.id),
              capture.0 != initialCapture.0 else {
            return nil
        }
        return capture
    }
    let selectionMilliseconds = changedCapture.map { _ in
        milliseconds(since: selectionStarted)
    }
    releaseSwitcherChord()
    dismissSwitcher()
    _ = waitFor(timeout: 1) {
        visibleWindows(pid: cmdTabPID).contains { $0.id == overlay.id }
            ? nil
            : true
    }

    let usageAfter = processUsage(pid: cmdTabPID)
    let cmdTabRunningAfterSession = NSRunningApplication(processIdentifier: cmdTabPID) != nil
    let cpuMilliseconds: Double?
    if let before = usageBefore, let after = usageAfter {
        let beforeCPU = before.userNanoseconds + before.systemNanoseconds
        let afterCPU = after.userNanoseconds + after.systemNanoseconds
        cpuMilliseconds = Double(afterCPU &- beforeCPU) / 1_000_000
    } else {
        cpuMilliseconds = nil
    }

    return SessionMeasurement(
        index: index,
        revealMilliseconds: revealMilliseconds,
        selectionMilliseconds: selectionMilliseconds,
        observationCaptureMilliseconds: changedCapture?.1 ?? initialCapture.1,
        cpuMilliseconds: cpuMilliseconds,
        residentBytes: usageAfter?.residentBytes,
        eventTapState: "responsive",
        interruptionCode: !cmdTabRunningAfterSession
            ? "cmdtab_terminated_or_unresponsive"
            : selectionMilliseconds == nil
            ? "selection_timeout"
            : nil,
        interruptionDetail: !cmdTabRunningAfterSession
            ? "CmdTab was not running after the selection attempt."
            : selectionMilliseconds == nil
            ? "No externally visible selection change was observed."
            : nil,
        previewIntegrity: "observed",
        activationOutcome: NSWorkspace.shared.frontmostApplication?.processIdentifier == fixture.processIdentifier
            ? "fixture_application_frontmost_verified"
            : "frontmost_mismatch",
        cmdTabRunningAfterSession: cmdTabRunningAfterSession
    )
}

private func hostArchitecture() -> String {
#if arch(arm64)
    return "arm64"
#elseif arch(x86_64)
    return "x86_64"
#else
    return "unknown"
#endif
}

private func run() throws {
    let arguments = try Arguments.parse()
    guard FileManager.default.fileExists(atPath: arguments.cmdTabApp.path),
          FileManager.default.fileExists(atPath: arguments.windowLabApp.path) else {
        throw ProbeError.invalidArgument("CmdTab.app and WindowLab.app must exist")
    }

    guard let cmdTabBundleIdentifier = Bundle(
        url: arguments.cmdTabApp
    )?.bundleIdentifier else {
        throw ProbeError.invalidArgument("CmdTab.app has no bundle identifier")
    }
    try terminateApplications(bundleIdentifier: cmdTabBundleIdentifier)
    try terminateApplications(bundleIdentifier: "net.cmdtab.fixture.WindowLab")
    RunLoop.current.run(until: Date().addingTimeInterval(1))
    let cmdTab = try launch(app: arguments.cmdTabApp, arguments: [])
    let candidateLaunchMatches =
        cmdTab.bundleURL?.resolvingSymlinksInPath().standardizedFileURL ==
        arguments.cmdTabApp.resolvingSymlinksInPath().standardizedFileURL
    let candidateBecameFrontmost = candidateLaunchMatches && waitFor(timeout: 1) {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == cmdTab.processIdentifier
            ? true
            : nil
    } == true
    let fixture = try launch(
        app: arguments.windowLabApp,
        arguments: ["standard", "--window-count", String(arguments.windowCount)]
    )
    defer { _ = fixture.terminate() }

    RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    let observedWindowCount = visibleWindows(pid: fixture.processIdentifier).count
    let preconditions = Preconditions(
        accessibilityTrusted: AXIsProcessTrusted(),
        screenCaptureAuthorized: CGPreflightScreenCaptureAccess(),
        secureInputObservation: "not_observable_by_probe",
        eventTapHIDObservation: "external_behavioral_proxy_only",
        candidateLaunchStatus: candidateLaunchMatches ? "exact_bundle_verified" : "mismatch",
        candidateFrontmostStatus: candidateBecameFrontmost ? "verified" : "mismatch",
        cmdTabProcessRunning: NSRunningApplication(processIdentifier: cmdTab.processIdentifier) != nil,
        fixtureWindowCountExpected: arguments.windowCount,
        fixtureWindowCountObserved: observedWindowCount
    )
    let activationMetricsBaseline = ActivationOutcomeMetrics.snapshot()

    var measurements: [SessionMeasurement] = []
    if preconditions.accessibilityTrusted,
       preconditions.screenCaptureAuthorized,
       observedWindowCount == arguments.windowCount {
        for index in 1...arguments.sessions {
            autoreleasepool {
                measurements.append(
                    measureSession(
                        index: index,
                        cmdTabPID: cmdTab.processIdentifier,
                        fixture: fixture
                    )
                )
            }
        }
    }

    let idleStartedAt = DispatchTime.now().uptimeNanoseconds
    let idleUsageBefore = processUsage(pid: cmdTab.processIdentifier)
    RunLoop.current.run(until: Date().addingTimeInterval(2))
    let idleUsageAfter = processUsage(pid: cmdTab.processIdentifier)
    let idleElapsed = Double(
        DispatchTime.now().uptimeNanoseconds - idleStartedAt
    )
    let idleCPUPercent: Double?
    if let before = idleUsageBefore, let after = idleUsageAfter, idleElapsed > 0 {
        let beforeCPU = before.userNanoseconds + before.systemNanoseconds
        let afterCPU = after.userNanoseconds + after.systemNanoseconds
        idleCPUPercent = Double(afterCPU &- beforeCPU) / idleElapsed * 100
    } else {
        idleCPUPercent = nil
    }

    var prerequisiteInterruptions: [String] = []
    if !preconditions.accessibilityTrusted {
        prerequisiteInterruptions.append("accessibility_unavailable")
    }
    if !preconditions.screenCaptureAuthorized {
        prerequisiteInterruptions.append("screen_recording_unavailable")
    }
    if observedWindowCount != arguments.windowCount {
        prerequisiteInterruptions.append("fixture_window_count_mismatch")
    }
    if !preconditions.cmdTabProcessRunning {
        prerequisiteInterruptions.append("cmdtab_terminated_or_unresponsive")
    }
    if !candidateLaunchMatches {
        prerequisiteInterruptions.append("candidate_launch_mismatch")
    }
    if !candidateBecameFrontmost {
        prerequisiteInterruptions.append("candidate_frontmost_mismatch")
    }
    let preconditionsReady = prerequisiteInterruptions.isEmpty
    let result = ProbeResult(
        metadata: RunMetadata(
            schemaVersion: 2,
            sourceSHA: arguments.sourceSHA,
            runKind: arguments.runKind,
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            hostOS: ProcessInfo.processInfo.operatingSystemVersionString,
            hostArchitecture: hostArchitecture(),
            cmdTabExecutableSHA256: executableURL(for: arguments.cmdTabApp).flatMap(sha256),
            windowLabExecutableSHA256: executableURL(for: arguments.windowLabApp).flatMap(sha256)
        ),
        preconditions: preconditions,
        measurements: measurements,
        idleCPUPercent: idleCPUPercent,
        evidenceState: preconditionsReady ? "measured" : "blocked",
        evidenceStateReason: preconditionsReady
            ? "Real measurements were collected on this host."
            : "Typed prerequisite interruptions prevented measurement; no samples were fabricated.",
        prerequisiteInterruptions: prerequisiteInterruptions,
        activationOutcomeMetrics: ActivationOutcomeMetrics.snapshot().delta(since: activationMetricsBaseline),
        eventTapObservationMethod:
            "External behavioral proxy: responsive means the global shortcut produced a visible CmdTab overlay; the foreign process CFMachPort is not introspected."
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(result)
    do {
        try FileManager.default.createDirectory(
            at: arguments.output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: arguments.output, options: .atomic)
    } catch {
        throw ProbeError.serialization("Could not write \(arguments.output.path): \(error)")
    }
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data(("PerformanceProbe: \(error)\n").utf8))
    exit(2)
}
