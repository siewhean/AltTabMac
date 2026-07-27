import Foundation

final class SwitcherPreferences: ObservableObject {
    static let shared = SwitcherPreferences()
    static let didChangeNotification = Notification.Name("SwitcherPreferences.didChange")

    private let includeBackgroundWindowsKey = "includeBackgroundWindows"
    private let windowVisibilityScopeKey = "windowVisibilityScope"
    private let includeMinimizedWindowsKey = "includeMinimizedWindows"
    private let launchAtLoginKey = "launchAtLogin"
    private let maxWindowsPerAppKey = "maxWindowsPerApp"
    private let enableVibrancyKey = "enableVibrancy"
    private let showSelectedPreviewBackdropKey = "showSelectedPreviewBackdrop"
    private let switcherStyleKey = "switcherStyle"
    private let displayPlacementKey = "displayPlacement"
    private let alternateTriggerKey = "alternateTrigger"
    private let excludedAppsKey = "excludedAppsText"
    private let ignoredWindowTitlesKey = "ignoredWindowTitlesText"

    @Published var windowVisibilityScope: WindowVisibilityScope {
        didSet {
            persist(windowVisibilityScope.rawValue, forKey: windowVisibilityScopeKey)
            persist(windowVisibilityScope == .allSpaces, forKey: includeBackgroundWindowsKey)
        }
    }

    /// Include minimized top-level windows as exact switcher targets.
    /// Kept opt-in for existing users to avoid changing membership unexpectedly.
    @Published var includeMinimizedWindows: Bool {
        didSet { persist(includeMinimizedWindows, forKey: includeMinimizedWindowsKey) }
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

    /// Which display the switcher should appear on.
    @Published var displayPlacement: SwitcherDisplayPreference {
        didSet { persist(displayPlacement.rawValue, forKey: displayPlacementKey) }
    }

    /// Optional secondary trigger. Production accepts a short same-side Command
    /// double tap or a simultaneous same-side Command+Option chord. Legacy
    /// modifier-only single taps decode for migration but normalize to Standard Only.
    @Published var alternateTrigger: AlternateTriggerMode {
        didSet {
            let safeMode = alternateTrigger.productionSafeMode
            if safeMode != alternateTrigger {
                // `@Published` observers re-enter when the wrapped property is
                // normalized. Let that safe inner assignment persist once rather
                // than sending duplicate preference notifications.
                alternateTrigger = safeMode
                return
            }
            persist(alternateTrigger.rawValue, forKey: alternateTriggerKey)
        }
    }

    /// Comma or newline-separated app identifiers / names to keep out of the switcher.
    @Published var excludedAppsText: String {
        didSet { persist(excludedAppsText, forKey: excludedAppsKey) }
    }

    /// Comma or newline-separated title fragments used to declutter utility windows.
    @Published var ignoredWindowTitlesText: String {
        didSet { persist(ignoredWindowTitlesText, forKey: ignoredWindowTitlesKey) }
    }

    private init() {
        let defaults = UserDefaults.standard
        let legacyIncludeBackgroundWindows = defaults.object(forKey: includeBackgroundWindowsKey) as? Bool ?? true
        let storedAlternateTrigger = defaults.string(forKey: alternateTriggerKey)
            .flatMap(AlternateTriggerMode.init(rawValue:)) ?? .disabled
        let safeAlternateTrigger = storedAlternateTrigger.productionSafeMode

        self.windowVisibilityScope = defaults.string(forKey: windowVisibilityScopeKey)
            .flatMap(WindowVisibilityScope.init(rawValue:))
            ?? (legacyIncludeBackgroundWindows ? .allSpaces : .visibleSpaces)
        self.includeMinimizedWindows = defaults.object(forKey: includeMinimizedWindowsKey) as? Bool ?? false
        self.launchAtLogin = defaults.object(forKey: launchAtLoginKey) as? Bool ?? true
        // Completeness is the default contract. Users can opt into a cap later,
        // but a fresh installation must not silently hide the fourth window.
        self.maxWindowsPerApp = defaults.object(forKey: maxWindowsPerAppKey) as? Int ?? 0
        self.enableVibrancy = defaults.object(forKey: enableVibrancyKey) as? Bool ?? true
        self.showSelectedPreviewBackdrop = defaults.object(forKey: showSelectedPreviewBackdropKey) as? Bool ?? false
        self.switcherStyle = defaults.string(forKey: switcherStyleKey)
            .flatMap(SwitcherStyle.init(rawValue:)) ?? .classicGrid
        self.displayPlacement = defaults.string(forKey: displayPlacementKey)
            .flatMap(SwitcherDisplayPreference.init(rawValue:)) ?? .activeWindowDisplay
        self.alternateTrigger = safeAlternateTrigger
        self.excludedAppsText = defaults.string(forKey: excludedAppsKey) ?? ""
        self.ignoredWindowTitlesText = defaults.string(forKey: ignoredWindowTitlesKey) ?? ""

        if safeAlternateTrigger != storedAlternateTrigger {
            defaults.set(safeAlternateTrigger.rawValue, forKey: alternateTriggerKey)
        }
    }

    private func persist(_ value: Any, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    var excludedAppEntries: [String] {
        WindowExclusionRules.normalizedEntries(from: excludedAppsText)
    }

    var ignoredWindowTitleEntries: [String] {
        WindowExclusionRules.normalizedEntries(from: ignoredWindowTitlesText)
    }

    func excludesApp(identifier: String, appName: String) -> Bool {
        WindowExclusionRules.matchesApp(
            identifier: identifier,
            appName: appName,
            entries: excludedAppEntries
        )
    }

    func excludesWindowTitle(_ title: String) -> Bool {
        WindowExclusionRules.matchesWindowTitle(title, entries: ignoredWindowTitleEntries)
    }

    func resetDurableWindowHistory() {
        DurableSwitcherHistoryStore.shared.reset()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
