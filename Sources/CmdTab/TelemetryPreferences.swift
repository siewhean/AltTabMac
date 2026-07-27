import Combine
import Foundation

@MainActor
final class TelemetryPreferences: ObservableObject {
    static let shared = TelemetryPreferences()

    @Published private(set) var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            defaults.set(isEnabled, forKey: key)
        }
    }

    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "CmdTab.telemetry.enabled"
    ) {
        self.defaults = defaults
        self.key = key
        self.isEnabled = defaults.object(forKey: key) as? Bool ?? false
    }

    func setEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}
