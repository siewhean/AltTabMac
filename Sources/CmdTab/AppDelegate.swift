import AppKit
import Combine
import Darwin

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Responsive apps answer Accessibility requests in a few milliseconds.
    static let accessibilityMessagingTimeout: Float = 0.25

    private var singletonLockFileDescriptor: Int32 = -1
    private var focusedWindowHistoryObserver: FocusedWindowHistoryObserver?
    private var screenTopologyObserver: ScreenTopologyObserver?
    private var licensingObserver: AnyCancellable?
    private var pendingActivationDeepLink: ActivationDeepLink?
    private let trialNotificationCoordinator = TrialNotificationCoordinator()
    var switcher: ProductionSwitcherWindowController!
    var hotkeyManager: ProfileHotkeyManager!
    var menuBar: MenuBarController!
    var preferencesWindowController: PreferencesWindowController!
    var onboardingWindowController: OnboardingWindowController!
    private var updaterController: UpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !acquireSingletonLock() {
            activateExistingInstanceIfPossible()
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        // Accessibility calls are synchronous IPC and run on the main thread,
        // which also services the keyboard event tap. Against a hung app the
        // ~6 s default timeout stalls typing system-wide until macOS disables
        // the tap and native Command-Tab bleeds through. Setting the timeout on
        // the system-wide element makes it the process-wide default; window
        // membership already treats AX failure as missing enrichment.
        AXUIElementSetMessagingTimeout(
            AXUIElementCreateSystemWide(),
            Self.accessibilityMessagingTimeout
        )

        // Materialize and validate the profile document before installing the
        // event tap so the callback always reads one immutable valid snapshot.
        _ = SwitcherProfileStore.shared.profilesSnapshot()

        switcher = ProductionSwitcherWindowController()
        preferencesWindowController = PreferencesWindowController()
        onboardingWindowController = OnboardingWindowController()
        preferencesWindowController.onOpenApplications = { [weak self] in
            self?.beginDefaultConfigurationFreeze()
            self?.switcher?.showStandalone()
        }
        preferencesWindowController.onRefreshPreviews = { [weak self] in
            self?.switcher?.refreshPreviewCache()
        }
        preferencesWindowController.onApplySwitcherStyle = { [weak self] style in
            self?.switcher?.applyStyleChangeFromSettings()
            self?.preferencesWindowController?.showStyleChangeHUD(for: style)
        }
        preferencesWindowController.onOpenOnboarding = { [weak self] in
            self?.onboardingWindowController?.show()
        }
        onboardingWindowController.onTrySwitcher = { [weak self] in
            self?.beginDefaultConfigurationFreeze()
            self?.switcher?.showStandalone()
        }
        updaterController = UpdaterController.shared
        menuBar = MenuBarController(
            preferencesWindowController: preferencesWindowController,
            onboardingWindowController: onboardingWindowController,
            licensingController: LicensingController.shared,
            updaterController: updaterController
        )

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
        licensingObserver = LicensingController.shared.$status
            .removeDuplicates()
            .sink { [weak self] status in
                self?.trialNotificationCoordinator.refresh(for: status)
            }
        refreshTrialNotifications()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencesDidChange),
            name: SwitcherPreferences.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRecoveredWindowPreview(_:)),
            name: ReliableWindowPreviewRecovery.didRecoverPreviewNotification,
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
        onboardingWindowController.showAutomaticallyIfNeeded()
        processPendingActivationDeepLink()
    }

    private func beginDefaultConfigurationFreeze() {
        guard let profileID = SwitcherProfileStore.shared
            .profilesSnapshot()
            .first(where: \.isEnabled)?
            .id else {
            return
        }
        SwitcherSessionConfigurationFreeze.shared.begin(
            profileID: profileID,
            preserveExisting: switcher?.isVisible == true
        )
    }

    private func refreshTrialNotifications() {
        trialNotificationCoordinator.refresh(for: LicensingController.shared.status)
    }

    private func processPendingActivationDeepLink() {
        guard let link = pendingActivationDeepLink,
              preferencesWindowController != nil else {
            return
        }
        pendingActivationDeepLink = nil
        // Any web page can open a cmdtab:// link, so never activate from one
        // directly: prefill the code and let the user confirm with Activate.
        LicensingController.shared.prefillActivationCode(link.activationCode)
        preferencesWindowController.showLicensing()
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

    @objc private func handleRecoveredWindowPreview(_ notification: Notification) {
        // The recovered exact frame is already in the continuity store. Publish
        // that tile without triggering another whole-desktop capture pass.
        guard let windowID = notification.userInfo?["windowID"] as? CGWindowID else { return }
        switcher?.publishRecoveredPreview(windowID: windowID)
    }

    func requestTermination() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        licensingObserver = nil
        SwitcherSessionConfigurationFreeze.shared.end()
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
        .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Reopen/activation can accompany switching. Only explicit menu actions
        // may open Settings; suppress AppKit's automatic window ordering too.
        return SettingsWindowVisibilityPolicy.handleReopen(onboardingWindow: onboardingWindowController?.window)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let link = urls.lazy.compactMap(ActivationDeepLink.parse).first else {
            return
        }
        pendingActivationDeepLink = link
        processPendingActivationDeepLink()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        onboardingWindowController?.refreshPermissions()
        LicensingController.shared.refreshStatus()
        refreshTrialNotifications()
        Task { @MainActor [weak self] in
            await self?.menuBar?.refreshLicenseAuthorization()
        }
    }
}
