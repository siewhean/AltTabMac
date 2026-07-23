import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class ProductionProfilePreferencesWindowController: NSWindowController, NSWindowDelegate {
    private let model = ProductionProfileEditorModel()
    private var retainedController: NSHostingController<ProductionProfilePreferencesView>?

    init() {
        let hosting = NSHostingController(
            rootView: ProductionProfilePreferencesView(model: model)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "CmdTab Shortcut Profiles"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 1_020, height: 740))
        window.minSize = NSSize(width: 860, height: 640)
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
        model.refreshFromStore(preserveDirtyDraft: true)
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard model.hasUnsavedChanges else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Save changes to this shortcut profile?"
        alert.informativeText = "Closing now would discard edits that have not passed validation and been saved."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Discard")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return model.saveDraft()
        case .alertThirdButtonReturn:
            model.discardDraft()
            return true
        default:
            return false
        }
    }
}

@MainActor
final class ProductionProfileEditorModel: ObservableObject {
    @Published private(set) var profiles: [SwitcherShortcutProfile] = []
    @Published private(set) var selectedID: UUID?
    @Published var draft: SwitcherShortcutProfile?
    @Published private(set) var statusMessage = ""
    @Published private(set) var validationMessages: [String] = []

    let applicationCatalog = ProductionApplicationCatalog()

    private let store: SwitcherProfileStore
    private var observation: NSObjectProtocol?
    private var isWritingStore = false

