import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var preferences: SwitcherPreferences
    @ObservedObject var licensingController: LicensingController
    var onComplete: () -> Void

    @State private var currentStep = 0
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var screenRecordingGranted = CGPreflightScreenCaptureAccess()

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().overlay(Color.white.opacity(0.1))

            Group {
                switch currentStep {
                case 0: welcomeStep
                case 1: permissionsStep
                case 2: modesStep
                case 3: trialStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().overlay(Color.white.opacity(0.1))
            footerView
        }
        .frame(width: 580, height: 480)
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            accessibilityGranted = AXIsProcessTrusted()
            if #available(macOS 10.15, *) {
                screenRecordingGranted = CGPreflightScreenCaptureAccess()
            }
        }
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "square.stack.3d.down.right.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.accentColor)
            Text("Welcome to CmdTab")
                .font(.system(size: 16, weight: .bold))
            Spacer()
            Text("Step \(currentStep + 1) of 4")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var footerView: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation { currentStep -= 1 }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            if currentStep < 3 {
                Button("Skip for Now") {
                    preferences.hasCompletedOnboarding = true
                    onComplete()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.leading, currentStep > 0 ? 8 : 0)
            }

            Spacer()
            if currentStep < 3 {
                Button("Continue") {
                    withAnimation { currentStep += 1 }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            } else {
                Button("Get Started") {
                    preferences.hasCompletedOnboarding = true
                    onComplete()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "macwindow.on.macwindow")
                .font(.system(size: 56, weight: .regular))
                .foregroundColor(.accentColor)
                .padding(.top, 20)

            Text("Window-Level Switching for macOS")
                .font(.system(size: 22, weight: .bold))

            Text("CmdTab replaces the native macOS ⌘Tab switcher with an exact, window-level switcher. Every window gets its own tile, live preview, and position in your recent-use sequence.")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(24)
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Permissions Setup")
                .font(.system(size: 20, weight: .bold))

            Text("CmdTab requires two system permissions to intercept the switcher hotkey and capture live window previews:")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                permissionRow(
                    title: "Accessibility",
                    subtitle: "Required for catching ⌘Tab and ⌥Tab global shortcuts.",
                    isGranted: accessibilityGranted,
                    actionTitle: "Grant Accessibility"
                ) {
                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                    _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
                }

                permissionRow(
                    title: "Screen Recording",
                    subtitle: "Required to capture live thumbnails of application windows.",
                    isGranted: screenRecordingGranted,
                    actionTitle: "Grant Screen Recording"
                ) {
                    if #available(macOS 10.15, *) {
                        _ = CGRequestScreenCaptureAccess()
                    }
                }
            }

            Spacer()
        }
        .padding(24)
    }

    private func permissionRow(
        title: String,
        subtitle: String,
        isGranted: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(isGranted ? .green : .orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isGranted {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            } else {
                Text("Granted")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    private var modesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Your Switcher Style")
                .font(.system(size: 20, weight: .bold))

            Text("CmdTab offers three distinct visualization modes. You can change your selection anytime in Settings:")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                modeOptionRow(
                    style: .classicGrid,
                    title: "Classic Grid",
                    description: "Visual thumbnail tiles arranged in a clean, responsive grid."
                )
                modeOptionRow(
                    style: .commandPalette,
                    title: "Command Palette",
                    description: "Fast, keyboard-driven search list for power users."
                )
                modeOptionRow(
                    style: .radialMenu,
                    title: "Radial Menu",
                    description: "Circular spatial ring designed for rapid directional selection."
                )
            }

            Spacer()
        }
        .padding(24)
    }

    private func modeOptionRow(style: SwitcherStyle, title: String, description: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if preferences.switcherStyle == style {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            preferences.switcherStyle = style
        }
    }

    private var trialStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .regular))
                .foregroundColor(.accentColor)
                .padding(.top, 10)

            if licensingController.hasUnlockedAccess {
                Text("Your 14-Day Trial Is Active")
                    .font(.system(size: 20, weight: .bold))

                Text("Enjoy full access to all CmdTab capabilities. No subscription required — CmdTab is a simple one-time purchase.")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
            } else {
                Text("Start Your 14-Day Trial")
                    .font(.system(size: 20, weight: .bold))

                Text("Enter your email to activate your free 14-day trial. No credit card required.")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    TextField("you@example.com", text: $licensingController.enteredTrialEmail)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                        .disabled(licensingController.isStartingTrial)

                    if let message = licensingController.trialMessage {
                        Text(message.text)
                            .font(.system(size: 12))
                            .foregroundColor(message.tone == .error ? .red : .green)
                    }

                    Button(action: {
                        Task {
                            _ = await licensingController.startTrialRegistration()
                        }
                    }) {
                        if licensingController.isStartingTrial {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Activate 14-Day Trial")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(licensingController.isStartingTrial || licensingController.enteredTrialEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Text("Shortcut: Hold ⌘Tab to switch windows.")
                .font(.system(size: 12, weight: .semibold))
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)

            Spacer()
        }
        .padding(24)
    }
}
