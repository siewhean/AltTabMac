import AppKit
import CoreGraphics
import ApplicationServices
import os.log

// MARK: - SkyLight private API (window capture for minimized / off-screen windows)

private enum SkyLightCapture {
    private typealias MainConnectionFn = @convention(c) () -> UInt32
    private typealias HWCaptureListFn  = @convention(c) (
        UInt32, UnsafeMutablePointer<CGWindowID>, Int32, UInt32
    ) -> Unmanaged<CFArray>?

    private static let resolved: (mainConn: MainConnectionFn, hwCapture: HWCaptureListFn)? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", 0x1) else {
            return nil
        }
        guard let mainSym    = dlsym(handle, "SLSMainConnectionID"),
              let captureSym = dlsym(handle, "SLSHWCaptureWindowList") else {
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
        guard let cfArrayRef = fns.hwCapture(cid, &wid, 1, 3) else { return nil }
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
    private var lastRefresh = Date.distantPast
    private var isRefreshing = false
    private let refreshInterval: TimeInterval = 0.8
    private let maxPreviewCacheEntries = 512
    private let maximumPhaseTwoFallbackAge: TimeInterval = 2.0
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

    func currentFrontmostIdentity() -> SwitcherHistoryIdentity? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        return currentFrontmostIdentity(for: app)
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

            let fullItems = self.assembleItems(
                from: context,
                capturePreviews: true,
                previewFallbacks: preservedPreviews
            )

            self.cacheLock.lock()
            self._cachedItems = fullItems
            self.updatePreviewCacheLocked(with: fullItems)
            self.cacheLock.unlock()
            self.lastRefresh = Date()
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
        ).sorted(by: compareCandidates)

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
            if capturePreviews {
                let assets = capturePreviewAssets(for: candidate)
                preview = assets?.thumbnail ?? reusablePhaseTwoFallback(from: previewFallbacks[previewKey])
                backdrop = assets?.backdrop ?? previewFallbacks[previewKey]?.backdropImage ?? preview
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
                previewCacheKey: previewKey,
                historyIdentity: candidate.historyIdentity,
                sourceAppIdentifier: candidate.sourceAppIdentifier,
                kind: .appWindow
                ) { [weak self] in
                    self?.activateWindow(candidate)
                }
            }

        return windowItems
    }

    private func reusablePhaseTwoFallback(from entry: PreviewCacheEntry?) -> NSImage? {
        guard let entry else { return nil }
        guard Date().timeIntervalSince(entry.capturedAt) <= maximumPhaseTwoFallbackAge else { return nil }
        return entry.image
    }

    static func shouldIncludeFallbackApp(
        processIdentifier: pid_t,
        sourceAppIdentifier: String,
        representedWindowPIDs: Set<pid_t>,
        representedWindowAppIdentifiers: Set<String>,
        seenFallbackAppIdentifiers: inout Set<String>
    ) -> Bool {
        guard !representedWindowPIDs.contains(processIdentifier) else { return false }
        guard !representedWindowAppIdentifiers.contains(sourceAppIdentifier) else { return false }
        return seenFallbackAppIdentifiers.insert(sourceAppIdentifier).inserted
    }

    static func shouldDisplayWindowItem(
        previewImage: NSImage?,
        capturePreviews: Bool,
        allowPreviewlessItems: Bool = false
    ) -> Bool {
        if previewImage != nil { return true }
        return !capturePreviews && allowPreviewlessItems
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
            return containing.visibleFrame
        }

        return NSScreen.screens.first(where: { $0.visibleFrame.intersects(rect) })?.visibleFrame
    }

    // MARK: - Identity helpers

    private func currentFrontmostIdentity(for app: NSRunningApplication) -> SwitcherHistoryIdentity? {
        let allowedWindowIDsByPID = switcherDisplayWindowIDsByPID(for: [app])
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
        markPendingActivation(candidate.ownerPID)
        schedulePendingActivationTimeout(for: candidate.ownerPID)

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
            confirmActivation(identity: identity, pid: app.processIdentifier)
            return
        }
        guard attempt < activationRetryLimit else {
            // Retries exhausted — record the history anyway so recency ordering
            // stays correct even when the app was slow to become frontmost.
            confirmActivation(identity: identity, pid: app.processIdentifier)
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
            // Retries exhausted — if the app is at least frontmost, confirm with
            // whatever identity we have so the history still gets updated.
            if currentSystemFrontmostPID() == candidate.ownerPID {
                confirmActivation(identity: candidate.historyIdentity, pid: candidate.ownerPID)
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
        guard sharingState != 0 else { return nil }

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
            bounds: bounds, orderIndex: orderIndex, sortScore: sortScore, isOnScreen: isOnScreen
        )
    }

    private func deduplicatedCandidates(from candidates: [WindowCandidate]) -> [WindowCandidate] {
        var seen = Set<String>()
        return candidates.filter { c in
            let key = [
                String(c.ownerPID), String(c.id), c.windowTitle.lowercased(),
                String(Int(c.bounds.origin.x / 12)), String(Int(c.bounds.origin.y / 12)),
                String(Int(c.bounds.width / 12)), String(Int(c.bounds.height / 12))
            ].joined(separator: "|")
            return seen.insert(key).inserted
        }
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
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement], !windows.isEmpty else {
            return nil
        }

        let ids = windows
            .filter { isSwitcherDisplayWindow($0) }
            .compactMap { AXWindowIDLookup.windowID(for: $0) }

        guard !ids.isEmpty else { return nil }
        return Set(ids)
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

    private func captureBackdropImage(for candidate: WindowCandidate) -> NSImage? {
        let framedBest: CGWindowImageOption = [.bestResolution]
        if let img = cgCapture(.null, .optionIncludingWindow, candidate.id, framedBest, minW: 80, minH: 60) { return img }
        if let img = cgCapture(candidate.bounds, .optionIncludingWindow, candidate.id, framedBest, minW: 80, minH: 60) { return img }

        let croppedBest: CGWindowImageOption = [.boundsIgnoreFraming, .bestResolution]
        if let img = cgCapture(.null, .optionIncludingWindow, candidate.id, croppedBest, minW: 80, minH: 60) { return img }
        if let img = cgCapture(candidate.bounds, .optionIncludingWindow, candidate.id, croppedBest, minW: 80, minH: 60) { return img }
        if let image = SkyLightCapture.captureWindow(candidate.id) {
            return trimmedWindowCaptureImage(image)
        }

        let nominal: CGWindowImageOption = [.boundsIgnoreFraming, .nominalResolution]
        if let img = cgCapture(.null, .optionIncludingWindow, candidate.id, nominal, minW: 40, minH: 30) { return img }

        return nil
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
              !isImageEffectivelyBlank(prepared) else { return nil }
        return NSImage(cgImage: prepared, size: NSSize(width: prepared.width, height: prepared.height))
    }

    private func trimmedWindowCaptureImage(_ image: NSImage) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        let prepared = Self.presentationPreparedWindowCapture(cgImage)
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

    private func isImageEffectivelyBlank(_ cgImage: CGImage) -> Bool {
        guard let dp = cgImage.dataProvider, let data = dp.data else { return true }
        let ptr = CFDataGetBytePtr(data)!
        let len = CFDataGetLength(data)
        let bpp = cgImage.bitsPerPixel / 8
        guard bpp >= 4 else { return false }

        let bpr = cgImage.bytesPerRow
        let w = cgImage.width, h = cgImage.height
        var opaque = 0
        for r in 0..<3 {
            for c in 0..<3 {
                let x = (c + 1) * w / 4, y = (r + 1) * h / 4
                let off = y * bpr + x * bpp
                let alpha: Int
                switch cgImage.alphaInfo {
                case .premultipliedFirst, .first, .noneSkipFirst: alpha = off
                default: alpha = off + bpp - 1
                }
                if alpha >= 0, alpha < len, ptr[alpha] > 10 { opaque += 1 }
            }
        }
        return opaque < 2
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
    let orderIndex: Int
    let sortScore: CGFloat
    let isOnScreen: Bool

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