    init(store: SwitcherProfileStore = .shared) {
        self.store = store
        refreshFromStore(preserveDirtyDraft: false)
        observation = NotificationCenter.default.addObserver(
            forName: SwitcherProfileStore.didChangeNotification,
            object: store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isWritingStore else { return }
                self.refreshFromStore(preserveDirtyDraft: true)
            }
        }
    }

    deinit {
        if let observation {
            NotificationCenter.default.removeObserver(observation)
        }
    }

    var hasUnsavedChanges: Bool {
        guard let draft else { return false }
        return store.profile(id: draft.id) != draft
    }

    func refreshFromStore(preserveDirtyDraft: Bool) {
        let previousDraft = draft
        let previousWasDirty = hasUnsavedChanges
        profiles = store.profilesSnapshot()

        if preserveDirtyDraft,
           previousWasDirty,
           let previousDraft,
           profiles.contains(where: { $0.id == previousDraft.id }) {
            selectedID = previousDraft.id
            draft = previousDraft
            validationMessages = validationIssues(for: previousDraft)
            return
        }

        if let selectedID,
           let profile = profiles.first(where: { $0.id == selectedID }) {
            draft = profile
        } else {
            selectedID = profiles.first?.id
            draft = profiles.first
        }
        validationMessages = []
    }

    func selectProfile(_ profileID: UUID) {
        guard selectedID != profileID else { return }
        if hasUnsavedChanges, !saveDraft() {
            statusMessage = "Resolve the current profile errors or choose Revert before switching profiles."
            return
        }
        selectedID = profileID
        draft = profiles.first(where: { $0.id == profileID })
        validationMessages = []
        statusMessage = ""
    }

    /// Keeps the raw draft intact while the user types. Normalization belongs at
    /// the save/import boundary; applying it on every keystroke would trim names,
    /// sort bundle identifiers, and move the TextEditor insertion point.
    func updateDraft(_ mutation: (inout SwitcherShortcutProfile) -> Void) {
        guard var value = draft else { return }
        mutation(&value)
        draft = value
        validationMessages = validationIssues(for: value)
        statusMessage = validationMessages.isEmpty
            ? "Unsaved changes"
            : "Resolve validation errors before saving."
    }

    @discardableResult
    func saveDraft() -> Bool {
        guard var value = draft else { return true }
        value.normalize()
        let issues = SwitcherProfileValidator.issues(
            in: candidateProfiles(replacing: value)
        )
        guard issues.isEmpty else {
            validationMessages = issues.map(\.description)
            statusMessage = "Profile was not saved."
            return false
        }

        isWritingStore = true
        let saved = store.update(value)
        isWritingStore = false
        guard saved else {
            validationMessages = store.validationIssues.map(\.description)
            statusMessage = "Profile was not saved."
            return false
        }

        profiles = store.profilesSnapshot()
        draft = profiles.first(where: { $0.id == value.id })
        validationMessages = []
        statusMessage = "Saved."
        return true
    }

    func discardDraft() {
        guard let selectedID else { return }
        draft = store.profile(id: selectedID)
        validationMessages = []
        statusMessage = "Changes reverted."
    }

    func addProfile() {
        guard !hasUnsavedChanges || saveDraft() else { return }
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
            inheritsGlobalSettings: true,
            style: SwitcherPreferences.shared.switcherStyle,
            visibilityScope: SwitcherPreferences.shared.windowVisibilityScope,
            includeMinimizedWindows: SwitcherPreferences.shared.includeMinimizedWindows,
            displayPlacement: SwitcherPreferences.shared.displayPlacement,
            appFilter: .all
        )

        isWritingStore = true
        let added = store.add(profile)
        isWritingStore = false
        guard added else {
            validationMessages = store.validationIssues.map(\.description)
            statusMessage = "The new profile could not be created."
            return
        }
        profiles = store.profilesSnapshot()
        selectedID = profile.id
        draft = store.profile(id: profile.id)
        validationMessages = []
        statusMessage = "New disabled profile created. Assign and validate its shortcut before enabling it."
    }

    func duplicateSelectedProfile() {
        guard !hasUnsavedChanges || saveDraft(), let selectedID else { return }
        isWritingStore = true
        let copy = store.duplicate(profileID: selectedID)
        isWritingStore = false
        guard let copy else { return }
        profiles = store.profilesSnapshot()
        self.selectedID = copy.id
        draft = store.profile(id: copy.id)
        validationMessages = []
        statusMessage = "Duplicate created disabled to avoid shortcut conflicts."
    }

    func removeSelectedProfile() {
        guard let selectedID else { return }
        let profileName = draft?.name ?? "this profile"
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete \(profileName)?"
        alert.informativeText = "This cannot be undone. At least one valid enabled profile must remain."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        isWritingStore = true
        let removed = store.remove(profileID: selectedID)
        isWritingStore = false
        guard removed else {
            validationMessages = store.validationIssues.map(\.description)
            statusMessage = "Profile was not deleted."
            return
        }
        profiles = store.profilesSnapshot()
        self.selectedID = profiles.first?.id
        draft = profiles.first
        validationMessages = []
        statusMessage = "Profile deleted."
    }

    func resetProfiles() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Reset all shortcut profiles?"
        alert.informativeText = "This restores the Command-Tab and Option-Tab defaults. Global settings, licensing, and durable MRU are not removed."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        isWritingStore = true
        store.resetToDefaults()
        isWritingStore = false
        refreshFromStore(preserveDirtyDraft: false)
        statusMessage = "Default profiles restored."
    }

    func exportProfiles() {
        guard !hasUnsavedChanges || saveDraft() else { return }
        do {
            let data = try store.exportDocument()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "CmdTab-Shortcut-Profiles.json"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url, options: .atomic)
            statusMessage = "Profiles exported."
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func importProfiles() {
        guard !hasUnsavedChanges || saveDraft() else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            isWritingStore = true
            defer { isWritingStore = false }
            try store.importDocument(data)
            refreshFromStore(preserveDirtyDraft: false)
            statusMessage = "Profiles imported and validated."
        } catch {
            validationMessages = [error.localizedDescription]
            statusMessage = "Import rejected without changing existing profiles."
        }
    }

    func resetDurableMRU() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Reset durable window history?"
        alert.informativeText = "This clears restored MRU order only. Profiles, settings, licensing, and current-session order remain intact."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        SwitcherHistoryStore.shared.resetDurableHistory()
        statusMessage = "Durable MRU reset."
    }

    func setApplicationFilterIdentifiers(_ values: Set<String>) {
        updateDraft { profile in
            profile.appFilter.bundleIdentifiers = values
                .map { $0.lowercased() }
                .sorted()
        }
    }

    private func validationIssues(
        for profile: SwitcherShortcutProfile
    ) -> [String] {
        SwitcherProfileValidator
            .issues(in: candidateProfiles(replacing: profile))
            .map(\.description)
    }

    private func candidateProfiles(
        replacing profile: SwitcherShortcutProfile
    ) -> [SwitcherShortcutProfile] {
        profiles.map { $0.id == profile.id ? profile : $0 }
    }
}

