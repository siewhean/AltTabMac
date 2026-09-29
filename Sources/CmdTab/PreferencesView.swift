import AppKit
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var preferences: SwitcherPreferences
    let onOpenApplications: () -> Void
    let onRefreshPreviews: () -> Void
    let onApplySwitcherStyle: (SwitcherStyle) -> Void
    let onOpenOnboarding: () -> Void
    @StateObject private var licensingController = LicensingController.shared
    #if DEBUG
    @StateObject private var developerSettings = DeveloperSettings.shared
    #endif
    @StateObject private var telemetryPreferences = TelemetryPreferences.shared
    @State private var selectedPane: PreferencesPaneSelection
    @StateObject private var appExclusionCatalog = AppExclusionCatalog()
    @State private var isAppExclusionPickerPresented = false
    private let headerLogo = PreferencesAssets.headerLogo

    init(
        preferences: SwitcherPreferences,
        onOpenApplications: @escaping () -> Void,
        onRefreshPreviews: @escaping () -> Void,
        onApplySwitcherStyle: @escaping (SwitcherStyle) -> Void,
        onOpenOnboarding: @escaping () -> Void = {},
        initialPane: PreferencesPaneSelection = .appearance
    ) {
        self.preferences = preferences
        self.onOpenApplications = onOpenApplications
        self.onRefreshPreviews = onRefreshPreviews
        self.onApplySwitcherStyle = onApplySwitcherStyle
        self.onOpenOnboarding = onOpenOnboarding
        _selectedPane = State(initialValue: initialPane)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.11, green: 0.13, blue: 0.17),
                        Color(red: 0.08, green: 0.09, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    header(availableWidth: max(0, proxy.size.width - 48))
                    settingsPanePicker

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            paneContent
                        }
                        .frame(width: max(0, proxy.size.width - 48), alignment: .leading)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                }
                .frame(width: max(0, proxy.size.width - 48), alignment: .leading)
                .padding(.top, 28)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(minWidth: 720, minHeight: 760)
    }

    private func header(availableWidth: CGFloat) -> some View {
        let logoSize = max(0, min(availableWidth * 0.25, 180))

        return HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CmdTab")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Tune how applications and windows appear in the switcher. The settings below prioritize stability, recency ordering, and fast previews of each visual style.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(nsImage: headerLogo)
                .resizable()
                .interpolation(.high)
                .frame(width: logoSize, height: logoSize)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 14, y: 8)
        }
    }

    private var settingsPanePicker: some View {
        HStack(spacing: 10) {
            ForEach(PreferencesPaneSelection.allCases) { pane in
                Button {
                    selectedPane = pane
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: pane.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                        Text(pane.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundColor(.white.opacity(selectedPane == pane ? 0.96 : 0.64))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                selectedPane == pane
                                    ? Color(red: 0.20, green: 0.42, blue: 0.90).opacity(0.28)
                                    : Color.white.opacity(0.05)
                            )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                selectedPane == pane
                                    ? Color(red: 0.31, green: 0.60, blue: 1.0).opacity(0.78)
                                    : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var paneContent: some View {
        switch selectedPane {
        case .appearance:
            appearanceSection
        case .windows:
            switcherSection
        case .shortcuts:
            triggerSection
            shortcutsSection
        case .general:
            startupSection
            updatesSection
            privacySection
            permissionsSection
            diagnosticsSection
            feedbackSection
        case .licensing:
            LicensingPreferencesPane(controller: licensingController)
        #if DEBUG
        case .developer:
            DeveloperPreferencesPane(
                settings: developerSettings,
                licensingController: licensingController
            )
        #endif
        }
    }

    private var triggerSection: some View {
        SettingsCard(title: "Hot Swap Shortcut", subtitle: "Set an optional quick double-tap or side-matched modifier chord for immediate switching. The normal `⌘Tab` path still works exactly the same.") {
            SettingsMenuPickerRow(
                title: "Shortcut",
                subtitle: "Choose whether hot swap should listen for a left or right modifier key, then double-tap that key to jump straight to the most recent app or window without opening the switcher.",
                selection: $preferences.alternateTrigger,
                options: hotSwapShortcutOptions
            )

            Divider().overlay(Color.white.opacity(0.08))

            HStack(alignment: .center, spacing: 16) {
                SettingsRowText(
                    title: "Current Hot Swap Shortcut",
                    subtitle: preferences.alternateTrigger.subtitle
                )
                Spacer()
                Text(preferences.alternateTrigger.shortcutLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }
        }
    }

    private var feedbackSection: some View {
        SettingsCard(title: "Feedback", subtitle: "Report bugs or propose changes directly from CmdTab.") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Use the actions below to open a prefilled message for bug reports or feature requests.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button {
                        NSWorkspace.shared.open(FeedbackConfiguration.reportBugURL)
                    } label: {
                        Text("Report a Bug")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button {
                        NSWorkspace.shared.open(FeedbackConfiguration.requestFeatureURL)
                    } label: {
                        Text("Request a Feature")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
    }

    private var privacySection: some View {
        SettingsCard(
            title: "Privacy",
            subtitle: "Usage telemetry is optional and disabled by default. Search history memory is stored locally."
        ) {
            SettingsToggleRow(
                title: "Share Usage Telemetry",
                subtitle: "Share app launches, hourly usage, trial starts, and license activations, including an installation ID, license state, app and macOS versions, and the license ID when activated.",
                isOn: Binding(
                    get: { telemetryPreferences.isEnabled },
                    set: { isEnabled in
                        AppTelemetryReporter.shared.setEnabled(
                            isEnabled,
                            licensingController: licensingController
                        )
                    }
                )
            )

            Divider().overlay(Color.white.opacity(0.08))

            SettingsButtonRow(
                title: "Clear Search History",
                subtitle: "Erase locally remembered command palette search ranking memory.",
                buttonTitle: "Clear Search History"
            ) {
                SearchMemoryStore.shared.clearMemory()
            }
        }
    }

    private var updatesSection: some View {
        SettingsCard(
            title: "Beta Updates",
            subtitle: "CmdTab checks the beta update channel daily after you grant Sparkle permission."
        ) {
            SettingsButtonRow(
                title: "Check for Beta Updates",
                subtitle: UpdaterController.shared.isConfigured
                    ? "Look for a newer signed CmdTab beta release now."
                    : "Unavailable in this local QA build because no release signing key is embedded.",
                buttonTitle: "Check Now"
            ) {
                UpdaterController.shared.checkForUpdates()
            }
            .disabled(!UpdaterController.shared.isConfigured)
        }
    }

    private var hotSwapShortcutOptions: [(AlternateTriggerMode, String)] {
        [
            (.disabled, AlternateTriggerMode.disabled.title),
            (.leftCommandDoubleTap, AlternateTriggerMode.leftCommandDoubleTap.title),
            (.rightCommandDoubleTap, AlternateTriggerMode.rightCommandDoubleTap.title),
            (.leftOptionDoubleTap, AlternateTriggerMode.leftOptionDoubleTap.title),
            (.rightOptionDoubleTap, AlternateTriggerMode.rightOptionDoubleTap.title)
        ]
    }

    private var switcherSection: some View {
        SettingsCard(title: "Switcher", subtitle: "Control what shows up when you press the shortcut.") {
            SettingsMenuPickerRow(
                title: "Window Visibility",
                subtitle: "Choose whether CmdTab focuses on the current space, visible spaces, or every space.",
                selection: $preferences.windowVisibilityScope,
                options: WindowVisibilityScope.allCases.map { ($0, $0.title) }
            )

            Divider().overlay(Color.white.opacity(0.08))

            SettingsMenuPickerRow(
                title: "Display Target",
                subtitle: "Choose where the switcher should appear when multiple displays are connected.",
                selection: $preferences.displayPlacement,
                options: SwitcherDisplayPreference.allCases.map { ($0, $0.title) }
            )

            Divider().overlay(Color.white.opacity(0.08))

            SettingsToggleRow(
                title: "Show Minimized Windows",
                subtitle: "Include minimized windows in the switcher and restore them when activated.",
                isOn: $preferences.includeMinimizedWindows
            )

            Divider().overlay(Color.white.opacity(0.08))

            HStack(alignment: .center, spacing: 16) {
                SettingsRowText(
                    title: "Max windows per application",
                    subtitle: "Limit the number of windows shown for each app. Set to 0 to show all windows."
                )
                Spacer()
                Picker("", selection: $preferences.maxWindowsPerApp) {
                    Text("All").tag(0)
                    ForEach(1...10, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 80)
            }

            Divider().overlay(Color.white.opacity(0.08))

            SettingsSelectableAppsRow(
                title: "Exclude Apps",
                subtitle: "Select the applications you want CmdTab to hide from the switcher.",
                selectedApps: selectedExcludedApps,
                hasUnresolvedEntries: hasUnresolvedExcludedApps,
                onSelectApps: { isAppExclusionPickerPresented = true }
            )
            .popover(isPresented: $isAppExclusionPickerPresented, arrowEdge: .top) {
                AppExclusionPickerSheet(
                    catalog: appExclusionCatalog,
                    selectedBundleIdentifiers: Binding(
                        get: { selectedExcludedAppBundleIdentifiers },
                        set: { updateExcludedApps(using: $0) }
                    )
                )
            }
        }
    }

    private var appearanceSection: some View {
        SettingsCard(title: "Appearance", subtitle: "Preview each style inline before applying it.") {
            VStack(alignment: .leading, spacing: 10) {
                SettingsRowText(
                    title: "Switcher Style",
                    subtitle: "Each preview below is a static mock of the style so you can see the look immediately."
                )

                HStack(alignment: .top, spacing: 12) {
                    ForEach(SwitcherStyle.allCases, id: \.self) { style in
                        StylePreviewCard(
                            style: style,
                            isSelected: preferences.switcherStyle == style
                        ) {
                            guard preferences.switcherStyle != style else { return }
                            preferences.switcherStyle = style
                            onApplySwitcherStyle(style)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().overlay(Color.white.opacity(0.08))

            SettingsToggleRow(
                title: "Liquid Glass (vibrancy)",
                subtitle: "Use a more transparent frosted-glass background that lets more of the desktop show through behind the switcher.",
                isOn: $preferences.enableVibrancy
            )

            Divider().overlay(Color.white.opacity(0.08))

            SettingsToggleRow(
                title: "Show selected window behind the switcher",
                subtitle: "Project the currently selected app window into the background of the Alt-Tab overlay so you can preview it before switching.",
                isOn: $preferences.showSelectedPreviewBackdrop
            )
        }
    }

    private var startupSection: some View {
        SettingsCard(title: "Startup", subtitle: "Keep the switcher ready every time you sign in.") {
            SettingsToggleRow(
                title: "Launch CmdTab at login",
                subtitle: "Start automatically when you log in so the switcher is always available.",
                isOn: $preferences.launchAtLogin
            )
        }
    }

    private var shortcutsSection: some View {
        SettingsCard(title: "Shortcuts", subtitle: "Current control surface. Quick actions fire while the switcher is visible.") {
            ShortcutRow(shortcut: "⌘ Tab", detail: "Open the primary switcher")
            Divider().overlay(Color.white.opacity(0.08))
            ShortcutRow(shortcut: "⌥ Tab", detail: "Open the same switcher with the alternate modifier")
            if preferences.alternateTrigger != .disabled {
                Divider().overlay(Color.white.opacity(0.08))
                ShortcutRow(shortcut: preferences.alternateTrigger.shortcutLabel, detail: "Immediate hot swap to the most recent item")
            }
            Divider().overlay(Color.white.opacity(0.08))
            ShortcutRow(shortcut: "Arrow Keys", detail: "Move through the grid")
            Divider().overlay(Color.white.opacity(0.08))
            ShortcutRow(shortcut: "Return", detail: "Activate the selected item")
            Divider().overlay(Color.white.opacity(0.08))
            ShortcutRow(shortcut: "Esc", detail: "Cancel the current switcher session")

            Divider().overlay(Color.white.opacity(0.08))

            ForEach(SwitcherQuickAction.allCases, id: \.rawValue) { action in
                ShortcutRow(shortcut: action.shortcut, detail: "\(action.title) on the selected item")
                Divider().overlay(Color.white.opacity(0.08))
            }

            SettingsButtonRow(
                title: "Advanced Profiles",
                subtitle: "Configure independent shortcut profiles with custom triggers, styles, filters, and display behaviors.",
                buttonTitle: "Manage Profiles…"
            ) {
                ProductionProfilePreferencesWindowController.shared.show()
            }
        }
    }

    private var permissionsSection: some View {
        SettingsCard(title: "Permissions", subtitle: "Accessibility is required to switch windows. Screen Recording is optional for window thumbnails.") {
            SettingsButtonRow(
                title: "Setup Guide",
                subtitle: "Review why CmdTab requests each permission and run the first-switch practice again.",
                buttonTitle: "Open"
            ) {
                onOpenOnboarding()
            }

            Divider().overlay(Color.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(PermissionDiagnostics.allStatuses().enumerated()), id: \.offset) { index, status in
                    PermissionStatusRow(status: status)
                    if index != PermissionDiagnostics.allStatuses().count - 1 {
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
            }

            Divider().overlay(Color.white.opacity(0.08))

            SettingsButtonRow(
                title: "Open Accessibility Settings",
                subtitle: "Required for intercepting the global shortcut and switching windows.",
                buttonTitle: "Open"
            ) {
                openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            }

            Divider().overlay(Color.white.opacity(0.08))

            SettingsButtonRow(
                title: "Open Screen Recording Settings",
                subtitle: "Optional. Lets CmdTab show window thumbnails. Switching still works without it using app icons and text.",
                buttonTitle: "Open"
            ) {
                openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
            }
        }
    }

    private var diagnosticsSection: some View {
        SettingsCard(title: "Diagnostics", subtitle: "Inspect system capabilities, window discovery metrics, and support logs.") {
            SettingsButtonRow(
                title: "Diagnostics Window",
                subtitle: "View capability states, exact window identity logs, durable history status, and copy sanitized support reports.",
                buttonTitle: "Open Diagnostics…"
            ) {
                ProductionDiagnosticsWindowController.shared.show()
            }
        }
    }

    private func openSystemSettingsPane(_ rawValue: String) {
        guard let url = URL(string: rawValue) else { return }
        NSWorkspace.shared.open(url)
    }

    private var selectedExcludedApps: [AppExclusionOption] {
        appExclusionCatalog.selectedOptions(for: preferences.excludedAppEntries)
    }

    private var selectedExcludedAppBundleIdentifiers: Set<String> {
        Set(selectedExcludedApps.map(\.bundleIdentifier))
    }

    private var hasUnresolvedExcludedApps: Bool {
        let resolvedBundleIdentifiers = selectedExcludedAppBundleIdentifiers
        return preferences.excludedAppEntries.contains { entry in
            !resolvedBundleIdentifiers.contains(where: { $0.caseInsensitiveCompare(entry) == .orderedSame })
        }
    }

    private func updateExcludedApps(using selectedBundleIdentifiers: Set<String>) {
        let orderedBundleIdentifiers = appExclusionCatalog.options
            .map(\.bundleIdentifier)
            .filter { selectedBundleIdentifiers.contains($0) }
        preferences.excludedAppsText = orderedBundleIdentifiers.joined(separator: "\n")
    }
}

private enum PreferencesAssets {
    static let headerLogo: NSImage = {
        if let url = Bundle.main.url(forResource: "CmdTab", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 1024, height: 1024)
            return image
        }
        return NSApp.applicationIconImage
    }()
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }
}

private struct SettingsSegmentedPicker<Value: Hashable>: View {
    let title: String
    let subtitle: String
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsRowText(title: title, subtitle: subtitle)

            Picker(title, selection: $selection) {
                ForEach(options, id: \.1) { option in
                    Text(option.1).tag(option.0)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct SettingsButtonRow: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            SettingsRowText(title: title, subtitle: subtitle)
            Spacer()
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
        }
    }
}

private struct SettingsMenuPickerRow<Value: Hashable>: View {
    let title: String
    let subtitle: String
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            SettingsRowText(title: title, subtitle: subtitle)
            Spacer()
            Picker("", selection: $selection) {
                ForEach(options, id: \.1) { option in
                    Text(option.1).tag(option.0)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 170)
        }
    }
}

private struct SettingsTextEditorRow: View {
    let title: String
    let subtitle: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsRowText(title: title, subtitle: subtitle)

            ZStack(alignment: .topLeading) {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.24))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }

                TextEditor(text: $text)
                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(minHeight: 88)
                    .background(Color.clear)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
}

private struct SettingsSelectableAppsRow: View {
    let title: String
    let subtitle: String
    let selectedApps: [AppExclusionOption]
    let hasUnresolvedEntries: Bool
    let onSelectApps: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                SettingsRowText(title: title, subtitle: subtitle)
                Spacer()
                Button("Select Apps", action: onSelectApps)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
            }

            if selectedApps.isEmpty {
                Text("No excluded apps selected.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.46))
            } else {
                SelectedAppChipCloud(items: selectedApps)
            }

            if hasUnresolvedEntries {
                Text("Some older manual exclusion entries could not be matched to installed apps. Re-select them from the picker if you still want to keep them.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.40))
            }
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            SettingsRowText(title: title, subtitle: subtitle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.blue)
                .accessibilityLabel(title)
                .accessibilityHint(subtitle)
        }
    }
}

private struct SelectedAppChipCloud: View {
    let items: [AppExclusionOption]

    var body: some View {
        FlowWrapLayout(spacing: 8) {
            ForEach(items) { item in
                HStack(spacing: 7) {
                    if let icon = item.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 14, height: 14)
                    }

                    Text(item.displayName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(item.pillBorderColor, lineWidth: 1)
                    )
            }
        }
    }
}

private struct SettingsStepperRow: View {
    let title: String
    let subtitle: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    private var displayedValue: String {
        value == 0 ? "All" : "\(value)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            SettingsRowText(title: title, subtitle: subtitle)
            Spacer()
            Stepper(value: $value, in: range) {
                Text(displayedValue)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(minWidth: 40, alignment: .trailing)
            }
            .labelsHidden()
            .fixedSize()
        }
    }
}

private struct ShortcutRow: View {
    let shortcut: String
    let detail: String

    var body: some View {
        HStack {
            Text(shortcut)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            Text(detail)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
            Spacer()
        }
    }
}

private struct QuickActionFeatureGrid: View {
    let actions: [SwitcherQuickAction]

    private let columns = [
        GridItem(.flexible(minimum: 200), spacing: 12),
        GridItem(.flexible(minimum: 200), spacing: 12),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(actions, id: \.rawValue) { action in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(action.shortcut)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.09))
                            )

                        Text(action.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    Text(action.subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
        }
    }
}

private struct PermissionStatusRow: View {
    let status: PermissionStatusDescriptor

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            SettingsRowText(title: status.name, subtitle: status.detail)
                .frame(maxWidth: .infinity, alignment: .leading)

            StatusBadge(title: status.state.title, state: status.state)
        }
    }
}

private struct StatusBadge: View {
    let title: String
    let state: PermissionHealthState

    private var fillColor: Color {
        switch state {
        case .ready:
            return Color(red: 0.14, green: 0.44, blue: 0.30)
        case .warning:
            return Color(red: 0.52, green: 0.35, blue: 0.08)
        case .blocked:
            return Color(red: 0.58, green: 0.19, blue: 0.18)
        }
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(fillColor.opacity(0.92))
            )
    }
}

