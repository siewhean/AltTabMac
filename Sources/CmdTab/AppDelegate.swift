import AppKit
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var singletonLockFileDescriptor: Int32 = -1
    private var shouldAllowTermination = false
    private var focusedWindowHistoryObserver: FocusedWindowHistoryObserver?
    var switcher: SwitcherWindowController!
    var hotkeyManager: HotkeyManager!
    var menuBar: MenuBarController!
    var preferencesWindowController: PreferencesWindowController!
    var onboardingWindowController: OnboardingWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !acquireSingletonLock() {
            activateExistingInstanceIfPossible()
            shouldAllowTermination = true
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        switcher = SwitcherWindowController()
        preferencesWindowController = PreferencesWindowController()
        onboardingWindowController = OnboardingWindowController()

        preferencesWindowController.onOpenApplications = { [weak self] in
            self?.switcher?.showStandalone()
        }
        switcher.onVisibilityChanged = { [weak self] _ in
            self?.menuBar?.dismissContextMenu()
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
            self?.hotkeyManager?.setEnabled(false)
            self?.preferencesWindowController?.showLicensing()
            self?.showExpiredTrialAlertIfNeeded()
        }

        AppTelemetryReporter.shared.startSession(licensingController: LicensingController.shared)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencesDidChange),
            name: SwitcherPreferences.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLicensingStateDidChange),
            name: LicensingController.didChangeNotification,
            object: nil
        )

        updateEventTapStateForLicensing()
        if LicensingController.shared.status.isExpired {
            showExpiredTrialAlertIfNeeded()
        } else {
            onboardingWindowController.showOnboardingIfNeeded()
        }

        if SwitcherPreferences.shared.hasCompletedOnboarding {
            if !AXIsProcessTrusted() {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
            }

            if #available(macOS 10.15, *) {
                if !CGPreflightScreenCaptureAccess() {
                    _ = CGRequestScreenCaptureAccess()
                }
            }
        }

        focusedWindowHistoryObserver = FocusedWindowHistoryObserver()
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

    @objc private func handlePreferencesDidChange() {
        LaunchAtLoginController.shared.sync(enabled: SwitcherPreferences.shared.launchAtLogin)
    }

    @objc @MainActor private func handleLicensingStateDidChange() {
        updateEventTapStateForLicensing()
    }

    @MainActor private func updateEventTapStateForLicensing() {
        let isExpired = LicensingController.shared.status.isExpired
        hotkeyManager?.setEnabled(!isExpired)
    }

    @MainActor private func showExpiredTrialAlertIfNeeded() {
        guard LicensingController.shared.status.isExpired else { return }
        let alert = NSAlert()
        alert.messageText = "CmdTab Trial Expired"
        alert.informativeText = "Your 14-day trial has ended. The native macOS window switcher has been restored. Please purchase a license to continue using CmdTab."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Buy License")
        alert.addButton(withTitle: "Enter License Key")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            LicensingController.shared.openBuyPage()
            preferencesWindowController?.showLicensing()
        case .alertSecondButtonReturn:
            preferencesWindowController?.showLicensing()
        default:
            requestTermination()
        }
    }

    func requestTermination() {
        shouldAllowTermination = true
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        focusedWindowHistoryObserver = nil
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

    @MainActor
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleURLScheme(url)
        }
    }

    @MainActor
    private func handleURLScheme(_ url: URL) {
        guard url.scheme?.lowercased() == "cmdtab" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }

        let host = components.host?.lowercased() ?? ""
        let path = components.path.lowercased()

        if host.contains("activate") || path.contains("activate") {
            if let keyItem = components.queryItems?.first(where: { $0.name.lowercased() == "key" }),
               let licenseKey = keyItem.value, !licenseKey.isEmpty {
                let activated = LicensingController.shared.activateLicense(licenseKey)
                preferencesWindowController?.showLicensing()
                if activated {
                    updateEventTapStateForLicensing()
                }
            }
        }
    }
}
