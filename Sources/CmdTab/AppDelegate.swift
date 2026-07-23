import AppKit
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var singletonLockFileDescriptor: Int32 = -1
    private var shouldAllowTermination = false
    private var focusedWindowHistoryObserver: FocusedWindowHistoryObserver?
    private var screenTopologyObserver: ScreenTopologyObserver?
    var switcher: ProductionSwitcherWindowController!
    var hotkeyManager: ProfileHotkeyManager!
    var menuBar: MenuBarController!
    var preferencesWindowController: PreferencesWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !acquireSingletonLock() {
            activateExistingInstanceIfPossible()
            shouldAllowTermination = true
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        // Materialize and validate the profile document before installing the
        // event tap so the callback always reads one immutable valid snapshot.
        _ = SwitcherProfileStore.shared.profilesSnapshot()

        switcher = ProductionSwitcherWindowController()
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

        requestRequiredPermissionsIfNeeded()

        // ProfileHotkeyManager retries event-tap installation after an
        // Accessibility grant, so users no longer have to discover that a full
        // application restart is required merely to begin switching.
        hotkeyManager = ProfileHotkeyManager(switcher: switcher)
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

        focusedWindowHistoryObserver = FocusedWindowHistoryObserver()
        screenTopologyObserver = ScreenTopologyObserver { [weak self] in
            guard let self else { return }
            self.switcher?.refreshPreviewCache()
            if self.switcher?.isVisible == true {
                self.switcher?.applyCurrentStyleImmediately()
            }
        }
        LaunchAtLoginController.shared.sync(enabled: SwitcherPreferences.shared.launchAtLogin)
    }

    private func requestRequiredPermissionsIfNeeded() {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        }

        if #available(macOS 10.15, *), !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
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

    @objc private func handlePreferencesDidChange() {
        LaunchAtLoginController.shared.sync(enabled: SwitcherPreferences.shared.launchAtLogin)
    }

    func requestTermination() {
        shouldAllowTermination = true
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        screenTopologyObserver = nil
        focusedWindowHistoryObserver = nil
        DurableSwitcherHistoryStore.shared.waitForPendingWrites()
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