import AppKit
import CoreGraphics

// MARK: - Mode

enum SwitcherMode: String {
    case app

    var title: String {
        return "Applications"
    }

    var systemImage: String {
        return "square.stack.3d.up.fill"
    }
}

enum SwitcherItemKind: String {
    case appWindow
    case appFallback
}

/// Debounces transient false Screen Recording preflight results.
///
/// TCC state can briefly lag a successful or recently revoked capture. A single
/// false sample must not erase every last-known-good Arc or Telegram thumbnail,
/// but a sustained denial must clear previews promptly. Successful captures reset
/// the denial window immediately.
enum SwitcherPreviewPermissionState {
    private static let lock = NSLock()
    private static var denialBeganAt: Date?
    private static let denialConfirmationInterval: TimeInterval = 1.0

    static func effectiveAccess(
        hasCurrentCapture: Bool,
        preflightGranted: Bool,
        now: Date = Date()
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if hasCurrentCapture || preflightGranted {
            denialBeganAt = nil
            return true
        }

        guard let denialBeganAt else {
            self.denialBeganAt = now
            return true
        }
        return now.timeIntervalSince(denialBeganAt) < denialConfirmationInterval
    }

    static func noteSuccessfulCapture() {
        lock.lock()
        denialBeganAt = nil
        lock.unlock()
    }

    static func resetForTesting() {
        lock.lock()
        denialBeganAt = nil
        lock.unlock()
    }
}

/// In-memory continuity for a real window's last known good preview.
///
/// GPU-backed applications such as Arc and Telegram can intermittently return no
/// capture even though the exact same window produced a valid image moments
/// earlier. Exact preview metadata may also change with a tab title or a tiny frame
/// adjustment, so a process-generation-scoped identity record bridges those misses
/// without borrowing from another exact window. The cache is bounded, never written
/// to disk, and is cleared for the affected identity when Screen Recording denial is
/// stable rather than on one transient preflight sample.
enum SwitcherPreviewContinuityStore {
    struct ResolvedImages {
        let preview: NSImage?
        let backdrop: NSImage?
        var capturedAt: Date? = nil
    }

    private struct WindowKey: Hashable { let pid: pid_t; let windowID: CGWindowID }
    private struct Verification {
        let generation: Date
        let element: AXUIElement
        let token: UUID
        var minimized: Bool
    }
    private struct Entry {
        let preview: NSImage
        let capturedAt: Date
        let bytes: Int
        let verificationToken: UUID?
        var access: UInt64
    }

    private static let lock = NSLock()
    private static var entries: [String: Entry] = [:]
    private static var windows: [WindowKey: Verification] = [:]
    private static var identityWindows: [String: WindowKey] = [:]
    private static var captureTokens: [String: UUID] = [:]
    private static var lastObservedAtByPID: [pid_t: Date] = [:]
    private static var access: UInt64 = 0
    private static var byteLimit = 128 * 1_024 * 1_024
    private static let identityMaximumAge: TimeInterval = 600

    static func captureToken(identityKey: String) -> UUID {
        lock.lock()
        defer { lock.unlock() }
        if let token = captureTokens[identityKey] { return token }
        let token = UUID()
        captureTokens[identityKey] = token
        trimMetadataLocked()
        return token
    }

    static func isCurrentCapture(identityKey: String, token: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return captureTokens[identityKey] == token
    }

    /// Only a complete AX list proves closure. A failed/partial enumeration must
    /// not erase a minimized window's last captured frame.
    static func observe(
        snapshot: AXWindowCatalogSnapshot,
        knownLiveWindowIDsByPID: [pid_t: Set<CGWindowID>] = [:]
    ) {
        observeIdentitySnapshot(
            generations: snapshot.processGenerations, elements: snapshot.elementsByPID,
            completePIDs: snapshot.completeIdentityPIDs,
            minimizedIDs: snapshot.byPID.mapValues { Set($0.values.filter(\.isMinimized).map(\.windowID)) },
            observedAtByPID: snapshot.observedAtByPID,
            knownLiveWindowIDsByPID: knownLiveWindowIDsByPID
        )
    }

