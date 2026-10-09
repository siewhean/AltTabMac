import AppKit
import ApplicationServices

/// Observes exact focused-window changes without performing a whole-app AX and
/// workspace catalogue walk on the main thread. Observer registration remains on
/// the main run loop; privacy-minimised descriptor enrichment runs on one serial
/// utility queue and stale retries are coalesced by PID.
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
        instance.scheduleReconcile(pid: pid, attempt: 0, newGeneration: true)
        // Lets the switcher refresh its cached frontmost identity off the main
        // thread so opening it never needs a synchronous AX walk.
        NotificationCenter.default.post(
            name: AppSwitcher.frontmostFocusDidChangeNotification,
            object: nil
        )
    }

    private let history: SwitcherHistoryStore
    private let catalog: AXWindowCatalog
    private let workspace = NSWorkspace.shared
    private let metadataQueue = DispatchQueue(
        label: "CmdTab.FocusedWindowHistoryObserver.Metadata",
        qos: .utility
    )
    private let generationLock = NSLock()

    /// Main-run-loop owned.
    private var observersByPID: [pid_t: AXObserver] = [:]
    private var observations: [(NotificationCenter, NSObjectProtocol)] = []
    private var permissionRetryTimer: Timer?

    /// Accessed only through `generationLock`.
    private var generationByPID: [pid_t: UInt64] = [:]

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
        for observer in observersByPID.values {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .commonModes
            )
        }
        for (center, token) in observations {
            center.removeObserver(token)
        }
    }

    // MARK: Notification and AX registration

    private func installWorkspaceObservers() {
        let workspaceCenter = workspace.notificationCenter
        let activationToken = workspaceCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            self.refreshAccessibilityObservers()
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication {
                self.scheduleReconcile(
                    pid: app.processIdentifier,
                    attempt: 0,
                    newGeneration: true
                )
            }
        }
        observations.append((workspaceCenter, activationToken))

        let launchToken = workspaceCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAccessibilityObservers()
        }
        observations.append((workspaceCenter, launchToken))

        let terminateToken = workspaceCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication {
                self.invalidateReconcile(pid: app.processIdentifier)
            }
            self.refreshAccessibilityObservers()
        }
        observations.append((workspaceCenter, terminateToken))

        let defaultCenter = NotificationCenter.default
        let activeToken = defaultCenter.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAccessibilityObservers()
            self?.startPermissionRetryIfNeeded()
        }
        observations.append((defaultCenter, activeToken))
    }

    private func startPermissionRetryIfNeeded() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.startPermissionRetryIfNeeded()
            }
            return
        }
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

        let applications = workspace.runningApplications.filter {
            $0.activationPolicy == .regular &&
                $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }
        let activePIDs = Set(applications.map(\.processIdentifier))

        for pid in observersByPID.keys.filter({ !activePIDs.contains($0) }) {
            guard let observer = observersByPID.removeValue(forKey: pid) else {
                continue
            }
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .commonModes
            )
            invalidateReconcile(pid: pid)
        }

        guard AXIsProcessTrusted() else {
            removeAllAccessibilityObservers()
            startPermissionRetryIfNeeded()
            return
        }
        permissionRetryTimer?.invalidate()
        permissionRetryTimer = nil

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for app in applications where observersByPID[app.processIdentifier] == nil {
            var observer: AXObserver?
            guard AXObserverCreate(
                app.processIdentifier,
                Self.observerCallback,
                &observer
            ) == .success,
            let observer else {
                continue
            }

            let axApplication = AXUIElementCreateApplication(
                app.processIdentifier
            )
            let notifications = [
                kAXFocusedWindowChangedNotification as CFString,
                kAXMainWindowChangedNotification as CFString,
            ]
            let installed = notifications.reduce(false) {
                installedAny, notification in
                let result = AXObserverAddNotification(
                    observer,
                    axApplication,
                    notification,
                    refcon
                )
                return installedAny || result == .success
            }

            guard installed else { continue }
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
            guard let observer = observersByPID.removeValue(forKey: pid) else {
                continue
            }
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .commonModes
            )
            invalidateReconcile(pid: pid)
        }
    }

    // MARK: Background reconciliation

    private func reconcileFrontmostApplication() {
        guard let app = workspace.frontmostApplication else { return }
        scheduleReconcile(
            pid: app.processIdentifier,
            attempt: 0,
            newGeneration: true
        )
    }

    private func scheduleReconcile(
        pid: pid_t,
        attempt: Int,
        newGeneration: Bool,
        expectedGeneration: UInt64? = nil
    ) {
        let generation: UInt64
        if newGeneration {
            generation = nextGeneration(pid: pid)
        } else if let expectedGeneration {
            generation = expectedGeneration
        } else {
            return
        }

        let delay = attempt == 0 ? 0 : 0.04 * Double(attempt)
        metadataQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self,
                  self.isCurrentGeneration(generation, pid: pid) else {
                return
            }
            self.reconcile(
                pid: pid,
                attempt: attempt,
                generation: generation
            )
        }
    }

    private func reconcile(
        pid: pid_t,
        attempt: Int,
        generation: UInt64
    ) {
        guard AXIsProcessTrusted(),
              let app = NSRunningApplication(processIdentifier: pid),
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier,
              workspace.frontmostApplication?.processIdentifier == pid else {
            return
        }

        if let identity = focusedIdentity(for: app) {
            let snapshot = catalog.snapshot(for: [app])
            guard isCurrentGeneration(generation, pid: pid),
                  workspace.frontmostApplication?.processIdentifier == pid else {
                return
            }

            if let windowID = identity.windowID,
               let metadata = snapshot.metadata(
                   ownerPID: pid,
                   windowID: windowID
               ) {
                let descriptor = LiveWindowHistoryDescriptor(
                    identity: identity,
                    bundleIdentifier: app.bundleIdentifier ?? "app-\(pid)",
                    title: metadata.title.isEmpty
                        ? (app.localizedName ?? "Application")
                        : metadata.title,
                    documentURL: metadata.documentURL,
                    role: metadata.role,
                    subrole: metadata.subrole,
                    bounds: metadata.frame,
                    displayIdentifier: metadata.workspace
                        .primaryWorkspace?
                        .displayIdentifier,
                    workspaceKey: metadata.workspace
                        .primaryWorkspace?
                        .stableKey
                )
                history.noteActivation(identity, descriptor: descriptor)
            } else {
                history.noteActivation(identity)
            }
            return
        }

        guard attempt < 2 else {
            guard isCurrentGeneration(generation, pid: pid),
                  workspace.frontmostApplication?.processIdentifier == pid else {
                return
            }
            history.noteActivation(
                .appFallback(
                    bundleID: app.bundleIdentifier ?? "pid:\(pid)",
                    pid: pid
                )
            )
            return
        }

        scheduleReconcile(
            pid: pid,
            attempt: attempt + 1,
            newGeneration: false,
            expectedGeneration: generation
        )
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
            ) == .success,
            let value else {
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

    // MARK: Generation coalescing

    private func nextGeneration(pid: pid_t) -> UInt64 {
        generationLock.lock()
        let next = (generationByPID[pid] ?? 0) &+ 1
        generationByPID[pid] = next
        generationLock.unlock()
        return next
    }

    private func isCurrentGeneration(
        _ generation: UInt64,
        pid: pid_t
    ) -> Bool {
        generationLock.lock()
        let matches = generationByPID[pid] == generation
        generationLock.unlock()
        return matches
    }

    private func invalidateReconcile(pid: pid_t) {
        _ = nextGeneration(pid: pid)
    }
}