struct ProductionProfilePreferencesView: View {
    @ObservedObject var model: ProductionProfileEditorModel
    @State private var forwardRecording = false
    @State private var reverseRecording = false
    @State private var appPickerPresented = false

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 230, idealWidth: 270, maxWidth: 310)
            editor
                .frame(minWidth: 580, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: selectionBinding) {
                ForEach(model.profiles) { profile in
                    HStack(spacing: 10) {
                        Image(systemName: profile.isEnabled ? "keyboard.fill" : "keyboard")
                            .foregroundStyle(
                                profile.isEnabled ? Color.accentColor : Color.secondary
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name).lineLimit(1)
                            Text(profile.forwardShortcut.displayLabel)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        if profile.id == model.selectedID, model.hasUnsavedChanges {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 7, height: 7)
                                .help("Unsaved changes")
                        }
                    }
                    .tag(profile.id)
                }
            }
            .listStyle(.sidebar)

            Divider()
            HStack(spacing: 8) {
                Button(action: model.addProfile) { Image(systemName: "plus") }
                    .help("Add profile")
                Button(action: model.duplicateSelectedProfile) {
                    Image(systemName: "plus.square.on.square")
                }
                .disabled(model.selectedID == nil)
                .help("Duplicate profile")
                Button(action: model.removeSelectedProfile) { Image(systemName: "minus") }
                    .disabled(model.profiles.count <= 1 || model.selectedID == nil)
                    .help("Delete profile")
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
    }

    @ViewBuilder
    private var editor: some View {
        if let draft = model.draft {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    shortcutSection
                    scopeSection(for: draft)
                    filterSection(for: draft)
                    persistenceSection
                    validationSection
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("No Profile Selected")
                    .font(.title3.weight(.semibold))
                Text("Select or create a shortcut profile.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            TextField("Profile name", text: binding(\.name))
                .font(.title2.weight(.semibold))
            Toggle("Enabled", isOn: binding(\.isEnabled))
                .toggleStyle(.switch)
        }
    }

    private var shortcutSection: some View {
        GroupBox("Shortcuts") {
            VStack(alignment: .leading, spacing: 14) {
                shortcutRow(
                    title: "Forward",
                    shortcut: Binding(
                        get: { model.draft?.forwardShortcut },
                        set: { value in
                            guard let value else { return }
                            model.updateDraft { $0.forwardShortcut = value }
                        }
                    ),
                    recording: $forwardRecording,
                    canClear: false
                )
                shortcutRow(
                    title: "Reverse",
                    shortcut: Binding(
                        get: { model.draft?.reverseShortcut },
                        set: { value in
                            model.updateDraft { $0.reverseShortcut = value }
                        }
                    ),
                    recording: $reverseRecording,
                    canClear: true
                )
                Picker("Session Behaviour", selection: binding(\.releaseBehavior)) {
                    ForEach(SwitcherReleaseBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.title).tag(behavior)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(8)
        }
    }

    private func scopeSection(
        for draft: SwitcherShortcutProfile
    ) -> some View {
        GroupBox("Scope and Presentation") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(
                    "Use global appearance, visibility, minimized-window, and display settings",
                    isOn: binding(\.inheritsGlobalSettings)
                )

                if !draft.inheritsGlobalSettings {
                    Picker("Style", selection: binding(\.style)) {
                        ForEach(SwitcherStyle.allCases, id: \.self) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    Picker("Window Visibility", selection: binding(\.visibilityScope)) {
                        ForEach(WindowVisibilityScope.allCases, id: \.self) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    Toggle(
                        "Include minimized windows",
                        isOn: binding(\.includeMinimizedWindows)
                    )
                    Picker("Display Target", selection: binding(\.displayPlacement)) {
                        ForEach(SwitcherDisplayPreference.allCases, id: \.self) { placement in
                            Text(placement.title).tag(placement)
                        }
                    }
                }

                Text("The resolved values are frozen when a session opens. Edits made while a switcher is visible apply to the next session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
    }

    private func filterSection(
        for draft: SwitcherShortcutProfile
    ) -> some View {
        GroupBox("Application Filter") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Mode", selection: binding(\.appFilter.mode)) {
                    Text("All Applications").tag(ProfileFilterMode.allApplications)
                    Text("Include Only").tag(ProfileFilterMode.includeOnly)
                    Text("Exclude").tag(ProfileFilterMode.exclude)
                }
                .pickerStyle(.segmented)

                if draft.appFilter.mode != .allApplications {
                    HStack {
                        Text("\(draft.appFilter.bundleIdentifiers.count) selected bundle identifier\(draft.appFilter.bundleIdentifiers.count == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Choose Installed Apps…") {
                            appPickerPresented = true
                        }
                    }

                    TextEditor(text: bundleIdentifierTextBinding)
                        .font(.body.monospaced())
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.25))
                        )
                    Text("Use one bundle identifier per line. Include Only must contain at least one entry before an enabled profile can be saved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
        .sheet(isPresented: $appPickerPresented) {
            ProductionApplicationPicker(
                catalog: model.applicationCatalog,
                selectedBundleIdentifiers: Binding(
                    get: {
                        Set(
                            (model.draft?.appFilter.bundleIdentifiers ?? [])
                                .map { $0.lowercased() }
                        )
                    },
                    set: model.setApplicationFilterIdentifiers
                )
            )
        }
    }

    private var persistenceSection: some View {
        GroupBox("Backup and Privacy") {
            HStack {
                Button("Import…", action: model.importProfiles)
                Button("Export…", action: model.exportProfiles)
                Button("Reset Profiles…", role: .destructive, action: model.resetProfiles)
                Button("Reset Durable MRU…", role: .destructive, action: model.resetDurableMRU)
                Spacer()
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private var validationSection: some View {
        if !model.validationMessages.isEmpty {
            GroupBox("Validation") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.validationMessages, id: \.self) { message in
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .padding(8)
            }
        }
    }

    private var actionBar: some View {
        HStack {
            Text(model.statusMessage)
                .font(.caption)
                .foregroundStyle(
                    model.validationMessages.isEmpty
                        ? Color.secondary
                        : Color.orange
                )
            Spacer()
            Button("Revert", action: model.discardDraft)
                .disabled(!model.hasUnsavedChanges)
            Button("Save", action: { _ = model.saveDraft() })
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(
                    !model.hasUnsavedChanges ||
                        !model.validationMessages.isEmpty
                )
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { model.selectedID },
            set: { value in
                if let value { model.selectProfile(value) }
            }
        )
    }

    private func binding<Value>(
        _ keyPath: WritableKeyPath<SwitcherShortcutProfile, Value>
    ) -> Binding<Value> {
        Binding(
            get: {
                guard let draft = model.draft else {
                    preconditionFailure(
                        "A profile binding was read without a selected draft"
                    )
                }
                return draft[keyPath: keyPath]
            },
            set: { value in
                model.updateDraft { $0[keyPath: keyPath] = value }
            }
        )
    }

    private var bundleIdentifierTextBinding: Binding<String> {
        Binding(
            get: {
                (model.draft?.appFilter.bundleIdentifiers ?? [])
                    .joined(separator: "\n")
            },
            set: { value in
                let identifiers = value
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .map(String.init)
                model.updateDraft { $0.appFilter.bundleIdentifiers = identifiers }
            }
        )
    }

    private func shortcutRow(
        title: String,
        shortcut: Binding<RecordedShortcut?>,
        recording: Binding<Bool>,
        canClear: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if canClear, shortcut.wrappedValue != nil {
                    Button("Clear") { shortcut.wrappedValue = nil }
                        .buttonStyle(.borderless)
                }
            }
            ShortcutRecorder(shortcut: shortcut, isRecording: recording)
                .frame(height: 42)
        }
    }
}

private struct ProductionApplicationOption: Identifiable, Hashable {
    let bundleIdentifier: String
    let displayName: String
    let icon: NSImage?

    var id: String { bundleIdentifier }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }

    static func == (
        lhs: ProductionApplicationOption,
        rhs: ProductionApplicationOption
    ) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}

@MainActor
final class ProductionApplicationCatalog: ObservableObject {
    @Published private(set) var options: [ProductionApplicationOption] = []
    @Published private(set) var isLoading = false

    init() {
        reload()
    }

    func reload() {
        guard !isLoading else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let discovered = Self.discoverApplications()
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated {
                    self?.options = discovered
                    self?.isLoading = false
                }
            }
        }
    }

    nonisolated private static func discoverApplications() -> [ProductionApplicationOption] {
        let fileManager = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Setapp", isDirectory: true),
        ]

        var seen = Set<String>()
        var results: [ProductionApplicationOption] = []

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let identifier = bundle.bundleIdentifier else {
                    continue
                }
                let normalized = identifier.lowercased()
                guard seen.insert(normalized).inserted else { continue }

                let name =
                    (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? url.deletingPathExtension().lastPathComponent

                results.append(
                    ProductionApplicationOption(
                        bundleIdentifier: normalized,
                        displayName: name,
                        icon: NSWorkspace.shared.icon(forFile: url.path)
                    )
                )
            }
        }

        return results.sorted {
            let nameComparison = $0.displayName.localizedCaseInsensitiveCompare(
                $1.displayName
            )
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            return $0.bundleIdentifier < $1.bundleIdentifier
        }
    }
}

