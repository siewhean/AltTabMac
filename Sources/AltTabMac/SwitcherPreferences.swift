import Foundation

final class SwitcherPreferences: ObservableObject {
    static let shared = SwitcherPreferences()
    static let didChangeNotification = Notification.Name("SwitcherPreferences.didChange")

    private let primaryModeKey = "primarySwitcherMode"
    private let includeBackgroundWindowsKey = "includeBackgroundWindows"
    private let includeTabsInAppSwitcherKey = "includeTabsInAppSwitcher"
    private let launchAtLoginKey = "launchAtLogin"
    private let maxWindowsPerAppKey = "maxWindowsPerApp"
    private let maxBrowserTabsShownKey = "maxBrowserTabsShown"
    private let enableVibrancyKey = "enableVibrancy"
    private let switcherStyleKey = "switcherStyle"

    @Published var primaryMode: SwitcherMode {
        didSet { persist(primaryMode.rawValue, forKey: primaryModeKey) }
    }

    @Published var includeBackgroundWindows: Bool {
        didSet { persist(includeBackgroundWindows, forKey: includeBackgroundWindowsKey) }
    }

    @Published var includeTabsInAppSwitcher: Bool {
        didSet { persist(includeTabsInAppSwitcher, forKey: includeTabsInAppSwitcherKey) }
    }

    @Published var launchAtLogin: Bool {
        didSet { persist(launchAtLogin, forKey: launchAtLoginKey) }
    }

    /// Max windows shown per application. 0 = show all (unlimited).
    @Published var maxWindowsPerApp: Int {
        didSet { persist(maxWindowsPerApp, forKey: maxWindowsPerAppKey) }
    }

    /// Max browser tabs returned by the Tab Switcher. Tabs are sorted by most
    /// recently used before the limit is applied. 0 = show all.
    @Published var maxBrowserTabsShown: Int {
        didSet { persist(maxBrowserTabsShown, forKey: maxBrowserTabsShownKey) }
    }

    /// Use frosted-glass / vibrancy for the switcher background.
    /// When off, a solid dark background is used instead.
    @Published var enableVibrancy: Bool {
        didSet { persist(enableVibrancy, forKey: enableVibrancyKey) }
    }

    /// Which UI presentation style to use for the switcher overlay.
    @Published var switcherStyle: SwitcherStyle {
        didSet { persist(switcherStyle.rawValue, forKey: switcherStyleKey) }
    }

    private init() {
        let defaults = UserDefaults.standard
        let savedPrimaryMode = defaults.string(forKey: primaryModeKey).flatMap(SwitcherMode.init(rawValue:)) ?? .app

        self.primaryMode = savedPrimaryMode
        self.includeBackgroundWindows = defaults.object(forKey: includeBackgroundWindowsKey) as? Bool ?? true
        self.includeTabsInAppSwitcher = defaults.object(forKey: includeTabsInAppSwitcherKey) as? Bool ?? false
        self.launchAtLogin = defaults.object(forKey: launchAtLoginKey) as? Bool ?? true
        self.maxWindowsPerApp = defaults.object(forKey: maxWindowsPerAppKey) as? Int ?? 3
        self.maxBrowserTabsShown = defaults.object(forKey: maxBrowserTabsShownKey) as? Int ?? 20
        self.enableVibrancy = defaults.object(forKey: enableVibrancyKey) as? Bool ?? true
        self.switcherStyle = defaults.string(forKey: switcherStyleKey)
            .flatMap(SwitcherStyle.init(rawValue:)) ?? .classicGrid
    }

    func alternateMode() -> SwitcherMode {
        primaryMode == .app ? .tab : .app
    }

    private func persist(_ value: Any, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
