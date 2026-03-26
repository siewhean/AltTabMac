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

private let appSwitcherLog = OSLog(subsystem: "AltTabMac", category: "AppSwitcher")

/// Enumerates real application windows and captures thumbnails for the switcher.
final class AppSwitcher: NSObject {
    private let preferences = SwitcherPreferences.shared
    private let history = SwitcherHistoryStore.shared

    // ── Non-blocking cache architecture ──────────────────────────────────────
    // The build queue runs thumbnail capture off the main thread.
    // The cacheLock protects reads/writes to _cachedItems so getItems() never
    // blocks on a pending thumbnail capture — it returns stale data instantly
    // and the UI updates when onItemsChanged fires.
    private let buildQueue = DispatchQueue(label: "AltTabMac.AppSwitcher.Build", qos: .userInitiated)
    private var _cachedItems: [SwitcherItem] = []
    private let cacheLock = NSLock()
    private var lastRefresh = Date.distantPast
    private var isRefreshing = false
    private let refreshInterval: TimeInterval = 0.8

    var onItemsChanged: (([SwitcherItem]) -> Void)?
    private var pendingActivationPID: pid_t?

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

        if app.processIdentifier == pendingActivationPID {
            pendingActivationPID = nil
            warmCache(force: true)
            return
        }

        if let identity = currentFrontmostIdentity(for: app) {
            history.noteActivation(identity)
        }
        warmCache(force: true)
    }

    @objc private func workspaceChanged() { warmCache(force: true) }
    @objc private func preferencesChanged() { warmCache(force: true) }

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

    /// Populate a fast icon-only cache synchronously when the app is first
    /// invoked and the background builder has not produced anything yet.
    /// This keeps the first Alt-Tab reveal from stalling on the empty-cache path.
    @discardableResult
    func primeCacheIfNeeded() -> [SwitcherItem] {
        let existing = cachedItemsSnapshot()
        guard existing.isEmpty else { return existing }

        let context = enumerateWindows()
        let iconItems = assembleItems(from: context, capturePreviews: false)

        cacheLock.lock()
        if _cachedItems.isEmpty {
            _cachedItems = iconItems
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

    func currentFrontmostIdentity() -> SwitcherHistoryIdentity? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        return currentFrontmostIdentity(for: app)
    }

    // MARK: - Two-phase cache build
    //
    // Phase 1 (fast): Enumerate windows via CGWindowListCopyWindowInfo,
    //   create items with app icons only (previewImage = nil), cache
    //   immediately, and notify the UI so the panel can appear instantly.
    // Phase 2 (slow): Capture window thumbnails via CGWindowListCreateImage
    //   on this background queue, rebuild items with real previews, cache
    //   again, and notify the UI to swap icons for thumbnails.

    private func refreshCacheIfNeeded(force: Bool) {
        guard force || Date().timeIntervalSince(lastRefresh) > refreshInterval else { return }
        guard !isRefreshing else { return }
        isRefreshing = true

        // ── Phase 1: Icon-only pass (fast) ─────────────────────────────────
        let context = enumerateWindows()
        let iconItems = assembleItems(from: context, capturePreviews: false)

        cacheLock.lock()
        _cachedItems = iconItems
        cacheLock.unlock()

        // Notify UI immediately — icons appear, zero preview lag.
        DispatchQueue.main.async { [weak self] in
            self?.onItemsChanged?(iconItems)
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

            let fullItems = self.assembleItems(from: context, capturePreviews: true)

            self.cacheLock.lock()
            self._cachedItems = fullItems
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

        let allWindows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates = deduplicatedCandidates(
            from: allWindows.enumerated().compactMap { index, info in
                makeCandidate(from: info, orderIndex: index, appsByPID: appsByPID)
            }
        ).sorted(by: compareCandidates)

        return BuildContext(candidates: limitedByApp(candidates), runningApps: runningApps)
    }

    /// Create SwitcherItem arrays from a BuildContext. When `capturePreviews`
    /// is false, every item gets `previewImage: nil` (icon-only). When true,
    /// each window candidate is captured via CGWindowListCreateImage.
    private func assembleItems(from context: BuildContext, capturePreviews: Bool) -> [SwitcherItem] {
        let appsWithWindows = Set(context.candidates.map(\.ownerPID))

        let fallbackAppItems = context.runningApps
            .sorted(by: compareApps)
            .filter { !appsWithWindows.contains($0.processIdentifier) }
            .map { app in
                let bundleID = sourceAppIdentifier(for: app)
                let identity = SwitcherHistoryIdentity.appFallback(bundleID: bundleID, pid: app.processIdentifier)
                return SwitcherItem(
                    title: app.localizedName ?? "Application",
                    subtitle: "Running in background",
                    icon: app.icon,
                    previewImage: nil,
                    historyIdentity: identity,
                    sourceAppIdentifier: bundleID,
                    kind: .appFallback
                ) { [weak self] in
                    self?.activateFallbackApplication(app, identity: identity)
                }
            }

        let windowItems = context.candidates.map { candidate in
            let preview: NSImage? = capturePreviews ? capturePreview(for: candidate) : nil
            return SwitcherItem(
                title: candidate.windowTitle,
                subtitle: candidate.appName,
                icon: candidate.appIcon,
                previewImage: preview,
                historyIdentity: candidate.historyIdentity,
                sourceAppIdentifier: candidate.sourceAppIdentifier,
                kind: .appWindow
            ) { [weak self] in
                self?.activateWindow(candidate)
            }
        }

        return windowItems + fallbackAppItems
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

    // MARK: - Identity helpers

    private func currentFrontmostIdentity(for app: NSRunningApplication) -> SwitcherHistoryIdentity? {
        let onScreenWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let visibleCandidates = deduplicatedCandidates(
            from: onScreenWindows.enumerated().compactMap { index, info in
                makeCandidate(from: info, orderIndex: index, includeBackgroundWindows: false, restrictToPID: app.processIdentifier)
            }
        )

        if let candidate = visibleCandidates.first {
            return candidate.historyIdentity
        }
        return .appFallback(bundleID: sourceAppIdentifier(for: app), pid: app.processIdentifier)
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
        pendingActivationPID = app.processIdentifier
        app.unhide()
        let didActivate = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)

        if !didActivate {
            if #available(macOS 14.0, *) { app.activate() }
        }

        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
           let windows = value as? [AXUIElement], let first = windows.first {
            raiseWindow(first)
        }

        history.noteActivation(identity)
        // warmCache intentionally omitted: the NSWorkspace.didActivateApplication
        // notification fires after app.activate() and already calls warmCache(force: true)
        // via appActivated(_:). Calling it here too queues a redundant rebuild that
        // races with the AX focus operations above, adding perceived latency.
    }

    private func activateWindow(_ candidate: WindowCandidate) {
        guard let app = NSRunningApplication(processIdentifier: candidate.ownerPID) else { return }
        pendingActivationPID = candidate.ownerPID

        app.unhide()
        let didActivate = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        let axApp = AXUIElementCreateApplication(candidate.ownerPID)
        AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)

        if !didActivate {
            if #available(macOS 14.0, *) { app.activate() }
        }

        history.noteActivation(candidate.historyIdentity)
        focusBestMatchingWindow(candidate, attempt: 0)
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
                raiseWindow(axWindow)
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
            raiseWindow(bestWindow.0)
        } else if attempt < 2 {
            scheduleWindowFocusRetry(for: candidate, attempt: attempt)
        } else {
            raiseWindow(windows[0])
        }
    }

    private func raiseWindow(_ axWindow: AXUIElement) {
        let t = kCFBooleanTrue!
        AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, t)
        AXUIElementSetAttributeValue(axWindow, kAXFocusedAttribute as CFString, t)
        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
    }

    /// Returns true only for standard application windows — excludes dialogs,
    /// sheets, system dialogs, and other non-standard window types that should
    /// never be the target of an explicit user focus action.
    private func isStandardWindow(_ axWindow: AXUIElement) -> Bool {
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWindow, kAXRoleAttribute as CFString, &roleRef) == .success,
              let role = roleRef as? String, role == (kAXWindowRole as String) else {
            return false
        }
        var subroleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axWindow, kAXSubroleAttribute as CFString, &subroleRef) == .success,
           let subrole = subroleRef as? String {
            let valid: Set<String> = [
                kAXStandardWindowSubrole as String,
                kAXFloatingWindowSubrole as String,
                "AXFullScreenWindow"
            ]
            return valid.contains(subrole)
        }
        return true
    }

    private func scheduleWindowFocusRetry(for candidate: WindowCandidate, attempt: Int) {
        guard attempt < 4 else { return }
        let delay = 0.04 + Double(attempt) * 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.focusBestMatchingWindow(candidate, attempt: attempt + 1)
        }
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
        appsByPID: [pid_t: NSRunningApplication]? = nil
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

        let isOnScreen = (windowInfo[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
        let allowBackground = includeBackgroundWindows ?? preferences.includeBackgroundWindows
        if !allowBackground && !isOnScreen { return nil }

        let sharingState = (windowInfo[kCGWindowSharingState as String] as? NSNumber)?.intValue ?? 1
        guard sharingState != 0 else { return nil }

        let area = bounds.width * bounds.height
        let appName = app.localizedName ?? (windowInfo[kCGWindowOwnerName as String] as? String) ?? "Application"
        let windowTitle = title.isEmpty ? appName : title
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
            bounds: bounds, orderIndex: orderIndex, sortScore: sortScore
        )
    }

    private func deduplicatedCandidates(from candidates: [WindowCandidate]) -> [WindowCandidate] {
        var seen = Set<String>()
        return candidates.filter { c in
            let key = [
                String(c.ownerPID), c.windowTitle.lowercased(),
                String(Int(c.bounds.origin.x / 12)), String(Int(c.bounds.origin.y / 12)),
                String(Int(c.bounds.width / 12)), String(Int(c.bounds.height / 12))
            ].joined(separator: "|")
            return seen.insert(key).inserted
        }
    }

    // MARK: - Multi-strategy window capture

    private func capturePreview(for candidate: WindowCandidate) -> NSImage? {
        let best: CGWindowImageOption = [.boundsIgnoreFraming, .bestResolution]

        if let img = cgCapture(candidate.bounds, .optionIncludingWindow, candidate.id, best, minW: 80, minH: 60) { return downscaledPreview(img) }
        if let img = cgCapture(.null, .optionIncludingWindow, candidate.id, best, minW: 80, minH: 60) { return downscaledPreview(img) }
        if let image = SkyLightCapture.captureWindow(candidate.id) { return downscaledPreview(image) }

        let nominal: CGWindowImageOption = [.boundsIgnoreFraming, .nominalResolution]
        if let img = cgCapture(.null, .optionIncludingWindow, candidate.id, nominal, minW: 40, minH: 30) { return downscaledPreview(img) }

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
        guard let cgImage = CGWindowListCreateImage(rect, listOption, wid, imageOption),
              cgImage.width >= minW, cgImage.height >= minH,
              !isImageEffectivelyBlank(cgImage) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
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

    var historyIdentity: SwitcherHistoryIdentity { .appWindow(pid: ownerPID, windowID: id) }
    var sourceAppIdentifier: String { bundleIdentifier ?? "app-\(ownerPID)" }
}

