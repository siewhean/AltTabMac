import SwiftUI

struct LicensingPreferencesPane: View {
    @ObservedObject var controller: LicensingController
    @State private var showConfetti = false
    @State private var confettiBurstID = 0
    @State private var lastStatusSignature = ""

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 20) {
                statusCard
                activationCard
            }
            .zIndex(0)

            if showConfetti {
                LicensingConfettiOverlay()
                    .id(confettiBurstID)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .zIndex(1)
            }
        }
        .onAppear {
            controller.refreshStatus()
            lastStatusSignature = statusSignature(for: controller.status)
            Task {
                await controller.refreshLicensedDevices()
            }
        }
        .onChange(of: controller.status) { newStatus in
            let newSignature = statusSignature(for: newStatus)
            let wasLicensed = lastStatusSignature.hasPrefix("licensed:")
            let isLicensed = newSignature.hasPrefix("licensed:")

            if isLicensed && !wasLicensed {
                triggerConfetti()
            }

            lastStatusSignature = newSignature
        }
    }

    private var statusCard: some View {
        LicensingCard(
            title: "License Status",
            subtitle: "CmdTab includes a 14-day free trial. Email is optional and used only for expiration reminders."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(statusAccentColor.opacity(0.16))
                            .frame(width: 42, height: 42)

                        Image(systemName: statusSymbolName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(statusAccentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(controller.licenseSummaryTitle)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        Text(controller.licenseSummaryDetail)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    statusBadge
                }

                HStack(spacing: 12) {
                    if case .licensed = controller.status {
                        EmptyView()
                    } else if LicensingConfiguration.commerceEnabled {
                        Button(action: controller.openBuyPage) {
                            Text("Buy CmdTab")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }

                if let warning = controller.trialWarningMessage {
                    LicensingInlineMessage(message: warning)
                }
            }
        }
    }

    private var activationCard: some View {
        if case let .licensed(payload, _) = controller.status {
            return AnyView(licensedThankYouCard(payload: payload))
        }

        return AnyView(accessCard)
    }

    private var accessCard: some View {
        LicensingCard(
            title: controller.status.requiresTrialRegistration
                ? "Start your 14-day trial"
                : (LicensingConfiguration.commerceEnabled ? "Activate This Mac" : "Beta Access"),
            subtitle: controller.status.requiresTrialRegistration
                ? "Start on this Mac immediately. Add an email only when you want an expiry reminder."
                : (LicensingConfiguration.commerceEnabled
                    ? "Open the link in your purchase email, then click Activate, or paste the activation code below."
                    : "This beta accepts a verified trial entitlement. Paid activation is not available in this build.")
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if controller.status.requiresTrialRegistration {
                    Text("Email for reminders (optional)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    TextField("you@mac.com (optional)", text: $controller.enteredTrialEmail)
                        .textFieldStyle(.roundedBorder)
                        .frame(height: 32)
                        .accessibilityLabel("Optional email for trial reminders")

                    Button(action: {
                        Task {
                            _ = await controller.startTrialRegistration()
                        }
                    }) {
                        if controller.isStartingTrial {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Start Free Trial")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(controller.isStartingTrial)

                    Text("Leave the field blank to start without sharing an email. Local trial warnings still appear in CmdTab.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.52))
                        .fixedSize(horizontal: false, vertical: true)

                    if let message = controller.trialMessage {
                        LicensingInlineMessage(message: message)
                    }

                    Divider().overlay(Color.white.opacity(0.08))
                }

                if LicensingConfiguration.commerceEnabled {
                    purchaseActivationControls
                }
            }
        }
    }

    private var purchaseActivationControls: some View {
        Group {
                Text("Purchase activation code")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                LicenseKeyInputField(text: $controller.enteredLicenseKey)
                    .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )

                if let message = controller.licenseMessage {
                    LicensingInlineMessage(message: message)
                }

                HStack(spacing: 12) {
                    Button(action: {
                        Task {
                            _ = await controller.activateEnteredLicenseKeyOnline()
                        }
                    }) {
                        if controller.isManagingLicense {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Activate License", systemImage: "checkmark.seal.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(controller.isManagingLicense)

                    Button(action: {
                        Task {
                            _ = await controller.deactivateCurrentDevice()
                        }
                    }) {
                        Text("Deactivate This Mac")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(controller.isManagingLicense)
                }
        }
    }

    private func licensedThankYouCard(payload: SignedLicensePayload) -> some View {
        LicensingCard(
            title: "Thanks for supporting CmdTab",
            subtitle: "Hope you enjoy using CmdTab."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("This Mac is activated for \(payload.email).")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text("If you ever need purchase or activation help, you can open the Help page from here.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !controller.licensedDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Activated Macs (\(controller.licensedDevices.count) of 3)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.78))
                        ForEach(controller.licensedDevices, id: \.deviceId) { device in
                            Text("• \(device.deviceName)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.58))
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button(action: controller.openHelpPage) {
                        Text("Open Help")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(action: {
                        Task {
                            _ = await controller.deactivateCurrentDevice()
                        }
                    }) {
                        Text("Deactivate This Mac")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(controller.isManagingLicense)
                }
            }
        }
    }

    private var statusBadge: some View {
        Text(statusBadgeTitle)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(statusAccentColor.opacity(0.92))
            )
    }

    private var statusBadgeTitle: String {
        switch controller.status {
        case .licensed:
            return "Licensed"
        case .unregistered:
            return "Start Trial"
        case .activeTrial:
            return "Trial"
        case .expired:
            return "Expired"
        }
    }

    private var statusAccentColor: Color {
        switch controller.status {
        case .licensed:
            return Color(red: 0.14, green: 0.44, blue: 0.30)
        case .unregistered:
            return Color(red: 0.74, green: 0.46, blue: 0.11)
        case .activeTrial:
            return Color(red: 0.20, green: 0.42, blue: 0.90)
        case .expired:
            return Color(red: 0.58, green: 0.19, blue: 0.18)
        }
    }

    private var statusSymbolName: String {
        switch controller.status {
        case .licensed:
            return "checkmark.seal.fill"
        case .unregistered:
            return "timer"
        case .activeTrial:
            return "timer"
        case .expired:
            return "lock.slash"
        }
    }

    private func statusSignature(for status: LicensingStatus) -> String {
        switch status {
        case let .licensed(payload, _):
            return "licensed:\(payload.licenseID)"
        case .unregistered:
            return "unregistered"
        case let .activeTrial(_, endsAt, daysRemaining):
            return "trial:\(endsAt.timeIntervalSince1970):\(daysRemaining)"
        case let .expired(_, endedAt, daysOverdue):
            return "expired:\(endedAt.timeIntervalSince1970):\(daysOverdue)"
        }
    }

    private func triggerConfetti() {
        confettiBurstID += 1
        withAnimation(.easeOut(duration: 0.18)) {
            showConfetti = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.25)) {
                showConfetti = false
            }
        }
    }
}

private struct LicenseKeyInputField: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = PasteFriendlyLicenseTextField()
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        textField.textColor = .white
        textField.placeholderString = "CMDTAB-ACT-… or legacy CMDTAB1 key"
        textField.delegate = context.coordinator
        textField.lineBreakMode = .byClipping
        textField.usesSingleLineMode = true
        textField.maximumNumberOfLines = 1
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            self._text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }
    }
}

private final class PasteFriendlyLicenseTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch key {
        case "v":
            return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
        case "c":
            return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
        case "x":
            return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
        case "a":
            return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}

private struct LicensingCard<Content: View>: View {
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

private struct LicensingInlineMessage: View {
    let message: LicensingMessage

    private var accentColor: Color {
        switch message.tone {
        case .success:
            return Color(red: 0.14, green: 0.44, blue: 0.30)
        case .warning:
            return Color(red: 0.72, green: 0.55, blue: 0.20)
        case .error:
            return Color(red: 0.76, green: 0.26, blue: 0.26)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(accentColor)
                .frame(width: 8, height: 8)
                .padding(.top, 4)

            Text(message.text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(accentColor.opacity(0.55), lineWidth: 1)
                )
        )
    }
}

private struct LicensingConfettiOverlay: View {
    @State private var isAnimating = false

    private let particles: [LicensingConfettiParticle] = (0..<22).map { index in
        LicensingConfettiParticle(index: index)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(particles) { particle in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(particle.color)
                        .frame(width: particle.size.width, height: particle.size.height)
                        .rotationEffect(.degrees(isAnimating ? particle.endRotation : particle.startRotation))
                        .opacity(isAnimating ? 0.94 : 0)
                        .position(
                            x: proxy.size.width * (isAnimating ? particle.endX : particle.startX),
                            y: proxy.size.height * (isAnimating ? particle.endY : particle.startY)
                        )
                        .animation(
                            .timingCurve(0.16, 0.84, 0.24, 1, duration: 1.05)
                                .delay(particle.delay),
                            value: isAnimating
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                isAnimating = false
                DispatchQueue.main.async {
                    isAnimating = true
                }
            }
        }
    }
}

private struct LicensingConfettiParticle: Identifiable {
    let id: Int
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let startRotation: Double
    let endRotation: Double
    let delay: Double
    let color: Color
    let size: CGSize

    init(index: Int) {
        self.id = index
        self.startX = 0.5 + (CGFloat((index % 5) - 2) * 0.012)
        self.startY = 0.22
        self.endX = 0.15 + (CGFloat((index * 37) % 70) / 100.0)
        self.endY = 0.12 + (CGFloat((index * 29) % 48) / 100.0)
        self.startRotation = Double((index * 17) % 60) - 30
        self.endRotation = Double((index * 41) % 240) - 120
        self.delay = Double(index % 6) * 0.025
        self.color = [
            Color(red: 0.24, green: 0.56, blue: 1.0),
            Color(red: 0.34, green: 0.84, blue: 0.68),
            Color(red: 1.0, green: 0.77, blue: 0.29),
            Color(red: 0.95, green: 0.42, blue: 0.58),
        ][index % 4]
        self.size = CGSize(width: 8 + (index % 4), height: 10 + (index % 5))
    }
}
