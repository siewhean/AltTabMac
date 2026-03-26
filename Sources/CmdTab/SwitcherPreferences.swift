import Foundation

final class SwitcherPreferences: ObservableObject {
    static let shared = SwitcherPreferences()
    static let didChangeNotification = Notification.Name("SwitcherPreferences.didChange")

    private let includeBackgroundWindowsKey = "includeBackgroundWindows"
    private let launchAtLoginKey = "launchAtLogin"
    private let maxWindowsPerAppKey = "maxWindowsPerApp"
    private let enableVibrancyKey = "enableVibrancy"
    private let showSelectedPreviewBackdropKey = "showSelectedPreviewBackdrop"
    private let switcherStyleKey = "switcherStyle"

    @Published var includeBackgroundWindows: Bool {
        didSet { persist(includeBackgroundWindows, forKey: includeBackgroundWindowsKey) }
    }

    @Published var launchAtLogin: Bool {
        didSet { persist(launchAtLogin, forKey: launchAtLoginKey) }
    }

    /// Max windows shown per application. 0 = show all (unlimited).
    @Published var maxWindowsPerApp: Int {
        didSet { persist(maxWindowsPerApp, forKey: maxWindowsPerAppKey) }
    }

    /// Use frosted-glass / vibrancy for the switcher background.
    /// When off, a solid dark background is used instead.
    @Published var enableVibrancy: Bool {
        didSet { persist(enableVibrancy, forKey: enableVibrancyKey) }
    }

    /// Show the selected window preview behind the switcher surface.
    @Published var showSelectedPreviewBackdrop: Bool {
        didSet { persist(showSelectedPreviewBackdrop, forKey: showSelectedPreviewBackdropKey) }
    }

    /// Which UI presentation style to use for the switcher overlay.
    @Published var switcherStyle: SwitcherStyle {
        didSet { persist(switcherStyle.rawValue, forKey: switcherStyleKey) }
    }

    private init() {
        let defaults = UserDefaults.standard

        self.includeBackgroundWindows = defaults.object(forKey: includeBackgroundWindowsKey) as? Bool ?? true
        self.launchAtLogin = defaults.object(forKey: launchAtLoginKey) as? Bool ?? true
        self.maxWindowsPerApp = defaults.object(forKey: maxWindowsPerAppKey) as? Int ?? 3
        self.enableVibrancy = defaults.object(forKey: enableVibrancyKey) as? Bool ?? true
        self.showSelectedPreviewBackdrop = defaults.object(forKey: showSelectedPreviewBackdropKey) as? Bool ?? false
        self.switcherStyle = defaults.string(forKey: switcherStyleKey)
            .flatMap(SwitcherStyle.init(rawValue:)) ?? .classicGrid
    }

    private func persist(_ value: Any, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
