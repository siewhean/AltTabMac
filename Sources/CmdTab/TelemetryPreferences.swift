import Combine
import Foundation

@MainActor
final class TelemetryPreferences: ObservableObject {
    static let shared = TelemetryPreferences()
    static let didChangeNotification = Notification.Name("CmdTab.TelemetryPreferencesDidChange")

    private let defaults: UserDefaults
    private let enabledKey: String

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: enabledKey)
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        }
    }

    init(defaults: UserDefaults = .standard, enabledKey: String = "CmdTab.telemetry.enabled") {
        self.defaults = defaults
        self.enabledKey = enabledKey
        self.isEnabled = defaults.bool(forKey: enabledKey)
    }
}