private struct SettingsRowText: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct StylePreviewCard: View {
    let style: SwitcherStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                StyleMockPreview(style: style, isSelected: isSelected)
                    .frame(height: 132)

                HStack(spacing: 8) {
                    Image(systemName: style.systemImage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.62))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(style.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.82))
                        Text(previewSubtitle(for: style))
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.50))
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color(red: 0.18, green: 0.38, blue: 0.82).opacity(0.22) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isSelected ? Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.70) : Color.white.opacity(0.08),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func previewSubtitle(for style: SwitcherStyle) -> String {
        switch style {
        case .classicGrid:
            return "Wide thumbnail grid"
        case .commandPalette:
            return "Searchable compact list"
        case .radialMenu:
            return "Screen-centered ring"
        }
    }
}

private struct StyleMockPreview: View {
    let style: SwitcherStyle
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.04),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            switch style {
            case .classicGrid:
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(index == 1 && isSelected ? 0.24 : 0.12))
                                .frame(height: 56)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(index == 1 && isSelected ? Color.blue.opacity(0.85) : Color.white.opacity(0.08), lineWidth: index == 1 && isSelected ? 2 : 1)
                                )
                            Capsule()
                                .fill(Color.white.opacity(0.28))
                                .frame(height: 8)
                        }
                    }
                }
                .padding(12)

            case .commandPalette:
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 22)
                        .overlay(
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.55))
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.white.opacity(0.18))
                                    .frame(width: 72, height: 8)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                        )

                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(index == 0 && isSelected ? Color.blue.opacity(0.32) : Color.white.opacity(0.08))
                            .frame(height: 22)
                            .overlay(
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.white.opacity(0.26))
                                        .frame(width: 12, height: 12)
                                    VStack(alignment: .leading, spacing: 3) {
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(Color.white.opacity(0.30))
                                            .frame(width: 76, height: 6)
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(Color.white.opacity(0.16))
                                            .frame(width: 46, height: 5)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                            )
                    }
                }
                .padding(12)

            case .radialMenu:
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        .padding(18)

                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 34, height: 34)

                    ForEach(0..<5, id: \.self) { index in
                        let angle = Angle.degrees(Double(index) * 72 - 90)
                        Circle()
                            .fill(index == 0 && isSelected ? Color.blue.opacity(0.42) : Color.white.opacity(0.12))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(index == 0 && isSelected ? Color.blue.opacity(0.9) : Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .offset(x: cos(angle.radians) * 36, y: sin(angle.radians) * 36)
                    }
                }
                .padding(10)
            }
        }
    }
}

