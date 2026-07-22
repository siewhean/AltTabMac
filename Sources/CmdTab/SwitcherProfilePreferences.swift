import AppKit
import SwiftUI

final class ShortcutRecordingState {
    static let shared = ShortcutRecordingState()

    private let lock = NSLock()
    private var recordingCount = 0

    var isRecording: Bool {
        lock.lock()
        let value = recordingCount > 0
        lock.unlock()
        return value
    }

    func begin() {
        lock.lock()
        recordingCount += 1
        lock.unlock()
    }

    func end() {
        lock.lock()
        recordingCount = max(0, recordingCount - 1)
        lock.unlock()
    }
}

private final class ShortcutCaptureNSView: NSView {
    var shortcut: RecordedShortcut?
    var isRecording = false {
        didSet {
            if isRecording && !oldValue {
                ShortcutRecordingState.shared.begin()
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.window?.makeFirstResponder(self)
                    self.needsDisplay = true
                }
            } else if !isRecording && oldValue {
                ShortcutRecordingState.shared.end()
                needsDisplay = true
            }
        }
    }
    var onRecord: ((RecordedShortcut?) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override var focusRingType: NSFocusRingType {
        get { .exterior }
        set {}
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if !isRecording { isRecording = true }
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
            onCancel?()
        }
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 {
            isRecording = false
            onCancel?()
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            isRecording = false
            shortcut = nil
            onRecord?(nil)
            return
        }

        let modifiers = ShortcutModifierMask(eventFlags: event.modifierFlags)
        let label = Self.label(for: event)
        let recorded = RecordedShortcut(
            keyCode: Int64(event.keyCode),
            modifiers: modifiers,
            keyLabel: label
        )
        shortcut = recorded
        isRecording = false
        onRecord?(recorded)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        (isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.24)
            : NSColor.controlBackgroundColor.withAlphaComponent(0.85)
        ).setFill()
        path.fill()
        (isRecording
            ? NSColor.controlAccentColor
            : NSColor.separatorColor
        ).setStroke()
        path.lineWidth = isRecording ? 2 : 1
        path.stroke()

        let text: String
        if isRecording {
            text = "Press shortcut · Esc cancels · Delete clears"
        } else {
            text = shortcut?.displayLabel ?? "Not Set"
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(x: max(10, bounds.midX - size.width / 2), y: bounds.midY - size.height / 2),
            withAttributes: attributes
        )
    }

    private static func label(for event: NSEvent) -> String {
        switch event.keyCode {
        case 48: return "Tab"
        case 49: return "Space"
        case 36, 76: return "Return"
        case 51: return "Delete"
        case 117: return "Forward Delete"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            let value = event.charactersIgnoringModifiers?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased() ?? ""
            return value.isEmpty ? "Key \(event.keyCode)" : value
        }
    }

    deinit {
        if isRecording { ShortcutRecordingState.shared.end() }
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: RecordedShortcut?
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView(frame: NSRect(x: 0, y: 0, width: 280, height: 40))
        view.shortcut = shortcut
        view.isRecording = isRecording
        view.onRecord = { value in
            shortcut = value
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        nsView.shortcut = shortcut
        nsView.isRecording = isRecording
        nsView.needsDisplay = true
    }
}

final class SwitcherProfilePreferencesWindowController: NSWindowController, NSWindowDelegate {
    private var retainedController: NSHostingController<SwitcherProfilePreferencesView>?

    init() {
        let root = SwitcherProfilePreferencesView()
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "CmdTab Shortcut Profiles"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 980, height: 720))
        window.minSize = NSSize(width: 820, height: 620)
        window.isReleasedWhenClosed = false
        retainedController = hosting
        super.init(window: window)
        window.delegate = self
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

struct SwitcherProfilePreferencesView: View {
    @StateObject private var store = SwitcherProfileStore.shared
    @State private var selectedID: UUID?
    @State private var draft: SwitcherShortcutProfile?
    @State private var forwardRecording = false
    @State private var reverseRecording = false
    @State private var statusMessage = ""

