import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    var switcher: SwitcherWindowController!
    var hotkeyManager: HotkeyManager!
    var menuBar: MenuBarController!
    var preferencesWindowController: PreferencesWindowController!
    private let preferences = SwitcherPreferences.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a regular app so the Dock icon is visible and users can click
        // it to open Settings. The switcher panel is .nonactivatingPanel, so it
        // never competes for foreground status — interaction is unaffected.

        switcher = SwitcherWindowController()
        preferencesWindowController = PreferencesWindowController()
        preferencesWindowController.onOpenApplications = { [weak self] in
            self?.switcher?.showStandalone(mode: .app)
        }
        preferencesWindowController.onOpenBrowserTabs = { [weak self] in
            self?.switcher?.showStandalone(mode: .tab)
        }
        menuBar = MenuBarController(
            preferencesWindowController: preferencesWindowController,
            onActivatePrimarySwitcher: { [weak self] in
                self?.showPrimarySwitcher()
            }
        )
        hotkeyManager = HotkeyManager(switcher: switcher)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencesDidChange),
            name: SwitcherPreferences.didChangeNotification,
            object: nil
        )

        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        }

        if #available(macOS 10.15, *) {
            if !CGPreflightScreenCaptureAccess() {
                _ = CGRequestScreenCaptureAccess()
            }
        }

        LaunchAtLoginController.shared.sync(enabled: preferences.launchAtLogin)
    }

    @objc private func handlePreferencesDidChange() {
        LaunchAtLoginController.shared.sync(enabled: preferences.launchAtLogin)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Prevent the system from killing us (e.g. memory pressure, logout
        // cleanup before the user explicitly quits). A background helper must
        // stay alive to keep the global hotkey tap active.
        return .terminateCancel
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Dock-icon click (or re-launch from Finder) → open Settings, not the switcher.
        preferencesWindowController?.show()
        return true
    }

    private func showPrimarySwitcher() {
        switcher?.showStandalone(mode: preferences.primaryMode)
    }
}