private struct AppExclusionPickerSheet: View {
    @ObservedObject var catalog: AppExclusionCatalog
    @Binding var selectedBundleIdentifiers: Set<String>
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredApps: [AppExclusionOption] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return catalog.options }
        return catalog.options.filter {
            $0.displayName.lowercased().contains(normalizedQuery) ||
            $0.bundleIdentifier.lowercased().contains(normalizedQuery)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Exclude Apps")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Choose which applications CmdTab should hide from the switcher.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.58))
                }
                Spacer()
                Button("Unselect All") {
                    selectedBundleIdentifiers.removeAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.42))
                TextField("Search apps…", text: $query)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )

            OverlayScrollContainer {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(filteredApps) { app in
                        Button {
                            toggle(app.bundleIdentifier)
                        } label: {
                            HStack(spacing: 12) {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .interpolation(.high)
                                        .frame(width: 26, height: 26)
                                } else {
                                    Image(systemName: "app")
                                        .frame(width: 26, height: 26)
                                        .foregroundColor(.white.opacity(0.35))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.displayName)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Text(app.bundleIdentifier)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.40))
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: selectedBundleIdentifiers.contains(app.bundleIdentifier) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(selectedBundleIdentifiers.contains(app.bundleIdentifier) ? .blue : .white.opacity(0.24))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
                .padding(.trailing, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if filteredApps.isEmpty {
                Text("No matching apps found.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.46))
            }
        }
        .padding(20)
        .frame(width: 620, height: 620, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.13, blue: 0.17),
                    Color(red: 0.08, green: 0.09, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func toggle(_ bundleIdentifier: String) {
        if selectedBundleIdentifiers.contains(bundleIdentifier) {
            selectedBundleIdentifiers.remove(bundleIdentifier)
        } else {
            selectedBundleIdentifiers.insert(bundleIdentifier)
        }
    }
}

private struct FlowWrapLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        _FlowWrapLayout(spacing: spacing) {
            content
        }
    }
}

