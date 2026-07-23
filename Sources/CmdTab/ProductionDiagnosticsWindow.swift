import AppKit
import Darwin
import SwiftUI

final class ProductionDiagnosticsWindowController: NSWindowController {
    private var retainedController: NSHostingController<ProductionDiagnosticsView>?

    init() {
        let hosting = NSHostingController(rootView: ProductionDiagnosticsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "CmdTab Diagnostics"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 640, height: 540))
        window.minSize = NSSize(width: 560, height: 460)
        window.isReleasedWhenClosed = false
        retainedController = hosting
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}

struct ProductionDiagnosticsSnapshot: Equatable {
    let accessibilityReady: Bool
    let screenRecordingReady: Bool
    let secureInputActive: Bool
    let exactIdentity: CapabilityStatus
    let workspace: CapabilityStatus
    let enabledProfileCount: Int
    let profileValidationIssues: [String]
    let durableRecordCount: Int
    let durableHistoryPath: String

    static func capture() -> ProductionDiagnosticsSnapshot {
        let profileStore = SwitcherProfileStore.shared
        let historyURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?
            .appendingPathComponent("CmdTab", isDirectory: true)
            .appendingPathComponent("window-history-v1.json")

        return ProductionDiagnosticsSnapshot(
            accessibilityReady: AXIsProcessTrusted(),
            screenRecordingReady: CGPreflightScreenCaptureAccess(),
            secureInputActive: SecureInputMonitor.isEnabled,
            exactIdentity: AXWindowIdentityLookup.status,
            workspace: WindowWorkspaceProvider.shared.status,
            enabledProfileCount: profileStore.profilesSnapshot().filter(\.isEnabled).count,
            profileValidationIssues: profileStore.validationIssues.map(\.description),
            durableRecordCount: DurableSwitcherHistoryStore.shared.snapshot().count,
            durableHistoryPath: historyURL?.path ?? "Unavailable"
        )
    }

    var sanitizedReport: String {
        let profileIssues = profileValidationIssues.isEmpty
            ? "none"
            : profileValidationIssues.joined(separator: " | ")
        return """
        CmdTab diagnostics
        bundle=\(Bundle.main.bundleIdentifier ?? "unknown")
        version=\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")
        build=\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown")
        macOS=\(ProcessInfo.processInfo.operatingSystemVersionString)
        architecture=\(ProcessInfo.processInfo.machineArchitecture)
        accessibility=\(accessibilityReady ? "ready" : "required")
        screenRecording=\(screenRecordingReady ? "ready" : "required")
        secureInput=\(secureInputActive ? "active" : "inactive")
        exactWindowIdentity=\(exactIdentity.level.rawValue):\(exactIdentity.reason ?? "ok")
        workspace=\(workspace.level.rawValue):\(workspace.reason ?? "ok")
        enabledProfiles=\(enabledProfileCount)
        profileValidation=\(profileIssues)
        durableRecords=\(durableRecordCount)
        durableHistoryPath=\(durableHistoryPath)
        """
    }
}

struct ProductionDiagnosticsView: View {
    @State private var snapshot = ProductionDiagnosticsSnapshot.capture()
    @State private var statusMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CmdTab Diagnostics")
                        .font(.title2.weight(.bold))
                    Text("Sanitized capability and persistence status. No window titles, document paths, previews, search text, or clipboard content are included.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh") { refresh() }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    diagnosticRow(
                        title: "Accessibility",
                        value: snapshot.accessibilityReady ? "Ready" : "Required",
                        level: snapshot.accessibilityReady ? .available : .unavailable
                    )
                    diagnosticRow(
                        title: "Screen Recording",
                        value: snapshot.screenRecordingReady ? "Ready" : "Required",
                        level: snapshot.screenRecordingReady ? .available : .degraded
                    )
                    diagnosticRow(
                        title: "Secure Input",
                        value: snapshot.secureInputActive ? "Active — shortcuts bypassed" : "Inactive",
                        level: snapshot.secureInputActive ? .degraded : .available
                    )
                    diagnosticRow(
                        title: "Exact Window Identity",
                        value: statusText(snapshot.exactIdentity),
                        level: snapshot.exactIdentity.level
                    )
                    diagnosticRow(
                        title: "Workspace Provider",
                        value: statusText(snapshot.workspace),
                        level: snapshot.workspace.level
                    )
                    diagnosticRow(
                        title: "Shortcut Profiles",
                        value: snapshot.profileValidationIssues.isEmpty
                            ? "\(snapshot.enabledProfileCount) enabled; valid"
                            : snapshot.profileValidationIssues.joined(separator: " · "),
                        level: snapshot.profileValidationIssues.isEmpty ? .available : .failed
                    )
                    diagnosticRow(
                        title: "Durable MRU",
                        value: "\(snapshot.durableRecordCount) privacy-minimised record\(snapshot.durableRecordCount == 1 ? "" : "s")",
                        level: .available
                    )
                    Text(snapshot.durableHistoryPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Divider()

            HStack {
                Button("Copy Sanitized Report") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(snapshot.sanitizedReport, forType: .string)
                    statusMessage = "Copied."
                }
                Button("Reset Durable MRU", role: .destructive) {
                    SwitcherHistoryStore.shared.resetDurableHistory()
                    refresh()
                    statusMessage = "Durable MRU reset. Preferences and licensing were not changed."
                }
                Spacer()
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 460)
    }

    private func diagnosticRow(
        title: String,
        value: String,
        level: CapabilityStatus.Level
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(for: level))
                .foregroundStyle(color(for: level))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(value)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
    }

    private func statusText(_ status: CapabilityStatus) -> String {
        "\(status.level.rawValue.capitalized) — \(status.reason ?? "No limitation reported")"
    }

    private func icon(for level: CapabilityStatus.Level) -> String {
        switch level {
        case .available: return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.triangle.fill"
        case .unavailable: return "minus.circle.fill"
        case .failed: return "xmark.octagon.fill"
        }
    }

    private func color(for level: CapabilityStatus.Level) -> Color {
        switch level {
        case .available: return .green
        case .degraded: return .orange
        case .unavailable: return .secondary
        case .failed: return .red
        }
    }

    private func refresh() {
        WindowWorkspaceProvider.shared.refresh()
        snapshot = .capture()
    }
}

private extension ProcessInfo {
    var machineArchitecture: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let bytes = mirror.children.compactMap { child -> UInt8? in
            guard let value = child.value as? Int8, value != 0 else { return nil }
            return UInt8(bitPattern: value)
        }
        return String(bytes: bytes, encoding: .utf8) ?? "unknown"
    }
}