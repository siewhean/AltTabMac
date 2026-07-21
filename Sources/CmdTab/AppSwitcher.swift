import AppKit
import CoreGraphics
import ApplicationServices
import ScreenCaptureKit
import os.log

final class LockedCaptureResult<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value?

    func store(_ value: Value?) {
        lock.lock()
        self.value = value
        lock.unlock()
    }

    func load() -> Value? {
        lock.lock()
        let snapshot = value
        lock.unlock()
        return snapshot
    }
}

/// Isolates the deprecated Core Graphics capture path from the switcher's
/// serial build queue. Some modern macOS sessions leave this call blocked in
/// the capture service; after one timeout, the circuit remains open until that
/// attempt actually returns so repeated refreshes cannot leak worker threads.
final class BoundedCaptureGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private let queue: DispatchQueue
    private let failureCooldown: TimeInterval
    private var isInFlight = false
    private var retryAfter = Date.distantPast

    init(label: String, failureCooldown: TimeInterval = 0) {
        queue = DispatchQueue(label: label, qos: .utility)
        self.failureCooldown = failureCooldown
    }

    func run(
        timeout: TimeInterval,
        operation: @escaping @Sendable () -> Value?
    ) -> Value? {
        lock.lock()
        guard !isInFlight, Date() >= retryAfter else {
            lock.unlock()
            return nil
        }
        isInFlight = true
        lock.unlock()

        let semaphore = DispatchSemaphore(value: 0)
        let result = LockedCaptureResult<Value>()
        queue.async { [self] in
            let captured = autoreleasepool(invoking: operation)
            result.store(captured)
            lock.lock()
            if captured == nil {
                retryAfter = Date().addingTimeInterval(failureCooldown)
            }
            isInFlight = false
            lock.unlock()
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            return nil
        }
        return result.load()
    }
}

private let legacyCaptureGate = BoundedCaptureGate<NSImage>(
    label: "CmdTab.AppSwitcher.LegacyCapture",
    failureCooldown: 1
)

// MARK: - SkyLight private API (window capture for minimized / off-screen windows)

private enum SkyLightCapture {
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

