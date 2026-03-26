import SwiftUI
import AppKit

struct PreferencesView: View {
    @ObservedObject var preferences: SwitcherPreferences
    let onOpenApplications: () -> Void

    var body: some View {
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

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    quickActionsSection
                    switcherSection
                    appearanceSection
                    startupSection
                    shortcutsSection
                    permissionsSection
                }
                .padding(24)
            }
        }
        .frame(minWidth: 680, minHeight: 700)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AltTabMac")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Tune how applications and windows appear in the switcher. The settings below prioritize stability, recency ordering, and fast previews of each visual style.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var quickActionsSection: some View {
        SettingsCard(title: "Quick Actions", subtitle: "Open the live switcher directly from this control page.") {
            Button(action: onOpenApplications) {
                Label("Show Applications", systemImage: "square.stack.3d.up.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
    }

    private var switcherSection: some View {
        SettingsCard(title: "Switcher", subtitle: "Control what shows up when you press the shortcut.") {
            SettingsRowText(
                title: "Strict separate-window recency",
                subtitle: "Applications and windows stay in one global MRU list, so repeated apps remain interleaved instead of grouped together."
            )

            Divider().overlay(Color.white.opacity(0.08))

            Toggle(isOn: $preferences.includeBackgroundWindows) {
                SettingsRowText(
                    title: "Include background and minimized windows",
                    subtitle: "Keep hidden windows in the switcher so apps running in the background still appear."
                )
            }
            .toggleStyle(.switch)
            .tint(.blue)

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
                            preferences.switcherStyle = style
                        }
                    }
                }
            }

            Divider().overlay(Color.white.opacity(0.08))

            Toggle(isOn: $preferences.enableVibrancy) {
                SettingsRowText(
                    title: "Liquid Glass (vibrancy)",
                    subtitle: "Use a more transparent frosted-glass background that lets more of the desktop show through behind the switcher."
                )
            }
            .toggleStyle(.switch)
            .tint(.blue)
        }
    }

    private var startupSection: some View {
        SettingsCard(title: "Startup", subtitle: "Keep the switcher ready every time you sign in.") {
            Toggle(isOn: $preferences.launchAtLogin) {
                SettingsRowText(
                    title: "Launch AltTabMac at login",
                    subtitle: "Start automatically when you log in so the switcher is always available."
                )
            }
            .toggleStyle(.switch)
            .tint(.blue)
        }
    }

    private var shortcutsSection: some View {
        SettingsCard(title: "Shortcuts", subtitle: "Current control surface.") {
            ShortcutRow(shortcut: "⌘ Tab", detail: "Open the primary switcher")
            Divider().overlay(Color.white.opacity(0.08))
            ShortcutRow(shortcut: "⌥ Tab", detail: "Open the same switcher with the alternate modifier")
            Divider().overlay(Color.white.opacity(0.08))
            ShortcutRow(shortcut: "Arrow Keys", detail: "Move through the grid")
            Divider().overlay(Color.white.opacity(0.08))
            ShortcutRow(shortcut: "Return", detail: "Activate the selected item")
            Divider().overlay(Color.white.opacity(0.08))
            ShortcutRow(shortcut: "Esc", detail: "Cancel the current switcher session")
        }
    }

    private var permissionsSection: some View {
        SettingsCard(title: "Permissions", subtitle: "AltTabMac depends on Accessibility and Screen Recording.") {
            SettingsButtonRow(
                title: "Open Accessibility Settings",
                subtitle: "Required for intercepting the global shortcut.",
                buttonTitle: "Open"
            ) {
                openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            }

            Divider().overlay(Color.white.opacity(0.08))

            SettingsButtonRow(
                title: "Open Screen Recording Settings",
                subtitle: "Required for live thumbnails of application windows.",
                buttonTitle: "Open"
            ) {
                openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
            }
        }
    }

    private func openSystemSettingsPane(_ rawValue: String) {
        guard let url = URL(string: rawValue) else { return }
        NSWorkspace.shared.open(url)
    }
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
            return "Cursor-centered ring"
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