    var body: some View {
        HSplitView {
            profileSidebar
                .frame(minWidth: 230, idealWidth: 260, maxWidth: 300)
            editor
                .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if selectedID == nil {
                selectedID = store.profiles.first?.id
                loadDraft()
            }
        }
        .onChange(of: selectedID) { _ in loadDraft() }
    }

    private var profileSidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedID) {
                ForEach(store.profiles) { profile in
                    HStack(spacing: 10) {
                        Image(systemName: profile.isEnabled ? "keyboard.fill" : "keyboard")
                            .foregroundStyle(profile.isEnabled ? .tint : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .lineLimit(1)
                            Text(profile.forwardShortcut.displayLabel)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(profile.id)
                }
            }

            Divider()
            HStack(spacing: 8) {
                Button(action: addProfile) { Image(systemName: "plus") }
                    .help("Add profile")
                Button(action: duplicateProfile) { Image(systemName: "plus.square.on.square") }
                    .disabled(selectedID == nil)
                    .help("Duplicate profile")
                Button(action: removeProfile) { Image(systemName: "minus") }
                    .disabled(store.profiles.count <= 1 || selectedID == nil)
                    .help("Delete profile")
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
    }

    @ViewBuilder
    private var editor: some View {
        if let draftBinding = Binding($draft) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("Profile name", text: draftBinding.name)
                            .font(.title2.weight(.semibold))
                        Toggle("Enabled", isOn: draftBinding.isEnabled)
                            .toggleStyle(.switch)
                    }

                    GroupBox("Shortcuts") {
                        VStack(alignment: .leading, spacing: 14) {
                            shortcutRow(
                                title: "Forward",
                                shortcut: Binding(
                                    get: { draftBinding.wrappedValue.forwardShortcut },
                                    set: { if let value = $0 { draftBinding.wrappedValue.forwardShortcut = value } }
                                ),
                                recording: $forwardRecording,
                                canClear: false
                            )
                            shortcutRow(
                                title: "Reverse",
                                shortcut: draftBinding.reverseShortcut,
                                recording: $reverseRecording,
                                canClear: true
                            )
                            Picker("Session Behaviour", selection: draftBinding.releaseBehavior) {
                                ForEach(SwitcherReleaseBehavior.allCases, id: \.self) { behavior in
                                    Text(behavior.title).tag(behavior)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(8)
                    }

                    GroupBox("Scope and Presentation") {
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle("Use global appearance, visibility, minimized-window, and display settings", isOn: draftBinding.inheritsGlobalSettings)
                            if !draftBinding.wrappedValue.inheritsGlobalSettings {
                                Picker("Style", selection: draftBinding.style) {
                                    ForEach(SwitcherStyle.allCases, id: \.self) { style in
                                        Text(style.title).tag(style)
                                    }
                                }
                                Picker("Window Visibility", selection: draftBinding.visibilityScope) {
                                    ForEach(WindowVisibilityScope.allCases, id: \.self) { scope in
                                        Text(scope.title).tag(scope)
                                    }
                                }
                                Toggle("Include minimized windows", isOn: draftBinding.includeMinimizedWindows)
                                Picker("Display Target", selection: draftBinding.displayPlacement) {
                                    ForEach(SwitcherDisplayPreference.allCases, id: \.self) { placement in
                                        Text(placement.title).tag(placement)
                                    }
                                }
                            }
                        }
                        .padding(8)
                    }

                    GroupBox("Application Filter") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Mode", selection: draftBinding.appFilter.mode) {
                                Text("All Applications").tag(ProfileFilterMode.allApplications)
                                Text("Include Only").tag(ProfileFilterMode.includeOnly)
                                Text("Exclude").tag(ProfileFilterMode.exclude)
                            }
                            .pickerStyle(.segmented)

                            if draftBinding.wrappedValue.appFilter.mode != .allApplications {
                                Text("Enter one bundle identifier per line, for example `company.thebrowser.Browser`.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextEditor(
                                    text: Binding(
                                        get: { draftBinding.wrappedValue.appFilter.bundleIdentifiers.joined(separator: "\n") },
                                        set: { draftBinding.wrappedValue.appFilter.bundleIdentifiers = $0.split(separator: "\n").map(String.init) }
                                    )
                                )
                                .font(.body.monospaced())
                                .frame(minHeight: 90)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                            }
                        }
                        .padding(8)
                    }

                    if !store.validationIssues.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(store.validationIssues.enumerated()), id: \.offset) { _, issue in
                                Label(issue.description, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .font(.callout)
                            }
                        }
                    }

                    HStack {
                        Button("Import…", action: importProfiles)
                        Button("Export…", action: exportProfiles)
                        Button("Reset Profiles", role: .destructive, action: resetProfiles)
                        Button("Reset Durable MRU", role: .destructive) {
                            SwitcherHistoryStore.shared.resetDurableHistory()
                            statusMessage = "Durable window history was cleared."
                        }
                        Spacer()
                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button("Revert", action: loadDraft)
                        Button("Save", action: saveDraft)
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(24)
            }
        } else {
            ContentUnavailableView(
                "No Profile Selected",
                systemImage: "keyboard",
                description: Text("Select or create a shortcut profile.")
            )
        }
    }

    private func shortcutRow(
        title: String,
        shortcut: Binding<RecordedShortcut?>,
        recording: Binding<Bool>,
        canClear: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 70, alignment: .leading)
            ShortcutRecorder(shortcut: shortcut, isRecording: recording)
                .frame(height: 40)
            Button(recording.wrappedValue ? "Cancel" : "Record") {
                recording.wrappedValue.toggle()
            }
            if canClear {
                Button("Clear") { shortcut.wrappedValue = nil }
            }
        }
    }

    private func loadDraft() {
        guard let selectedID,
              let profile = store.profiles.first(where: { $0.id == selectedID }) else {
            draft = nil
            return
        }
        draft = profile
        statusMessage = ""
    }

    private func saveDraft() {
        guard let draft else { return }
        if store.update(draft) {
            statusMessage = "Saved."
            loadDraft()
        } else {
            statusMessage = "Resolve the validation issues before saving."
        }
    }

    private func addProfile() {
        let profile = SwitcherShortcutProfile(
            id: UUID(),
            name: "New Switcher",
            isEnabled: false,
            forwardShortcut: RecordedShortcut(
                keyCode: 49,
                modifiers: [.control, .option],
                keyLabel: "Space"
            ),
            reverseShortcut: nil,
            releaseBehavior: .pressToToggle,
            inheritsGlobalSettings: false,
            style: .classicGrid,
            visibilityScope: .visibleSpaces,
            includeMinimizedWindows: true,
            displayPlacement: .activeWindowDisplay,
            appFilter: .all
        )
        if store.add(profile) {
            selectedID = profile.id
        }
    }

    private func duplicateProfile() {
        guard let selectedID,
              let copy = store.duplicate(profileID: selectedID) else { return }
        self.selectedID = copy.id
    }

    private func removeProfile() {
        guard let selectedID, store.remove(profileID: selectedID) else { return }
        self.selectedID = store.profiles.first?.id
    }

    private func resetProfiles() {
        store.resetToDefaults()
        selectedID = store.profiles.first?.id
        statusMessage = "Default profiles restored."
    }

    private func exportProfiles() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "CmdTab-Shortcut-Profiles.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportDocument().write(to: url, options: .atomic)
            statusMessage = "Exported profiles."
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importProfiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.importDocument(Data(contentsOf: url))
            selectedID = store.profiles.first?.id
            statusMessage = "Imported profiles."
        } catch {
            statusMessage = "Import rejected: \(error.localizedDescription)"
        }
    }
}
