import AppKit
import Darwin

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let reopenSwitcherNotification = Notification.Name("CmdTab.ReopenSwitcher")

    private var singletonLockFileDescriptor: Int32 = -1
    private var shouldAllowTermination = false
    var switcher: SwitcherWindowController!
    var hotkeyManager: HotkeyManager!
    var menuBar: MenuBarController!
    var preferencesWindowController: PreferencesWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !acquireSingletonLock() {
            notifyExistingInstanceToShowSwitcher()
            activateExistingInstanceIfPossible()
            shouldAllowTermination = true
            NSApp.terminate(nil)
            return
        }

        LegacyAppIdentityMigration.runIfNeeded()
        NSApp.setActivationPolicy(.accessory)
        ProductionSignpost.prepare()

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
        switcher.onDismiss = { [weak self] committingSelection in
            if committingSelection {
                self?.hotkeyManager?.clearTriggerStateFromClickCommit()
            } else {
                self?.hotkeyManager?.clearTriggerStateFromDismissal()
            }
        }
        switcher.onLicenseAccessRequired = { [weak self] in
            self?.preferencesWindowController?.showLicensing()
        }

        applyTelemetryPreference()
        Task {
            await LicensingController.shared.refreshRemoteLicenseStatus(force: true)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencesDidChange),
            name: SwitcherPreferences.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTelemetryPreferencesDidChange),
            name: TelemetryPreferences.didChangeNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleReopenSwitcherRequest),
            name: Self.reopenSwitcherNotification,
            object: nil
        )

        DispatchQueue.main.async {
            PermissionOnboardingController.presentIfNeeded()
            self.hotkeyManager.start()
        }

        LaunchAtLoginController.shared.sync(enabled: SwitcherPreferences.shared.launchAtLogin)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        PermissionOnboardingController.presentIfNeeded()
        hotkeyManager?.start()
        switcher?.refreshPreviewCache()
        Task {
            await LicensingController.shared.refreshRemoteLicenseStatus(force: true)
        }
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

    private func notifyExistingInstanceToShowSwitcher() {
        DistributedNotificationCenter.default().post(
            name: Self.reopenSwitcherNotification,
            object: Bundle.main.bundleIdentifier,
            userInfo: nil
        )
    }

    @objc private func handlePreferencesDidChange() {
        LaunchAtLoginController.shared.sync(enabled: SwitcherPreferences.shared.launchAtLogin)
    }

    @objc private func handleTelemetryPreferencesDidChange() {
        applyTelemetryPreference()
    }

    private func applyTelemetryPreference() {
        if TelemetryPreferences.shared.isEnabled {
            AppTelemetryReporter.shared.startSession(licensingController: LicensingController.shared)
        } else {
            AppTelemetryReporter.shared.stopSession()
        }
    }

    @objc private func handleReopenSwitcherRequest() {
        switcher?.showStandalone()
    }

    func requestTermination() {
        shouldAllowTermination = true
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppTelemetryReporter.shared.stopSession()
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
        switcher?.showStandalone()
        return true
    }
}
