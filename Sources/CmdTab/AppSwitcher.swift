import AppKit
import CoreGraphics
import ApplicationServices
import os.log

// MARK: - AppSwitcher

private let appSwitcherLog = OSLog(subsystem: "CmdTab", category: "AppSwitcher")

/// Retains only live CG IDs from the same process launch generation. Confirmation
/// never transfers to a reused PID, and closed windows leave on the next snapshot.
struct ConfirmedSwitcherWindowIdentities {
    private var generations: [pid_t: Date] = [:]
    private var windows: [pid_t: Set<CGWindowID>] = [:]
    private(set) var minimizedWindows: [pid_t: Set<CGWindowID>] = [:]
    private(set) var inferredHiddenWindows: [pid_t: Set<CGWindowID>] = [:]

    mutating func update(
        generations liveGenerations: [pid_t: Date],
        currentIDs: [pid_t: Set<CGWindowID>],
        approvedIDs: [pid_t: Set<CGWindowID>],
        observedIDs: [pid_t: Set<CGWindowID>] = [:],
        minimizedIDs: [pid_t: Set<CGWindowID>] = [:]
    ) -> [pid_t: Set<CGWindowID>] {
        windows = windows.filter { liveGenerations[$0.key] != nil }
        minimizedWindows = minimizedWindows.filter { liveGenerations[$0.key] != nil }
        inferredHiddenWindows = inferredHiddenWindows.filter { liveGenerations[$0.key] != nil }
        for (pid, generation) in liveGenerations {
            let live = currentIDs[pid] ?? []
            let previous = generations[pid] == generation ? windows[pid, default: []] : []
            let previousMinimized = generations[pid] == generation ? minimizedWindows[pid, default: []] : []
            let previousHidden = generations[pid] == generation ? inferredHiddenWindows[pid, default: []] : []
            inferredHiddenWindows[pid] = Set(previousHidden.intersection(live).sorted().prefix(4096))
            minimizedWindows[pid] = Set(previousMinimized.intersection(live)
                .subtracting(observedIDs[pid, default: []])
                .union(minimizedIDs[pid, default: []].intersection(live)).sorted().prefix(4096))
            // Bound retained state even for unusually large or hostile window lists.
            let confirmed = previous.intersection(live).union(approvedIDs[pid, default: []].intersection(live))
            windows[pid] = Set(confirmed.sorted().prefix(4096))
        }
        generations = liveGenerations
        return windows
    }

    mutating func recordHiddenDecision(
        pid: pid_t, windowID: CGWindowID, isOnScreen: Bool,
        decision: AppSwitcher.WindowMembershipDecision
    ) {
        if decision.isInferredHidden {
            inferredHiddenWindows[pid, default: []].insert(windowID)
        } else if isOnScreen || (decision.isIncluded && decision.isExactAXMatched) {
            inferredHiddenWindows[pid]?.remove(windowID)
        }
    }
}

/// Enumerates real application windows and captures thumbnails for the switcher.
final class AppSwitcher: NSObject {
    private let preferences = SwitcherPreferences.shared
    private let history = SwitcherHistoryStore.shared
    private let privateCapabilities: PrivateWindowCapabilityProviding

    private struct PreviewCacheEntry {
        let image: NSImage
        let backdropImage: NSImage?
        let capturedAt: Date
    }

    // ── Non-blocking cache architecture ──────────────────────────────────────
    // The build queue runs thumbnail capture off the main thread.
    // The cacheLock protects reads/writes to _cachedItems so getItems() never
    // blocks on a pending thumbnail capture — it returns stale data instantly
    // and the UI updates when onItemsChanged fires.
    private let buildQueue = DispatchQueue(label: "CmdTab.AppSwitcher.Build", qos: .userInitiated)
    /// Serial queue for frontmost-window AX walks kept off the main thread.
    private let frontmostQueue = DispatchQueue(label: "CmdTab.AppSwitcher.Frontmost", qos: .userInitiated)
    let frontmostCache = FrontmostIdentityCache()
    /// Serial queue for activation Accessibility IPC (lookups, raises, checks).
    let activationQueue = DispatchQueue(label: "CmdTab.AppSwitcher.Activation", qos: .userInteractive)
    /// The latest switch request; superseded activation chains stop.
    let activationRequests = ActivationRequestLedger()
    private var _cachedItems: [SwitcherItem] = []
    private var previewCache: [String: PreviewCacheEntry] = [:]
    private let cacheLock = NSLock()
    private let confirmedIdentityLock = NSLock()
    private var confirmedWindowIdentities = ConfirmedSwitcherWindowIdentities()
    private var lastRefresh = Date.distantPast
    private var isRefreshing = false
    private var pendingForcedRefresh = false
    private let refreshInterval: TimeInterval = 0.8
    private let maxPreviewCacheEntries = 512
    private let maximumPhaseTwoFallbackAge: TimeInterval = 120.0
    private let activationRetryLimit = 8
    private let pendingActivationTimeout: TimeInterval = 4.0
    private let initialWindowFocusDelay: TimeInterval = 0.08
    private let observedActivationRetryLimit = 3
    private let observedActivationRetryDelay: TimeInterval = 0.05

    var onItemsChanged: (([SwitcherItem]) -> Void)?
    var onActivationConfirmed: ((SwitcherHistoryIdentity, pid_t) -> Void)?
    private var pendingActivationPIDs = Set<pid_t>()

    override init() {
        privateCapabilities = SystemPrivateWindowCapabilityProvider.shared
        super.init()
        configure()
    }

    init(observeWorkspace: Bool) {
        privateCapabilities = SystemPrivateWindowCapabilityProvider.shared
        super.init()
        if observeWorkspace { configure() }
    }

    /// Test-only and integration injection point for private capability state.
    /// Production callers use the default initializer above.
    init(privateCapabilities: PrivateWindowCapabilityProviding) {
        self.privateCapabilities = privateCapabilities
        super.init()
        configure()
    }

    private func configure() {
        PrivateWindowCapabilityDiagnostics.shared.update(from: privateCapabilities)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(workspaceChanged),
            name: NSWorkspace.didLaunchApplicationNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(workspaceChanged),
            name: NSWorkspace.didTerminateApplicationNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(preferencesChanged),
            name: SwitcherPreferences.didChangeNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(frontmostFocusChanged),
            name: Self.frontmostFocusDidChangeNotification, object: nil
        )
        refreshFrontmostIdentityInBackground()