private struct _FlowWrapLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: proposal.width ?? x, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct AppExclusionOption: Identifiable, Hashable {
    let bundleIdentifier: String
    let displayName: String
    let icon: NSImage?

    var id: String { bundleIdentifier }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }

    static func == (lhs: AppExclusionOption, rhs: AppExclusionOption) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }

    var pillBorderColor: Color {
        guard let iconColor = icon?.averageAccentColor else {
            return Color.white.opacity(0.14)
        }

        return Color(nsColor: iconColor.withAlphaComponent(0.68))
    }
}

private final class AppExclusionCatalog: ObservableObject {
    @Published private(set) var options: [AppExclusionOption] = []

    init() {
        reload()
    }

    func selectedOptions(for entries: [String]) -> [AppExclusionOption] {
        options.filter { option in
            WindowExclusionRules.matchesApp(
                identifier: option.bundleIdentifier,
                appName: option.displayName,
                entries: entries
            )
        }
    }

    private func reload() {
        DispatchQueue.global(qos: .userInitiated).async {
            let discovered = Self.discoverApps()
            DispatchQueue.main.async {
                self.options = discovered
            }
        }
    }

    private static func discoverApps() -> [AppExclusionOption] {
        let fileManager = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Setapp", isDirectory: true)
        ]

