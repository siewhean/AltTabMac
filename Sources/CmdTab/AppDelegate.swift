import AppKit
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let reopenSettingsNotification = Notification.Name("CmdTab.ReopenSettings")

    private var singletonLockFileDescriptor: Int32 = -1
    private var shouldAllowTermination = false
    var switcher: SwitcherWindowController!
    var hotkeyManager: HotkeyManager!
    var menuBar: MenuBarController!
    var preferencesWindowController: PreferencesWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !acquireSingletonLock() {
            notifyExistingInstanceToShowSettings()
            activateExistingInstanceIfPossible()
            shouldAllowTermination = true
            NSApp.terminate(nil)
            return
        }

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
        switcher.onLicenseAccessRequired = { [weak self] in
            self?.preferencesWindowController?.showLicensing()
        }

        AppTelemetryReporter.shared.startSession(licensingController: LicensingController.shared)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencesDidChange),
            name: SwitcherPreferences.didChangeNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleReopenSettingsRequest),
            name: Self.reopenSettingsNotification,
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

    private func acquireSingletonLock() -> Bool {
        let lockPath = "\(NSTemporaryDirectory())CmdTab.singleton.lock"
        let fileDescriptor = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fileDescriptor >= 0 else {
            return true
        }

        if flock(fileDescriptor, LOCK_EX | LOCK_NB) == 0 {
            singletonLockFileDescriptor = fileDescriptor
            return true
        }

        close(fileDescriptor)
        return false
    }

    private func activateExistingInstanceIfPossible() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier, !bundleIdentifier.isEmpty else {
            return
        }

        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let otherInstances = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentProcessIdentifier }

        otherInstances.first?.activate(options: [.activateIgnoringOtherApps])
    }

    private func notifyExistingInstanceToShowSettings() {
        DistributedNotificationCenter.default().post(
            name: Self.reopenSettingsNotification,
            object: Bundle.main.bundleIdentifier,
            userInfo: nil
        )
    }

    @objc private func handlePreferencesDidChange() {
        LaunchAtLoginController.shared.sync(enabled: SwitcherPreferences.shared.launchAtLogin)
    }

    @objc private func handleReopenSettingsRequest() {
        preferencesWindowController?.show(initialPane: .general)
    }

    func requestTermination() {
        shouldAllowTermination = true
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        DistributedNotificationCenter.default().removeObserver(self)
        if singletonLockFileDescriptor >= 0 {
            flock(singletonLockFileDescriptor, LOCK_UN)
            close(singletonLockFileDescriptor)
            singletonLockFileDescriptor = -1
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        shouldAllowTermination ? .terminateNow : .terminateCancel
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        preferencesWindowController?.show()
        return true
    }
}