    static func observeIdentitySnapshot(
        generations: [pid_t: Date], elements: [pid_t: [CGWindowID: AXUIElement]],
        completePIDs: Set<pid_t>, minimizedIDs: [pid_t: Set<CGWindowID>],
        observedAtByPID: [pid_t: Date] = [:],
        knownLiveWindowIDsByPID: [pid_t: Set<CGWindowID>] = [:]
    ) {
        lock.lock()
        defer { lock.unlock() }
        let receivedAt = Date()
        let pids = Set(generations.keys).union(elements.keys).union(completePIDs)
        let acceptedPIDs = Set(pids.filter { pid in
            let observedAt = observedAtByPID[pid] ?? receivedAt
            guard lastObservedAtByPID[pid].map({ observedAt > $0 }) ?? true else { return false }
            lastObservedAtByPID[pid] = observedAt
            return true
        })
        for (key, verified) in windows where acceptedPIDs.contains(key.pid) {
            if let generation = generations[key.pid], generation != verified.generation {
                purgeLocked(window: key)
            // AXWindows can omit a window on another Space even when its call
            // succeeds. A current accepted CG candidate preserves exact-ID
            // continuity until both inventories agree that it disappeared.
            } else if completePIDs.contains(key.pid),
                      elements[key.pid]?[key.windowID] == nil,
                      !knownLiveWindowIDsByPID[key.pid, default: []].contains(key.windowID) {
                purgeLocked(window: key)
            }
        }
        for (pid, processElements) in elements where acceptedPIDs.contains(pid) {
            guard let generation = generations[pid] else { continue }
            for (windowID, element) in processElements {
                let key = WindowKey(pid: pid, windowID: windowID)
                let old = windows[key]
                let same = old.map { $0.generation == generation && CFEqual($0.element, element) } ?? false
                if old != nil && !same { purgeLocked(window: key) }
                windows[key] = Verification(
                    generation: generation, element: element,
                    token: same ? old!.token : UUID(),
                    minimized: minimizedIDs[pid]?.contains(windowID) ?? false
                )
            }
        }
        trimMetadataLocked()
    }

    private static func trimMetadataLocked() {
        // Desktop churn must not leave unlimited identity/AX objects behind.
        // Eviction is conservative: an evicted request token cannot publish.
        while windows.count > 4096, let key = windows.keys.first {
            purgeLocked(window: key)
        }
        while identityWindows.count > 4096, let identity = identityWindows.keys.first {
            identityWindows.removeValue(forKey: identity)
            captureTokens.removeValue(forKey: identity)
            entries.removeValue(forKey: identity)
        }
        while captureTokens.count > 4096, let identity = captureTokens.keys.first {
            captureTokens.removeValue(forKey: identity)
        }
        while lastObservedAtByPID.count > 4096,
              let pid = lastObservedAtByPID.min(by: { $0.value < $1.value })?.key {
            lastObservedAtByPID.removeValue(forKey: pid)
        }
    }

    static func purge(ownerPID: pid_t) {
        lock.lock()
        defer { lock.unlock() }
        lastObservedAtByPID[ownerPID] = Date()
        for key in windows.keys.filter({ $0.pid == ownerPID }) { purgeLocked(window: key) }
        for identity in identityWindows.keys.filter({ identityWindows[$0]?.pid == ownerPID }) {
            entries.removeValue(forKey: identity)
            captureTokens.removeValue(forKey: identity)
            identityWindows.removeValue(forKey: identity)
        }
    }

    private static func purgeLocked(window: WindowKey) {
        windows.removeValue(forKey: window)
        for identity in identityWindows.keys.filter({ identityWindows[$0] == window }) {
            entries.removeValue(forKey: identity)
            captureTokens.removeValue(forKey: identity)
            identityWindows.removeValue(forKey: identity)
        }
    }

