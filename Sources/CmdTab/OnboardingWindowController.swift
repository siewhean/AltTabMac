import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController {
    private let coordinator: OnboardingCoordinator
    var onTrySwitcher: (() -> Void)?

    convenience init() {
        self.init(coordinator: OnboardingCoordinator())
    }

    init(coordinator: OnboardingCoordinator) {
        self.coordinator = coordinator

        let rootView = OnboardingView(
            coordinator: coordinator,
            onTrySwitcher: {},
            onFinish: {}
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Set Up CmdTab"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.setContentSize(NSSize(width: 680, height: 610))
        window.minSize = NSSize(width: 680, height: 610)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenAuxiliary]
        window.center()

        super.init(window: window)
        refreshContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAutomaticallyIfNeeded() {
        show(isAutomatic: true)
    }

    func show() {
        show(isAutomatic: false)
    }

    func refreshPermissions() {
        coordinator.refresh()
    }

    private func show(isAutomatic: Bool) {
        guard coordinator.prepareForPresentation(isAutomatic: isAutomatic) else { return }
        refreshContent()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func refreshContent() {
        guard let hostingController =
                window?.contentViewController as? NSHostingController<OnboardingView> else {
            return
        }
        hostingController.rootView = OnboardingView(
            coordinator: coordinator,
            onTrySwitcher: { [weak self] in self?.onTrySwitcher?() },
            onFinish: { [weak self] in self?.close() }
        )
    }
}

private struct OnboardingView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @ObservedObject private var licensingController: LicensingController
    let onTrySwitcher: () -> Void
    let onFinish: () -> Void

    init(
        coordinator: OnboardingCoordinator,
        onTrySwitcher: @escaping () -> Void,
        onFinish: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        licensingController = coordinator.licensingController
        self.onTrySwitcher = onTrySwitcher
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.13, blue: 0.17),
                    Color(red: 0.08, green: 0.09, blue: 0.12),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                progressHeader
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                navigation
            }
            .padding(34)
        }
        .frame(minWidth: 680, minHeight: 610)
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Set Up CmdTab")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    Capsule()
                        .fill(
                            step.rawValue <= coordinator.step.rawValue
                                ? Color.blue
                                : Color.white.opacity(0.12)
                        )
                        .frame(height: 5)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(
                "Setup step \(coordinator.step.rawValue + 1) of \(OnboardingStep.allCases.count)"
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch coordinator.step {
        case .welcome:
            stepContent(
                symbol: "arrow.right.arrow.left",
                title: "Welcome to CmdTab",
                detail: "CmdTab replaces the application-only Command-Tab view with one recent-use list of individual windows. This setup explains every permission before macOS asks for it."
            )
        case .accessibility:
            permissionStep(
                symbol: "accessibility",
                title: "Allow Accessibility",
                detail: "Required. CmdTab uses Accessibility to identify and activate the exact window you select, and to listen for your configured switcher shortcut.",
                isGranted: coordinator.isAccessibilityGranted,
                requestTitle: "Ask macOS for Accessibility Access",
                request: coordinator.requestAccessibility,
                openSettings: coordinator.openAccessibilitySettings
            )
        case .screenRecording:
            permissionStep(
                symbol: "rectangle.inset.filled.and.person.filled",
                title: "Enable Window Previews",
                detail: "Optional. Screen Recording lets CmdTab show live window thumbnails. Without it, switching still works and CmdTab uses app icons and text instead.",
                isGranted: coordinator.isScreenRecordingGranted,
                requestTitle: "Ask macOS for Screen Recording Access",
                request: coordinator.requestScreenRecording,
                openSettings: coordinator.openScreenRecordingSettings
            )
        case .access:
            accessStep
        case .practice:
            practiceStep
        case .completion:
            stepContent(
                symbol: "checkmark.seal.fill",
                title: "CmdTab Is Ready",
                detail: "Use Command-Tab or your configured profile shortcut to switch between individual windows. You can reopen this setup at any time from the CmdTab menu-bar menu or System Settings pane."
            )
        }
    }

    private func stepContent(symbol: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(detail)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func permissionStep(
        symbol: String,
        title: String,
        detail: String,
        isGranted: Bool,
        requestTitle: String,
        request: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            stepContent(symbol: symbol, title: title, detail: detail)

            Label(
                isGranted ? "Permission granted" : "Permission not granted",
                systemImage: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle"
            )
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(isGranted ? .green : .orange)

            HStack(spacing: 12) {
                if !isGranted {
                    Button(requestTitle, action: request)
                        .buttonStyle(.borderedProminent)
                    Button("Open System Settings", action: openSettings)
                        .buttonStyle(.bordered)
                }
                Button("Check Again", action: coordinator.refresh)
                    .buttonStyle(.bordered)
            }
        }
    }

    private var accessStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepContent(
                symbol: "checkmark.shield.fill",
                title: "Start a Trial or Activate",
                detail: "Access is granted only after CmdTab verifies a server-backed 14-day trial claim or a signed license. An unavailable server never creates an unsigned local trial."
            )

            Text(licensingController.licenseSummaryTitle)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(licensingController.licenseSummaryDetail)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)

            if let warning = licensingController.trialWarningMessage {
                onboardingMessage(warning)
            }

            if licensingController.status.requiresTrialRegistration {
                HStack(spacing: 12) {
                    TextField("Email for the 14-day trial", text: $licensingController.enteredTrialEmail)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            _ = await licensingController.startTrialRegistration()
                            coordinator.refresh()
                        }
                    } label: {
                        if licensingController.isStartingTrial {
                            ProgressView()
                        } else {
                            Text("Start Trial")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        licensingController.isStartingTrial
                            || licensingController.isManagingLicense
                    )
                }
            }

            HStack(spacing: 12) {
                SecureField("Purchase activation code", text: $licensingController.enteredLicenseKey)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task {
                        _ = await licensingController.activateEnteredLicenseKeyOnline()
                        coordinator.refresh()
                    }
                } label: {
                    if licensingController.isManagingLicense {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Activating this Mac")
                    } else {
                        Text("Activate This Mac")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    licensingController.isManagingLicense
                        || licensingController.isStartingTrial
                        || licensingController.enteredLicenseKey
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                )
            }

            if let message = licensingController.trialMessage {
                onboardingMessage(message)
            }
            if let message = licensingController.licenseMessage {
                onboardingMessage(message)
            }
        }
    }

    private var practiceStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepContent(
                symbol: "command",
                title: "Try Your First Switch",
                detail: "Open at least two application windows, then choose Try CmdTab. Navigate with Tab or the arrow keys, release the modifier or press Return to select, and press Escape to cancel."
            )
            Button {
                coordinator.attemptPractice(onTrySwitcher)
            } label: {
                Label(
                    coordinator.attemptedPractice ? "Try CmdTab Again" : "Try CmdTab",
                    systemImage: "play.fill"
                )
            }
            .buttonStyle(.borderedProminent)

            if coordinator.attemptedPractice {
                Label(
                    "Practice attempt started. Complete a selection or press Escape, then continue when ready.",
                    systemImage: "play.circle"
                )
                    .foregroundStyle(.white.opacity(0.72))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
        }
    }

    private func onboardingMessage(_ message: LicensingMessage) -> some View {
        Text(message.text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(onboardingMessageColor(message.tone))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(message.text)
    }

    private func onboardingMessageColor(_ tone: LicensingMessageTone) -> Color {
        switch tone {
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private var navigation: some View {
        HStack {
            if coordinator.step != .welcome {
                Button("Back", action: coordinator.moveBack)
                    .buttonStyle(.bordered)
            }

            Spacer()

            if coordinator.step == .screenRecording,
               !coordinator.isScreenRecordingGranted {
                Button("Skip for Now", action: coordinator.skipScreenRecording)
                    .buttonStyle(.bordered)
            }

            if coordinator.step == .completion {
                Button("Finish") {
                    _ = coordinator.advance()
                    onFinish()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Continue") {
                    _ = coordinator.advance()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!coordinator.canContinue)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}
