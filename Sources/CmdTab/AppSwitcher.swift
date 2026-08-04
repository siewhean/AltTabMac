import AppKit
import CoreGraphics
import ApplicationServices
import os.log

// MARK: - SkyLight private API (window capture for minimized / off-screen windows)

enum SkyLightCapture {
    private struct WindowCaptureOptions: OptionSet {
        let rawValue: UInt32

        static let ignoreGlobalClipShape = WindowCaptureOptions(rawValue: 1 << 11)
        static let bestResolution = WindowCaptureOptions(rawValue: 1 << 8)
        static let fullSize = WindowCaptureOptions(rawValue: 1 << 19)
    }

    private typealias MainConnectionFn = @convention(c) () -> UInt32
    private typealias HWCaptureListFn  = @convention(c) (
        UInt32, UnsafeMutablePointer<CGWindowID>, UInt32, UInt32
    ) -> Unmanaged<CFArray>?

    private static let resolved: (mainConn: MainConnectionFn, hwCapture: HWCaptureListFn)? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", 0x1) else {
            return nil
        }
        guard let mainSym = dlsym(handle, "CGSMainConnectionID") ?? dlsym(handle, "SLSMainConnectionID"),
              let captureSym = dlsym(handle, "CGSHWCaptureWindowList") ?? dlsym(handle, "SLSHWCaptureWindowList") else {
            return nil
        }
        return (
            unsafeBitCast(mainSym,    to: MainConnectionFn.self),
            unsafeBitCast(captureSym, to: HWCaptureListFn.self)
        )
    }()

    private static let capabilityStatus = NativeCapabilityStatus(
        initial: NativeCapabilityStatusEvaluator.operationStatus(
            symbolAvailable: resolved != nil,
            resultCode: nil,
            capability: "SkyLight hardware preview capture"
        )
    )

    static var status: CapabilityStatus { capabilityStatus.status }

    static func captureWindow(_ windowID: CGWindowID) -> NSImage? {
        guard let fns = resolved else { return nil }
        let cid = fns.mainConn()
        guard cid != 0 else {
            capabilityStatus.record(.failed("SkyLight hardware preview capture returned an invalid connection."))
            return nil
        }
        var wid = windowID
        let options: WindowCaptureOptions = [.ignoreGlobalClipShape, .bestResolution, .fullSize]
        guard let cfArrayRef = fns.hwCapture(cid, &wid, 1, options.rawValue) else {
            capabilityStatus.record(.degraded("SkyLight hardware preview capture failed; public Core Graphics fallback is in use."))
            return nil
        }
        let cfArray = cfArrayRef.takeRetainedValue()
        guard CFArrayGetCount(cfArray) > 0,
              let rawPtr = CFArrayGetValueAtIndex(cfArray, 0) else {
            capabilityStatus.record(.degraded("SkyLight hardware preview capture returned no image; public Core Graphics fallback is in use."))
            return nil
        }
        let cgImage = Unmanaged<CGImage>.fromOpaque(rawPtr).takeUnretainedValue()
        guard cgImage.width >= 40, cgImage.height >= 30 else {
            capabilityStatus.record(.degraded("SkyLight hardware preview capture returned an invalid image; public Core Graphics fallback is in use."))
            return nil
        }
        capabilityStatus.record(.available)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

enum WindowServerFocus {
    private enum Mode: UInt32 {
        case allWindows = 0x100
        case userGenerated = 0x200
        case noWindows = 0x400
    }

    private typealias GetProcessForPIDFn = @convention(c) (
        pid_t,
        UnsafeMutablePointer<ProcessSerialNumber>
    ) -> OSStatus
    private typealias SetFrontProcessWithOptionsFn = @convention(c) (
        UnsafeMutablePointer<ProcessSerialNumber>,
        CGWindowID,
        Mode.RawValue
    ) -> CGError
    private typealias PostEventRecordToFn = @convention(c) (
        UnsafeMutablePointer<ProcessSerialNumber>,
        UnsafeMutablePointer<UInt8>
    ) -> CGError

    private static let resolved: (
        getProcessForPID: GetProcessForPIDFn,
        setFrontProcessWithOptions: SetFrontProcessWithOptionsFn,
        postEventRecordTo: PostEventRecordToFn
    )? = {
        let globalHandle = UnsafeMutableRawPointer(bitPattern: -2)
        guard let getProcessSym = dlsym(globalHandle, "GetProcessForPID"),
              let skyLightHandle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", 0x1),
              let setFrontSym = dlsym(skyLightHandle, "_SLPSSetFrontProcessWithOptions"),
              let postEventSym = dlsym(skyLightHandle, "SLPSPostEventRecordTo") else {
            return nil
        }
        return (
            unsafeBitCast(getProcessSym, to: GetProcessForPIDFn.self),
            unsafeBitCast(setFrontSym, to: SetFrontProcessWithOptionsFn.self),
            unsafeBitCast(postEventSym, to: PostEventRecordToFn.self)
        )
    }()

    private static let capabilityStatus = NativeCapabilityStatus(
        initial: NativeCapabilityStatusEvaluator.operationStatus(
            symbolAvailable: resolved != nil,
            resultCode: nil,
            capability: "SkyLight exact-window focus"
        )
    )

    static var status: CapabilityStatus { capabilityStatus.status }

    @discardableResult
    static func focusWindow(ownerPID: pid_t, windowID: CGWindowID) -> CapabilityStatus {
        guard windowID != 0 else {
            return capabilityStatus.record(.failed("SkyLight exact-window focus was requested without a window ID."))
        }
        guard let fns = resolved else { return capabilityStatus.status }
        var psn = ProcessSerialNumber()
        let processResult = fns.getProcessForPID(ownerPID, &psn)
        guard processResult == 0 else {
            return capabilityStatus.record(
                NativeCapabilityStatusEvaluator.operationStatus(
                    symbolAvailable: true,
                    resultCode: processResult,
                    capability: "SkyLight exact-window focus process lookup"
                )
            )
        }
        let frontResult = fns.setFrontProcessWithOptions(
            &psn,
            windowID,
            Mode.userGenerated.rawValue
        )
        guard frontResult == .success else {
            return capabilityStatus.record(.failed("SkyLight exact-window focus request failed with result \(frontResult.rawValue)."))
        }
        return capabilityStatus.record(
            makeKeyWindow(&psn, windowID: windowID, postEventRecordTo: fns.postEventRecordTo)
        )
    }

    private static func makeKeyWindow(
        _ psn: inout ProcessSerialNumber,
        windowID: CGWindowID,
        postEventRecordTo: PostEventRecordToFn
    ) -> CapabilityStatus {
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        bytes[0x3a] = 0x10
        var mutableWindowID = windowID
        memcpy(&bytes[0x3c], &mutableWindowID, MemoryLayout<UInt32>.size)
        memset(&bytes[0x20], 0xff, 0x10)
        bytes[0x08] = 0x01
        let mouseDownResult = postEventRecordTo(&psn, &bytes)
        guard mouseDownResult == .success else {
            return .failed("SkyLight exact-window focus mouse-down event failed with result \(mouseDownResult.rawValue).")
        }
        bytes[0x08] = 0x02
        let mouseUpResult = postEventRecordTo(&psn, &bytes)
        guard mouseUpResult == .success else {
            return .failed("SkyLight exact-window focus mouse-up event failed with result \(mouseUpResult.rawValue).")
        }
        return .available
    }
}

// MARK: - AppSwitcher

private let appSwitcherLog = OSLog(subsystem: "CmdTab", category: "AppSwitcher")

/// Enumerates real application windows and captures thumbnails for the switcher.
final class AppSwitcher: NSObject {
    private let preferences = SwitcherPreferences.shared
    private let history = SwitcherHistoryStore.shared

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
    private var _cachedItems: [SwitcherItem] = []
    private var previewCache: [String: PreviewCacheEntry] = [:]
    private let cacheLock = NSLock()
    private var previewPermissionMonitor: Timer?
    private let previewPermissionStateLock = NSLock()
    private var screenRecordingDenialIsConfirmed = false
    private var lastRefresh = Date.distantPast
    private var isRefreshing = false
    // Build work is serialized. A forced request that arrives during Phase 2
    // must therefore be replayed after capture instead of being dropped.
    private var needsForcedRefreshReplay = false
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
        super.init()

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
        previewPermissionMonitor = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            self?.clearProtectedPreviewCachesIfPermissionWasRevoked()
        }

        // Warm cache asynchronously. Do NOT wait — getItems() will return whatever
        // is currently cached (empty on first call, but refreshCacheIfNeeded will
        // populate it from onItemsChanged callbacks).
        warmCache(force: true)
    }

    deinit {
        previewPermissionMonitor?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
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
        warmCache(force: true)
    }

    @objc private func workspaceChanged() { warmCache(force: true) }
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

            let identity = self.currentFrontmostIdentity(for: frontmost) ?? fallbackIdentity
            self.history.noteActivation(identity)

            if case .appFallback = identity, attempt < self.observedActivationRetryLimit {
                self.noteObservedActivation(for: frontmost, attempt: attempt + 1)
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
        Date().timeIntervalSince(lastRefresh) > refreshInterval
    }

    func warmCache(force: Bool = false) {
        buildQueue.async { [weak self] in
            self?.refreshCacheIfNeeded(force: force)
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

    /// A confirmed TCC denial invalidates both the AppSwitcher phase-one cache
    /// and the process/window-scoped continuity store. Rebuild items without
    /// images so eligible membership, selection, and activation closures remain
    /// unchanged while the UI switches to its safe icon/placeholder state.
    private func clearProtectedPreviewCaches() {
        // Clear continuity before rebuilding items. Otherwise a permission regrant
        // racing this transition could let the initializer borrow an old image
        // into the new visible snapshot just before the store is emptied.
        SwitcherPreviewContinuityStore.clearProtectedContent()

        cacheLock.lock()
        previewCache.removeAll()
        _cachedItems = _cachedItems.map { item in
            SwitcherItem(
                title: item.title,
                subtitle: item.subtitle,
                icon: item.icon,
                previewImage: nil,
                backdropImage: nil,
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
        let items = _cachedItems
        cacheLock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.onItemsChanged?(items)
        }
    }

    private func clearProtectedPreviewCachesIfPermissionWasRevoked() {
        guard recordScreenRecordingDenialState(
            hasConfirmedScreenRecordingDenial()
        ) else { return }
        clearProtectedPreviewCaches()
    }

    /// Records transitions only: a persistent denial should clear protected
    /// content once, not rebuild and re-notify the visible switcher every poll.
    @discardableResult
    private func recordScreenRecordingDenialState(_ isConfirmed: Bool) -> Bool {
        previewPermissionStateLock.lock()
        defer { previewPermissionStateLock.unlock() }
        let newlyConfirmed = isConfirmed && !screenRecordingDenialIsConfirmed
        screenRecordingDenialIsConfirmed = isConfirmed
        return newlyConfirmed
    }

    /// Returns `true` only after the sustained-denial confirmation interval has
    /// elapsed. New capture is gated separately and immediately by preflight.
    private func hasConfirmedScreenRecordingDenial(now: Date = Date()) -> Bool {
        let preflightGranted: Bool
        if #available(macOS 10.15, *) {
            preflightGranted = CGPreflightScreenCaptureAccess()
        } else {
            preflightGranted = true
        }
        return !SwitcherPreviewPermissionState.effectiveAccess(
            hasCurrentCapture: false,
            preflightGranted: preflightGranted,
            now: now
        )
    }

    func currentFrontmostIdentity() -> SwitcherHistoryIdentity? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        return currentFrontmostIdentity(for: app)
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
        guard force || Date().timeIntervalSince(lastRefresh) > refreshInterval else { return }
        guard !isRefreshing else {
            if Self.shouldReplayForcedRefresh(force: force, isRefreshing: isRefreshing) {
                needsForcedRefreshReplay = true
                RuntimeDiagnostics.shared.increment(.forcedRefreshReplay)
            }
            return
        }
        isRefreshing = true

        let hasConfirmedDenial = hasConfirmedScreenRecordingDenial()
        if recordScreenRecordingDenialState(hasConfirmedDenial) {
            clearProtectedPreviewCaches()
        }

        // ── Phase 1: Reuse cached previews immediately ──────────────────────
        let context = enumerateWindows()
        let preservedPreviews = hasConfirmedDenial ? [:] : cachedPreviewSnapshot()
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

            let preflightGranted: Bool
            if #available(macOS 10.15, *) {
                preflightGranted = CGPreflightScreenCaptureAccess()
                if !preflightGranted {
                    os_log(.error, log: appSwitcherLog,
                           "Screen Recording permission not granted — thumbnails will be unavailable. Grant access in System Settings > Privacy & Security > Screen Recording.")
                }
            } else {
                preflightGranted = true
            }

            let fullItems = self.assembleItems(
                from: context,
                capturePreviews: SwitcherPreviewPermissionState.allowsNewCapture(
                    preflightGranted: preflightGranted
                ),
                previewFallbacks: preservedPreviews
            )

            let hasConfirmedDenialAfterCapture = self.hasConfirmedScreenRecordingDenial()
            let newlyConfirmedDenialAfterCapture = self.recordScreenRecordingDenialState(
                hasConfirmedDenialAfterCapture
            )
            self.cacheLock.lock()
            self._cachedItems = fullItems
            if !hasConfirmedDenialAfterCapture {
                self.updatePreviewCacheLocked(with: fullItems)
            } else {
                self.previewCache.removeAll()
            }
            self.cacheLock.unlock()
            self.lastRefresh = Date()
            self.isRefreshing = false
            let shouldReplayForcedRefresh = self.needsForcedRefreshReplay
            self.needsForcedRefreshReplay = false

            if newlyConfirmedDenialAfterCapture {
                // The confirmation may occur between item assembly and cache
                // publication. Replace that just-assembled snapshot before any
                // UI callback can expose its provisional cached images.
                self.clearProtectedPreviewCaches()
                if shouldReplayForcedRefresh {
                    self.refreshCacheIfNeeded(force: true)
                }
                return
            }

            // Notify UI again — thumbnails now available.
            DispatchQueue.main.async { [weak self] in
                self?.onItemsChanged?(fullItems)
            }

            if shouldReplayForcedRefresh {
                self.refreshCacheIfNeeded(force: true)
            }
        }
    }

    // MARK: - Build helpers

    /// Shared context from the fast window-enumeration pass, reused by both
    /// the icon-only and thumbnail assembly phases.
    private struct BuildContext {
        let candidates: [WindowCandidate]
        let runningApps: [NSRunningApplication]
    }

    /// Phase 1 core: enumerate windows, filter, sort, limit — no preview I/O.
    private func enumerateWindows() -> BuildContext {
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }

        let appsByPID: [pid_t: NSRunningApplication] = Dictionary(
            runningApps.map { ($0.processIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let allowedWindowIDsByPID = switcherDisplayWindowIDsByPID(for: runningApps)
        let historyEntries = history.snapshot()

        let allWindows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates = deduplicatedCandidates(
            from: allWindows.enumerated().compactMap { index, info in
                makeCandidate(
                    from: info,
                    orderIndex: index,
                    appsByPID: appsByPID,
                    allowedWindowIDsByPID: allowedWindowIDsByPID
                )
            }
        ).sorted {
            compareCandidates($0, $1, historyEntries: historyEntries)
        }

        let scopedCandidates = visibilityScopedCandidates(candidates)
        return BuildContext(candidates: limitedByApp(scopedCandidates), runningApps: runningApps)
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
            if capturePreviews, candidate.allowsPreviewCapture {
                let assets = capturePreviewAssets(for: candidate)
                let fallback = reusablePhaseTwoFallback(from: previewFallbacks[previewKey])
                if assets == nil {
                    RuntimeDiagnostics.shared.increment(.previewCaptureFailure)
                }
                if fallback != nil {
                    RuntimeDiagnostics.shared.increment(.previewFallbackPresentation)
                }
                preview = assets?.thumbnail ?? fallback
                backdrop = assets?.backdrop ?? previewFallbacks[previewKey]?.backdropImage ?? preview
            } else if !candidate.allowsPreviewCapture {
                // Window sharing controls capture permission only. It must not
                // remove a valid CG window from switcher membership or borrow
                // a stale image for content the WindowServer will not share.
                preview = nil
                backdrop = nil
            } else {
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

            return SwitcherItem(
                title: candidate.windowTitle,
                subtitle: candidate.appName,
                icon: candidate.appIcon,
                previewImage: preview,
                backdropImage: backdrop,
                backdropFrame: candidate.bounds,
                backdropSourceScreenFrame: candidate.screenFrame,
                previewCacheKey: previewKey,
                historyIdentity: candidate.historyIdentity,
                sourceAppIdentifier: candidate.sourceAppIdentifier,
                kind: .appWindow
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
                let sourceAppIdentifier = sourceAppIdentifier(for: app)
                let appName = app.localizedName ?? "Application"

                guard !preferences.excludesApp(identifier: sourceAppIdentifier, appName: appName) else {
                    return nil
                }

                guard Self.shouldIncludeFallbackApp(
                    processIdentifier: app.processIdentifier,
                    representedWindowPIDs: representedWindowPIDs,
                    seenFallbackPIDs: &seenFallbackPIDs
                ) else {
                    return nil
                }

                let identity = SwitcherHistoryIdentity.appFallback(
                    bundleID: sourceAppIdentifier,
                    pid: app.processIdentifier
                )

                return SwitcherItem(
                    title: appName,
                    subtitle: "",
                    icon: app.icon,
                    previewImage: nil,
                    historyIdentity: identity,
                    sourceAppIdentifier: sourceAppIdentifier,
                    kind: .appFallback
                ) { [weak self] in
                    self?.activateFallbackApplication(app, identity: identity)
                }
            }

        return windowItems + fallbackItems
    }

    private func reusablePhaseTwoFallback(from entry: PreviewCacheEntry?) -> NSImage? {
        guard let entry else { return nil }
        guard Date().timeIntervalSince(entry.capturedAt) <= maximumPhaseTwoFallbackAge else { return nil }
        return entry.image
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

        return screenFrame(containing: CGRect(origin: NSEvent.mouseLocation, size: .zero))
    }

    private func screenFrame(containing rect: CGRect) -> CGRect? {
        let point = NSPoint(x: rect.midX, y: rect.midY)
        if let containing = NSScreen.screens.first(where: { $0.frame.contains(point) }) {
            return containing.frame
        }

        return NSScreen.screens.first(where: { $0.frame.intersects(rect) })?.frame
    }

    // MARK: - Identity helpers

    private func currentFrontmostIdentity(for app: NSRunningApplication) -> SwitcherHistoryIdentity? {
        let allowedWindowIDsByPID = switcherDisplayWindowIDsByPID(for: [app])
        let historyEntries = history.snapshot()
        let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates = deduplicatedCandidates(
            from: windows.enumerated().compactMap { index, info in
                makeCandidate(
                    from: info,
                    orderIndex: index,
                    includeBackgroundWindows: true,
                    restrictToPID: app.processIdentifier,
                    allowedWindowIDsByPID: allowedWindowIDsByPID
                )
            }
        ).sorted {
            compareCandidates($0, $1, historyEntries: historyEntries)
        }

        if let focusedWindowID = focusedWindowID(for: app.processIdentifier) {
            if let focusedCandidate = candidates.first(where: { $0.id == focusedWindowID }) {
                return focusedCandidate.historyIdentity
            }
            return .appWindow(pid: app.processIdentifier, windowID: focusedWindowID)
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

        if lhs.sortScore != rhs.sortScore { return lhs.sortScore > rhs.sortScore }
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
        markPendingActivation(app.processIdentifier)
        schedulePendingActivationTimeout(for: app.processIdentifier)
        activateApplication(app, activateAllWindows: true)

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let preferredWindows = [
            preferredWindow(for: axApp, attribute: kAXFocusedWindowAttribute as CFString),
            preferredWindow(for: axApp, attribute: kAXMainWindowAttribute as CFString),
        ].compactMap { $0 }

        if let preferred = preferredWindows.first(where: { isStandardWindow($0) }) {
            raiseWindow(preferred, ownerPID: app.processIdentifier)
        } else {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
               let windows = value as? [AXUIElement],
               let target = windows.first(where: { isStandardWindow($0) }) ?? windows.first {
                raiseWindow(target, ownerPID: app.processIdentifier)
            }
        }

        ensureApplicationFrontmost(app, identity: identity, attempt: 0)
        // warmCache intentionally omitted: the NSWorkspace.didActivateApplication
        // notification fires after app.activate() and already calls warmCache(force: true)
        // via appActivated(_:). Calling it here too queues a redundant rebuild that
        // races with the AX focus operations above, adding perceived latency.
    }

    private func activateWindow(_ candidate: WindowCandidate) {
        guard let app = NSRunningApplication(processIdentifier: candidate.ownerPID) else { return }
        markPendingActivation(candidate.ownerPID)
        schedulePendingActivationTimeout(for: candidate.ownerPID)

        let focusStatus = WindowServerFocus.focusWindow(
            ownerPID: candidate.ownerPID,
            windowID: candidate.id
        )
        if focusStatus.level != .available {
            os_log(
                .error,
                log: appSwitcherLog,
                "Exact-window focus request degraded (pid=%{public}d, window=%{public}u, reason=%{public}@)",
                candidate.ownerPID,
                candidate.id,
                focusStatus.reason ?? "unknown"
            )
        }
        activateApplication(app, activateAllWindows: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + initialWindowFocusDelay) { [weak self] in
            self?.focusBestMatchingWindow(candidate, attempt: 0)
        }
        // warmCache intentionally omitted: NSWorkspace.didActivateApplication fires
        // after activate() and already triggers warmCache via appActivated(_:).
        // A second rebuild here races with the AX retry chain, doubling the work
        // and adding measurable latency to the switch.
    }

    // MARK: - Window focus (exact CGWindowID match first, then heuristic fallback)

    private func focusBestMatchingWindow(_ candidate: WindowCandidate, attempt: Int) {
        let axApp = AXUIElementCreateApplication(candidate.ownerPID)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement], !windows.isEmpty else {
            scheduleWindowFocusRetry(for: candidate, attempt: attempt)
            return
        }

        // ── Strategy 1: Exact CGWindowID match (eliminates wrong-window bugs) ──
        for axWindow in windows {
            if let axWinID = AXWindowIdentityLookup.windowID(for: axWindow), axWinID == candidate.id {
                raiseWindow(axWindow, ownerPID: candidate.ownerPID)
                ensureWindowFrontmost(candidate, attempt: attempt)
                return
            }
        }

        // ── Strategy 2: Score-based matching on standard windows only ──────────
        let standard = windows.filter { isStandardWindow($0) }
        let pool = standard.isEmpty ? windows : standard

        let scoredWindows = pool.map { ($0, matchScore(for: $0, candidate: candidate)) }
        guard let bestWindow = scoredWindows.max(by: { $0.1 < $1.1 }) else {
            scheduleWindowFocusRetry(for: candidate, attempt: attempt)
            return
        }

        if bestWindow.1 > 0 {
            raiseWindow(bestWindow.0, ownerPID: candidate.ownerPID)
            ensureWindowFrontmost(candidate, attempt: attempt)
        } else if attempt < 2 {
            scheduleWindowFocusRetry(for: candidate, attempt: attempt)
        } else {
            raiseWindow(windows[0], ownerPID: candidate.ownerPID)
            ensureWindowFrontmost(candidate, attempt: attempt)
        }
    }

    private func raiseWindow(_ axWindow: AXUIElement, ownerPID: pid_t) {
        let t = kCFBooleanTrue!
        let axApp = AXUIElementCreateApplication(ownerPID)
        if let axWindowID = AXWindowIdentityLookup.windowID(for: axWindow) {
            let focusStatus = WindowServerFocus.focusWindow(
                ownerPID: ownerPID,
                windowID: axWindowID
            )
            if focusStatus.level != .available {
                os_log(
                    .error,
                    log: appSwitcherLog,
                    "Exact-window focus retry degraded (pid=%{public}d, window=%{public}u, reason=%{public}@)",
                    ownerPID,
                    axWindowID,
                    focusStatus.reason ?? "unknown"
                )
            }
        }
        AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, t)
        AXUIElementSetAttributeValue(axApp, kAXMainWindowAttribute as CFString, axWindow)
        AXUIElementSetAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, axWindow)
        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, t)
        AXUIElementSetAttributeValue(axWindow, kAXFocusedAttribute as CFString, t)
        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
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

    private func scheduleWindowFocusRetry(for candidate: WindowCandidate, attempt: Int) {
        guard attempt < activationRetryLimit else {
            if clearPendingActivation(candidate.ownerPID) {
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
            self?.focusBestMatchingWindow(candidate, attempt: attempt + 1)
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

    private func ensureApplicationFrontmost(_ app: NSRunningApplication, identity: SwitcherHistoryIdentity, attempt: Int) {
        guard currentSystemFrontmostPID() != app.processIdentifier else {
            confirmActivation(identity: identity, pid: app.processIdentifier)
            return
        }
        guard attempt < activationRetryLimit else {
            if clearPendingActivation(app.processIdentifier) {
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
            guard let self else { return }
            guard self.currentSystemFrontmostPID() != app.processIdentifier else {
                self.confirmActivation(identity: identity, pid: app.processIdentifier)
                return
            }
            self.activateApplication(app, activateAllWindows: true)
            self.ensureApplicationFrontmost(app, identity: identity, attempt: attempt + 1)
        }
    }

    private func ensureWindowFrontmost(_ candidate: WindowCandidate, attempt: Int) {
        guard !isFrontmostWindow(candidate) else {
            confirmActivation(identity: candidate.historyIdentity, pid: candidate.ownerPID)
            return
        }
        guard attempt < activationRetryLimit,
              let app = NSRunningApplication(processIdentifier: candidate.ownerPID) else {
            if clearPendingActivation(candidate.ownerPID) {
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
            guard let self else { return }
            guard !self.isFrontmostWindow(candidate) else {
                self.confirmActivation(identity: candidate.historyIdentity, pid: candidate.ownerPID)
                return
            }
            self.activateApplication(app, activateAllWindows: true)
            self.focusBestMatchingWindow(candidate, attempt: attempt + 1)
        }
    }

    private func schedulePendingActivationTimeout(for pid: pid_t) {
        DispatchQueue.main.asyncAfter(deadline: .now() + pendingActivationTimeout) { [weak self] in
            guard let self else { return }
            _ = self.clearPendingActivation(pid)
        }
    }

    private func markPendingActivation(_ pid: pid_t) {
        pendingActivationPIDs.insert(pid)
    }

    @discardableResult
    private func clearPendingActivation(_ pid: pid_t) -> Bool {
        pendingActivationPIDs.remove(pid) != nil
    }

    private func confirmActivation(identity: SwitcherHistoryIdentity, pid: pid_t) {
        guard clearPendingActivation(pid) else { return }
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
           let exactWindow = windows.first(where: { AXWindowIdentityLookup.windowID(for: $0) == windowID }) {
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
        currentSystemFrontmostPID() == candidate.ownerPID &&
        focusedWindowID(for: candidate.ownerPID) == candidate.id
    }

    private func currentSystemFrontmostPID() -> pid_t {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return 0
        }
        return app.processIdentifier
    }

    private func focusedWindowID(for pid: pid_t) -> CGWindowID? {
        let axApp = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?

        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value) == .success,
           let focusedWindow = value {
            let axWindow = unsafeBitCast(focusedWindow, to: AXUIElement.self)
            if let windowID = AXWindowIdentityLookup.windowID(for: axWindow) {
                return windowID
            }
        }

        value = nil
        if AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &value) == .success,
           let mainWindow = value {
            let axWindow = unsafeBitCast(mainWindow, to: AXUIElement.self)
            return AXWindowIdentityLookup.windowID(for: axWindow)
        }

        return nil
    }

    private func matchScore(for axWindow: AXUIElement, candidate: WindowCandidate) -> CGFloat {
        let axTitle = axString(for: axWindow, attribute: kAXTitleAttribute as CFString) ?? ""
        let frame = axFrame(for: axWindow)
        let centerDistance = distanceBetweenCenters(frame, candidate.bounds)
        let areaDelta = abs((frame?.width ?? 0) * (frame?.height ?? 0) - candidate.bounds.width * candidate.bounds.height)

        var score: CGFloat = 0
        if !candidate.windowTitle.isEmpty && axTitle == candidate.windowTitle { score += 25_000 }
        else if !candidate.windowTitle.isEmpty && axTitle.contains(candidate.windowTitle) { score += 12_000 }
        if frame != nil {
            score += max(0, 8_000 - centerDistance * 8)
            score += max(0, 5_000 - areaDelta / 15)
        }
        return score
    }

    // MARK: - Candidate creation

    private func makeCandidate(
        from windowInfo: [String: Any],
        orderIndex: Int,
        includeBackgroundWindows: Bool? = nil,
        restrictToPID: pid_t? = nil,
        appsByPID: [pid_t: NSRunningApplication]? = nil,
        allowedWindowIDsByPID: [pid_t: Set<CGWindowID>] = [:]
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
                  found.activationPolicy == .regular,
                  found.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
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
        guard Self.isAllowedWindowID(windowID, allowedWindowIDs: allowedWindowIDsByPID[ownerPID]) else { return nil }

        let isOnScreen = (windowInfo[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
        let allowBackground = includeBackgroundWindows ?? (preferences.windowVisibilityScope == .allSpaces)
        if !allowBackground && !isOnScreen { return nil }

        let sharingState = (windowInfo[kCGWindowSharingState as String] as? NSNumber)?.intValue ?? 1

        let area = bounds.width * bounds.height
        let appName = app.localizedName ?? (windowInfo[kCGWindowOwnerName as String] as? String) ?? "Application"
        let windowTitle = title.isEmpty ? appName : title
        let sourceIdentifier = sourceAppIdentifier(for: app)
        guard !preferences.excludesApp(identifier: sourceIdentifier, appName: appName) else { return nil }
        guard !preferences.excludesWindowTitle(title) else { return nil }
        let historyIdentity = SwitcherHistoryIdentity.appWindow(pid: ownerPID, windowID: windowID)

        var sortScore = CGFloat(max(0, 1000 - orderIndex * 10))
        if isOnScreen { sortScore += 10_000 } else { sortScore += 500 }
        if !title.isEmpty { sortScore += 500 }
        sortScore += min(20_000, area / 120)
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
            allowsPreviewCapture: Self.shouldCapturePreview(sharingState: sharingState)
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

    private func switcherDisplayWindowIDsByPID(for apps: [NSRunningApplication]) -> [pid_t: Set<CGWindowID>] {
        var result: [pid_t: Set<CGWindowID>] = [:]
        result.reserveCapacity(apps.count)
        for app in apps {
            guard let windowIDs = switcherDisplayWindowIDs(for: app) else { continue }
            result[app.processIdentifier] = windowIDs
        }
        return result
    }

    private func switcherDisplayWindowIDs(for app: NSRunningApplication) -> Set<CGWindowID>? {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        let windows: [AXUIElement]
        if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
           let resolvedWindows = value as? [AXUIElement] {
            windows = resolvedWindows
        } else {
            windows = []
        }

        let displayWindows = windows.filter { isSwitcherDisplayWindow($0) }
        let displayIDs = displayWindows.compactMap { AXWindowIdentityLookup.windowID(for: $0) }

        // AX enumeration and the private ID bridge can be temporarily
        // incomplete. Never turn that uncertainty into a membership denylist:
        // CG candidates remain eligible until AX can identify every displayed
        // window used to build the filter.
        let preferredWindows = [
            preferredWindow(for: axApp, attribute: kAXFocusedWindowAttribute as CFString),
            preferredWindow(for: axApp, attribute: kAXMainWindowAttribute as CFString),
        ]
        .compactMap { $0 }
        let preferredIDs = preferredWindows.compactMap { AXWindowIdentityLookup.windowID(for: $0) }

        let hasUnresolvedAXWindowID = displayIDs.count != displayWindows.count ||
            preferredIDs.count != preferredWindows.count
        if hasUnresolvedAXWindowID {
            RuntimeDiagnostics.shared.increment(.accessibilityIdentityLookupFailure)
        }

        return Self.resolvedAllowedWindowIDs(
            displayWindowIDs: Set(displayIDs),
            preferredWindowIDs: preferredIDs,
            hasUnresolvedAXWindowID: hasUnresolvedAXWindowID
        )
    }

    private func isSwitcherDisplayWindow(_ axWindow: AXUIElement) -> Bool {
        Self.shouldAllowAXWindow(
            role: axString(for: axWindow, attribute: kAXRoleAttribute as CFString),
            subrole: axString(for: axWindow, attribute: kAXSubroleAttribute as CFString),
            parentRole: parentRole(for: axWindow),
            isMinimized: axBool(for: axWindow, attribute: kAXMinimizedAttribute as CFString)
        )
    }

    static func isAllowedWindowID(_ windowID: CGWindowID, allowedWindowIDs: Set<CGWindowID>?) -> Bool {
        guard let allowedWindowIDs else { return true }
        return allowedWindowIDs.contains(windowID)
    }

    static func shouldReplayForcedRefresh(force: Bool, isRefreshing: Bool) -> Bool {
        force && isRefreshing
    }

    static func shouldCapturePreview(sharingState: Int) -> Bool {
        sharingState != 0
    }

    static func resolvedAllowedWindowIDs(
        displayWindowIDs: Set<CGWindowID>,
        preferredWindowIDs: [CGWindowID],
        hasUnresolvedAXWindowID: Bool = false
    ) -> Set<CGWindowID>? {
        guard !hasUnresolvedAXWindowID else { return nil }
        let preferredSet = Set(preferredWindowIDs)
        if !displayWindowIDs.isEmpty {
            return displayWindowIDs.union(preferredSet)
        }

        if !preferredSet.isEmpty {
            return preferredSet
        }

        return nil
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
        allowFloating: Bool = false
    ) -> Bool {
        guard role == (kAXWindowRole as String) else { return false }
        guard !isMinimized else { return false }
        guard parentRole != (kAXWindowRole as String) else { return false }

        guard let subrole else { return false }
        if isSwitcherDisplaySubrole(subrole) { return true }
        if allowFloating && subrole == (kAXFloatingWindowSubrole as String) { return true }
        return false
    }

    // MARK: - Multi-strategy window capture

    private struct PreviewAssets {
        let thumbnail: NSImage
        let backdrop: NSImage
    }

    private func capturePreviewAssets(for candidate: WindowCandidate) -> PreviewAssets? {
        guard let backdrop = captureBackdropImage(for: candidate) else { return nil }
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

    private func captureBackdropImage(for candidate: WindowCandidate) -> NSImage? {
        // Prefer the WindowServer hardware path, but only accept it when the
        // captured image survives presentation validation. Some GPU-backed apps
        // (including Arc) can return a blank hardware frame even though the
        // public Core Graphics capture path can still produce a valid preview.
        return Self.resolvePreferredCapture(
            preferred: SkyLightCapture.captureWindow(candidate.id),
            prepare: { self.preparedWindowCaptureImage($0) }
        ) {
            let framedBest: CGWindowImageOption = [.bestResolution]
            if let img = cgCapture(.null, .optionIncludingWindow, candidate.id, framedBest, minW: 80, minH: 60) { return img }
            if let img = cgCapture(candidate.bounds, .optionIncludingWindow, candidate.id, framedBest, minW: 80, minH: 60) { return img }

            let croppedBest: CGWindowImageOption = [.boundsIgnoreFraming, .bestResolution]
            if let img = cgCapture(.null, .optionIncludingWindow, candidate.id, croppedBest, minW: 80, minH: 60) { return img }
            if let img = cgCapture(candidate.bounds, .optionIncludingWindow, candidate.id, croppedBest, minW: 80, minH: 60) { return img }
            let nominal: CGWindowImageOption = [.boundsIgnoreFraming, .nominalResolution]
            if let img = cgCapture(.null, .optionIncludingWindow, candidate.id, nominal, minW: 40, minH: 30) { return img }

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
        guard let dp = cgImage.dataProvider, let data = dp.data else { return cgImage }
        let ptr = CFDataGetBytePtr(data)!
        let len = CFDataGetLength(data)
        let bpp = cgImage.bitsPerPixel / 8
        guard bpp >= 4 else { return cgImage }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let insetLimit = max(0, min(maxInset, min(width / 4, height / 4)))
        guard insetLimit > 0 else { return cgImage }

        func alphaOffset(for base: Int) -> Int {
            switch cgImage.alphaInfo {
            case .premultipliedFirst, .first, .noneSkipFirst:
                return base
            default:
                return base + bpp - 1
            }
        }

        func rowHasOpaquePixels(_ y: Int) -> Bool {
            for x in 0..<width {
                let base = y * bytesPerRow + x * bpp
                let alphaIndex = alphaOffset(for: base)
                if alphaIndex >= 0, alphaIndex < len, ptr[alphaIndex] >= alphaThreshold {
                    return true
                }
            }
            return false
        }

        func columnHasOpaquePixels(_ x: Int) -> Bool {
            for y in 0..<height {
                let base = y * bytesPerRow + x * bpp
                let alphaIndex = alphaOffset(for: base)
                if alphaIndex >= 0, alphaIndex < len, ptr[alphaIndex] >= alphaThreshold {
                    return true
                }
            }
            return false
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

        let cropRect = CGRect(
            x: leftInset,
            y: bottomInset,
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
        !isImageEffectivelyBlank(cgImage) && !isImageEffectivelyBlack(cgImage)
    }

    private struct NormalizedRGBASample {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
        let alpha: UInt8
    }

    /// Normalizes capture validation to a 16×16 grid. This avoids deciding
    /// that a legitimate dark window is blank from a few unlucky pixels while
    /// keeping the validation work bounded independently of Retina size.
    private static func normalizedRGBASamples(from cgImage: CGImage) -> [NormalizedRGBASample]? {
        guard let provider = cgImage.dataProvider, let data = provider.data,
              let pointer = CFDataGetBytePtr(data) else { return nil }
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let width = cgImage.width
        let height = cgImage.height
        guard bytesPerPixel >= 4, width > 0, height > 0 else { return [] }

        let length = CFDataGetLength(data)
        let bytesPerRow = cgImage.bytesPerRow
        let alphaFirst: Bool
        let hasAlpha: Bool
        switch cgImage.alphaInfo {
        case .premultipliedFirst, .first, .noneSkipFirst:
            alphaFirst = true
            hasAlpha = cgImage.alphaInfo != .noneSkipFirst
        case .none:
            alphaFirst = false
            hasAlpha = false
        default:
            alphaFirst = false
            hasAlpha = true
        }

        var samples: [NormalizedRGBASample] = []
        samples.reserveCapacity(16 * 16)
        for row in 0..<16 {
            for column in 0..<16 {
                let x = min(width - 1, (column * 2 + 1) * width / 32)
                let y = min(height - 1, (row * 2 + 1) * height / 32)
                let base = y * bytesPerRow + x * bytesPerPixel
                guard base >= 0, base + 3 < length else { continue }
                if alphaFirst {
                    samples.append(.init(
                        red: pointer[base + 1], green: pointer[base + 2], blue: pointer[base + 3],
                        alpha: hasAlpha ? pointer[base] : 255
                    ))
                } else {
                    samples.append(.init(
                        red: pointer[base], green: pointer[base + 1], blue: pointer[base + 2],
                        alpha: hasAlpha ? pointer[base + bytesPerPixel - 1] : 255
                    ))
                }
            }
        }
        return samples
    }

    private static func isImageEffectivelyBlank(_ cgImage: CGImage) -> Bool {
        guard let samples = normalizedRGBASamples(from: cgImage) else { return true }
        return samples.filter { $0.alpha > 10 }.count < 2
    }

    private static func isImageEffectivelyBlack(_ cgImage: CGImage) -> Bool {
        guard let samples = normalizedRGBASamples(from: cgImage) else { return true }
        let luminances = samples.compactMap { sample -> Double? in
            guard sample.alpha > 10 else { return nil }
            let red = Double(sample.red) / 255.0
            let green = Double(sample.green) / 255.0
            let blue = Double(sample.blue) / 255.0
            return (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        }

        guard !luminances.isEmpty else { return true }

        let minLuminance = luminances.min() ?? 0
        let maxLuminance = luminances.max() ?? 0
        let averageLuminance = luminances.reduce(0, +) / Double(luminances.count)

        return averageLuminance < 0.07 && (maxLuminance - minLuminance) < 0.035
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

    private func axFrame(for element: AXUIElement) -> CGRect? {
        var pv: CFTypeRef?, sv: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &pv) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sv) == .success,
              let pAX = pv, let sAX = sv else { return nil }
        var pos = CGPoint.zero; var sz = CGSize.zero
        guard AXValueGetType(pAX as! AXValue) == .cgPoint,
              AXValueGetValue(pAX as! AXValue, .cgPoint, &pos),
              AXValueGetType(sAX as! AXValue) == .cgSize,
              AXValueGetValue(sAX as! AXValue, .cgSize, &sz) else { return nil }
        return CGRect(origin: pos, size: sz)
    }

    private func distanceBetweenCenters(_ lhs: CGRect?, _ rhs: CGRect) -> CGFloat {
        guard let lhs else { return 10_000 }
        let dx = lhs.midX - rhs.midX, dy = lhs.midY - rhs.midY
        return sqrt(dx * dx + dy * dy)
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
    let allowsPreviewCapture: Bool

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
