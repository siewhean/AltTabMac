import SwiftUI

#if DEBUG
struct DeveloperPreferencesPane: View {
    @ObservedObject var settings: DeveloperSettings
    @ObservedObject var licensingController: LicensingController
    @State private var generatorEmail = ""
    @State private var generatorName = ""
    @State private var generatorMessage: String?
    @State private var generatorError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            channelCard
            scenarioCard
            liveToolsCard
            generatorCard
        }
        .onAppear {
            licensingController.refreshStatus()
        }
        .onChange(of: settings.releaseChannel) { _ in
            licensingController.refreshStatus()
        }
        .onChange(of: settings.licensingScenario) { _ in
            licensingController.refreshStatus()
        }
    }

    private var channelCard: some View {
        DeveloperCard(
            title: "Release Channel",
            subtitle: "Keep stable behavior for normal use, or run this Mac in a local test profile."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Release Channel", selection: $settings.releaseChannel) {
                    ForEach(AppReleaseChannel.allCases) { channel in
                        Text(channel.title).tag(channel)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(AppReleaseChannel.allCases) { channel in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(channel == settings.releaseChannel ? activeAccentColor : Color.white.opacity(0.20))
                                .frame(width: 8, height: 8)
                                .padding(.top, 5)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(channel.title)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(channel.subtitle)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.58))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private var scenarioCard: some View {
        DeveloperCard(
            title: "Licensing Scenarios",
            subtitle: "Use these presets only in Test mode."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(DeveloperLicensingScenario.allCases) { scenario in
                    Button {
                        settings.licensingScenario = scenario
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(scenario.title)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)

                                Text(scenario.subtitle)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.58))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)

                            if settings.licensingScenario == scenario {
                                Text(settings.releaseChannel == .test ? "Active" : "Armed")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(activeAccentColor.opacity(0.92))
                                    )
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(settings.licensingScenario == scenario ? activeAccentColor.opacity(0.12) : Color.white.opacity(0.035))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            settings.licensingScenario == scenario ? activeAccentColor.opacity(0.75) : Color.white.opacity(0.08),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.releaseChannel == .stable && scenario != .live)
                    .opacity(settings.releaseChannel == .stable && scenario != .live ? 0.55 : 1)
                }

                if settings.releaseChannel == .stable {
                    Text("Stable mode ignores scenario presets. Switch to Test first, then use presets to simulate trial or license states.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.56))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var liveToolsCard: some View {
        DeveloperCard(
            title: "Live Trial Tools",
            subtitle: "The first action exits test mode. The second resets the real trial state on this Mac."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Button {
                        settings.restoreStableDefaults()
                        licensingController.refreshStatus()
                    } label: {
                        Label("Use Saved Stable State", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button {
                        settings.restoreStableDefaults()
                        licensingController.resetLiveTrialFromToday(clearSavedLicense: true)
                    } label: {
                        Label("Reset Real Trial", systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }

                VStack(alignment: .leading, spacing: 6) {
                        Text("Use Saved Stable State to exit test mode and return to the real saved license or trial state on this Mac.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.56))
                        .fixedSize(horizontal: false, vertical: true)

                        Text("Reset Real Trial exits test mode, clears saved license + server trial data, and returns CmdTab to registration-required state.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.56))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var generatorCard: some View {
        DeveloperCard(
            title: "Test License Generator",
            subtitle: "Generate a real signed license with your local developer key for activation and checkout flow checks."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.82))

                    TextField("Email", text: $generatorEmail)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.82))

                    TextField("Name", text: $generatorName)
                        .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 12) {
                    Button {
                        generateAndCopy()
                    } label: {
                        Text("Generate and Copy")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button {
                        generateAndActivate()
                    } label: {
                        Text("Generate + Activate")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }

                if let generatorMessage {
                    Text(generatorMessage)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(generatorError ? Color.red.opacity(0.9) : Color.white.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var activeAccentColor: Color {
        Color(red: 0.20, green: 0.42, blue: 0.90)
    }

    private func generateAndCopy() {
        do {
            let generated = try DeveloperLicenseGenerator.generate(
                email: generatorEmail,
                purchaserName: generatorName
            )
            DeveloperLicenseGenerator.copyToPasteboard(generated.token)
            generatorError = false
            generatorMessage = "Copied test license for \(generated.payload.email)."
        } catch {
            generatorError = true
            generatorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not generate the test license."
        }
    }

    private func generateAndActivate() {
        do {
            let generated = try DeveloperLicenseGenerator.generate(
                email: generatorEmail,
                purchaserName: generatorName
            )
            DeveloperLicenseGenerator.copyToPasteboard(generated.token)
            licensingController.activateLicense(generated.token)
            generatorError = false
            generatorMessage = "Generated and activated a real test license for \(generated.payload.email)."
        } catch {
            generatorError = true
            generatorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not generate the test license."
        }
    }
}
#endif

private struct DeveloperCard<Content: View>: View {
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