    static func captureWindow(_ windowID: CGWindowID) -> NSImage? {
        guard let fns = resolved else { return nil }
        let cid = fns.mainConn()
        var wid = windowID
        let options: WindowCaptureOptions = [.ignoreGlobalClipShape, .bestResolution, .fullSize]
        guard let cfArrayRef = fns.hwCapture(cid, &wid, 1, options.rawValue) else { return nil }
        let cfArray = cfArrayRef.takeRetainedValue()
        guard CFArrayGetCount(cfArray) > 0,
              let rawPtr = CFArrayGetValueAtIndex(cfArray, 0) else { return nil }
        let cgImage = Unmanaged<CGImage>.fromOpaque(rawPtr).takeUnretainedValue()
        guard cgImage.width >= 40, cgImage.height >= 30 else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

// MARK: - _AXUIElementGetWindow (exact CGWindowID → AXUIElement matching)
//
// Private but stable API used by every major window manager (yabai, AltTab,
// Amethyst, etc.). Resolves the CGWindowID for an AX window element so we can
// match the exact window the user clicked on — eliminating the heuristic
// title/position scoring that causes "wrong window focused" bugs.

private enum AXWindowIDLookup {
    private typealias GetWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> Int32

    private static let resolved: GetWindowFn? = {
        guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow") else { return nil }
        return unsafeBitCast(sym, to: GetWindowFn.self)
    }()

    /// Returns the CGWindowID for an AXUIElement window, or nil if unavailable.
    static func windowID(for element: AXUIElement) -> CGWindowID? {
        guard let fn = resolved else { return nil }
        var wid: CGWindowID = 0
        guard fn(element, &wid) == 0 else { return nil }  // 0 = kAXErrorSuccess
        return wid
    }
}

private enum WindowServerFocus {
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

    static func focusWindow(ownerPID: pid_t, windowID: CGWindowID) {
        guard windowID != 0 else { return }
        guard let fns = resolved else { return }
        var psn = ProcessSerialNumber()
        guard fns.getProcessForPID(ownerPID, &psn) == 0 else { return }
        _ = fns.setFrontProcessWithOptions(&psn, windowID, Mode.userGenerated.rawValue)
        makeKeyWindow(&psn, windowID: windowID, postEventRecordTo: fns.postEventRecordTo)
    }

    private static func makeKeyWindow(
        _ psn: inout ProcessSerialNumber,
        windowID: CGWindowID,
        postEventRecordTo: PostEventRecordToFn
    ) {
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        bytes[0x3a] = 0x10
        var mutableWindowID = windowID
        memcpy(&bytes[0x3c], &mutableWindowID, MemoryLayout<UInt32>.size)
        memset(&bytes[0x20], 0xff, 0x10)
        bytes[0x08] = 0x01
        _ = postEventRecordTo(&psn, &bytes)
        bytes[0x08] = 0x02
        _ = postEventRecordTo(&psn, &bytes)
    }
}

// MARK: - AppSwitcher

private let appSwitcherLog = OSLog(subsystem: "CmdTab", category: "AppSwitcher")

/// Enumerates real application windows and captures thumbnails for the switcher.
final class AppSwitcher: NSObject {
    private let preferences = SwitcherPreferences.shared
    private let history = SwitcherHistoryStore.shared

    enum AllowedWindowPolicy: Equatable {
        case unrestricted
        case fallbackHeuristics
        case restricted(Set<CGWindowID>)
        case noneTrusted
    }

    struct PreviewCacheEntry {
        let image: NSImage
        let backdropImage: NSImage?
        let capturedAt: Date
        var lastAccessAt: Date
        let byteCost: Int
    }

    // ── Non-blocking cache architecture ──────────────────────────────────────
    // The build queue runs thumbnail capture off the main thread.
    // The cacheLock protects reads/writes to _cachedItems so getItems() never
    // blocks on a pending thumbnail capture — it returns stale data instantly
    // and the UI updates when onItemsChanged fires.
    private let buildQueue = DispatchQueue(label: "CmdTab.AppSwitcher.Build", qos: .userInitiated)
    private var _cachedItems: [SwitcherItem] = []
    private var previewCache: [String: PreviewCacheEntry] = [:]
    private var stalePreviewKeys = Set<String>()
    private var previewCacheBytes = 0
    private let cacheLock = NSLock()
    private var lastRefresh = Date.distantPast
    private var isRefreshing = false
    private var consecutiveEmptyEnumerations = 0
    private let refreshInterval: TimeInterval = 0.8
    private let maximumEmptyEnumerationRetries = 2
    private let maxPreviewCacheBytes = 320 * 1024 * 1024
    private let previewSoftTTL: TimeInterval = 20
    private let previewHardTTL: TimeInterval = 180
    private let activationRetryLimit = 8
    private let pendingActivationTimeout: TimeInterval = 4.0
    private let initialWindowFocusDelay: TimeInterval = 0.08
    private let observedActivationRetryLimit = 3
    private let observedActivationRetryDelay: TimeInterval = 0.05

    var onItemsChanged: (([SwitcherItem]) -> Void)?
    var onActivationConfirmed: ((SwitcherHistoryIdentity, pid_t) -> Void)?
    private var pendingActivationPIDs = Set<pid_t>()
    private var pendingRuntimeQASessionsByPID: [pid_t: String] = [:]

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

        // The owning controller wires callbacks before starting the first build.
        // Starting here races its synchronous prime during application launch.
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
        if !Self.hasScreenRecordingPermission() {
            let cached = cachedItemsSnapshot()
            if !cached.isEmpty, cached.allSatisfy({ $0.previewImage == nil }) {
                if shouldRefresh() {
                    warmCache(force: false)
                }
                return cached
            }
            return skeletonOnlyItemsForDeniedCapture()
        }

        // Return cached items immediately without waiting.
        // Trigger a background refresh if stale.
        let cached = cachedItemsSnapshot()
        if cached.isEmpty {
            return primeCacheIfNeeded()
        }

        let needsFirstPreviewCapture = cached.contains { $0.previewImage == nil }
        if needsFirstPreviewCapture || shouldRefresh() {
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

    /// Populate a provisional window list when the background builder has not
    /// produced anything yet. Preview capture always remains on `buildQueue` so
    /// controller construction and hotkey installation never wait on it.
    @discardableResult
    func primeCacheIfNeeded() -> [SwitcherItem] {
        if !Self.hasScreenRecordingPermission() {
            return skeletonOnlyItemsForDeniedCapture()
        }

        let existing = cachedItemsSnapshot()
        guard existing.isEmpty else { return existing }

        let context = enumerateWindows()
        let preservedPreviews = cachedPreviewSnapshot()
        let provisionalItems = assembleItems(
            from: context,
            capturePreviews: false,
            previewFallbacks: preservedPreviews,
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

    private func skeletonOnlyItemsForDeniedCapture() -> [SwitcherItem] {
        let context = enumerateWindows()
        let skeletonItems = assembleItems(
            from: context,
            capturePreviews: false,
            previewFallbacks: [:],
            allowPreviewlessItems: true
        )

        cacheLock.lock()
        _cachedItems = skeletonItems
        previewCache.removeAll()
        stalePreviewKeys.removeAll()
        previewCacheBytes = 0
        cacheLock.unlock()
        return skeletonItems
    }

    private func shouldRefresh() -> Bool {
        cacheLock.lock()
        let refreshRequired = Date().timeIntervalSince(lastRefresh) > refreshInterval
        cacheLock.unlock()
        return refreshRequired
    }

    func warmCache(force: Bool = false) {
        buildQueue.async { [weak self] in
            self?.refreshCacheIfNeeded(force: force)
        }
    }

    func resetCacheForRuntimeQA(completion: (() -> Void)? = nil) {
        guard RuntimeQAEvidenceRecorder.shared.isEnabled else {
            completion?()
            return
        }
        buildQueue.sync {
            self.cacheLock.lock()
            self._cachedItems.removeAll()
            self.previewCache.removeAll()
            self.stalePreviewKeys.removeAll()
            self.previewCacheBytes = 0
            self.lastRefresh = .distantPast
            self.cacheLock.unlock()
            RuntimeQAEvidenceRecorder.shared.recordCacheReset()
        }
        completion?()
    }

    func waitForRuntimeQAIdle(completion: @escaping () -> Void) {
        guard RuntimeQAEvidenceRecorder.shared.isEnabled else {
            completion()
            return
        }
        buildQueue.async {
            DispatchQueue.main.async(execute: completion)
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

    func currentFrontmostIdentity() -> SwitcherHistoryIdentity? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        let identity = currentFrontmostIdentity(for: app)
        if let identity {
            // NSWorkspace does not emit an app-activation notification when
            // focus moves between windows of the already-frontmost app.
            history.noteActivation(identity)
        }
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
        guard !isRefreshing else { return }
        isRefreshing = true

        // ── Phase 1: Reuse cached previews immediately ──────────────────────
        let now = Date()
        let context = enumerateWindows()
        let cachedItems = cachedItemsSnapshot()
        if Self.shouldPreserveCachedItems(
            cachedItemCount: cachedItems.count,
            enumeratedCandidateCount: context.candidates.count,
            consecutiveEmptyEnumerations: consecutiveEmptyEnumerations,
            maximumRetries: maximumEmptyEnumerationRetries
        ) {
            consecutiveEmptyEnumerations += 1
            isRefreshing = false
            os_log(
                .info,
                log: appSwitcherLog,
                "Transient empty window enumeration; preserving %{public}d cached items (retry %{public}d/%{public}d)",
                cachedItems.count,
                consecutiveEmptyEnumerations,
                maximumEmptyEnumerationRetries
            )
            buildQueue.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.refreshCacheIfNeeded(force: true)
            }
            return
        }
        consecutiveEmptyEnumerations = context.candidates.isEmpty
            ? consecutiveEmptyEnumerations + 1
            : 0
        let screenRecordingGranted = Self.hasScreenRecordingPermission()
        let preservedPreviews = screenRecordingGranted ? cachedPreviewSnapshot() : [:]
        let provisionalItems = assembleItems(
            from: context,
            capturePreviews: false,
            previewFallbacks: preservedPreviews,
            allowPreviewlessItems: true
        )
        let refreshPreviewKeys = previewKeysNeedingRefresh(
            for: context.candidates,
            previewFallbacks: preservedPreviews,
            now: now
        )
        let cachedPreviewCount = provisionalItems.lazy.filter { $0.previewImage != nil }.count
        let captureOperationID = RuntimeQAEvidenceRecorder.shared.beginCaptureRefresh(
            totalItems: provisionalItems.count,
            cachedPreviewCount: cachedPreviewCount,
            requestedPreviewCount: refreshPreviewKeys.count
        )

        cacheLock.lock()
        _cachedItems = provisionalItems
        cacheLock.unlock()

        // Notify UI immediately — existing thumbnails stay in place while the
        // fresh capture pass updates anything new or changed. New or
        // uncapturable windows remain visible with their app identity.
        DispatchQueue.main.async { [weak self] in
            self?.onItemsChanged?(provisionalItems)
        }

        // ── Phase 2: Thumbnail pass (slow) ─────────────────────────────────
        // Schedule Phase 2 as a separate, independent work item so Phase 1
        // notification to the UI is not delayed by thumbnail capture.
        buildQueue.async { [weak self] in
            guard let self else { return }

            if !screenRecordingGranted {
                os_log(.default, log: appSwitcherLog,
                       "Screen Recording permission not granted - using skeleton-only previews.")
            }

            let fullItems: [SwitcherItem]
            var successfulCaptureCount = 0
            if !screenRecordingGranted || refreshPreviewKeys.isEmpty {
                fullItems = provisionalItems
            } else {
                let screenCaptureWindows = self.screenCaptureKitWindowSnapshot()
                fullItems = self.assembleItems(
                    from: context,
                    capturePreviews: true,
                    previewFallbacks: preservedPreviews,
                    allowPreviewlessItems: true,
                    screenCaptureWindows: screenCaptureWindows,
                    refreshPreviewKeys: refreshPreviewKeys,
                    onCaptureAttempt: { succeeded in
                        if succeeded { successfulCaptureCount += 1 }
                    }
                )
            }

            let capturedPreviewCount = fullItems.lazy.filter { $0.previewImage != nil }.count
            os_log(
                .default,
                log: appSwitcherLog,
                "Preview refresh permission=%{public}d candidates=%{public}d requested=%{public}d captured=%{public}d",
                screenRecordingGranted ? 1 : 0,
                context.candidates.count,
                refreshPreviewKeys.count,
                capturedPreviewCount
            )
            RuntimeQAEvidenceRecorder.shared.finishCaptureRefresh(
                operationID: captureOperationID,
                totalItems: fullItems.count,
                requestedPreviewCount: refreshPreviewKeys.count,
                successfulPreviewCount: successfulCaptureCount
            )

            self.cacheLock.lock()
            self._cachedItems = fullItems
            if !screenRecordingGranted {
                self.previewCache.removeAll()
                self.stalePreviewKeys.removeAll()
                self.previewCacheBytes = 0
            }
            self.updatePreviewCacheLocked(with: fullItems)
            self.lastRefresh = Date()
            self.cacheLock.unlock()
            self.isRefreshing = false

            // Notify UI again — thumbnails now available.
            DispatchQueue.main.async { [weak self] in
                self?.onItemsChanged?(fullItems)
            }
        }
    }

    // MARK: - Build helpers

    /// Shared context from the fast window-enumeration pass, reused by both
    /// the icon-only and thumbnail assembly phases.
    private struct BuildContext {
        let candidates: [WindowCandidate]
    }

    /// Phase 1 core: enumerate windows, filter, sort, limit — no preview I/O.
    private func enumerateWindows() -> BuildContext {
        let capturePermissionGranted = Self.hasScreenRecordingPermission()
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }

        let appsByPID: [pid_t: NSRunningApplication] = Dictionary(
            runningApps.map { ($0.processIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let allowedWindowPoliciesByPID = Self.policiesWithPerApplicationFallback(
            switcherDisplayWindowIDsByPID(for: runningApps)
        )

        let allWindows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates = deduplicatedCandidates(
            from: allWindows.enumerated().compactMap { index, info in
                makeCandidate(
                    from: info,
                    orderIndex: index,
                    appsByPID: appsByPID,
                    allowedWindowPoliciesByPID: allowedWindowPoliciesByPID,
                    allowUnsharedWindows: !capturePermissionGranted
                )
            }
        ).sorted(by: compareCandidates)

        let scopedCandidates = visibilityScopedCandidates(candidates)
        os_log(
            .info,
            log: appSwitcherLog,
            "Window enumeration apps=%{public}d surfaces=%{public}d candidates=%{public}d scoped=%{public}d",
            runningApps.count,
            allWindows.count,
            candidates.count,
            scopedCandidates.count
        )
        return BuildContext(
            candidates: scopedCandidates
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
        allowPreviewlessItems: Bool = false,
        screenCaptureWindows: [CGWindowID: SCWindow] = [:],
        refreshPreviewKeys: Set<String>? = nil,
        onCaptureAttempt: ((Bool) -> Void)? = nil
    ) -> [SwitcherItem] {
        let now = Date()
        var reusedPreviewKeys = Set<String>()
        let windowItems: [SwitcherItem] = context.candidates.compactMap { candidate -> SwitcherItem? in
            let previewKey = candidate.previewCacheKey
            let preview: NSImage?
            let backdrop: NSImage?
            if capturePreviews {
                if let refreshPreviewKeys, !refreshPreviewKeys.contains(previewKey) {
                    let cachedPreview = previewFallbacks[previewKey]
                    preview = cachedPreview?.image
                    backdrop = cachedPreview?.backdropImage ?? preview
                } else {
                    let assets = capturePreviewAssets(
                        for: candidate,
                        screenCaptureWindow: screenCaptureWindows[candidate.id]
                    )
                    onCaptureAttempt?(assets != nil)
                    preview = assets?.thumbnail ?? Self.reusablePhaseTwoFallback(from: previewFallbacks[previewKey])
                    backdrop = assets?.backdrop ?? previewFallbacks[previewKey]?.backdropImage ?? preview
                }
            } else {
                let immediate = bestImmediatePreview(for: previewKey, from: previewFallbacks)
                preview = immediate.previewImage
                backdrop = immediate.backdropImage
                enqueueBackgroundRefreshIfStale(
                    previewKey: previewKey,
                    now: now,
                    previewFallbacks: previewFallbacks
                )
                if immediate.previewImage != nil || immediate.backdropImage != nil {
                    reusedPreviewKeys.insert(previewKey)
                }
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
                isSkeletonOnly: preview == nil && allowPreviewlessItems,
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
        if !capturePreviews {
            markPreviewCacheAccessed(keys: reusedPreviewKeys, at: now)
        }
        return windowItems
    }

    static func reusablePhaseTwoFallback(from entry: PreviewCacheEntry?) -> NSImage? {
        entry?.image
    }

    static func shouldIncludeFallbackApp(
        processIdentifier: pid_t,
        sourceAppIdentifier: String,
        representedWindowPIDs: Set<pid_t>,
        representedWindowAppIdentifiers: Set<String>,
        seenFallbackAppIdentifiers: inout Set<String>
    ) -> Bool {
        _ = processIdentifier
        _ = sourceAppIdentifier
        _ = representedWindowPIDs
        _ = representedWindowAppIdentifiers
        _ = seenFallbackAppIdentifiers
        return false
    }

    static func shouldDisplayWindowItem(
        previewImage: NSImage?,
        capturePreviews: Bool,
        allowPreviewlessItems: Bool = false
    ) -> Bool {
        _ = capturePreviews
        if previewImage != nil { return true }
        return allowPreviewlessItems
    }

    static func shouldPreserveCachedItems(
        cachedItemCount: Int,
        enumeratedCandidateCount: Int,
        consecutiveEmptyEnumerations: Int,
        maximumRetries: Int
    ) -> Bool {
        cachedItemCount > 0
            && enumeratedCandidateCount == 0
            && consecutiveEmptyEnumerations < maximumRetries
    }

    static func hasScreenRecordingPermission() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    private func updatePreviewCacheLocked(with items: [SwitcherItem]) {
        let now = Date()
        let activeKeys = Set(items.map(\.previewCacheKey))

        for item in items {
            guard let preview = item.previewImage ?? item.backdropImage else { continue }
            let cachedImage = item.previewImage ?? preview
            let entry = Self.updatedPreviewCacheEntry(
                existing: previewCache[item.previewCacheKey],
                image: cachedImage,
                backdropImage: item.backdropImage,
                now: now,
                byteCost: byteCost(previewImage: cachedImage, backdropImage: item.backdropImage)
            )
            if let existing = previewCache[item.previewCacheKey] {
                previewCacheBytes -= existing.byteCost
            }
            previewCache[item.previewCacheKey] = entry
            stalePreviewKeys.remove(item.previewCacheKey)
            previewCacheBytes += entry.byteCost
        }

        pruneInactivePreviewCacheEntriesLocked(activeKeys: activeKeys, now: now)
        trimPreviewCacheToBudgetLocked(now: now)
    }

    static func updatedPreviewCacheEntry(
        existing: PreviewCacheEntry?,
        image: NSImage,
        backdropImage: NSImage?,
        now: Date,
        byteCost: Int
    ) -> PreviewCacheEntry {
        if var existing, existing.image === image {
            existing.lastAccessAt = now
            return existing
        }
        return PreviewCacheEntry(
            image: image,
            backdropImage: backdropImage,
            capturedAt: now,
            lastAccessAt: now,
            byteCost: byteCost
        )
    }

    private func bestImmediatePreview(
        for key: String,
        from previewFallbacks: [String: PreviewCacheEntry]
    ) -> (previewImage: NSImage?, backdropImage: NSImage?) {
        guard let entry = previewFallbacks[key] else { return (nil, nil) }
        return (entry.image, entry.backdropImage ?? entry.image)
    }

    private func enqueueBackgroundRefreshIfStale(
        previewKey: String,
        now: Date,
        previewFallbacks: [String: PreviewCacheEntry]
    ) {
        guard let entry = previewFallbacks[previewKey] else { return }
        guard now.timeIntervalSince(entry.capturedAt) >= previewSoftTTL else { return }
        cacheLock.lock()
        stalePreviewKeys.insert(previewKey)
        cacheLock.unlock()
    }

    private func previewKeysNeedingRefresh(
        for candidates: [WindowCandidate],
        previewFallbacks: [String: PreviewCacheEntry],
        now: Date
    ) -> Set<String> {
        let candidateKeys = Set(candidates.map(\.previewCacheKey))
        let cachedKeys = Set(previewFallbacks.keys)
        let missingKeys = candidateKeys.subtracting(cachedKeys)
        let staleByAge = candidateKeys.filter { key in
            guard let entry = previewFallbacks[key] else { return false }
            return now.timeIntervalSince(entry.capturedAt) >= previewSoftTTL
        }

        cacheLock.lock()
        let staleBySignal = stalePreviewKeys.intersection(candidateKeys)
        stalePreviewKeys.subtract(staleBySignal)
        cacheLock.unlock()

        return missingKeys.union(staleByAge).union(staleBySignal)
    }

    private func markPreviewCacheAccessed(keys: Set<String>, at now: Date) {
        guard !keys.isEmpty else { return }
        cacheLock.lock()
        for key in keys {
            guard var entry = previewCache[key] else { continue }
            entry.lastAccessAt = now
            previewCache[key] = entry
        }
        cacheLock.unlock()
    }

    private func pruneInactivePreviewCacheEntriesLocked(activeKeys: Set<String>, now: Date) {
        let removableKeys = previewCache.compactMap { key, entry -> String? in
            guard !activeKeys.contains(key) else { return nil }
            guard now.timeIntervalSince(entry.capturedAt) >= previewHardTTL else { return nil }
            return key
        }
        for key in removableKeys {
            guard let removed = previewCache.removeValue(forKey: key) else { continue }
            stalePreviewKeys.remove(key)
            previewCacheBytes -= removed.byteCost
        }
    }

    private func trimPreviewCacheToBudgetLocked(now: Date) {
        let evictionKeys = Self.previewCacheEvictionKeys(
            entries: previewCache,
            totalBytes: previewCacheBytes,
            maxBytes: maxPreviewCacheBytes,
            now: now,
            hardTTL: previewHardTTL
        )
        for key in evictionKeys {
            guard let removed = previewCache.removeValue(forKey: key) else { continue }
            stalePreviewKeys.remove(key)
            previewCacheBytes -= removed.byteCost
        }
    }

    static func previewCacheEvictionKeys(
        entries: [String: PreviewCacheEntry],
        totalBytes: Int,
        maxBytes: Int,
        now: Date,
        hardTTL: TimeInterval
    ) -> [String] {
        guard totalBytes > maxBytes else { return [] }

        var remainingBytes = totalBytes
        var evictionKeys: [String] = []
        var selectedKeys = Set<String>()

        let hardExpiredEntries = entries
            .filter { now.timeIntervalSince($0.value.capturedAt) >= hardTTL }
            .sorted(by: comparePreviewCacheAge)
        for (key, entry) in hardExpiredEntries where remainingBytes > maxBytes {
            evictionKeys.append(key)
            selectedKeys.insert(key)
            remainingBytes -= entry.byteCost
        }

        if remainingBytes > maxBytes {
            let lruEntries = entries
                .filter { !selectedKeys.contains($0.key) }
                .sorted(by: comparePreviewCacheAge)
            for (key, entry) in lruEntries where remainingBytes > maxBytes {
                evictionKeys.append(key)
                remainingBytes -= entry.byteCost
            }
        }
        return evictionKeys
    }

    private static func comparePreviewCacheAge(
        _ lhs: Dictionary<String, PreviewCacheEntry>.Element,
        _ rhs: Dictionary<String, PreviewCacheEntry>.Element
    ) -> Bool {
        if lhs.value.lastAccessAt != rhs.value.lastAccessAt {
            return lhs.value.lastAccessAt < rhs.value.lastAccessAt
        }
        return lhs.key < rhs.key
    }

    private func byteCost(previewImage: NSImage, backdropImage: NSImage?) -> Int {
        let previewCost = imageByteCost(previewImage)
        guard let backdropImage, backdropImage !== previewImage else { return previewCost }
        return previewCost + imageByteCost(backdropImage)
    }

    private func imageByteCost(_ image: NSImage) -> Int {
        if let bitmapRep = image.representations
            .compactMap({ $0 as? NSBitmapImageRep })
            .max(by: { $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh }) {
            return max(1, bitmapRep.pixelsWide * bitmapRep.pixelsHigh * 4)
        }
        let fallbackWidth = max(1, Int(image.size.width.rounded()))
        let fallbackHeight = max(1, Int(image.size.height.rounded()))
        return fallbackWidth * fallbackHeight * 4
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
        let allowedWindowPoliciesByPID = switcherDisplayWindowIDsByPID(for: [app])
        let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates = deduplicatedCandidates(
            from: windows.enumerated().compactMap { index, info in
                makeCandidate(
                    from: info,
                    orderIndex: index,
                    includeBackgroundWindows: true,
                    restrictToPID: app.processIdentifier,
                    allowedWindowPoliciesByPID: allowedWindowPoliciesByPID
                )
            }
        ).sorted(by: compareCandidates)

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

    private func compareCandidates(_ lhs: WindowCandidate, _ rhs: WindowCandidate) -> Bool {
        let lhsRank = history.rank(of: lhs.historyIdentity)
        let rhsRank = history.rank(of: rhs.historyIdentity)

        switch (lhsRank, rhsRank) {
        case let (.some(l), .some(r)) where l != r: return l < r
        case (.some, .none): return true
        case (.none, .some): return false
        default: break
        }

        if lhs.sortScore != rhs.sortScore { return lhs.sortScore > rhs.sortScore }
        return lhs.orderIndex < rhs.orderIndex
    }

    private func compareApps(_ lhs: NSRunningApplication, _ rhs: NSRunningApplication) -> Bool {
        let lhsIdentity = SwitcherHistoryIdentity.appFallback(bundleID: sourceAppIdentifier(for: lhs), pid: lhs.processIdentifier)
        let rhsIdentity = SwitcherHistoryIdentity.appFallback(bundleID: sourceAppIdentifier(for: rhs), pid: rhs.processIdentifier)

        let lhsRank = history.rank(of: lhsIdentity) ?? history.rankForApp(bundleID: lhs.bundleIdentifier, pid: lhs.processIdentifier) ?? Int.max
        let rhsRank = history.rank(of: rhsIdentity) ?? history.rankForApp(bundleID: rhs.bundleIdentifier, pid: rhs.processIdentifier) ?? Int.max

        if lhsRank != rhsRank { return lhsRank < rhsRank }
        return (lhs.localizedName ?? "") < (rhs.localizedName ?? "")
    }

    // MARK: - Window activation

    private func activateFallbackApplication(_ app: NSRunningApplication, identity: SwitcherHistoryIdentity) {
        ProductionSignpost.activationRequested()
        recordActivationRequested()
        markPendingActivation(app.processIdentifier)
        schedulePendingActivationTimeout(for: app.processIdentifier)
        activateApplication(app, activateAllWindows: true)

        var value: CFTypeRef?
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
           let windows = value as? [AXUIElement], let first = windows.first {
            raiseWindow(first, ownerPID: app.processIdentifier)
        }

        ensureApplicationFrontmost(app, identity: identity, attempt: 0)
        // warmCache intentionally omitted: the NSWorkspace.didActivateApplication
        // notification fires after app.activate() and already calls warmCache(force: true)
        // via appActivated(_:). Calling it here too queues a redundant rebuild that
        // races with the AX focus operations above, adding perceived latency.
    }

    private func activateWindow(_ candidate: WindowCandidate) {
        guard let app = NSRunningApplication(processIdentifier: candidate.ownerPID) else { return }
        ProductionSignpost.activationRequested()
        recordActivationRequested()
        markPendingActivation(candidate.ownerPID)
        schedulePendingActivationTimeout(for: candidate.ownerPID)

        WindowServerFocus.focusWindow(ownerPID: candidate.ownerPID, windowID: candidate.id)
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
            if let axWinID = AXWindowIDLookup.windowID(for: axWindow), axWinID == candidate.id {
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
        if let axWindowID = AXWindowIDLookup.windowID(for: axWindow) {
            WindowServerFocus.focusWindow(ownerPID: ownerPID, windowID: axWindowID)
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
        guard attempt < activationRetryLimit else { return }
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
            confirmActivation(identity: identity, pid: app.processIdentifier, verification: "applicationOnly")
            return
        }
        guard attempt < activationRetryLimit else {
            // Retries exhausted — record the history anyway so recency ordering
            // stays correct even when the app was slow to become frontmost.
            confirmActivation(identity: identity, pid: app.processIdentifier, verification: "applicationOnly")
            return
        }

        let delay = 0.05 + Double(attempt) * 0.08
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard self.currentSystemFrontmostPID() != app.processIdentifier else {
                self.confirmActivation(identity: identity, pid: app.processIdentifier, verification: "applicationOnly")
                return
            }
            self.activateApplication(app, activateAllWindows: true)
            self.ensureApplicationFrontmost(app, identity: identity, attempt: attempt + 1)
        }
    }

    private func ensureWindowFrontmost(_ candidate: WindowCandidate, attempt: Int) {
        guard !isFrontmostWindow(candidate) else {
            confirmActivation(identity: candidate.historyIdentity, pid: candidate.ownerPID, verification: "exactWindow")
            return
        }
        guard attempt < activationRetryLimit,
              let app = NSRunningApplication(processIdentifier: candidate.ownerPID) else {
            // Retries exhausted — if the app is at least frontmost, confirm with
            // whatever identity we have so the history still gets updated.
            if currentSystemFrontmostPID() == candidate.ownerPID {
                confirmActivation(identity: candidate.historyIdentity, pid: candidate.ownerPID, verification: "frontmostApplicationOnly")
            }
            return
        }

        let delay = 0.05 + Double(attempt) * 0.08
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard !self.isFrontmostWindow(candidate) else {
                self.confirmActivation(identity: candidate.historyIdentity, pid: candidate.ownerPID, verification: "exactWindow")
                return
            }
            self.activateApplication(app, activateAllWindows: true)
            self.focusBestMatchingWindow(candidate, attempt: attempt + 1)
        }
    }

    private func schedulePendingActivationTimeout(for pid: pid_t) {
        DispatchQueue.main.asyncAfter(deadline: .now() + pendingActivationTimeout) { [weak self] in
            guard let self else { return }
            guard self.clearPendingActivation(pid) else { return }
            let sessionID = self.pendingRuntimeQASessionsByPID.removeValue(forKey: pid)
            RuntimeQAEvidenceRecorder.shared.emit(RuntimeQARecord(
                event: "activationResult",
                sessionID: sessionID,
                success: false,
                verification: "timeout"
            ))
            RuntimeQAEvidenceRecorder.shared.finishSession(
                id: sessionID,
                success: false,
                verification: "activationTimeout"
            )
        }
    }

    private func markPendingActivation(_ pid: pid_t) {
        pendingActivationPIDs.insert(pid)
        if let sessionID = RuntimeQAEvidenceRecorder.shared.currentSessionID() {
            pendingRuntimeQASessionsByPID[pid] = sessionID
        }
    }

    @discardableResult
    private func clearPendingActivation(_ pid: pid_t) -> Bool {
        pendingActivationPIDs.remove(pid) != nil
    }

    private func confirmActivation(
        identity: SwitcherHistoryIdentity,
        pid: pid_t,
        verification: String
    ) {
        guard clearPendingActivation(pid) else { return }
        let sessionID = pendingRuntimeQASessionsByPID.removeValue(forKey: pid)
        ProductionSignpost.activationConfirmed()
        RuntimeQAEvidenceRecorder.shared.emit(RuntimeQARecord(
            event: "activationResult",
            sessionID: sessionID,
            success: verification == "exactWindow",
            verification: verification
        ))
        RuntimeQAEvidenceRecorder.shared.finishSession(
            id: sessionID,
            success: verification == "exactWindow",
            verification: verification
        )
        history.noteActivation(identity)
        onActivationConfirmed?(identity, pid)
    }

    private func recordActivationRequested() {
        RuntimeQAEvidenceRecorder.shared.emit(RuntimeQARecord(
            event: "activationRequested",
            sessionID: RuntimeQAEvidenceRecorder.shared.currentSessionID()
        ))
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
           let exactWindow = windows.first(where: { AXWindowIDLookup.windowID(for: $0) == windowID }) {
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
            if let windowID = AXWindowIDLookup.windowID(for: axWindow) {
                return windowID
            }
        }

        value = nil
        if AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &value) == .success,
           let mainWindow = value {
            let axWindow = unsafeBitCast(mainWindow, to: AXUIElement.self)
            return AXWindowIDLookup.windowID(for: axWindow)
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
        allowedWindowPoliciesByPID: [pid_t: AllowedWindowPolicy] = [:],
        allowUnsharedWindows: Bool = false
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
        let hasExplicitTitle = !title.isEmpty
        let windowID = (windowInfo[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0
        guard windowID != 0 else { return nil }
        let isOnScreen = (windowInfo[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
        let windowPolicy = allowedWindowPoliciesByPID[ownerPID]
        guard Self.isAllowedWindowID(windowID, policy: windowPolicy) else { return nil }
        if windowPolicy == .fallbackHeuristics, !isOnScreen, !hasExplicitTitle {
            return nil
        }

        let allowBackground = includeBackgroundWindows ?? (preferences.windowVisibilityScope == .allSpaces)
        if !allowBackground && !isOnScreen { return nil }

        let sharingState = (windowInfo[kCGWindowSharingState as String] as? NSNumber)?.intValue ?? 1
        guard Self.shouldAllowWindowSharingState(
            sharingState,
            allowUnsharedWindows: allowUnsharedWindows
        ) else { return nil }

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
            hasExplicitTitle: hasExplicitTitle,
            bounds: bounds,
            screenFrame: screenFrame(containing: bounds),
            orderIndex: orderIndex,
            sortScore: sortScore,
            isOnScreen: isOnScreen
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

    private func switcherDisplayWindowIDsByPID(for apps: [NSRunningApplication]) -> [pid_t: AllowedWindowPolicy] {
        var result: [pid_t: AllowedWindowPolicy] = [:]
        result.reserveCapacity(apps.count)
        for app in apps {
            result[app.processIdentifier] = switcherDisplayWindowIDs(for: app)
        }
        return result
    }

    private func switcherDisplayWindowIDs(for app: NSRunningApplication) -> AllowedWindowPolicy {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        let windowQueryResult = AXUIElementCopyAttributeValue(
            axApp,
            kAXWindowsAttribute as CFString,
            &value
        )
        let windows: [AXUIElement]
        if windowQueryResult == .success,
           let resolvedWindows = value as? [AXUIElement] {
            windows = resolvedWindows
        } else {
            windows = []
        }

        let displayWindows = windows.filter { isSwitcherDisplayWindow($0) }
        let displayIDs = displayWindows
            .compactMap { AXWindowIDLookup.windowID(for: $0) }

        let preferredIDs = [
            preferredWindow(for: axApp, attribute: kAXFocusedWindowAttribute as CFString),
            preferredWindow(for: axApp, attribute: kAXMainWindowAttribute as CFString),
        ]
        .compactMap { $0 }
        .compactMap { AXWindowIDLookup.windowID(for: $0) }

        return Self.allowedWindowPolicy(
            displayWindowIDs: Set(displayIDs),
            preferredWindowIDs: preferredIDs,
            hasEligibleAXWindows: !displayWindows.isEmpty,
            axWindowQuerySucceeded: windowQueryResult == .success
        )
    }

    private func isSwitcherDisplayWindow(_ axWindow: AXUIElement) -> Bool {
        Self.shouldAllowAXWindow(
            role: axString(for: axWindow, attribute: kAXRoleAttribute as CFString),
            subrole: axString(for: axWindow, attribute: kAXSubroleAttribute as CFString),
            parentRole: parentRole(for: axWindow),
            isMinimized: axBool(for: axWindow, attribute: kAXMinimizedAttribute as CFString),
            allowMinimizedStandardWindow: preferences.windowVisibilityScope == .allSpaces
        )
    }

    static func isAllowedWindowID(_ windowID: CGWindowID, policy: AllowedWindowPolicy?) -> Bool {
        let effectivePolicy = policy ?? .unrestricted
        switch effectivePolicy {
        case .unrestricted:
            return true
        case .fallbackHeuristics:
            return true
        case .restricted(let allowedWindowIDs):
            return allowedWindowIDs.contains(windowID)
        case .noneTrusted:
            return false
        }
    }

    static func policiesWithPerApplicationFallback(
        _ policies: [pid_t: AllowedWindowPolicy]
    ) -> [pid_t: AllowedWindowPolicy] {
        policies.mapValues { policy in
            switch policy {
            case .noneTrusted:
                return .fallbackHeuristics
            case .restricted(let windowIDs) where windowIDs.isEmpty:
                return .fallbackHeuristics
            case .unrestricted, .fallbackHeuristics, .restricted:
                return policy
            }
        }
    }

    static func shouldAllowWindowSharingState(
        _ sharingState: Int,
        allowUnsharedWindows: Bool
    ) -> Bool {
        sharingState != 0 || allowUnsharedWindows
    }

    static func allowedWindowPolicy(
        displayWindowIDs: Set<CGWindowID>,
        preferredWindowIDs: [CGWindowID],
        hasEligibleAXWindows: Bool = false,
        axWindowQuerySucceeded: Bool = true
    ) -> AllowedWindowPolicy {
        let preferredSet = Set(preferredWindowIDs)
        if !displayWindowIDs.isEmpty {
            return .restricted(displayWindowIDs.union(preferredSet))
        }

        if !preferredSet.isEmpty {
            return .restricted(preferredSet)
        }

        if hasEligibleAXWindows || !axWindowQuerySucceeded {
            return .fallbackHeuristics
        }

        return .noneTrusted
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
        allowFloating: Bool = false,
        allowMinimizedStandardWindow: Bool = false
    ) -> Bool {
        guard role == (kAXWindowRole as String) else { return false }
        guard parentRole != (kAXWindowRole as String) else { return false }

        guard let subrole else { return false }
        if isMinimized {
            return allowMinimizedStandardWindow && subrole == (kAXStandardWindowSubrole as String)
        }
        if isSwitcherDisplaySubrole(subrole) { return true }
        if allowFloating && subrole == (kAXFloatingWindowSubrole as String) { return true }
        return false
    }

    // MARK: - Multi-strategy window capture

    private struct PreviewAssets {
        let thumbnail: NSImage
        let backdrop: NSImage
    }

    private func capturePreviewAssets(
        for candidate: WindowCandidate,
        screenCaptureWindow: SCWindow?
    ) -> PreviewAssets? {
        let signpostID = ProductionSignpost.captureStarted()
        defer { ProductionSignpost.captureFinished(signpostID) }
        guard let backdrop = captureBackdropImage(
            for: candidate,
            screenCaptureWindow: screenCaptureWindow
        ) else { return nil }
        return PreviewAssets(
            thumbnail: downscaledPreview(backdrop),
            backdrop: backdrop
        )
    }

    private func captureBackdropImage(
        for candidate: WindowCandidate,
        screenCaptureWindow: SCWindow?
    ) -> NSImage? {
        if #available(macOS 14.0, *) {
            if let screenCaptureWindow,
               let image = screenCaptureKitImage(for: screenCaptureWindow) {
                if let prepared = Self.preparedSupportedWindowCapture(image) {
                    os_log(
                        .default,
                        log: appSwitcherLog,
                        "Preview capture strategy=ScreenCaptureKit accepted=1 width=%{public}d height=%{public}d",
                        Int(prepared.size.width.rounded()),
                        Int(prepared.size.height.rounded())
                    )
                    return prepared
                }
                os_log(.default, log: appSwitcherLog,
                       "Preview capture strategy=ScreenCaptureKit accepted=0 reason=blank")
            }
            // Keep a bounded compatibility path for systems where shareable
            // content discovery fails despite Screen Recording permission.
            // The private WindowServer and Core Graphics calls run only inside
            // the single-worker gate below, never on the switcher's build queue.
            let windowID = candidate.id
            let bounds = candidate.bounds
            let fallback = legacyCaptureGate.run(timeout: 0.75) {
                AppSwitcher.captureWithLegacyStrategies(windowID: windowID, bounds: bounds)
            }
            if fallback == nil {
                os_log(.error, log: appSwitcherLog,
                       "Legacy preview capture unavailable or timed out")
            }
            return fallback
        }

        // macOS 13 compatibility path.
        return Self.captureWithLegacyStrategies(windowID: candidate.id, bounds: candidate.bounds)
    }

    private static func captureWithLegacyStrategies(
        windowID: CGWindowID,
        bounds: CGRect
    ) -> NSImage? {
        if let image = SkyLightCapture.captureWindow(windowID),
           let prepared = preparedWindowCaptureImage(image) {
            return prepared
        }
        return captureWithCoreGraphics(windowID: windowID, bounds: bounds)
    }

    private static func captureWithCoreGraphics(
        windowID: CGWindowID,
        bounds: CGRect
    ) -> NSImage? {
        let framedBest: CGWindowImageOption = [.bestResolution]
        if let image = cgCapture(.null, .optionIncludingWindow, windowID, framedBest, minW: 80, minH: 60) { return image }
        if let image = cgCapture(bounds, .optionIncludingWindow, windowID, framedBest, minW: 80, minH: 60) { return image }

        let croppedBest: CGWindowImageOption = [.boundsIgnoreFraming, .bestResolution]
        if let image = cgCapture(.null, .optionIncludingWindow, windowID, croppedBest, minW: 80, minH: 60) { return image }
        if let image = cgCapture(bounds, .optionIncludingWindow, windowID, croppedBest, minW: 80, minH: 60) { return image }
        let nominal: CGWindowImageOption = [.boundsIgnoreFraming, .nominalResolution]
        return cgCapture(.null, .optionIncludingWindow, windowID, nominal, minW: 40, minH: 30)
    }

    private func screenCaptureKitWindowSnapshot(timeout: TimeInterval = 2.0) -> [CGWindowID: SCWindow] {
        guard #available(macOS 14.0, *) else { return [:] }

        let semaphore = DispatchSemaphore(value: 0)
        let result = LockedCaptureResult<SCShareableContent>()
        DispatchQueue.main.async {
            SCShareableContent.getExcludingDesktopWindows(
                false,
                onScreenWindowsOnly: false
            ) { content, error in
                if let error {
                    let nsError = error as NSError
                    os_log(.error, log: appSwitcherLog,
                           "ScreenCaptureKit enumeration failed code=%{public}d", nsError.code)
                }
                result.store(content)
                semaphore.signal()
            }
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success,
              let content = result.load() else {
            os_log(.error, log: appSwitcherLog, "ScreenCaptureKit enumeration timed out")
            return [:]
        }
        return Dictionary(
            content.windows.map { ($0.windowID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    @available(macOS 14.0, *)
    private func screenCaptureKitImage(
        for window: SCWindow,
        timeout: TimeInterval = 2.0
    ) -> CGImage? {
        let configuration = SCStreamConfiguration()
        let longestEdge = max(window.frame.width, window.frame.height)
        let scale = longestEdge > 0 ? min(2.0, 2_200 / longestEdge) : 1.0
        configuration.width = max(1, Int((window.frame.width * scale).rounded()))
        configuration.height = max(1, Int((window.frame.height * scale).rounded()))
        configuration.showsCursor = false

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let semaphore = DispatchSemaphore(value: 0)
        let result = LockedCaptureResult<CGImage>()
        DispatchQueue.main.async {
            SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            ) { image, error in
                if let error {
                    let nsError = error as NSError
                    os_log(.error, log: appSwitcherLog,
                           "ScreenCaptureKit screenshot failed code=%{public}d", nsError.code)
                }
                result.store(image)
                semaphore.signal()
            }
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            os_log(.error, log: appSwitcherLog, "ScreenCaptureKit screenshot timed out")
            return nil
        }
        return result.load()
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

    private static func cgCapture(_ rect: CGRect, _ listOption: CGWindowListOption, _ wid: CGWindowID,
                                  _ imageOption: CGWindowImageOption, minW: Int, minH: Int) -> NSImage? {
        guard let cgImage = CGWindowListCreateImage(rect, listOption, wid, imageOption) else { return nil }
        let prepared = Self.presentationPreparedWindowCapture(cgImage)
        guard prepared.width >= minW, prepared.height >= minH,
              Self.isPresentationUsefulWindowCapture(prepared) else { return nil }
        return NSImage(cgImage: prepared, size: NSSize(width: prepared.width, height: prepared.height))
    }

    private static func preparedWindowCaptureImage(_ image: NSImage) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        let prepared = Self.presentationPreparedWindowCapture(cgImage)
        guard Self.isPresentationUsefulWindowCapture(prepared) else { return nil }
        guard prepared.width != cgImage.width || prepared.height != cgImage.height else { return image }
        return NSImage(cgImage: prepared, size: NSSize(width: prepared.width, height: prepared.height))
    }

    static func preparedSupportedWindowCapture(_ cgImage: CGImage) -> NSImage? {
        let prepared = presentationPreparedWindowCapture(cgImage)
        guard prepared.width >= 40, prepared.height >= 30,
              !isImageEffectivelyBlank(prepared) else {
            return nil
        }
        return NSImage(
            cgImage: prepared,
            size: NSSize(width: prepared.width, height: prepared.height)
        )
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

        let alphaByteOffset: Int?
        switch cgImage.alphaInfo {
        case .premultipliedFirst, .first:
            alphaByteOffset = cgImage.bitmapInfo.contains(.byteOrder32Little) ? bpp - 1 : 0
        case .premultipliedLast, .last:
            alphaByteOffset = cgImage.bitmapInfo.contains(.byteOrder32Little) ? 0 : bpp - 1
        default:
            alphaByteOffset = nil
        }

        func hasVisibleAlpha(at base: Int) -> Bool {
            guard let alphaByteOffset else { return true }
            let alphaIndex = base + alphaByteOffset
            return alphaIndex >= 0 && alphaIndex < len && ptr[alphaIndex] >= alphaThreshold
        }

        func rowHasOpaquePixels(_ y: Int) -> Bool {
            for x in 0..<width {
                let base = y * bytesPerRow + x * bpp
                if hasVisibleAlpha(at: base) {
                    return true
                }
            }
            return false
        }

        func columnHasOpaquePixels(_ x: Int) -> Bool {
            for y in 0..<height {
                let base = y * bytesPerRow + x * bpp
                if hasVisibleAlpha(at: base) {
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

    private static func isImageEffectivelyBlank(_ cgImage: CGImage) -> Bool {
        guard let samples = normalizedCaptureSamples(cgImage) else { return true }
        return samples.filter { $0.alpha > 10 }.count < 2
    }

    private static func isImageEffectivelyBlack(_ cgImage: CGImage) -> Bool {
        guard let samples = normalizedCaptureSamples(cgImage) else { return true }
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

    private struct CaptureSample {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
        let alpha: UInt8
    }

    /// WindowServer images use several byte orders. Normalize a tiny copy so
    /// capture validation never interprets a color channel as alpha.
    private static func normalizedCaptureSamples(_ cgImage: CGImage) -> [CaptureSample]? {
        guard cgImage.width > 0, cgImage.height > 0 else { return nil }

        let dimension = 5
        let bytesPerRow = dimension * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * dimension)
        let didDraw = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: dimension,
                height: dimension,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                return false
            }
            context.interpolationQuality = .low
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: dimension, height: dimension))
            return true
        }
        guard didDraw else { return nil }

        return stride(from: 0, to: bytes.count, by: 4).map { offset in
            CaptureSample(
                red: bytes[offset],
                green: bytes[offset + 1],
                blue: bytes[offset + 2],
                alpha: bytes[offset + 3]
            )
        }
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
        ownerPID: pid_t,
        windowID: CGWindowID
    ) -> String {
        "window:\(ownerPID):\(windowID)"
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
    let hasExplicitTitle: Bool
    let bounds: CGRect
    let screenFrame: CGRect?
    let orderIndex: Int
    let sortScore: CGFloat
    let isOnScreen: Bool

    var historyIdentity: SwitcherHistoryIdentity { .appWindow(pid: ownerPID, windowID: id) }
    var sourceAppIdentifier: String { bundleIdentifier ?? "app-\(ownerPID)" }
    var previewCacheKey: String {
        AppSwitcher.previewCacheKey(
            ownerPID: ownerPID,
            windowID: id
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
    let hasExplicitTitle: Bool
    let bounds: CGRect
    let orderIndex: Int
    let sortScore: CGFloat
    let isOnScreen: Bool
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }
}
