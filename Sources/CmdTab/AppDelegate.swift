import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    var switcher: SwitcherWindowController!
    var hotkeyManager: HotkeyManager!
    var menuBar: MenuBarController!
    var preferencesWindowController: PreferencesWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        switcher = SwitcherWindowController()
        preferencesWindowController = PreferencesWindowController()
        preferencesWindowController.onOpenApplications = { [weak self] in
            self?.switcher?.showStandalone()
        }
        preferencesWindowController.onRefreshPreviews = { [weak self] in
            self?.switcher?.refreshPreviewCache()
        }
        preferencesWindowController.onApplySwitcherStyle = { [weak self] style in
            self?.switcher?.applyStyleChangeFromSettings()
            self?.preferencesWindowController?.showStyleChangeHUD(for: style)
        }
        menuBar = MenuBarController(preferencesWindowController: preferencesWindowController)
        hotkeyManager = HotkeyManager(switcher: switcher)
        switcher.onClickCommit = { [weak self] in
            self?.hotkeyManager?.clearTriggerStateFromClickCommit()
        }

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

        LaunchAtLoginController.shared.sync(enabled: SwitcherPreferences.shared.launchAtLogin)
    }

    @objc private func handlePreferencesDidChange() {
        LaunchAtLoginController.shared.sync(enabled: SwitcherPreferences.shared.launchAtLogin)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateCancel
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        preferencesWindowController?.show()
        return true
    }
}