private struct ProductionApplicationPicker: View {
    @ObservedObject var catalog: ProductionApplicationCatalog
    @Binding var selectedBundleIdentifiers: Set<String>
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredOptions: [ProductionApplicationOption] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return catalog.options }
        return catalog.options.filter {
            $0.displayName.localizedCaseInsensitiveContains(normalized) ||
                $0.bundleIdentifier.localizedCaseInsensitiveContains(normalized)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Choose Applications")
                        .font(.title2.weight(.semibold))
                    Text("The selected bundle identifiers are stored in this profile.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Reload", action: catalog.reload)
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }

            TextField("Search installed applications", text: $query)
                .textFieldStyle(.roundedBorder)

            if catalog.isLoading, catalog.options.isEmpty {
                ProgressView("Scanning Applications…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredOptions) { option in
                    Button {
                        toggle(option.bundleIdentifier)
                    } label: {
                        HStack(spacing: 12) {
                            if let icon = option.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .interpolation(.high)
                                    .frame(width: 28, height: 28)
                            } else {
                                Image(systemName: "app")
                                    .frame(width: 28, height: 28)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.displayName)
                                Text(option.bundleIdentifier)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(
                                systemName: selectedBundleIdentifiers.contains(
                                    option.bundleIdentifier
                                )
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .foregroundStyle(
                                selectedBundleIdentifiers.contains(
                                    option.bundleIdentifier
                                )
                                    ? Color.accentColor
                                    : Color.secondary
                            )
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("\(selectedBundleIdentifiers.count) selected")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear Selection") {
                    selectedBundleIdentifiers.removeAll()
                }
            }
        }
        .padding(20)
        .frame(width: 640, height: 620)
    }

    private func toggle(_ identifier: String) {
        if selectedBundleIdentifiers.contains(identifier) {
            selectedBundleIdentifiers.remove(identifier)
        } else {
            selectedBundleIdentifiers.insert(identifier)
        }
    }
}