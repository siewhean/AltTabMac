import AppKit
import Combine
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var singletonLockFileDescriptor: Int32 = -1
    private var shouldAllowTermination = false
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
        licensingObserver = LicensingController.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshTrialNotifications()
            }
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
        LicensingController.shared.refreshStatus()
        trialNotificationCoordinator.refresh(for: LicensingController.shared.status)
    }

    private func processPendingActivationDeepLink() {
        guard let link = pendingActivationDeepLink,
              preferencesWindowController != nil else {
            return
        }
        pendingActivationDeepLink = nil
        let controller = LicensingController.shared
        controller.enteredLicenseKey = link.activationCode
        preferencesWindowController.showLicensing()
        Task { @MainActor in
            _ = await controller.activateEnteredLicenseKeyOnline()
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

    @objc private func handleRecoveredWindowPreview(_ notification: Notification) {
        // A deferred ScreenCaptureKit image was added to the exact in-memory
        // continuity store. Refresh the current base/enriched snapshot so a visible
        // Arc or Telegram tile can replace its placeholder without another trigger.
        switcher?.refreshPreviewCache()
    }

    func requestTermination() {
        shouldAllowTermination = true
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
        shouldAllowTermination ? .terminateNow : .terminateCancel
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if onboardingWindowController?.window?.isVisible == true {
            onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        } else {
            preferencesWindowController?.show()
        }
        return true
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
        refreshTrialNotifications()
        Task { @MainActor [weak self] in
            await self?.menuBar?.refreshLicenseAuthorization()
        }
    }
}
