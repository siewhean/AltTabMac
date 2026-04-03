import Combine
import Foundation

enum AppReleaseChannel: String, CaseIterable, Identifiable {
    case stable
    case test

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stable:
            return "Stable"
        case .test:
            return "Test"
        }
    }

    var subtitle: String {
        switch self {
        case .stable:
            return "Normal app behavior. No developer licensing overrides."
        case .test:
            return "Local test profile for trying feature branches, trial states, and license scenarios."
        }
    }
}

enum DeveloperLicensingScenario: String, CaseIterable, Identifiable {
    case live
    case freshTrial
    case oneDayLeft
    case expiredTrial
    case simulatedLicensed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .live:
            return "Live state"
        case .freshTrial:
            return "Fresh trial"
        case .oneDayLeft:
            return "1 day left"
        case .expiredTrial:
            return "Expired trial"
        case .simulatedLicensed:
            return "Simulated license"
        }
    }

    var subtitle: String {
        switch self {
        case .live:
            return "Use the real saved trial and license data on this Mac."
        case .freshTrial:
            return "Pretend this Mac just started a new 14-day trial."
        case .oneDayLeft:
            return "Test warning copy and near-expiry behavior."
        case .expiredTrial:
            return "Force the switcher into the expired state."
        case .simulatedLicensed:
            return "Bypass trial expiry and act like a purchased license is active."
        }
    }
}

@MainActor
final class DeveloperSettings: ObservableObject {
    static let shared = DeveloperSettings()

    private let releaseChannelKey: String
    private let licensingScenarioKey: String
    private let defaults: UserDefaults

    @Published var releaseChannel: AppReleaseChannel {
        didSet {
            defaults.set(releaseChannel.rawValue, forKey: releaseChannelKey)
        }
    }

    @Published var licensingScenario: DeveloperLicensingScenario {
        didSet {
            defaults.set(licensingScenario.rawValue, forKey: licensingScenarioKey)
        }
    }

    init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "CmdTab.developer"
    ) {
        self.defaults = defaults
        self.releaseChannelKey = "\(keyPrefix).releaseChannel"
        self.licensingScenarioKey = "\(keyPrefix).licensingScenario"

        self.releaseChannel = defaults.string(forKey: "\(keyPrefix).releaseChannel")
            .flatMap(AppReleaseChannel.init(rawValue:))
            ?? .stable
        self.licensingScenario = defaults.string(forKey: "\(keyPrefix).licensingScenario")
            .flatMap(DeveloperLicensingScenario.init(rawValue:))
            ?? .live
    }

    var usesLicensingOverride: Bool {
        releaseChannel == .test && licensingScenario != .live
    }

    func restoreStableDefaults() {
        releaseChannel = .stable
        licensingScenario = .live
    }
}
