import AppKit
import ApplicationServices

/// Resolves exact CG window identities for Accessibility focus changes.
///
/// NSWorkspace only reports application activation. Without an AX observer,
/// A1 → A2 → A3 inside one already-frontmost application collapses into an
/// incomplete history. This observer records every focused/main-window change
/// and supplies privacy-minimised metadata to durable MRU persistence.
final class FocusedWindowHistoryObserver {
    private static let observerCallback: AXObserverCallback = {
        _, element, _, refcon in
        guard let refcon else { return }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid != 0 else {
            return
        }

        let instance = Unmanaged<FocusedWindowHistoryObserver>
            .fromOpaque(refcon)
            .takeUnretainedValue()
        DispatchQueue.main.async { [weak instance] in
            instance?.handleFocusedWindowChange(pid: pid)
        }
    }

    private let history: SwitcherHistoryStore
    private let catalog: AXWindowCatalog
    private let workspace = NSWorkspace.shared
    private var observersByPID: [pid_t: AXObserver] = [:]
    private var workspaceObserverTokens: [NSObjectProtocol] = []
    private var applicationObserverTokens: [NSObjectProtocol] = []
    private var permissionRetryTimer: Timer?

    init(
        history: SwitcherHistoryStore = .shared,
        catalog: AXWindowCatalog = .shared
    ) {
        self.history = history
        self.catalog = catalog
        installWorkspaceObservers()
        refreshAccessibilityObservers()
        reconcileFrontmostApplication()
        startPermissionRetryIfNeeded()
    }

    deinit {
        permissionRetryTimer?.invalidate()
        removeAllAccessibilityObservers()
        for token in workspaceObserverTokens {
            workspace.notificationCenter.removeObserver(token)
        }
        for token in applicationObserverTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    private func installWorkspaceObservers() {
        let activationToken = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.refreshAccessibilityObservers()
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication {
                self?.reconcile(app: app)
            }
        }

        let launchToken = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAccessibilityObservers()
        }

        let terminateToken = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAccessibilityObservers()
        }

        let activeToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAccessibilityObservers()
            self?.startPermissionRetryIfNeeded()
        }

        workspaceObserverTokens = [activationToken, launchToken, terminateToken]
        applicationObserverTokens = [activeToken]
    }

    private func startPermissionRetryIfNeeded() {
        guard !AXIsProcessTrusted(), permissionRetryTimer == nil else { return }
        permissionRetryTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            self.permissionRetryTimer = nil
            self.refreshAccessibilityObservers()
            self.reconcileFrontmostApplication()
        }
    }

    private func refreshAccessibilityObservers() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.refreshAccessibilityObservers()
            }
            return
        }

        guard AXIsProcessTrusted() else {
            removeAllAccessibilityObservers()
            startPermissionRetryIfNeeded()
            return
        }
        permissionRetryTimer?.invalidate()
        permissionRetryTimer = nil

        let applications = workspace.runningApplications.filter {
            $0.activationPolicy == .regular &&
            $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }
        let activePIDs = Set(applications.map(\.processIdentifier))

        let obsoletePIDs = observersByPID.keys.filter { !activePIDs.contains($0) }
        for pid in obsoletePIDs {
            removeAccessibilityObserver(for: pid)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for app in applications where observersByPID[app.processIdentifier] == nil {
            var observer: AXObserver?
            guard AXObserverCreate(
                app.processIdentifier,
                Self.observerCallback,
                &observer
            ) == .success, let observer else {
                continue
            }

            let axApplication = AXUIElementCreateApplication(app.processIdentifier)
            let notifications = [
                kAXFocusedWindowChangedNotification as CFString,
                kAXMainWindowChangedNotification as CFString,
            ]
            let addedAtLeastOneNotification = notifications.reduce(false) {
                addedAny, notification in
                let result = AXObserverAddNotification(
                    observer,
                    axApplication,
                    notification,
                    refcon
                )
                return addedAny || result == .success
            }

            guard addedAtLeastOneNotification else { continue }
            CFRunLoopAddSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .commonModes
            )
            observersByPID[app.processIdentifier] = observer
        }
    }

    private func removeAllAccessibilityObservers() {
        for pid in Array(observersByPID.keys) {
            removeAccessibilityObserver(for: pid)
        }
    }

    private func removeAccessibilityObserver(for pid: pid_t) {
        guard let observer = observersByPID.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )
    }

    private func handleFocusedWindowChange(pid: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: pid),
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier,
              workspace.frontmostApplication?.processIdentifier == pid else {
            return
        }
        reconcile(app: app)
    }

    private func reconcileFrontmostApplication() {
        guard let app = workspace.frontmostApplication else { return }
        reconcile(app: app)
    }

    private func reconcile(app: NSRunningApplication, attempt: Int = 0) {
        guard app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier,
              workspace.frontmostApplication?.processIdentifier == app.processIdentifier else {
            return
        }

        if let identity = focusedIdentity(for: app) {
            let snapshot = catalog.snapshot(for: [app])
            if let windowID = identity.windowID,
               let metadata = snapshot.metadata(
                   ownerPID: app.processIdentifier,
                   windowID: windowID
               ) {
                let descriptor = LiveWindowHistoryDescriptor(
                    identity: identity,
                    bundleIdentifier: app.bundleIdentifier ?? "app-\(app.processIdentifier)",
                    title: metadata.title.isEmpty
                        ? (app.localizedName ?? "Application")
                        : metadata.title,
                    documentURL: metadata.documentURL,
                    role: metadata.role,
                    subrole: metadata.subrole,
                    bounds: metadata.frame,
                    displayIdentifier: metadata.workspace.primaryWorkspace?.displayIdentifier,
                    workspaceKey: metadata.workspace.primaryWorkspace?.stableKey
                )
                history.noteActivation(identity, descriptor: descriptor)
            } else {
                history.noteActivation(identity)
            }
            return
        }

        guard attempt < 2 else {
            let identifier = app.bundleIdentifier ?? "pid:\(app.processIdentifier)"
            history.noteActivation(
                .appFallback(bundleID: identifier, pid: app.processIdentifier)
            )
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self, weak app] in
            guard let self, let app else { return }
            self.reconcile(app: app, attempt: attempt + 1)
        }
    }

    private func focusedIdentity(
        for app: NSRunningApplication
    ) -> SwitcherHistoryIdentity? {
        let axApplication = AXUIElementCreateApplication(app.processIdentifier)
        let attributes = [
            kAXFocusedWindowAttribute as CFString,
            kAXMainWindowAttribute as CFString,
        ]

        for attribute in attributes {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                axApplication,
                attribute,
                &value
            ) == .success, let value else {
                continue
            }

            let window = unsafeBitCast(value, to: AXUIElement.self)
            if let windowID = AXWindowIdentityLookup.windowID(for: window) {
                return .appWindow(
                    pid: app.processIdentifier,
                    windowID: windowID
                )
            }
        }

        return nil
    }
}
