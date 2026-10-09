import AppKit
import ApplicationServices
import SwiftUI

/// Keeps the exact running app within reach while System Settings owns focus.
enum PermissionSetupKind: CaseIterable {
    case accessibility
    case screenRecording

    var title: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .screenRecording: return "Screen Recording"
        }
    }

    var settingsURL: URL {
        let pane = self == .accessibility ? "Privacy_Accessibility" : "Privacy_ScreenCapture"
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
    }

    var isGranted: Bool {
        switch self {
        case .accessibility: return AXIsProcessTrusted()
        case .screenRecording: return CGPreflightScreenCaptureAccess()
        }
    }

    /// Command-line test binaries are not app bundles and must not be offered as apps.
    static func draggableAppURL(bundleURL: URL) -> URL? {
        guard bundleURL.isFileURL, bundleURL.pathExtension.lowercased() == "app" else { return nil }
        return bundleURL
    }
}

@MainActor
final class PermissionSetupWindowController: NSObject, NSWindowDelegate {
    static let shared = PermissionSetupWindowController()
    private(set) var panel: NSPanel?
    private var permission: PermissionSetupKind = .accessibility
    private var refreshTimer: Timer?
    private var lastGranted = false

    func show(for permission: PermissionSetupKind) {
        self.permission = permission
        refreshTimer?.invalidate()
        if panel == nil {
            let panel = Self.makePanel()
            panel.delegate = self
            self.panel = panel
        }
        refreshContent()
        if let panel, !panel.isVisible,
           let screen = NSApp.keyWindow?.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: max(visible.minX, visible.maxX - panel.frame.width - 20),
                y: max(visible.minY, visible.midY - panel.frame.height / 2)
            ))
        }
        NSWorkspace.shared.open(permission.settingsURL)
        panel?.orderFrontRegardless()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshIfChanged() }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 330, height: 380),
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.title = "Enable CmdTab Permissions"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        return panel
    }

    func windowWillClose(_ notification: Notification) {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refreshIfChanged() {
        guard panel?.isVisible == true else {
            refreshTimer?.invalidate()
            refreshTimer = nil
            return
        }
        if permission.isGranted != lastGranted { refreshContent() }
    }

    private func refreshContent() {
        lastGranted = permission.isGranted
        let hostingView = NSHostingView(rootView: PermissionSetupView(
            permission: permission,
            granted: lastGranted,
            appURL: PermissionSetupKind.draggableAppURL(bundleURL: Bundle.main.bundleURL),
            onRefresh: { [weak self] in self?.refreshContent() },
            onClose: { [weak self] in self?.panel?.close() }
        ))
        panel?.contentView = hostingView
        panel?.setContentSize(hostingView.fittingSize)
    }
}

private struct PermissionSetupView: View {
    let permission: PermissionSetupKind
    let granted: Bool
    let appURL: URL?
    let onRefresh: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Enable \(permission.title)").font(.headline)
            if let appURL {
                DraggablePermissionAppIcon(appURL: appURL)
                    .frame(width: 68, height: 68)
                Text("Drag CmdTab into the app list, then enable its switch.")
                    .font(.callout).multilineTextAlignment(.center)
                Text("Already listed? Just enable CmdTab. If dragging is unavailable, use + to add the app.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Show This CmdTab in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([appURL])
                }
            } else {
                Text("Open a packaged CmdTab app to drag it into System Settings.")
                    .font(.callout).multilineTextAlignment(.center)
            }
            Label(granted ? "Permission enabled" : "Waiting for permission",
                  systemImage: granted ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(granted ? Color.green : Color.secondary)
                .font(.callout)
            if permission == .screenRecording {
                Text("If macOS asks, quit and reopen CmdTab to enable previews.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack {
                Button("Refresh", action: onRefresh)
                Spacer()
                Button("Done", action: onClose).keyboardShortcut(.cancelAction)
            }
        }
        .padding(18)
        .frame(width: 330)
    }
}

private struct DraggablePermissionAppIcon: NSViewRepresentable {
    let appURL: URL

    func makeNSView(context: Context) -> PermissionAppDragView {
        PermissionAppDragView(appURL: appURL)
    }

    func updateNSView(_ nsView: PermissionAppDragView, context: Context) {}
}

/// NSURL writes public.file-url, which System Settings accepts as a real app URL.
private final class PermissionAppDragView: NSImageView, NSDraggingSource {
    private let appURL: URL

    init(appURL: URL) {
        self.appURL = appURL
        super.init(frame: .zero)
        image = NSWorkspace.shared.icon(forFile: appURL.path)
        imageScaling = .scaleProportionallyUpOrDown
        toolTip = "Drag this running CmdTab app into System Settings"
        setAccessibilityLabel("CmdTab app")
        setAccessibilityHelp("Drag into the permission list. Alternatively, use Show This CmdTab in Finder and the add button in System Settings.")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {}

    override func mouseDragged(with event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: appURL as NSURL)
        item.setDraggingFrame(bounds, contents: image)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}