        var seenBundleIdentifiers = Set<String>()
        var discovered: [AppExclusionOption] = []

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }
                guard let bundle = Bundle(url: url),
                      let bundleIdentifier = bundle.bundleIdentifier,
                      seenBundleIdentifiers.insert(bundleIdentifier).inserted else {
                    continue
                }

                let displayName =
                    (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? url.deletingPathExtension().lastPathComponent

                discovered.append(
                    AppExclusionOption(
                        bundleIdentifier: bundleIdentifier,
                        displayName: displayName,
                        icon: NSWorkspace.shared.icon(forFile: url.path)
                    )
                )
            }
        }

        return discovered.sorted {
            if $0.displayName.caseInsensitiveCompare($1.displayName) != .orderedSame {
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            return $0.bundleIdentifier.localizedCaseInsensitiveCompare($1.bundleIdentifier) == .orderedAscending
        }
    }
}

private extension NSImage {
    var averageAccentColor: NSColor? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        rep.size = NSSize(width: 1, height: 1)

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }

        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        draw(in: NSRect(x: 0, y: 0, width: 1, height: 1))

        guard let color = rep.colorAt(x: 0, y: 0)?.usingColorSpace(.deviceRGB) else {
            return nil
        }
        return color
    }
}

private struct OverlayScrollContainer<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller?.controlSize = .small
        scrollView.verticalScroller?.knobStyle = .light
        scrollView.contentView.drawsBackground = false

        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = hostingView
        context.coordinator.hostingView = hostingView
        context.coordinator.widthConstraint = hostingView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        context.coordinator.widthConstraint?.isActive = true

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let hostingView = context.coordinator.hostingView else { return }
        hostingView.rootView = content

        let width = max(0, nsView.contentSize.width)
        let fittingHeight = hostingView.fittingSize.height
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: fittingHeight)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var hostingView: NSHostingView<Content>?
        var widthConstraint: NSLayoutConstraint?
    }
}