    static func resolve(
        key: String,
        identityKey: String,
        preview: NSImage?,
        backdrop: NSImage?,
        captureAccessAllowed: Bool,
        ownerPID: pid_t? = nil,
        windowID: CGWindowID? = nil,
        captureToken: UUID? = nil,
        capturedAt: Date? = nil,
        now: Date = Date()
    ) -> ResolvedImages {
        // Decode/downscale before taking the cache lock. Never retain the source
        // backdrop: cached frames have one bounded bitmap, at most 900px per side.
        let thumbnail = captureAccessAllowed ? (preview ?? backdrop).flatMap(makeThumbnail) : nil
        lock.lock()
        defer { lock.unlock() }
        _ = key // Metadata changes do not replace an exact window identity.
        if let captureToken, captureTokens[identityKey] != captureToken {
            return ResolvedImages(preview: nil, backdrop: nil)
        }
        if let ownerPID, let windowID {
            identityWindows[identityKey] = WindowKey(pid: ownerPID, windowID: windowID)
        }
        guard captureAccessAllowed else {
            // A sustained global capture denial invalidates every retained frame.
            entries.removeAll()
            captureTokens.removeAll()
            return ResolvedImages(preview: nil, backdrop: nil)
        }
        access &+= 1
        let verification = identityWindows[identityKey].flatMap { windows[$0] }
        let captureDate = capturedAt ?? now
        if let thumbnail, entries[identityKey].map({ $0.capturedAt < captureDate }) ?? true {
            entries[identityKey] = Entry(preview: thumbnail.image, capturedAt: captureDate,
                                         bytes: thumbnail.bytes, verificationToken: verification?.token, access: access)
        }
        entries = entries.filter { identity, entry in
            if now.timeIntervalSince(entry.capturedAt) <= identityMaximumAge { return true }
            guard let key = identityWindows[identity], let current = windows[key] else { return false }
            return current.minimized && entry.verificationToken == current.token
        }
        var cost = entries.values.reduce(0) { $0 + $1.bytes }
        for identity in entries.keys.sorted(by: { entries[$0]!.access < entries[$1]!.access }) where cost > byteLimit || entries.count > 512 {
            cost -= entries.removeValue(forKey: identity)!.bytes
        }
        trimMetadataLocked()
        guard var entry = entries[identityKey] else { return ResolvedImages(preview: nil, backdrop: nil) }
        entry.access = access
        entries[identityKey] = entry
        return ResolvedImages(preview: entry.preview, backdrop: nil, capturedAt: entry.capturedAt)
    }

    private static func makeThumbnail(_ image: NSImage) -> (image: NSImage, bytes: Int)? {
        guard let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            // Empty NSImage fixtures have no pixel allocation.
            return (image, 0)
        }
        let ratio = min(1, 900.0 / Double(max(source.width, source.height)))
        let width = max(1, Int(Double(source.width) * ratio))
        let height = max(1, Int(Double(source.height) * ratio))
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let bitmap = context.makeImage() else { return nil }
        return (NSImage(cgImage: bitmap, size: NSSize(width: width, height: height)), bitmap.bytesPerRow * bitmap.height)
    }

    static func resetForTesting(byteBudget: Int = 128 * 1_024 * 1_024) {
        lock.lock()
        entries.removeAll()
        windows.removeAll()
        identityWindows.removeAll()
        captureTokens.removeAll()
        lastObservedAtByPID.removeAll()
        access = 0
        byteLimit = byteBudget
        lock.unlock()
        SwitcherPreviewPermissionState.resetForTesting()
        ReliableWindowPreviewRecovery.resetForTesting()
    }
}

enum SwitcherPreviewState: Equatable {
    case applicationOnly, pending, permissionDenied, unavailable
    case cached(capturedAt: Date)
    case live
}

// MARK: - Item

