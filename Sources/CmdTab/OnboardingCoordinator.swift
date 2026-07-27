import AppKit
import ApplicationServices
import Foundation

enum OnboardingStep: Int, CaseIterable, Codable, Equatable {
    case welcome
    case accessibility
    case screenRecording
    case access
    case practice
    case completion
}

struct OnboardingProgress: Codable, Equatable {
    var version: Int
    var step: OnboardingStep
    var completedVersion: Int
    var attemptedPractice: Bool
}

protocol OnboardingProgressStoring {
    func load() -> OnboardingProgress?
    func save(_ progress: OnboardingProgress)
}

final class UserDefaultsOnboardingProgressStore: OnboardingProgressStoring {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        key: String = "CmdTab.onboarding.progress"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> OnboardingProgress? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(OnboardingProgress.self, from: data)
    }

    func save(_ progress: OnboardingProgress) {
        guard let data = try? encoder.encode(progress) else { return }
        defaults.set(data, forKey: key)
    }
}

protocol OnboardingPermissionManaging {
    var isAccessibilityGranted: Bool { get }
    var isScreenRecordingGranted: Bool { get }
    func requestAccessibility()
    func requestScreenRecording()
    func openAccessibilitySettings()
    func openScreenRecordingSettings()
}

struct SystemOnboardingPermissionManager: OnboardingPermissionManaging {
    var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    var isScreenRecordingGranted: Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func requestScreenRecording() {
        if #available(macOS 10.15, *), !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
        }
    }

    func openAccessibilitySettings() {
        openSystemSettings(
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
    }

    func openScreenRecordingSettings() {
        openSystemSettings(
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        )
    }

    private func openSystemSettings(_ rawValue: String) {
        guard let url = URL(string: rawValue) else { return }
        NSWorkspace.shared.open(url)
    }
}

@MainActor
final class OnboardingCoordinator: ObservableObject {
    static let currentVersion = 1

    @Published private(set) var step: OnboardingStep
    @Published private(set) var attemptedPractice: Bool
    @Published private(set) var isAccessibilityGranted: Bool
    @Published private(set) var isScreenRecordingGranted: Bool

    let licensingController: LicensingController

    private let store: OnboardingProgressStoring
    private let permissionManager: OnboardingPermissionManaging
    private var completedVersion: Int

    convenience init() {
        self.init(
            store: UserDefaultsOnboardingProgressStore(),
            permissionManager: SystemOnboardingPermissionManager(),
            licensingController: .shared
        )
    }

    init(
        store: OnboardingProgressStoring,
        permissionManager: OnboardingPermissionManaging,
        licensingController: LicensingController
    ) {
        self.store = store
        self.permissionManager = permissionManager
        self.licensingController = licensingController

        let saved = store.load()
        if let saved, saved.version == Self.currentVersion {
            step = saved.step
            attemptedPractice = saved.attemptedPractice
            completedVersion = saved.completedVersion
        } else {
            step = .welcome
            attemptedPractice = false
            completedVersion = saved?.completedVersion ?? 0
        }
        isAccessibilityGranted = permissionManager.isAccessibilityGranted
        isScreenRecordingGranted = permissionManager.isScreenRecordingGranted
        licensingController.refreshStatus()
        persist()
    }

    var shouldPresentAutomatically: Bool {
        completedVersion < Self.currentVersion
    }

    var canContinue: Bool {
        switch step {
        case .accessibility:
            return isAccessibilityGranted
        case .access:
            return licensingController.hasUnlockedAccess
        case .practice:
            return attemptedPractice
        default:
            return true
        }
    }

    func prepareForPresentation(isAutomatic: Bool) -> Bool {
        refresh()
        guard !isAutomatic || shouldPresentAutomatically else { return false }
        if !isAutomatic, !shouldPresentAutomatically, step == .completion {
            step = .welcome
            attemptedPractice = false
            persist()
        }
        return true
    }

    func refresh() {
        isAccessibilityGranted = permissionManager.isAccessibilityGranted
        isScreenRecordingGranted = permissionManager.isScreenRecordingGranted
        licensingController.refreshStatus()
    }

    func requestAccessibility() {
        permissionManager.requestAccessibility()
        refresh()
    }

    func requestScreenRecording() {
        permissionManager.requestScreenRecording()
        refresh()
    }

    func openAccessibilitySettings() {
        permissionManager.openAccessibilitySettings()
    }

    func openScreenRecordingSettings() {
        permissionManager.openScreenRecordingSettings()
    }

    func skipScreenRecording() {
        guard step == .screenRecording else { return }
        step = .access
        persist()
    }

    func attemptPractice(_ action: () -> Void) {
        action()
        attemptedPractice = true
        persist()
    }

    func moveBack() {
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        step = previous
        persist()
    }

    @discardableResult
    func advance() -> Bool {
        refresh()
        guard canContinue else { return false }

        if step == .completion {
            completedVersion = Self.currentVersion
            persist()
            return true
        }

        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else {
            return false
        }
        step = next
        if next == .completion {
            completedVersion = Self.currentVersion
        }
        persist()
        return true
    }

    private func persist() {
        store.save(
            OnboardingProgress(
                version: Self.currentVersion,
                step: step,
                completedVersion: completedVersion,
                attemptedPractice: attemptedPractice
            )
        )
    }
}
