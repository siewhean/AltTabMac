import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    var switcher: SwitcherWindowController!
    var hotkeyManager: HotkeyManager!
    var menuBar: MenuBarController!
    var preferencesWindowController: PreferencesWindowController!
    private let preferences = SwitcherPreferences.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

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
        .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        preferencesWindowController?.show()
        return true
    }

    private func showPrimarySwitcher() {
        switcher?.showStandalone(mode: preferences.primaryMode)
    }
}