struct SwitcherItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: NSImage?
    let previewImage: NSImage?
    let previewState: SwitcherPreviewState
    let previewCaptureIsFresh: Bool
    let previewCapturedAt: Date?
    let allowsPreviewRecovery: Bool
    let backdropImage: NSImage?
    let backdropFrame: CGRect?
    let backdropSourceScreenFrame: CGRect?
    let previewCacheKey: String
    let sourceAppIdentifier: String?
    let historyIdentity: SwitcherHistoryIdentity
    let kind: SwitcherItemKind
    let dedupeKey: String
    let isMinimized: Bool
    let isFullscreen: Bool
    let workspaceSnapshot: WindowWorkspaceSnapshot?
    let historyDescriptor: LiveWindowHistoryDescriptor?
    let activate: () -> Void

    var ownerPID: pid_t? { historyIdentity.ownerPID }
    var windowID: CGWindowID? { historyIdentity.windowID }

    init(
        title: String,
        subtitle: String,
        icon: NSImage?,
        previewImage: NSImage?,
        previewCaptureIsFresh: Bool = true,
        previewCapturedAt: Date? = nil,
        allowsPreviewRecovery: Bool = true,
        backdropImage: NSImage? = nil,
        backdropFrame: CGRect? = nil,
        backdropSourceScreenFrame: CGRect? = nil,
        previewCacheKey: String? = nil,
        historyIdentity: SwitcherHistoryIdentity,
        sourceAppIdentifier: String? = nil,
        kind: SwitcherItemKind = .appWindow,
        dedupeKey: String? = nil,
        isMinimized: Bool = false,
        isFullscreen: Bool = false,
        workspaceSnapshot: WindowWorkspaceSnapshot? = nil,
        historyDescriptor: LiveWindowHistoryDescriptor? = nil,
        activate: @escaping () -> Void
    ) {
        let resolvedDedupeKey = dedupeKey ?? historyIdentity.stableKey
        let resolvedPreviewKey = previewCacheKey ?? historyIdentity.stableKey
        let resolvedImages: SwitcherPreviewContinuityStore.ResolvedImages
        var recoveryIdentityKey: String?
        var effectiveCaptureAccess = true

        if previewCacheKey != nil, kind == .appWindow {
            let hasCurrentCapture = previewCaptureIsFresh && (previewImage != nil || backdropImage != nil)
            let preflightGranted: Bool
            if hasCurrentCapture {
                preflightGranted = true
            } else if #available(macOS 10.15, *) {
                preflightGranted = CGPreflightScreenCaptureAccess()
            } else {
                preflightGranted = true
            }
            effectiveCaptureAccess = SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: hasCurrentCapture,
                preflightGranted: preflightGranted
            )
            let identityPreviewKey = Self.previewContinuityIdentityKey(
                historyIdentity: historyIdentity,
                sourceAppIdentifier: sourceAppIdentifier
            )
            recoveryIdentityKey = identityPreviewKey
            resolvedImages = SwitcherPreviewContinuityStore.resolve(
                key: resolvedPreviewKey,
                identityKey: identityPreviewKey,
                preview: previewCaptureIsFresh ? previewImage : nil,
                backdrop: previewCaptureIsFresh ? backdropImage : nil,
                captureAccessAllowed: effectiveCaptureAccess,
                ownerPID: historyIdentity.ownerPID,
                windowID: historyIdentity.windowID,
                capturedAt: previewCapturedAt
            )
        } else {
            resolvedImages = .init(
                preview: previewImage,
                backdrop: backdropImage
            )
        }

        self.id = resolvedDedupeKey
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.previewImage = resolvedImages.preview
        self.previewCaptureIsFresh = previewCaptureIsFresh
        self.previewCapturedAt = resolvedImages.capturedAt ?? previewCapturedAt
        self.allowsPreviewRecovery = allowsPreviewRecovery
        self.backdropImage = resolvedImages.backdrop
        self.backdropFrame = backdropFrame
        self.backdropSourceScreenFrame = backdropSourceScreenFrame
        self.previewCacheKey = resolvedPreviewKey
        self.sourceAppIdentifier = sourceAppIdentifier
        self.historyIdentity = historyIdentity
        self.kind = kind
        self.dedupeKey = resolvedDedupeKey
        self.isMinimized = isMinimized
        self.isFullscreen = isFullscreen
        self.workspaceSnapshot = workspaceSnapshot
        self.historyDescriptor = historyDescriptor
        self.activate = activate

        // Continuity keeps the last useful frame visible while a fresh capture
        // is requested. It must not suppress recovery for the cache's lifetime.
        if allowsPreviewRecovery,
           (!previewCaptureIsFresh || (previewImage == nil && backdropImage == nil)),
           effectiveCaptureAccess,
           let recoveryIdentityKey,
           let windowID = historyIdentity.windowID,
           let ownerPID = historyIdentity.ownerPID {
            ReliableWindowPreviewRecovery.schedule(
                windowID: windowID,
                ownerPID: ownerPID,
                isFullscreen: isFullscreen,
                exactKey: resolvedPreviewKey,
                identityKey: recoveryIdentityKey
            )
        }
        if kind == .appFallback {
            self.previewState = .applicationOnly
        } else if !effectiveCaptureAccess {
            self.previewState = .permissionDenied
        } else if resolvedImages.preview != nil {
            self.previewState = previewCaptureIsFresh && previewImage != nil ? .live
                : .cached(capturedAt: resolvedImages.capturedAt ?? Date())
        } else if let recoveryIdentityKey {
            self.previewState = ReliableWindowPreviewRecovery.previewState(identityKey: recoveryIdentityKey)
        } else {
            self.previewState = .unavailable
        }
    }

    private static let launchTokenLock = NSLock()
    private static var launchTokensByPID: [pid_t: String] = [:]
    private static var didRegisterTerminationObserver = false

    private static func ensureTerminationObserverRegistered() {
        guard !didRegisterTerminationObserver else { return }
        didRegisterTerminationObserver = true
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: nil
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            evictLaunchToken(for: app.processIdentifier)
        }
    }

    static func evictLaunchToken(for pid: pid_t) {
        launchTokenLock.lock()
        launchTokensByPID.removeValue(forKey: pid)
        launchTokenLock.unlock()
        SwitcherPreviewContinuityStore.purge(ownerPID: pid)
    }

    static func resetLaunchTokensForTesting() {
        launchTokenLock.lock()
        launchTokensByPID.removeAll()
        launchTokenLock.unlock()
    }

    private static func stableLaunchToken(for pid: pid_t) -> String {
        launchTokenLock.lock()
        ensureTerminationObserverRegistered()

        let app = NSRunningApplication(processIdentifier: pid)
        let isAlive = app != nil && !app!.isTerminated

        if let cached = launchTokensByPID[pid] {
            if isAlive {
                launchTokenLock.unlock()
                return cached
            } else {
                launchTokensByPID.removeValue(forKey: pid)
            }
        }
        defer { launchTokenLock.unlock() }

        guard isAlive, let liveApp = app else {
            return "pid-\(pid)"
        }

        if let launchDate = liveApp.launchDate {
            let token = String(Int64((launchDate.timeIntervalSince1970 * 1_000).rounded()))
            launchTokensByPID[pid] = token
            return token
        }
        let token = "pid-\(pid)"
        launchTokensByPID[pid] = token
        return token
    }

    static func previewContinuityIdentityKey(
        historyIdentity: SwitcherHistoryIdentity,
        sourceAppIdentifier: String?
    ) -> String {
        let launchToken: String
        if let pid = historyIdentity.ownerPID {
            launchToken = stableLaunchToken(for: pid)
        } else {
            launchToken = "unknown-launch"
        }
        return [
            historyIdentity.stableKey,
            sourceAppIdentifier?.lowercased() ?? "",
            launchToken,
        ].joined(separator: "|")
    }
}