        // Warm cache asynchronously. Do NOT wait — getItems() will return whatever
        // is currently cached (empty on first call, but refreshCacheIfNeeded will
        // populate it from onItemsChanged callbacks).
        warmCache(force: true)
    }

    @objc private func appActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }

        if pendingActivationPIDs.contains(app.processIdentifier) {
            warmCache(force: true)
            return
        }

        noteObservedActivation(for: app)
        refreshFrontmostIdentityInBackground()
        warmCache(force: true)
    }

    @objc private func frontmostFocusChanged() { refreshFrontmostIdentityInBackground() }

    @objc private func workspaceChanged() {
        refreshFrontmostIdentityInBackground()
        warmCache(force: true)
    }
    @objc private func preferencesChanged() { warmCache(force: true) }

    private func noteObservedActivation(for app: NSRunningApplication, attempt: Int = 0) {
        let delay = observedActivationRetryDelay * Double(attempt + 1)
        let pid = app.processIdentifier
        let fallbackIdentity = SwitcherHistoryIdentity.appFallback(
            bundleID: sourceAppIdentifier(for: app),
            pid: pid
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard let frontmost = NSWorkspace.shared.frontmostApplication,
                  frontmost.processIdentifier == pid,
                  frontmost.activationPolicy == .regular,
                  frontmost.bundleIdentifier != Bundle.main.bundleIdentifier else {
                return
            }

            // The AX walk runs off the main thread; history is thread-safe.
            self.frontmostQueue.async { [weak self] in
                guard let self else { return }
                let identity = self.currentFrontmostIdentity(for: frontmost) ?? fallbackIdentity
                self.history.noteActivation(identity)

                if case .appFallback = identity, attempt < self.observedActivationRetryLimit {
                    DispatchQueue.main.async { [weak self] in
                        self?.noteObservedActivation(for: frontmost, attempt: attempt + 1)
                    }
                }
            }
        }
    }

    /// Non-blocking. Returns cached items immediately — never waits for a
    /// pending thumbnail capture. Kicks off a background refresh if stale.
    func getItems() -> [SwitcherItem] {
        // Return cached items immediately without waiting.
        // Trigger a background refresh if stale.
        let cached = cachedItemsSnapshot()
        if cached.isEmpty {
            return primeCacheIfNeeded()
        }

        if shouldRefresh() {
            warmCache(force: false)
        }
        return cached
    }

    /// Read a published snapshot without scheduling capture. Use this from
    /// publication callbacks so slow AX enrichment cannot create a refresh loop.
    func getCachedItems() -> [SwitcherItem] {
        cachedItemsSnapshot()
    }

    @discardableResult
    func performQuickAction(_ action: SwitcherQuickAction, on item: SwitcherItem) -> Bool {
        let execution = action.execution(for: item.kind)
        let didDispatch: Bool

        switch execution {
        case .hideApp:
            guard let app = application(for: item) else { return false }
            app.hide()
            didDispatch = true

        case .minimizeWindow:
            guard let window = windowElement(for: item) else { return false }
            didDispatch = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue) == .success

        case .closeWindow:
            guard let window = windowElement(for: item) else { return false }
            var closeButtonValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &closeButtonValue) == .success,
                  let closeButton = closeButtonValue else {
                return false
            }
            let closeElement = unsafeBitCast(closeButton, to: AXUIElement.self)
            didDispatch = AXUIElementPerformAction(closeElement, kAXPressAction as CFString) == .success

        case .terminateApplication:
            guard let app = application(for: item) else { return false }
            didDispatch = app.terminate()
        }

        if didDispatch {
            warmCache(force: true)
        }
        return didDispatch
    }

    /// Populate a fast provisional cache synchronously when the app is first
    /// invoked and the background builder has not produced anything yet.
    /// This keeps the first Alt-Tab reveal from stalling on the empty-cache path.
    @discardableResult
    func primeCacheIfNeeded() -> [SwitcherItem] {
        let existing = cachedItemsSnapshot()
        guard existing.isEmpty else { return existing }

        let context = enumerateWindows()
        let provisionalItems = assembleItems(
            from: context,
            capturePreviews: false,
            previewFallbacks: cachedPreviewSnapshot(),
            allowPreviewlessItems: true
        )

        cacheLock.lock()
        if _cachedItems.isEmpty {
            _cachedItems = provisionalItems
        }
        let snapshot = _cachedItems
        cacheLock.unlock()

        if !snapshot.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.onItemsChanged?(snapshot)
            }
            warmCache(force: true)
        }

        return snapshot
    }

    private func shouldRefresh() -> Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return Date().timeIntervalSince(lastRefresh) > refreshInterval
    }

    func warmCache(force: Bool = false) {
        buildQueue.async { [weak self] in
            self?.refreshCacheIfNeeded(force: force)
        }
    }

    /// Publish a recovered exact-window frame from the continuity store without
    /// starting another whole-desktop capture pass. The recovery notification is
    /// emitted after a ScreenCaptureKit request; forcing Phase 2 here made every
    /// recovered frame recapture every window and could sustain high idle CPU.
    func publishRecoveredPreview(windowID: CGWindowID) {
        buildQueue.async { [weak self] in
            guard let self else { return }
            self.cacheLock.lock()
            let current = self._cachedItems
            self.cacheLock.unlock()
            guard current.contains(where: { $0.windowID == windowID }) else { return }
            let updated = Self.itemsPublishingRecoveredPreview(current, windowID: windowID)
            self.cacheLock.lock()
            self._cachedItems = updated
            self.cacheLock.unlock()
            DispatchQueue.main.async { [weak self] in
                self?.onItemsChanged?(updated)
            }
        }
    }

    static func itemsPublishingRecoveredPreview(
        _ items: [SwitcherItem], windowID: CGWindowID
    ) -> [SwitcherItem] {
        items.map { item in
            guard item.windowID == windowID else { return item }
            return SwitcherPreviewResolver.item(
                title: item.title,
                subtitle: item.subtitle,
                icon: item.icon,
                previewImage: item.previewImage,
                previewCaptureIsFresh: false,
                previewCapturedAt: item.previewCapturedAt,
                allowsPreviewRecovery: false,
                backdropImage: item.backdropImage,
                backdropFrame: item.backdropFrame,
                backdropSourceScreenFrame: item.backdropSourceScreenFrame,
                previewCacheKey: item.previewCacheKey,
                historyIdentity: item.historyIdentity,
                sourceAppIdentifier: item.sourceAppIdentifier,
                kind: item.kind,
                dedupeKey: item.dedupeKey,
                isMinimized: item.isMinimized,
                isFullscreen: item.isFullscreen,
                workspaceSnapshot: item.workspaceSnapshot,
                historyDescriptor: item.historyDescriptor,
                activate: item.activate
            )
        }
    }

    private func cachedItemsSnapshot() -> [SwitcherItem] {
        cacheLock.lock()
        let items = _cachedItems
        cacheLock.unlock()
        return items
    }

    private func cachedPreviewSnapshot() -> [String: PreviewCacheEntry] {
        cacheLock.lock()
        let snapshot = previewCache
        cacheLock.unlock()
        return snapshot
    }

    static let frontmostFocusDidChangeNotification = Notification.Name(
        "CmdTab.AppSwitcher.frontmostFocusDidChange"
    )

    /// Identity of the frontmost window. Opening the switcher calls this
    /// several times; the answer comes from a cache refreshed off the main
    /// thread on every activation and focus change, because computing it walks
    /// the frontmost app over synchronous Accessibility IPC. The cache is used
    /// only when it is for the current frontmost process and no newer focus
    /// event is still being processed; otherwise the exact synchronous lookup
    /// runs, so a stale identity can never mark the wrong window as current.
    func currentFrontmostIdentity() -> SwitcherHistoryIdentity? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        if let cached = frontmostCache.validIdentity(for: app.processIdentifier) {
            return cached.identity
        }
        return currentFrontmostIdentity(for: app)
    }

    /// Recomputes the frontmost identity on a background queue.
    func refreshFrontmostIdentityInBackground() {
        let generation = frontmostCache.beginRefresh()
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        frontmostQueue.async { [weak self] in
            guard let self else { return }
            let identity = self.currentFrontmostIdentity(for: app)
            self.frontmostCache.finishRefresh(
                generation: generation,
                pid: app.processIdentifier,
                identity: identity
            )
        }
    }

    @discardableResult
    func reconcileCurrentFrontmostHistory() -> SwitcherHistoryIdentity? {
        guard let identity = currentFrontmostIdentity() else { return nil }
        history.noteActivation(identity)
        return identity
    }

    // MARK: - Two-phase cache build
    //
    // Phase 1 (fast): Enumerate windows via CGWindowListCopyWindowInfo,
    //   reuse any previously captured thumbnails, cache immediately, and notify
    //   the UI so the panel can appear instantly without flashing back to icons.
    // Phase 2 (slow): Capture window thumbnails via CGWindowListCreateImage
    //   on this background queue, rebuild items with real previews, cache
    //   again, and notify the UI to swap icons for thumbnails.

    private func refreshCacheIfNeeded(force: Bool) {
        cacheLock.lock()
        let isStale = Date().timeIntervalSince(lastRefresh) > refreshInterval
        guard force || isStale else {
            cacheLock.unlock()
            return
        }
        if isRefreshing {
            if force {
                pendingForcedRefresh = true
            }
            cacheLock.unlock()
            return
        }
        isRefreshing = true
        cacheLock.unlock()

        // ── Phase 1: Reuse cached previews immediately ──────────────────────
        let context = enumerateWindows()
        let preservedPreviews = cachedPreviewSnapshot()
        let shouldAllowPreviewlessItems = cachedItemsSnapshot().isEmpty
        let provisionalItems = assembleItems(
            from: context,
            capturePreviews: false,
            previewFallbacks: preservedPreviews,
            allowPreviewlessItems: shouldAllowPreviewlessItems
        )

        cacheLock.lock()
        _cachedItems = provisionalItems
        cacheLock.unlock()

        // Notify UI immediately — existing thumbnails stay in place while the
        // fresh capture pass updates anything new or changed. Once the cache is
        // warm, previewless windows are held back from this provisional pass so
        // the grid does not regress to large icon-only tiles.
        DispatchQueue.main.async { [weak self] in
            self?.onItemsChanged?(provisionalItems)
        }

        // ── Phase 2: Thumbnail pass (slow) ─────────────────────────────────
        // Schedule Phase 2 as a separate, independent work item so Phase 1
        // notification to the UI is not delayed by thumbnail capture.
        buildQueue.async { [weak self] in
            guard let self else { return }

            if #available(macOS 10.15, *) {
                if !CGPreflightScreenCaptureAccess() {
                    os_log(.error, log: appSwitcherLog,
                           "Screen Recording permission not granted — thumbnails will be unavailable. Grant access in System Settings > Privacy & Security > Screen Recording.")
                }
            }

            let phase2Start = Date()
            let fullItems = self.assembleItems(
                from: context,
                capturePreviews: true,
                previewFallbacks: preservedPreviews
            )
            let phase2Duration = Date().timeIntervalSince(phase2Start)
            var metrics = SnapshotDiagnosticsTracker.shared.snapshot()
            metrics.phase2Duration = phase2Duration
            SnapshotDiagnosticsTracker.shared.record(metrics)

            self.cacheLock.lock()
            self._cachedItems = fullItems
            self.updatePreviewCacheLocked(with: fullItems)
            self.lastRefresh = Date()
            self.isRefreshing = false
            let shouldReplay = self.pendingForcedRefresh
            self.pendingForcedRefresh = false
            self.cacheLock.unlock()

            // Notify UI again — thumbnails now available.
            DispatchQueue.main.async { [weak self] in
                self?.onItemsChanged?(fullItems)
            }

            if shouldReplay {
                self.buildQueue.async { [weak self] in
                    self?.refreshCacheIfNeeded(force: true)
                }
            }
        }
    }

    // MARK: - Build helpers

    /// Shared context from the fast window-enumeration pass, reused by both
    /// the icon-only and thumbnail assembly phases.
    private struct BuildContext {
        let candidates: [WindowCandidate]
        let runningApps: [NSRunningApplication]
        let membershipMetrics: SnapshotDiagnosticMetrics
        let axIdentityFailures: Int
        let phase1Duration: TimeInterval
    }

    /// Phase 1 core: enumerate windows, filter, sort, limit — no preview I/O.
    private func enumerateWindows() -> BuildContext {
        let phase1Start = Date()
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { ApplicationEligibilityPolicy.isEligibleApplication($0) }

        let appsByPID: [pid_t: NSRunningApplication] = Dictionary(
            runningApps.map { ($0.processIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let (axInspections, axFailures) = inspectAXWindowsByPID(for: runningApps)
        let historyEntries = history.snapshot()

        let allWindows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var currentIDs: [pid_t: Set<CGWindowID>] = [:]
        for row in allWindows {
            if let pid = (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
               let id = (row[kCGWindowNumber as String] as? NSNumber)?.uint32Value {
                currentIDs[pid, default: []].insert(id)
            }
        }
        let generations = Dictionary(uniqueKeysWithValues: runningApps.compactMap { app in
            app.launchDate.map { (app.processIdentifier, $0) }
        })
        confirmedIdentityLock.lock()
        let confirmedIDs = confirmedWindowIdentities.update(
            generations: generations,
            currentIDs: currentIDs,
            approvedIDs: axInspections.mapValues { $0.isTrusted ? $0.approvedIDs : [] },
            observedIDs: axInspections.mapValues { $0.isTrusted ? Set($0.elementsByID.keys) : [] },
            minimizedIDs: axInspections.mapValues { $0.isTrusted ? $0.minimizedIDs : [] }
        )
        let previouslyMinimizedIDs = confirmedWindowIdentities.minimizedWindows
        let previouslyHiddenIDs = confirmedWindowIdentities.inferredHiddenWindows
        confirmedIdentityLock.unlock()
        var membershipMetrics = SnapshotMembershipMetricsBuilder(
            cgWindowsEnumerated: allWindows.count
        )

        var rawCandidates: [WindowCandidate] = []
        var candidateInspections = axInspections
        let rowsByPID = Dictionary(grouping: allWindows.enumerated()) { row in
            (row.element[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? -1
        }
        for app in runningApps {
            let pid = app.processIdentifier
            guard let rows = rowsByPID[pid], !rows.isEmpty,
                  let inspection = candidateInspections[pid] else { continue }
            // Classify this process contiguously so another slow application
            // cannot age its evidence between its first surface and its helper.
            candidateInspections[pid] = Self.freshInspectionForCandidates(inspection) {
                self.inspectAXWindows(for: app)
            }
            for (index, info) in rows {
                if let candidate = makeCandidate(
                    from: info,
                    orderIndex: index,
                    appsByPID: appsByPID,
                    axInspectionsByPID: candidateInspections,
                    previouslyConfirmedIDsByPID: confirmedIDs,
                    previouslyMinimizedIDsByPID: previouslyMinimizedIDs,
                    previouslyHiddenIDsByPID: previouslyHiddenIDs,
                    membershipObserver: { decision in
                        membershipMetrics.recordCGCandidate(
                            exactAXMatched: decision.isExactAXMatched,
                            positivelyRejected: decision.isPositivelyRejected,
                            unknownAXIdentity: decision.isUnknownIdentity
                        )
                    }
                ) {
                    rawCandidates.append(candidate)
                }
            }

        }
        // Bind the existing AX identity evidence before phase-two capture can
        // create a saved frame. This reuses discovery, not another AX walk.
        let trustedInspections = candidateInspections.filter { $0.value.isTrusted }
        let knownLiveWindowIDsByPID = Dictionary(grouping: rawCandidates, by: \.ownerPID)
            .mapValues { Set($0.map(\.id)) }
        SwitcherPreviewContinuityStore.observeIdentitySnapshot(
            generations: generations,
            elements: trustedInspections.mapValues(\.elementsByID),
            completePIDs: Set(trustedInspections.compactMap { pid, inspection in
                inspection.enumerationComplete && inspection.identityFailures == 0 ? pid : nil
            }),
            minimizedIDs: trustedInspections.mapValues(\.minimizedIDs),
            observedAtByPID: trustedInspections.mapValues(\.observedAt),
            knownLiveWindowIDsByPID: knownLiveWindowIDsByPID
        )
        rawCandidates.sort { $0.orderIndex < $1.orderIndex }
        let candidates = deduplicatedCandidates(from: rawCandidates).sorted {
            compareCandidates($0, $1, historyEntries: historyEntries)
        }

        let scopedCandidates = visibilityScopedCandidates(candidates)
        let duration = Date().timeIntervalSince(phase1Start)

        return BuildContext(
            candidates: limitedByApp(scopedCandidates),
            runningApps: runningApps,
            membershipMetrics: membershipMetrics.metrics,
            axIdentityFailures: axFailures,
            phase1Duration: duration
        )
    }

    /// Create SwitcherItem arrays from a BuildContext. When `capturePreviews`
    /// is false, previously captured thumbnails are reused. When true, each
    /// window candidate attempts a fresh capture and falls back to the cached
    /// preview if capture fails.
    private func assembleItems(
        from context: BuildContext,
        capturePreviews: Bool,
        previewFallbacks: [String: PreviewCacheEntry],
        allowPreviewlessItems: Bool = false
    ) -> [SwitcherItem] {
        let windowItems: [SwitcherItem] = context.candidates.compactMap { candidate -> SwitcherItem? in
            let previewKey = candidate.previewCacheKey
            let preview: NSImage?
            let backdrop: NSImage?
            let previewCaptureIsFresh: Bool
            if capturePreviews {
                let assets = capturePreviewAssets(for: candidate)
                previewCaptureIsFresh = assets != nil
                preview = assets?.thumbnail ?? reusablePhaseTwoFallback(from: previewFallbacks[previewKey])
                backdrop = assets?.backdrop ?? previewFallbacks[previewKey]?.backdropImage ?? preview
            } else {
                previewCaptureIsFresh = false
                preview = previewFallbacks[previewKey]?.image
                backdrop = previewFallbacks[previewKey]?.backdropImage ?? preview
            }

            guard Self.shouldDisplayWindowItem(
                previewImage: preview,
                capturePreviews: capturePreviews,
                allowPreviewlessItems: allowPreviewlessItems
            ) else {
                return nil
            }

            return SwitcherPreviewResolver.item(
                title: candidate.windowTitle,
                subtitle: candidate.appName,
                icon: candidate.appIcon,
                previewImage: preview,
                previewCaptureIsFresh: previewCaptureIsFresh,
                allowsPreviewRecovery: capturePreviews,
                backdropImage: backdrop,
                backdropFrame: candidate.bounds,
                backdropSourceScreenFrame: candidate.screenFrame,
                previewCacheKey: previewKey,
                historyIdentity: candidate.historyIdentity,
                sourceAppIdentifier: candidate.sourceAppIdentifier,
                kind: .appWindow,
                isFullscreen: candidate.isFullscreen
                ) { [weak self] in
                    self?.activateWindow(candidate)
                }
            }

        // Membership is based on emitted items, never raw candidates. A
        // failed screenshot therefore cannot suppress both the window tile and
        // its application fallback.
        let representedWindowPIDs = Set(windowItems.compactMap(\.historyIdentity.ownerPID))
        var seenFallbackPIDs = Set<pid_t>()
        let fallbackHistoryEntries = history.snapshot()

        let fallbackItems: [SwitcherItem] = context.runningApps
            .sorted {
                compareApps($0, $1, historyEntries: fallbackHistoryEntries)
            }
            .compactMap { app in
                guard Self.shouldIncludeFallbackApp(
                    processIdentifier: app.processIdentifier,
                    representedWindowPIDs: representedWindowPIDs,
                    seenFallbackPIDs: &seenFallbackPIDs
                ) else {
                    return nil
                }

                return makeFallbackItem(for: app)
            }

        let resultItems = windowItems + fallbackItems

        var metricsBuilder = SnapshotMembershipMetricsBuilder(metrics: context.membershipMetrics)
        for item in windowItems {
            metricsBuilder.recordPublishedWindow(previewAvailable: item.previewImage != nil)
        }
        for _ in fallbackItems {
            metricsBuilder.recordPublishedFallback()
        }
        let representedPIDs = Set(windowItems.compactMap(\.historyIdentity.ownerPID) + fallbackItems.compactMap(\.historyIdentity.ownerPID))
        let metrics = metricsBuilder.finish(
            regularApplicationsDetected: context.runningApps.count,
            processesRepresented: representedPIDs.count,
            axIdentityFailures: context.axIdentityFailures,
            phase1Duration: context.phase1Duration
        )
        SnapshotDiagnosticsTracker.shared.record(metrics)

        return resultItems
    }

    private func reusablePhaseTwoFallback(from entry: PreviewCacheEntry?) -> NSImage? {
        guard let entry else { return nil }
        guard Date().timeIntervalSince(entry.capturedAt) <= maximumPhaseTwoFallbackAge else { return nil }
        return entry.image
    }

    /// Shared by base enumeration and post-scope enrichment so fallback activation
    /// keeps the same confirmation and history behavior in both paths.
    func makeFallbackItem(for app: NSRunningApplication) -> SwitcherItem? {
        let identifier = sourceAppIdentifier(for: app)
        let appName = app.localizedName ?? "Application"
        guard !preferences.excludesApp(identifier: identifier, appName: appName) else { return nil }
        let identity = SwitcherHistoryIdentity.appFallback(bundleID: identifier, pid: app.processIdentifier)
        return SwitcherItem(
            title: appName,
            subtitle: "",
            icon: app.icon,
            previewImage: nil,
            historyIdentity: identity,
            sourceAppIdentifier: identifier,
            kind: .appFallback
        ) { [weak self] in
            self?.activateFallbackApplication(app, identity: identity)
        }
    }

    static func shouldIncludeFallbackApp(
        processIdentifier: pid_t,
        representedWindowPIDs: Set<pid_t>,
        seenFallbackPIDs: inout Set<pid_t>
    ) -> Bool {
        // A regular running process without an emitted window gets one fallback.
        // Bundle-level deduplication is incorrect because two independent regular
        // processes may legitimately share a bundle identifier.
        guard !representedWindowPIDs.contains(processIdentifier) else { return false }
        return seenFallbackPIDs.insert(processIdentifier).inserted
    }

    static func shouldDisplayWindowItem(
        previewImage: NSImage?,
        capturePreviews: Bool,
        allowPreviewlessItems: Bool = false
    ) -> Bool {
        // An eligible window remains a switcher item even when Screen Recording
        // is denied, a private capture API is unavailable, or a cached preview
        // expires. The UI already renders a safe icon/placeholder state.
        _ = previewImage
        _ = capturePreviews
        _ = allowPreviewlessItems
        return true
    }

    private func updatePreviewCacheLocked(with items: [SwitcherItem]) {
        for item in items {
            guard item.previewCaptureIsFresh else { continue }
            guard let preview = item.previewImage ?? item.backdropImage else { continue }
            previewCache[item.previewCacheKey] = PreviewCacheEntry(
                image: item.previewImage ?? preview,
                backdropImage: item.backdropImage,
                capturedAt: Date()
            )
        }

        guard previewCache.count > maxPreviewCacheEntries else { return }

        let activeKeys = Set(items.map(\.previewCacheKey))
        previewCache = previewCache.filter { activeKeys.contains($0.key) }

        if previewCache.count > maxPreviewCacheEntries {
            let overflow = previewCache.count - maxPreviewCacheEntries
            let oldestKeys = previewCache
                .sorted { $0.value.capturedAt < $1.value.capturedAt }
                .prefix(overflow)
                .map(\.key)
            for key in oldestKeys {
                previewCache.removeValue(forKey: key)
            }
        }
    }

    /// Keep at most N windows per application. 0 = unlimited.
    private func limitedByApp(_ candidates: [WindowCandidate]) -> [WindowCandidate] {
        let limit = preferences.maxWindowsPerApp
        guard limit > 0 else { return candidates }

        var countByApp: [String: Int] = [:]
        return candidates.filter { candidate in
            let key = candidate.sourceAppIdentifier
            let current = countByApp[key, default: 0]
            guard current < limit else { return false }
            countByApp[key] = current + 1
            return true
        }
    }

    private func visibilityScopedCandidates(_ candidates: [WindowCandidate]) -> [WindowCandidate] {
        switch preferences.windowVisibilityScope {
        case .allSpaces:
            return candidates

        case .visibleSpaces:
            return candidates.filter(\.isOnScreen)

        case .currentSpaceOnly:
            let onScreenCandidates = candidates.filter(\.isOnScreen)
            guard let activeScreenFrame = activeScreenFrame(for: onScreenCandidates) else {
                return onScreenCandidates
            }
            return onScreenCandidates.filter { $0.bounds.intersects(activeScreenFrame) }
        }
    }

    private func activeScreenFrame(for candidates: [WindowCandidate]) -> CGRect? {
        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           frontmostApp.activationPolicy == .regular,
           frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            let focusedWindowID = focusedWindowID(for: frontmostApp.processIdentifier)
            if let focusedWindowID,
               let focusedCandidate = candidates.first(where: {
                   $0.ownerPID == frontmostApp.processIdentifier && $0.id == focusedWindowID
               }) {
                return screenFrame(containing: focusedCandidate.bounds)
            }

            if let appCandidate = candidates.first(where: { $0.ownerPID == frontmostApp.processIdentifier }) {
                return screenFrame(containing: appCandidate.bounds)
            }
        }

        return screenFrame(
            containing: CGRect(origin: DisplayGeometry.mouseLocationInCG(), size: .zero)
        )
    }

    /// Window bounds are CG global coordinates, so match them against CG
    /// display bounds (not AppKit `NSScreen` frames) and return CG bounds.
    private func screenFrame(containing rect: CGRect) -> CGRect? {
        DisplayGeometry.screenFrame(
            containing: rect,
            displayBounds: DisplayGeometry.activeDisplayBounds()
        )
    }

    // MARK: - Identity helpers

    private func currentFrontmostIdentity(for app: NSRunningApplication) -> SwitcherHistoryIdentity? {
        // Core Graphics remains the authority for membership here just as it is
        // for the main switcher snapshot.  AX can positively reject a mapped
        // ineligible surface, but an omitted or unmapped AX window must not
        // hide a frontmost Core Graphics candidate.
        let axInspectionsByPID = [app.processIdentifier: inspectAXWindows(for: app)]
        let historyEntries = history.snapshot()
        let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates = deduplicatedCandidates(
            from: windows.enumerated().compactMap { index, info in
                makeCandidate(
                    from: info,
                    orderIndex: index,
                    includeBackgroundWindows: true,
                    restrictToPID: app.processIdentifier,
                    axInspectionsByPID: axInspectionsByPID
                )
            }
        ).sorted {
            compareCandidates($0, $1, historyEntries: historyEntries)
        }

        if let focusedWindowID = focusedWindowID(for: app.processIdentifier) {
            if let focusedCandidate = candidates.first(where: { $0.id == focusedWindowID }) {
                return focusedCandidate.historyIdentity
            }
            // The focused AX surface did not survive the same positive-only
            // membership evaluation used by the snapshot.  Do not create an
            // exact-window MRU entry for a positively rejected or otherwise
            // ineligible surface; retain only the truthful app fallback.
            if let bundleID = app.bundleIdentifier {
                return .appFallback(bundleID: bundleID, pid: app.processIdentifier)
            }
            return nil
        }

        if candidates.count == 1, let candidate = candidates.first {
            return candidate.historyIdentity
        }
        if let bundleID = app.bundleIdentifier {
            return .appFallback(bundleID: bundleID, pid: app.processIdentifier)
        }
        return nil
    }

    // MARK: - Sorting

    private func compareCandidates(
        _ lhs: WindowCandidate,
        _ rhs: WindowCandidate,
        historyEntries: [SwitcherHistoryIdentity]
    ) -> Bool {
        let lhsRank = historyEntries.firstIndex(of: lhs.historyIdentity)
        let rhsRank = historyEntries.firstIndex(of: rhs.historyIdentity)

        switch (lhsRank, rhsRank) {
        case let (.some(l), .some(r)) where l != r: return l < r
        case (.some, .none): return true
        case (.none, .some): return false
        default: break
        }

        return lhs.orderIndex < rhs.orderIndex
    }

    private func compareApps(
        _ lhs: NSRunningApplication,
        _ rhs: NSRunningApplication,
        historyEntries: [SwitcherHistoryIdentity]
    ) -> Bool {
        func rank(for app: NSRunningApplication) -> Int {
            let identity = SwitcherHistoryIdentity.appFallback(
                bundleID: sourceAppIdentifier(for: app),
                pid: app.processIdentifier
            )
            return historyEntries.firstIndex(of: identity)
                ?? historyEntries.firstIndex {
                    $0.matches(
                        bundleID: app.bundleIdentifier,
                        pid: app.processIdentifier
                    )
                }
                ?? Int.max
        }

        let lhsRank = rank(for: lhs)
        let rhsRank = rank(for: rhs)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        return (lhs.localizedName ?? "") < (rhs.localizedName ?? "")
    }

    // MARK: - Window activation

    private func activateFallbackApplication(_ app: NSRunningApplication, identity: SwitcherHistoryIdentity) {
        let token = activationRequests.begin(pid: app.processIdentifier)
        ActivationOutcomeTracker.shared.recordRequested()
        markPendingActivation(app.processIdentifier)
        schedulePendingActivationTimeout(for: app.processIdentifier, token: token)
        activateApplication(app, activateAllWindows: true)

        // Window lookup and raise are Accessibility IPC: keep them off main.
        activationQueue.async { [weak self] in
            guard let self, self.activationRequests.isCurrent(token) else { return }
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            let preferredWindows = [
                self.preferredWindow(for: axApp, attribute: kAXFocusedWindowAttribute as CFString),
                self.preferredWindow(for: axApp, attribute: kAXMainWindowAttribute as CFString),
            ].compactMap { $0 }

            var needsReopen = false
            if let preferred = preferredWindows.first(where: { self.isStandardWindow($0) }) {
                _ = self.raiseWindow(preferred, ownerPID: app.processIdentifier)
            } else {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
                   let windows = value as? [AXUIElement],
                   let target = windows.first(where: { self.isStandardWindow($0) }) ?? windows.first {
                    _ = self.raiseWindow(target, ownerPID: app.processIdentifier)
                } else {
                    needsReopen = true
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.continuesActivation(token) else { return }
                if needsReopen { self.reopenApplication(app) }
                self.ensureApplicationFrontmost(app, identity: identity, attempt: 0, token: token)
            }
        }
        // warmCache intentionally omitted: the NSWorkspace.didActivateApplication
        // notification fires after app.activate() and already calls warmCache(force: true)
        // via appActivated(_:). Calling it here too queues a redundant rebuild that
        // races with the AX focus operations above, adding perceived latency.
    }

    /// An app with no open windows (for example Calendar or Spotify after their
    /// window is closed) shows nothing when merely activated. Opening a running
    /// app sends it the same reopen event as a Dock click, so it shows its main
    /// window instead of leaving the user on an empty desktop.
    private func reopenApplication(_ app: NSRunningApplication) {
        guard let bundleURL = app.bundleURL else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, error in
            guard let error else { return }
            os_log(.error, log: appSwitcherLog, "Reopening a windowless application failed: %{public}@",
                   (error as NSError).domain)
        }
    }

    private func activateWindow(_ candidate: WindowCandidate) {
        let token = activationRequests.begin(pid: candidate.ownerPID)
        ActivationOutcomeTracker.shared.recordRequested()
        guard let app = NSRunningApplication(processIdentifier: candidate.ownerPID) else {
            ActivationOutcomeTracker.shared.record(.targetDisappeared)
            return
        }
        markPendingActivation(candidate.ownerPID)
        schedulePendingActivationTimeout(for: candidate.ownerPID, token: token)

        // An unavailable identity or focus bridge must never be treated as an
        // exact selection.  Public application activation still preserves a
        // usable switcher, but it is explicitly an unverified app fallback and
        // cannot advance exact-window MRU.
        guard exactFocusCapabilityAvailable else {
            activateApplication(app, activateAllWindows: true)
            ensureApplicationFrontmost(app, identity: candidate.historyIdentity, attempt: 0, token: token)
            return
        }

        guard case .success = privateCapabilities.focusWindow(
            ownerPID: candidate.ownerPID,
            windowID: candidate.id
        ) else {
            activateApplication(app, activateAllWindows: true)
            ensureApplicationFrontmost(app, identity: candidate.historyIdentity, attempt: 0, token: token)
            return
        }
        // Activating every sibling can return macOS to the app's desktop Space
        // after the selected fullscreen window was brought forward.
        activateApplication(app, activateAllWindows: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + initialWindowFocusDelay) { [weak self] in
            self?.focusBestMatchingWindow(candidate, attempt: 0, token: token)
        }
        // warmCache intentionally omitted: NSWorkspace.didActivateApplication fires
        // after activate() and already triggers warmCache via appActivated(_:).
        // A second rebuild here races with the AX retry chain, doubling the work
        // and adding measurable latency to the switch.
    }

    // MARK: - Window focus (exact CGWindowID only)
    //
    // The chain runs for up to a few seconds. NSRunningApplication activation,
    // retry scheduling, pending state, and history stay on the main thread;
    // Accessibility reads and raises run on `activationQueue`. Every step
    // checks its request token so a newer switch cancels this chain.

    private enum WindowRaiseResult {
        case windowsUnavailable, exactWindowNotFound, raised, raiseFailed
    }

    /// Main thread. Returns true while `token` is the latest request. A
    /// superseded chain stops, releasing its pending state only when the newer
    /// request targets a different process (which still owns it otherwise).
    private func continuesActivation(_ token: ActivationRequestLedger.Token) -> Bool {
        guard activationRequests.isCurrent(token) else {
            if activationRequests.currentPID != token.pid {
                pendingActivationPIDs.remove(token.pid)
            }
            return false
        }
        return true
    }

    private func focusBestMatchingWindow(
        _ candidate: WindowCandidate, attempt: Int, token: ActivationRequestLedger.Token
    ) {
        guard continuesActivation(token) else { return }
        activationQueue.async { [weak self] in
            guard let self, self.activationRequests.isCurrent(token) else { return }
            let result = self.raiseExactWindow(candidate)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.continuesActivation(token) else { return }
                switch result {
                case .windowsUnavailable, .exactWindowNotFound:
                    // Do not raise a same-PID sibling based on title/frame
                    // heuristics. Retrying lets a temporarily stale AX bridge
                    // resolve; terminal handling records a non-exact outcome.
                    self.scheduleWindowFocusRetry(for: candidate, attempt: attempt, token: token)
                case .raiseFailed:
                    guard let app = NSRunningApplication(processIdentifier: candidate.ownerPID) else {
                        self.scheduleWindowFocusRetry(for: candidate, attempt: attempt, token: token)
                        return
                    }
                    self.ensureApplicationFrontmost(
                        app, identity: candidate.historyIdentity, attempt: attempt, token: token
                    )
                case .raised:
                    self.ensureWindowFrontmost(candidate, attempt: attempt, token: token)
                }
            }
        }
    }

    /// Activation queue. The Accessibility half of one focus attempt.
    private func raiseExactWindow(_ candidate: WindowCandidate) -> WindowRaiseResult {
        let axApp = AXUIElementCreateApplication(candidate.ownerPID)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement], !windows.isEmpty else {
            return .windowsUnavailable
        }
        let mappedWindowIDs = windows.map { resolvedWindowID(for: $0) }
        guard let exactIndex = ExactWindowActivationPolicy.selectedWindowIndex(
            selectedWindowID: candidate.id,
            mappedWindowIDs: mappedWindowIDs
        ) else {
            return .exactWindowNotFound
        }
        return raiseWindow(windows[exactIndex], ownerPID: candidate.ownerPID) ? .raised : .raiseFailed
    }

    private func raiseWindow(_ axWindow: AXUIElement, ownerPID: pid_t) -> Bool {
        let t = kCFBooleanTrue!
        let axApp = AXUIElementCreateApplication(ownerPID)
        guard let axWindowID = resolvedWindowID(for: axWindow),
              case .success = privateCapabilities.focusWindow(ownerPID: ownerPID, windowID: axWindowID) else {
            return false
        }
        AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, t)
        AXUIElementSetAttributeValue(axApp, kAXMainWindowAttribute as CFString, axWindow)
        AXUIElementSetAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, axWindow)
        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, t)
        AXUIElementSetAttributeValue(axWindow, kAXFocusedAttribute as CFString, t)
        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
        return true
    }

    /// Returns true only for standard application windows — excludes dialogs,
    /// sheets, system dialogs, and other non-standard window types that should
    /// never be the target of an explicit user focus action.
    private func isStandardWindow(_ axWindow: AXUIElement) -> Bool {
        Self.shouldAllowAXWindow(
            role: axString(for: axWindow, attribute: kAXRoleAttribute as CFString),
            subrole: axString(for: axWindow, attribute: kAXSubroleAttribute as CFString),
            parentRole: parentRole(for: axWindow),
            isMinimized: axBool(for: axWindow, attribute: kAXMinimizedAttribute as CFString),
            allowFloating: true
        )
    }

    private func scheduleWindowFocusRetry(
        for candidate: WindowCandidate, attempt: Int, token: ActivationRequestLedger.Token
    ) {
        guard attempt < activationRetryLimit else {
            if clearPendingActivation(candidate.ownerPID) {
                ActivationOutcomeTracker.shared.record(
                    AXIsProcessTrusted() ? .failure : .accessibilityUnavailable
                )
                os_log(
                    .error,
                    log: appSwitcherLog,
                    "Window activation failed after retries (pid=%{public}d, window=%{public}u)",
                    candidate.ownerPID,
                    candidate.id
                )
            }
            return
        }
        let delay = 0.05 + Double(attempt) * 0.08
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.focusBestMatchingWindow(candidate, attempt: attempt + 1, token: token)
        }
    }

    private func activateApplication(_ app: NSRunningApplication, activateAllWindows: Bool) {
        app.unhide()
        let options: NSApplication.ActivationOptions = activateAllWindows
            ? [.activateAllWindows, .activateIgnoringOtherApps]
            : [.activateIgnoringOtherApps]
        let didActivate = app.activate(options: options)
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)

        if !didActivate, #available(macOS 14.0, *) {
            app.activate()
        }
    }

    private func ensureApplicationFrontmost(
        _ app: NSRunningApplication,
        identity: SwitcherHistoryIdentity,
        attempt: Int,
        token: ActivationRequestLedger.Token
    ) {
        guard continuesActivation(token) else { return }
        guard currentSystemFrontmostPID() != app.processIdentifier else {
            confirmActivation(
                identity: identity,
                pid: app.processIdentifier,
                outcome: .applicationFallbackUnverified
            )
            return
        }
        guard attempt < activationRetryLimit else {
            if clearPendingActivation(app.processIdentifier) {
                ActivationOutcomeTracker.shared.record(.failure)
                os_log(
                    .error,
                    log: appSwitcherLog,
                    "Application activation failed after retries (pid=%{public}d)",
                    app.processIdentifier
                )
            }
            return
        }

        let delay = 0.05 + Double(attempt) * 0.08
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.continuesActivation(token) else { return }
            guard self.currentSystemFrontmostPID() != app.processIdentifier else {
                self.confirmActivation(
                    identity: identity,
                    pid: app.processIdentifier,
                    outcome: .applicationFallbackUnverified
                )
                return
            }
            self.activateApplication(app, activateAllWindows: true)
            self.ensureApplicationFrontmost(app, identity: identity, attempt: attempt + 1, token: token)
        }
    }

    private func ensureWindowFrontmost(
        _ candidate: WindowCandidate, attempt: Int, token: ActivationRequestLedger.Token
    ) {
        verifyFrontmostWindow(candidate, token: token) { [weak self] isFrontmost in
            guard let self else { return }
            guard !isFrontmost else {
                self.confirmActivation(
                    identity: candidate.historyIdentity,
                    pid: candidate.ownerPID,
                    outcome: .exactVerified
                )
                return
            }
            guard attempt < self.activationRetryLimit,
                  let app = NSRunningApplication(processIdentifier: candidate.ownerPID) else {
                if self.clearPendingActivation(candidate.ownerPID) {
                    ActivationOutcomeTracker.shared.record(
                        NSRunningApplication(processIdentifier: candidate.ownerPID) == nil
                            ? .targetDisappeared
                            : (AXIsProcessTrusted() ? .failure : .accessibilityUnavailable)
                    )
                    os_log(
                        .error,
                        log: appSwitcherLog,
                        "Exact window activation failed after retries (pid=%{public}d, window=%{public}u)",
                        candidate.ownerPID,
                        candidate.id
                    )
                }
                return
            }

            let delay = 0.05 + Double(attempt) * 0.08
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.verifyFrontmostWindow(candidate, token: token) { [weak self] isFrontmost in
                    guard let self else { return }
                    guard !isFrontmost else {
                        self.confirmActivation(
                            identity: candidate.historyIdentity,
                            pid: candidate.ownerPID,
                            outcome: .exactVerified
                        )
                        return
                    }
                    self.activateApplication(app, activateAllWindows: false)
                    self.focusBestMatchingWindow(candidate, attempt: attempt + 1, token: token)
                }
            }
        }
    }

    /// Runs the Accessibility focus check on the activation queue and calls
    /// `completion` on the main thread, unless a newer request superseded it.
    private func verifyFrontmostWindow(
        _ candidate: WindowCandidate,
        token: ActivationRequestLedger.Token,
        completion: @escaping (Bool) -> Void
    ) {
        guard continuesActivation(token) else { return }
        activationQueue.async { [weak self] in
            guard let self, self.activationRequests.isCurrent(token) else { return }
            let isFrontmost = self.isFrontmostWindow(candidate)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.continuesActivation(token) else { return }
                completion(isFrontmost)
            }
        }
    }

    private func schedulePendingActivationTimeout(for pid: pid_t, token: ActivationRequestLedger.Token) {
        DispatchQueue.main.asyncAfter(deadline: .now() + pendingActivationTimeout) { [weak self] in
            // A superseded request must not clear or fail a newer request's
            // pending state for the same process.
            guard let self, self.continuesActivation(token) else { return }
            if self.clearPendingActivation(pid) {
                ActivationOutcomeTracker.shared.record(.failure)
            }
        }
    }

    private func markPendingActivation(_ pid: pid_t) {
        pendingActivationPIDs.insert(pid)
    }

    @discardableResult
    private func clearPendingActivation(_ pid: pid_t) -> Bool {
        pendingActivationPIDs.remove(pid) != nil
    }

    private func confirmActivation(
        identity: SwitcherHistoryIdentity,
        pid: pid_t,
        outcome: ActivationOutcome
    ) {
        guard clearPendingActivation(pid) else { return }
        ActivationOutcomeTracker.shared.record(outcome)
        guard ActivationOutcomePolicy.recordsExactWindowMRU(outcome) else { return }
        history.noteActivation(identity)
        onActivationConfirmed?(identity, pid)
    }

    private func application(for item: SwitcherItem) -> NSRunningApplication? {
        if let pid = item.historyIdentity.ownerPID,
           let app = NSRunningApplication(processIdentifier: pid) {
            return app
        }

        guard let sourceAppIdentifier = item.sourceAppIdentifier else { return nil }
        return NSWorkspace.shared.runningApplications.first {
            sourceAppIdentifier.caseInsensitiveCompare(self.sourceAppIdentifier(for: $0)) == .orderedSame
        }
    }

    private func windowElement(for item: SwitcherItem) -> AXUIElement? {
        guard let app = application(for: item) else { return nil }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement],
              !windows.isEmpty else {
            return nil
        }

        if case let .appWindow(_, windowID) = item.historyIdentity,
           let exactWindow = windows.first(where: { resolvedWindowID(for: $0) == windowID }) {
            return exactWindow
        }

        if let focusedWindow = preferredWindow(for: axApp, attribute: kAXFocusedWindowAttribute as CFString) {
            return focusedWindow
        }
        if let mainWindow = preferredWindow(for: axApp, attribute: kAXMainWindowAttribute as CFString) {
            return mainWindow
        }

        let standardWindow = windows.first(where: { isStandardWindow($0) })
        return standardWindow ?? windows.first
    }

    private func preferredWindow(for app: AXUIElement, attribute: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, attribute, &value) == .success,
              let rawWindow = value else {
            return nil
        }
        return unsafeBitCast(rawWindow, to: AXUIElement.self)
    }

    private func isFrontmostWindow(_ candidate: WindowCandidate) -> Bool {
        ExactWindowActivationPolicy.mayConfirm(
            frontmostPID: currentSystemFrontmostPID(),
            focusedWindowID: focusedWindowID(for: candidate.ownerPID),
            targetPID: candidate.ownerPID,
            targetWindowID: candidate.id,
            isOnScreen: ExactWindowActivationPolicy.isTargetOnScreen(
                ownerPID: candidate.ownerPID,
                windowID: candidate.id
            )
        )
    }

    private func currentSystemFrontmostPID() -> pid_t {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return 0
        }
        return app.processIdentifier
    }

    private var exactFocusCapabilityAvailable: Bool {
        PrivateWindowCapabilityPolicy.permitsExactFocus(
            identity: privateCapabilities.identityStatus,
            focus: privateCapabilities.focusStatus
        )
    }

    private func resolvedWindowID(for element: AXUIElement) -> CGWindowID? {
        switch privateCapabilities.windowID(for: element) {
        case let .success(windowID): return windowID
        case .unavailable, .failed: return nil
        }
    }

    private func focusedWindowID(for pid: pid_t) -> CGWindowID? {
        let axApp = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?

        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value) == .success,
           let focusedWindow = value {
            let axWindow = unsafeBitCast(focusedWindow, to: AXUIElement.self)
            if let windowID = resolvedWindowID(for: axWindow) {
                return windowID
            }
        }

        value = nil
        if AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &value) == .success,
           let mainWindow = value {
            let axWindow = unsafeBitCast(mainWindow, to: AXUIElement.self)
            return resolvedWindowID(for: axWindow)
        }

        return nil
    }

    // MARK: - Candidate creation

    private func makeCandidate(
        from windowInfo: [String: Any],
        orderIndex: Int,
        includeBackgroundWindows: Bool? = nil,
        restrictToPID: pid_t? = nil,
        appsByPID: [pid_t: NSRunningApplication]? = nil,
        axInspectionsByPID: [pid_t: AXAppInspection]? = nil,
        previouslyConfirmedIDsByPID: [pid_t: Set<CGWindowID>] = [:],
        previouslyMinimizedIDsByPID: [pid_t: Set<CGWindowID>] = [:],
        previouslyHiddenIDsByPID: [pid_t: Set<CGWindowID>] = [:],
        membershipObserver: ((WindowMembershipDecision) -> Void)? = nil
    ) -> WindowCandidate? {
        guard let ownerPIDNumber = windowInfo[kCGWindowOwnerPID as String] as? NSNumber else { return nil }
        let ownerPID = ownerPIDNumber.int32Value
        if let restrictToPID, ownerPID != restrictToPID { return nil }

        let app: NSRunningApplication
        if let lookup = appsByPID {
            // Fast O(1) lookup from pre-built table
            guard let found = lookup[ownerPID] else { return nil }
            app = found
        } else {
            // Fallback path (used by currentFrontmostIdentity helper)
            guard let found = NSRunningApplication(processIdentifier: ownerPID),
                  ApplicationEligibilityPolicy.isEligibleApplication(found) else { return nil }
            app = found
        }

        let alpha = (windowInfo[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0
        guard alpha > 0.08 else { return nil }

        let layer = (windowInfo[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
        guard (0...2).contains(layer) else { return nil }

        guard let boundsDictionary = windowInfo[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDictionary) else { return nil }
        guard bounds.width >= 120, bounds.height >= 80 else { return nil }

        let title = (windowInfo[kCGWindowName as String] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let windowID = (windowInfo[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0
        guard windowID != 0 else { return nil }

        let decision: WindowMembershipDecision
        if let inspections = axInspectionsByPID {
            let isOnScreen = (windowInfo[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue == true
            let workspace = isOnScreen ? nil : WindowWorkspaceProvider.shared.snapshot(for: windowID, isOnScreen: false)
            decision = Self.evaluateMembership(
                windowInfo: windowInfo,
                inspection: inspections[ownerPID],
                previouslyConfirmed: previouslyConfirmedIDsByPID[ownerPID]?.contains(windowID) ?? false,
                previouslyMinimized: previouslyMinimizedIDsByPID[ownerPID]?.contains(windowID) ?? false,
                previouslyInferredHidden: previouslyHiddenIDsByPID[ownerPID]?.contains(windowID) ?? false,
                applicationIsHidden: app.isHidden,
                workspace: workspace
            )
            if decision.isIncluded, decision.isUnknownIdentity, !isOnScreen {
                // Off-screen windows admitted without AX confirmation are the
                // source of phantom tiles; record the evidence (no titles).
                let inspection = inspections[ownerPID]
                os_log(.info, log: appSwitcherLog,
                       "Admitted unconfirmed off-screen window pid=%d wid=%u size=%.0fx%.0f spaces=%d trusted=%d complete=%d failures=%d approved=%d standard=%d minimized=%d",
                       ownerPID, windowID, bounds.width, bounds.height,
                       workspace?.memberships.count ?? -1,
                       inspection?.isTrusted == true ? 1 : 0,
                       inspection?.enumerationComplete == true ? 1 : 0,
                       inspection?.identityFailures ?? -1,
                       inspection?.approvedIDs.count ?? -1,
                       inspection?.standardWindowIDs.count ?? -1,
                       inspection?.minimizedIDs.count ?? -1)
            }
            confirmedIdentityLock.lock()
            confirmedWindowIdentities.recordHiddenDecision(
                pid: ownerPID, windowID: windowID, isOnScreen: isOnScreen, decision: decision
            )
            confirmedIdentityLock.unlock()
        } else {
            // The helper is also used by paths without AX enrichment.  In that
            // case CG membership remains fail-open after the ordinary CG
            // candidate checks above.
            decision = WindowMembershipDecision(isIncluded: true, isUnknownIdentity: false)
        }
        membershipObserver?(decision)
        guard decision.isIncluded else { return nil }

        let isOnScreen = (windowInfo[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
        let allowBackground = includeBackgroundWindows ?? (preferences.windowVisibilityScope == .allSpaces)
        if !allowBackground && !isOnScreen { return nil }

        let sharingState = (windowInfo[kCGWindowSharingState as String] as? NSNumber)?.intValue ?? 1
        let isShareable = sharingState != 0

        let appName = app.localizedName ?? (windowInfo[kCGWindowOwnerName as String] as? String) ?? "Application"
        let windowTitle = title.isEmpty ? appName : title
        let sourceIdentifier = sourceAppIdentifier(for: app)
        guard !preferences.excludesApp(identifier: sourceIdentifier, appName: appName) else { return nil }
        guard !preferences.excludesWindowTitle(title) else { return nil }
        let historyIdentity = SwitcherHistoryIdentity.appWindow(pid: ownerPID, windowID: windowID)

        var sortScore = CGFloat(max(0, 1000 - orderIndex * 10))
        if isOnScreen { sortScore += 10_000 } else { sortScore += 500 }
        if !title.isEmpty { sortScore += 500 }
        if let historyRank = history.rank(of: historyIdentity) {
            sortScore += CGFloat(max(0, 8_000 - historyRank * 40))
        }

        return WindowCandidate(
            id: windowID, ownerPID: ownerPID, bundleIdentifier: app.bundleIdentifier,
            appName: appName, appIcon: app.icon, windowTitle: windowTitle,
            bounds: bounds,
            screenFrame: screenFrame(containing: bounds),
            orderIndex: orderIndex,
            sortScore: sortScore,
            isOnScreen: isOnScreen,
            isShareable: isShareable,
            isUnknownIdentity: decision.isUnknownIdentity,
            isFullscreen: axInspectionsByPID?[ownerPID]?.fullscreenIDs.contains(windowID) ?? false
        )
    }

    private func deduplicatedCandidates(from candidates: [WindowCandidate]) -> [WindowCandidate] {
        Self.deduplicateCandidates(
            candidates,
            identityKey: { .init(ownerPID: $0.ownerPID, windowID: $0.id) },
            prefersReplacement: { lhs, rhs in
                Self.prefersReplacementCandidate(
                    isOnScreen: lhs.isOnScreen,
                    title: lhs.windowTitle,
                    bounds: lhs.bounds,
                    sortScore: lhs.sortScore,
                    orderIndex: lhs.orderIndex,
                    overIsOnScreen: rhs.isOnScreen,
                    overTitle: rhs.windowTitle,
                    overBounds: rhs.bounds,
                    overSortScore: rhs.sortScore,
                    overOrderIndex: rhs.orderIndex
                )
            }
        )
    }

    struct AXAppInspection {
        let approvedIDs: Set<CGWindowID>
        let positivelyDisallowedIDs: Set<CGWindowID>
        let identityFailures: Int
        var enumerationComplete: Bool = false
        var isTrusted: Bool = false
        var completedAt: Date = .distantPast
        var observedAt: Date = .distantPast
        var fullscreenIDs: Set<CGWindowID> = []
        // Standard siblings still establish helper-surface evidence when the
        // user's visibility policy excludes their minimized representation.
        var standardWindowIDs: Set<CGWindowID> = []
        var elementsByID: [CGWindowID: AXUIElement] = [:]
        var minimizedIDs: Set<CGWindowID> = []
    }

    struct WindowMembershipDecision {
        let isIncluded: Bool
        let isUnknownIdentity: Bool
        let isExactAXMatched: Bool
        let isPositivelyRejected: Bool
        let isInferredHidden: Bool

        init(
            isIncluded: Bool,
            isUnknownIdentity: Bool,
            isExactAXMatched: Bool = false,
            isPositivelyRejected: Bool = false,
            isInferredHidden: Bool = false
        ) {
            self.isIncluded = isIncluded
            self.isUnknownIdentity = isUnknownIdentity
            self.isExactAXMatched = isExactAXMatched
            self.isPositivelyRejected = isPositivelyRejected
            self.isInferredHidden = isInferredHidden
        }
    }

    static func freshInspectionForCandidates(
        _ inspection: AXAppInspection,
        now: Date = Date(),
        refresh: () -> AXAppInspection
    ) -> AXAppInspection {
        let age = now.timeIntervalSince(inspection.completedAt)
        guard age < 0 || age > 1.0 else { return inspection }
        return refresh()
    }

    private func inspectAXWindowsByPID(for apps: [NSRunningApplication]) -> (inspections: [pid_t: AXAppInspection], failures: Int) {
        var result: [pid_t: AXAppInspection] = [:]
        result.reserveCapacity(apps.count)
        var failures = 0
        for app in apps {
            let inspection = inspectAXWindows(for: app)
            result[app.processIdentifier] = inspection
            failures += inspection.identityFailures
        }
        return (result, failures)
    }

    private func inspectAXWindows(for app: NSRunningApplication) -> AXAppInspection {
        let observedAt = Date()
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        let windows: [AXUIElement]
        let enumerationComplete: Bool
        let isTrusted = AXIsProcessTrusted()
        if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
           let resolvedWindows = value as? [AXUIElement] {
            windows = resolvedWindows
            enumerationComplete = true
        } else {
            windows = []
            enumerationComplete = false
        }

        var approvedIDs = Set<CGWindowID>()
        var disallowedIDs = Set<CGWindowID>()
        var identityFailures = 0
        var fullscreenIDs = Set<CGWindowID>()
        var standardWindowIDs = Set<CGWindowID>()
        var elementsByID: [CGWindowID: AXUIElement] = [:]
        var minimizedIDs = Set<CGWindowID>()

        for window in windows {
            guard AXWindowCatalog.shouldResolveWindowIdentity(
                role: axString(for: window, attribute: kAXRoleAttribute as CFString)
            ) else { continue }
            guard let windowID = resolvedWindowID(for: window) else {
                identityFailures += 1
                continue
            }
            elementsByID[windowID] = window
            if axBool(for: window, attribute: kAXMinimizedAttribute as CFString) { minimizedIDs.insert(windowID) }
            if isSwitcherDisplayWindow(window, includeMinimized: true) {
                standardWindowIDs.insert(windowID)
            }
            if isSwitcherDisplayWindow(window) {
                approvedIDs.insert(windowID)
                if axBool(for: window, attribute: "AXFullScreen" as CFString) { fullscreenIDs.insert(windowID) }
            } else {
                disallowedIDs.insert(windowID)
            }
        }

        let preferredWindows = [
            preferredWindow(for: axApp, attribute: kAXFocusedWindowAttribute as CFString),
            preferredWindow(for: axApp, attribute: kAXMainWindowAttribute as CFString),
        ].compactMap { $0 }

        for window in preferredWindows {
            guard AXWindowCatalog.shouldResolveWindowIdentity(
                role: axString(for: window, attribute: kAXRoleAttribute as CFString)
            ) else { continue }
            guard let id = resolvedWindowID(for: window) else {
                identityFailures += 1
                continue
            }
            elementsByID[id] = window
            if axBool(for: window, attribute: kAXMinimizedAttribute as CFString) { minimizedIDs.insert(id) }
            if isSwitcherDisplayWindow(window, includeMinimized: true) {
                standardWindowIDs.insert(id)
            }
            // Main/focused is a discovery hint, not an exemption from the same
            // minimized/role policy used for AXWindows. Positive rejection wins.
            if isSwitcherDisplayWindow(window), !disallowedIDs.contains(id) {
                approvedIDs.insert(id)
                if axBool(for: window, attribute: "AXFullScreen" as CFString) { fullscreenIDs.insert(id) }
            } else {
                approvedIDs.remove(id)
                disallowedIDs.insert(id)
            }
        }

        return AXAppInspection(
            approvedIDs: approvedIDs,
            positivelyDisallowedIDs: disallowedIDs,
            identityFailures: identityFailures,
            enumerationComplete: enumerationComplete,
            isTrusted: isTrusted,
            completedAt: Date(),
            observedAt: observedAt,
            fullscreenIDs: fullscreenIDs,
            standardWindowIDs: standardWindowIDs,
            elementsByID: elementsByID,
            minimizedIDs: minimizedIDs
        )
    }

    private func isSwitcherDisplayWindow(_ axWindow: AXUIElement, includeMinimized: Bool? = nil) -> Bool {
        Self.shouldAllowAXWindow(
            role: axString(for: axWindow, attribute: kAXRoleAttribute as CFString),
            subrole: axString(for: axWindow, attribute: kAXSubroleAttribute as CFString),
            parentRole: parentRole(for: axWindow),
            isMinimized: axBool(for: axWindow, attribute: kAXMinimizedAttribute as CFString),
            includeMinimized: includeMinimized ?? preferences.includeMinimizedWindows
        )
    }

    /// Raw CG boundary: retain the difference between an explicitly empty title
    /// and a title that macOS withheld. Display-name substitution happens later.
    static func evaluateMembership(
        windowInfo: [String: Any],
        inspection: AXAppInspection?,
        previouslyConfirmed: Bool = false,
        previouslyMinimized: Bool = false,
        previouslyInferredHidden: Bool = false,
        applicationIsHidden: Bool = false,
        workspace: WindowWorkspaceSnapshot? = nil,
        now: Date = Date()
    ) -> WindowMembershipDecision {
        let rawTitle = windowInfo[kCGWindowName as String] as? String
        let title = rawTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return evaluateMembership(
            windowID: (windowInfo[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0,
            inspection: inspection,
            layer: (windowInfo[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0,
            hasTitle: !title.isEmpty,
            bounds: .zero,
            isOnScreen: (windowInfo[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false,
            hasExplicitEmptyTitle: rawTitle != nil && title.isEmpty,
            previouslyConfirmed: previouslyConfirmed,
            previouslyMinimized: previouslyMinimized,
            previouslyInferredHidden: previouslyInferredHidden,
            applicationIsHidden: applicationIsHidden,
            workspace: workspace,
            now: now
        )
    }

    static func evaluateMembership(
        windowID: CGWindowID,
        inspection: AXAppInspection?,
        layer: Int,
        hasTitle: Bool,
        bounds: CGRect,
        isOnScreen: Bool = true,
        hasExplicitEmptyTitle: Bool = false,
        previouslyConfirmed: Bool = false,
        previouslyMinimized: Bool = false,
        previouslyInferredHidden: Bool = false,
        applicationIsHidden: Bool = false,
        workspace: WindowWorkspaceSnapshot? = nil,
        now: Date = Date()
    ) -> WindowMembershipDecision {
        // 1. Positive AX Disallow: AX examined this window and confirmed it is ineligible
        if let inspection, inspection.positivelyDisallowedIDs.contains(windowID) {
            return WindowMembershipDecision(
                isIncluded: false,
                isUnknownIdentity: false,
                isExactAXMatched: true,
                isPositivelyRejected: true
            )
        }

        // 2. Positive AX Approval: AX examined and approved this window
        if let inspection, inspection.approvedIDs.contains(windowID) {
            return WindowMembershipDecision(
                isIncluded: true,
                isUnknownIdentity: false,
                isExactAXMatched: true
            )
        }

        // A window that belongs to no Space is ordered out: it is not on any
        // desktop or fullscreen Space, and minimized windows keep their Space.
        // Apps keep such helper surfaces (often 500x500 placeholders)
        // registered with CG; they are never selectable. This is positive
        // SkyLight evidence, not inference from AX absence or dimensions.
        if !isOnScreen, !applicationIsHidden, !previouslyMinimized,
           let workspace, workspace.capability.level == .available,
           workspace.memberships.isEmpty {
            return WindowMembershipDecision(isIncluded: false, isUnknownIdentity: true, isInferredHidden: true)
        }

        // Preserve a strong hidden-surface finding after the user moves to
        // another Space. That move changes current-Space evidence but does not
        // make the same unobserved CG surface a selectable window again.
        if previouslyInferredHidden, !isOnScreen, !previouslyMinimized,
           let inspection, inspection.isTrusted, inspection.enumerationComplete,
           inspection.identityFailures == 0,
           !inspection.approvedIDs.isEmpty || !inspection.standardWindowIDs.isEmpty,
           now.timeIntervalSince(inspection.observedAt) >= 0,
           now.timeIntervalSince(inspection.observedAt) <= 1.0,
           now.timeIntervalSince(inspection.completedAt) >= 0,
           now.timeIntervalSince(inspection.completedAt) <= 1.0 {
            return WindowMembershipDecision(isIncluded: false, isUnknownIdentity: true, isInferredHidden: true)
        }

        // A formerly selectable window can remain registered with CG after the
        // app hides it internally. Exact current-desktop evidence, a complete AX
        // catalog and a real sibling distinguish this from off-space/minimized
        // windows. Historical confirmation cannot keep such a stale tile alive.
        if !isOnScreen, !applicationIsHidden, !previouslyMinimized,
           let workspace, workspace.capability.level == .available,
           workspace.stageManagerState == .disabled,
           !workspace.currentSpaceIDs.isEmpty,
           workspace.memberships.isEmpty || workspace.isOnCurrentManagedSpace,
           let inspection, inspection.isTrusted, inspection.enumerationComplete,
           inspection.identityFailures == 0,
           !inspection.approvedIDs.isEmpty || !inspection.standardWindowIDs.isEmpty,
           now.timeIntervalSince(inspection.observedAt) >= 0,
           now.timeIntervalSince(inspection.observedAt) <= 1.0,
           now.timeIntervalSince(inspection.completedAt) >= 0,
           now.timeIntervalSince(inspection.completedAt) <= 1.0 {
            return WindowMembershipDecision(isIncluded: false, isUnknownIdentity: true, isInferredHidden: true)
        }

        // Apps such as Calendar and Spotify keep their windows registered with
        // CG after the user closes them. On the current Space, a window that is
        // neither on screen nor reported by a complete, trusted AX catalog is not
        // minimized either (AX lists minimized windows), so it is closed. This
        // covers the case above without a visible sibling: the app has no open
        // windows at all and is represented by its application entry instead.
        if !isOnScreen, !applicationIsHidden, !previouslyMinimized,
           let workspace, workspace.capability.level == .available,
           workspace.stageManagerState == .disabled,
           workspace.isOnCurrentManagedSpace,
           let inspection, inspection.isTrusted, inspection.enumerationComplete,
           inspection.identityFailures == 0,
           inspection.approvedIDs.isEmpty, inspection.standardWindowIDs.isEmpty,
           inspection.minimizedIDs.isEmpty, inspection.positivelyDisallowedIDs.isEmpty,
           now.timeIntervalSince(inspection.completedAt) >= 0,
           now.timeIntervalSince(inspection.completedAt) <= 1.0 {
            return WindowMembershipDecision(isIncluded: false, isUnknownIdentity: true, isInferredHidden: true)
        }

        // A conservative desktop-evidence heuristic: some apps publish unnamed,
        // offscreen CG helper surfaces alongside their real AX windows. Never
        // infer this from failed capture, missing titles under denied permission,
        // AX absence alone, or dimensions. Previously confirmed windows survive.
        if !isOnScreen, !hasTitle, hasExplicitEmptyTitle, !previouslyConfirmed, !previouslyMinimized,
           let inspection, inspection.isTrusted, inspection.enumerationComplete,
           inspection.identityFailures == 0,
           !inspection.approvedIDs.isEmpty || !inspection.standardWindowIDs.isEmpty,
           now.timeIntervalSince(inspection.completedAt) >= 0,
           now.timeIntervalSince(inspection.completedAt) <= 1.0 {
            return WindowMembershipDecision(isIncluded: false, isUnknownIdentity: true)
        }
        _ = layer
        _ = bounds
        return WindowMembershipDecision(isIncluded: true, isUnknownIdentity: true)
    }

    static func isSwitcherDisplaySubrole(_ subrole: String) -> Bool {
        let valid: Set<String> = [
            kAXStandardWindowSubrole as String,
            "AXFullScreenWindow"
        ]
        return valid.contains(subrole)
    }

    static func shouldAllowAXWindow(
        role: String?,
        subrole: String?,
        parentRole: String?,
        isMinimized: Bool,
        includeMinimized: Bool = false,
        allowFloating: Bool = false
    ) -> Bool {
        AXWindowCatalog.isEligible(
            role: role,
            subrole: subrole,
            parentRole: parentRole,
            isMinimized: isMinimized,
            includeMinimized: includeMinimized,
            allowFloating: allowFloating
        )
    }

    // MARK: - Multi-strategy window capture

    struct PreviewAssets {
        let thumbnail: NSImage
        let backdrop: NSImage
    }

    private func capturePreviewAssets(for candidate: WindowCandidate) -> PreviewAssets? {
        // `kCGWindowSharingState == 0` is advisory and can disagree with the
        // capture APIs on modern macOS. In particular, ScreenCaptureKit's
        // deferred recovery already attempts these exact windows. Try the same
        // validated SkyLight/Core Graphics sequence here so a usable immediate
        // frame is not unnecessarily replaced by the icon placeholder. Blank,
        // black, and protected-content frames are still rejected below.
        guard let backdrop = captureBackdropImage(windowID: candidate.id, bounds: candidate.bounds) else { return nil }
        return PreviewAssets(
            thumbnail: downscaledPreview(backdrop),
            backdrop: backdrop
        )
    }

    static func resolvePreferredCapture<T>(
        preferred: T?,
        prepare: (T) -> T?,
        fallback: () -> T?
    ) -> T? {
        if let preferred, let prepared = prepare(preferred) {
            return prepared
        }
        return fallback()
    }

    /// AX-only inventory uses the same validated capture path as CG candidates.
    /// Called on the enrichment queue, never from the keyboard event tap.
    func captureExactPreviewAssets(ownerPID: pid_t, windowID: CGWindowID, bounds: CGRect) -> PreviewAssets? {
        guard let owner = NSRunningApplication(processIdentifier: ownerPID),
              !owner.isTerminated, let launchDate = owner.launchDate else { return nil }
        func ownerIsCurrent() -> Bool {
            guard let currentOwner = NSRunningApplication(processIdentifier: ownerPID),
                  !currentOwner.isTerminated, currentOwner.launchDate == launchDate,
                  let rows = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]] else { return false }
            return rows.contains { row in
                (row[kCGWindowNumber as String] as? NSNumber)?.uint32Value == windowID &&
                (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == ownerPID
            }
        }
        guard CGPreflightScreenCaptureAccess(), ownerIsCurrent(),
              let backdrop = captureBackdropImage(windowID: windowID, bounds: bounds),
              ownerIsCurrent() else { return nil }
        return PreviewAssets(thumbnail: downscaledPreview(backdrop), backdrop: backdrop)
    }

    private func captureBackdropImage(windowID: CGWindowID, bounds: CGRect) -> NSImage? {
        // Prefer the WindowServer hardware path, but only accept it when the
        // captured image survives presentation validation. Some GPU-backed apps
        // (including Arc) can return a blank hardware frame even though the
        // public Core Graphics capture path can still produce a valid preview.
        return Self.resolvePreferredCapture(
            preferred: {
                guard case let .success(image) = privateCapabilities.captureWindow(windowID) else {
                    return nil
                }
                return image
            }(),
            prepare: { self.preparedWindowCaptureImage($0) }
        ) {
            let framedBest: CGWindowImageOption = [.bestResolution]
            if let img = cgCapture(.null, .optionIncludingWindow, windowID, framedBest, minW: 80, minH: 60) { return img }
            if let img = cgCapture(bounds, .optionIncludingWindow, windowID, framedBest, minW: 80, minH: 60) { return img }

            let croppedBest: CGWindowImageOption = [.boundsIgnoreFraming, .bestResolution]
            if let img = cgCapture(.null, .optionIncludingWindow, windowID, croppedBest, minW: 80, minH: 60) { return img }
            if let img = cgCapture(bounds, .optionIncludingWindow, windowID, croppedBest, minW: 80, minH: 60) { return img }
            let nominal: CGWindowImageOption = [.boundsIgnoreFraming, .nominalResolution]
            if let img = cgCapture(.null, .optionIncludingWindow, windowID, nominal, minW: 40, minH: 30) { return img }

            return nil
        }
    }

    /// Cap thumbnails at maxWidth pixels wide using a CoreGraphics context.
    /// A full-resolution Retina capture can be 20–40 MB; capping at 900px wide
    /// brings each thumbnail to ~1–2 MB — a 15–20x RAM reduction per window.
    /// Uses CGContext directly (thread-safe; AppKit drawing is not reliable off-main).
    private func downscaledPreview(_ image: NSImage, maxWidth: CGFloat = 900) -> NSImage {
        let naturalSize = image.size
        guard naturalSize.width > maxWidth, naturalSize.width > 0 else { return image }
        let scale = maxWidth / naturalSize.width
        let targetW = Int(maxWidth)
        let targetH = Int(floor(naturalSize.height * scale))
        guard targetW > 0, targetH > 0 else { return image }

        guard let cgSrc = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let ctx = CGContext(data: nil, width: targetW, height: targetH,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: colorSpace, bitmapInfo: bitmapInfo) else { return image }
        ctx.interpolationQuality = .medium
        ctx.draw(cgSrc, in: CGRect(x: 0, y: 0, width: targetW, height: targetH))

        guard let downscaled = ctx.makeImage() else { return image }
        return NSImage(cgImage: downscaled, size: NSSize(width: targetW, height: targetH))
    }

    private func cgCapture(_ rect: CGRect, _ listOption: CGWindowListOption, _ wid: CGWindowID,
                           _ imageOption: CGWindowImageOption, minW: Int, minH: Int) -> NSImage? {
        guard let cgImage = CGWindowListCreateImage(rect, listOption, wid, imageOption) else { return nil }
        let prepared = Self.presentationPreparedWindowCapture(cgImage)
        guard prepared.width >= minW, prepared.height >= minH,
              Self.isPresentationUsefulWindowCapture(prepared) else { return nil }
        return NSImage(cgImage: prepared, size: NSSize(width: prepared.width, height: prepared.height))
    }

    private func preparedWindowCaptureImage(_ image: NSImage) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        let prepared = Self.presentationPreparedWindowCapture(cgImage)
        guard Self.isPresentationUsefulWindowCapture(prepared) else { return nil }
        guard prepared.width != cgImage.width || prepared.height != cgImage.height else { return image }
        return NSImage(cgImage: prepared, size: NSSize(width: prepared.width, height: prepared.height))
    }

    static func presentationPreparedWindowCapture(_ cgImage: CGImage) -> CGImage {
        let trimmed = trimmedWindowCapture(cgImage)
        return presentationSafeWindowCapture(trimmed)
    }

    static func trimmedWindowCapture(_ cgImage: CGImage, alphaThreshold: UInt8 = 20, maxInset: Int = 48) -> CGImage {
        // Skip bytes in RGBX/XRGB are not transparency. Images without alpha
        // cannot have transparent borders, regardless of their pixel byte order.
        switch cgImage.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return cgImage
        default:
            break
        }
        let width = cgImage.width
        let height = cgImage.height
        let insetLimit = max(0, min(maxInset, min(width / 4, height / 4)))
        guard insetLimit > 0,
              let alphaContext = CGContext(
                data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ), let data = alphaContext.data else { return cgImage }
        defer { withExtendedLifetime(alphaContext) {} }
        // Core Graphics converts any source layout into RGBA; alpha is the
        // fourth byte of each pixel. An alpha-only context would be smaller but
        // needs a nil color space, which older macOS SDKs cannot express.
        alphaContext.setBlendMode(.copy)
        alphaContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let alpha = data.assumingMemoryBound(to: UInt8.self)
        let stride = alphaContext.bytesPerRow

        func rowHasOpaquePixels(_ y: Int) -> Bool {
            (0..<width).contains { alpha[y * stride + $0 * 4 + 3] >= alphaThreshold }
        }

        func columnHasOpaquePixels(_ x: Int) -> Bool {
            (0..<height).contains { alpha[$0 * stride + x * 4 + 3] >= alphaThreshold }
        }

        var topInset = 0
        while topInset < insetLimit && !rowHasOpaquePixels(topInset) {
            topInset += 1
        }

        var bottomInset = 0
        while bottomInset < insetLimit && !rowHasOpaquePixels(height - 1 - bottomInset) {
            bottomInset += 1
        }

        var leftInset = 0
        while leftInset < insetLimit && !columnHasOpaquePixels(leftInset) {
            leftInset += 1
        }

        var rightInset = 0
        while rightInset < insetLimit && !columnHasOpaquePixels(width - 1 - rightInset) {
            rightInset += 1
        }

        guard topInset > 0 || bottomInset > 0 || leftInset > 0 || rightInset > 0 else {
            return cgImage
        }

        // CGImage cropping and the normalized image rows both count from the
        // top. Using bottomInset here shifts asymmetric borders into the result.
        let cropRect = CGRect(
            x: leftInset,
            y: topInset,
            width: max(1, width - leftInset - rightInset),
            height: max(1, height - topInset - bottomInset)
        )

        return cgImage.cropping(to: cropRect) ?? cgImage
    }

    static func presentationSafeWindowCapture(_ cgImage: CGImage) -> CGImage {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 40, height > 40 else { return cgImage }

        let sideInset = min(4, max(1, width / 500))
        let bottomInset = min(3, max(1, height / 700))
        let topInset = min(8, max(2, height / 280))

        let cropRect = CGRect(
            x: sideInset,
            y: bottomInset,
            width: max(1, width - sideInset * 2),
            height: max(1, height - topInset - bottomInset)
        )

        guard cropRect.width < CGFloat(width) || cropRect.height < CGFloat(height) else { return cgImage }
        return cgImage.cropping(to: cropRect) ?? cgImage
    }

    static func isPresentationUsefulWindowCapture(_ cgImage: CGImage) -> Bool {
        // Normalize only a small sample, once. Source buffers may be BGRA, ARGB,
        // RGBX, grayscale, or higher bit depth; alphaInfo alone cannot decode them.
        let width = min(64, cgImage.width)
        let height = min(64, cgImage.height)
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
              ), let data = context.data else { return false }
        defer { withExtendedLifetime(context) {} }
        context.setBlendMode(.copy)
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        var count = 0
        var total = 0.0
        var minimum = 1.0
        var maximum = 0.0
        // Window chrome and capture borders can be bright while the captured
        // content is entirely black. Judge the interior, as the former spaced
        // sampler did, so those edges cannot make a failed frame look useful.
        // Keep a smaller inset than the old 1/9 sampling margin to retain more
        // dark-window content near the edges. Tiny images retain all pixels.
        let horizontalInset = width / 12
        let verticalInset = height / 12
        for y in verticalInset..<(height - verticalInset) {
            for x in horizontalInset..<(width - horizontalInset) {
                let offset = y * context.bytesPerRow + x * 4
                let alpha = Double(pixels[offset + 3])
                guard alpha > 10 else { continue }
                // Unpremultiply so a translucent but visible surface is not
                // mistaken for a black capture.
                let luminance = (0.2126 * Double(pixels[offset])
                    + 0.7152 * Double(pixels[offset + 1])
                    + 0.0722 * Double(pixels[offset + 2])) / alpha
                count += 1
                total += luminance
                minimum = min(minimum, luminance)
                maximum = max(maximum, luminance)
            }
        }
        guard count >= 2 else { return false }
        return !(total / Double(count) < 0.07 && maximum - minimum < 0.035)
    }

    // MARK: - AX helpers

    private func axString(for element: AXUIElement, attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    private func axBool(for element: AXUIElement, attribute: CFString) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let number = value as? NSNumber else { return false }
        return number.boolValue
    }

    private func parentRole(for element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &value) == .success,
              let parent = value else { return nil }
        let parentElement = unsafeBitCast(parent, to: AXUIElement.self)
        return axString(for: parentElement, attribute: kAXRoleAttribute as CFString)
    }

    private func sourceAppIdentifier(for app: NSRunningApplication) -> String {
        app.bundleIdentifier ?? "app-\(app.processIdentifier)"
    }

    static func previewCacheKey(
        for historyIdentity: SwitcherHistoryIdentity,
        title: String,
        bounds: CGRect,
        sourceAppIdentifier: String
    ) -> String {
        let normalizedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedBounds = [
            Int(bounds.origin.x.rounded()),
            Int(bounds.origin.y.rounded()),
            Int(bounds.width.rounded()),
            Int(bounds.height.rounded())
        ]
        return [
            historyIdentity.stableKey,
            sourceAppIdentifier.lowercased(),
            normalizedTitle,
            normalizedBounds.map(String.init).joined(separator: ",")
        ].joined(separator: "|")
    }

    static func deduplicateCandidateProbes(_ candidates: [WindowCandidateDeduplicationProbe]) -> [WindowCandidateDeduplicationProbe] {
        deduplicateCandidates(
            candidates,
            identityKey: { .init(ownerPID: $0.ownerPID, windowID: $0.windowID) },
            prefersReplacement: { lhs, rhs in
                prefersReplacementCandidate(
                    isOnScreen: lhs.isOnScreen,
                    title: lhs.title,
                    bounds: lhs.bounds,
                    sortScore: lhs.sortScore,
                    orderIndex: lhs.orderIndex,
                    overIsOnScreen: rhs.isOnScreen,
                    overTitle: rhs.title,
                    overBounds: rhs.bounds,
                    overSortScore: rhs.sortScore,
                    overOrderIndex: rhs.orderIndex
                )
            }
        )
    }

    private static func deduplicateCandidates<T>(
        _ candidates: [T],
        identityKey: (T) -> WindowCandidateIdentityKey,
        prefersReplacement: (T, T) -> Bool
    ) -> [T] {
        var bestByIdentity: [WindowCandidateIdentityKey: T] = [:]

        for candidate in candidates {
            let key = identityKey(candidate)
            if let existing = bestByIdentity[key] {
                if prefersReplacement(candidate, existing) {
                    bestByIdentity[key] = candidate
                }
            } else {
                bestByIdentity[key] = candidate
            }
        }

        return candidates.compactMap { candidate in
            let key = identityKey(candidate)
            return bestByIdentity.removeValue(forKey: key)
        }
    }

    private static func prefersReplacementCandidate(
        isOnScreen lhsIsOnScreen: Bool,
        title lhsTitle: String,
        bounds lhsBounds: CGRect,
        sortScore lhsSortScore: CGFloat,
        orderIndex lhsOrderIndex: Int,
        overIsOnScreen rhsIsOnScreen: Bool,
        overTitle rhsTitle: String,
        overBounds rhsBounds: CGRect,
        overSortScore rhsSortScore: CGFloat,
        overOrderIndex rhsOrderIndex: Int
    ) -> Bool {
        if lhsIsOnScreen != rhsIsOnScreen {
            return lhsIsOnScreen
        }

        let lhsHasSpecificTitle = !lhsTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let rhsHasSpecificTitle = !rhsTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if lhsHasSpecificTitle != rhsHasSpecificTitle {
            return lhsHasSpecificTitle
        }

        let lhsArea = lhsBounds.width * lhsBounds.height
        let rhsArea = rhsBounds.width * rhsBounds.height
        if lhsArea != rhsArea {
            return lhsArea > rhsArea
        }

        if lhsSortScore != rhsSortScore {
            return lhsSortScore > rhsSortScore
        }

        return lhsOrderIndex < rhsOrderIndex
    }
}

// MARK: - Data types

private struct WindowCandidate {
    let id: CGWindowID
    let ownerPID: pid_t
    let bundleIdentifier: String?
    let appName: String
    let appIcon: NSImage?
    let windowTitle: String
    let bounds: CGRect
    let screenFrame: CGRect?
    let orderIndex: Int
    let sortScore: CGFloat
    let isOnScreen: Bool
    let isShareable: Bool
    let isUnknownIdentity: Bool
    let isFullscreen: Bool

    var historyIdentity: SwitcherHistoryIdentity { .appWindow(pid: ownerPID, windowID: id) }
    var sourceAppIdentifier: String { bundleIdentifier ?? "app-\(ownerPID)" }
    var previewCacheKey: String {
        AppSwitcher.previewCacheKey(
            for: historyIdentity,
            title: windowTitle,
            bounds: bounds,
            sourceAppIdentifier: sourceAppIdentifier
        )
    }
}

private struct WindowCandidateIdentityKey: Hashable {
    let ownerPID: pid_t
    let windowID: CGWindowID
}

struct WindowCandidateDeduplicationProbe: Equatable {
    let ownerPID: pid_t
    let windowID: CGWindowID
    let title: String
    let bounds: CGRect
    let orderIndex: Int
    let sortScore: CGFloat
    let isOnScreen: Bool
}
