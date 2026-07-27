import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import os.log

private let productionSwitcherLog = OSLog(
    subsystem: "CmdTab",
    category: "ProductionAppSwitcher"
)

struct ProductionEnrichmentInputSignature: Equatable {
    let configuration: SwitcherSessionConfiguration
    let itemKeys: [String]

    init(
        configuration: SwitcherSessionConfiguration,
        itemKeys: [String]
    ) {
        self.configuration = configuration
        self.itemKeys = itemKeys
    }

    init(
        configuration: SwitcherSessionConfiguration,
        items: [SwitcherItem]
    ) {
        self.configuration = configuration
        itemKeys = items.map { item in
            let previewIdentity = item.previewImage.map {
                String(ObjectIdentifier($0).hashValue)
            } ?? "none"
            let backdropIdentity = item.backdropImage.map {
                String(ObjectIdentifier($0).hashValue)
            } ?? "none"
            return [
                item.id,
                item.title,
                item.subtitle,
                item.previewCacheKey,
                previewIdentity,
                backdropIdentity,
                item.isMinimized ? "minimized" : "normal",
                item.isFullscreen ? "fullscreen" : "windowed",
            ].joined(separator: "|")
        }
    }
}

/// Prevents an unchanged published snapshot from recursively scheduling another
/// whole-desktop Accessibility/workspace enrichment pass.
struct ProductionEnrichmentGate {
    private(set) var lastScheduled: ProductionEnrichmentInputSignature?

    mutating func shouldSchedule(
        _ signature: ProductionEnrichmentInputSignature,
        force: Bool
    ) -> Bool {
        if force || signature != lastScheduled {
            lastScheduled = signature
            return true
        }
        return false
    }

    mutating func invalidate() {
        lastScheduled = nil
    }
}

enum ProvisionalSwitcherPolicy {
    /// A base snapshot is safe only when it is already a subset of the requested
    /// profile scope. A narrower profile must wait for exact AX/Space enrichment
    /// rather than briefly exposing an item the user explicitly excluded.
    static func permitsBaseSnapshot(
        profileVisibility: WindowVisibilityScope,
        globalVisibility: WindowVisibilityScope,
        profileIncludesMinimized: Bool,
        globalIncludesMinimized: Bool
    ) -> Bool {
        visibilityRank(profileVisibility) >= visibilityRank(globalVisibility) &&
            (profileIncludesMinimized || !globalIncludesMinimized)
    }

    static func filteredItems(
        _ items: [SwitcherItem],
        configuration: SwitcherSessionConfiguration,
        globalVisibility: WindowVisibilityScope,
        globalIncludesMinimized: Bool
    ) -> [SwitcherItem] {
        guard permitsBaseSnapshot(
            profileVisibility: configuration.visibilityScope,
            globalVisibility: globalVisibility,
            profileIncludesMinimized: configuration.includeMinimizedWindows,
            globalIncludesMinimized: globalIncludesMinimized
        ) else {
            return []
        }

        return items.filter { item in
            let bundleIdentifier = item.sourceAppIdentifier ?? ""
            return configuration.includes(bundleIdentifier: bundleIdentifier) &&
                (configuration.includeMinimizedWindows || !item.isMinimized)
        }
    }

    static func filteredEnrichedItems(
        _ items: [SwitcherItem],
        configuration: SwitcherSessionConfiguration
    ) -> [SwitcherItem] {
        items.filter { item in
            let bundleIdentifier = item.sourceAppIdentifier ?? ""
            guard configuration.includes(bundleIdentifier: bundleIdentifier),
                  configuration.includeMinimizedWindows || !item.isMinimized else {
                return false
            }

            guard let workspace = item.workspaceSnapshot else {
                // A process fallback has no exact Space identity. It is safe only
                // for an all-Spaces profile; narrower profiles wait for exact data.
                return configuration.visibilityScope == .allSpaces
            }
            switch configuration.visibilityScope {
            case .allSpaces:
                return true
            case .visibleSpaces:
                // `SwitcherItem` does not retain the exact on-screen bit. Only an
                // explicitly active Stage Manager set is safe to reuse here.
                return workspace.stageManagerState == .activeSet
            case .currentSpaceOnly:
                return workspace.isOnCurrentManagedSpace
            }
        }
    }

    private static func visibilityRank(_ scope: WindowVisibilityScope) -> Int {
        switch scope {
        case .currentSpaceOnly: return 0
        case .visibleSpaces: return 1
        case .allSpaces: return 2
        }
    }
}

/// Profile-aware facade over the proven Phase 1 `AppSwitcher`.
///
/// The base switcher remains responsible for fast CG enumeration, previews, and
/// ordinary exact activation. Accessibility/workspace enrichment is performed on
/// a serial background queue and published atomically so opening the overlay never
/// blocks on a whole-desktop AX walk.
final class ProductionAppSwitcher {
    private struct EnrichmentResult {
        let items: [SwitcherItem]
        let descriptors: [SwitcherHistoryIdentity: LiveWindowHistoryDescriptor]
    }

    private let base: AppSwitcher
    private let preferences: SwitcherPreferences
    private let profileStore: SwitcherProfileStore
    private let history: SwitcherHistoryStore
    private let catalog: AXWindowCatalog
    private let workspaceProvider: WindowWorkspaceProviding
    private let actionProvider: ExactWindowActionProvider

    private let stateLock = NSLock()
    private let enrichmentQueue = DispatchQueue(
        label: "CmdTab.ProductionAppSwitcher.Enrichment",
        qos: .userInitiated
    )
    private var activeConfiguration: SwitcherSessionConfiguration
    private var descriptorsByIdentity: [SwitcherHistoryIdentity: LiveWindowHistoryDescriptor] = [:]
    private var latestBaseItems: [SwitcherItem] = []
    private var cachedEnrichedItems: [SwitcherItem] = []
    private var enrichmentGeneration: UInt64 = 0
    private var enrichmentGate = ProductionEnrichmentGate()

    private var catalogCache: AXWindowCatalogSnapshot?
    private var catalogCacheDate = Date.distantPast
    private let catalogRefreshInterval: TimeInterval = 0.35

    var onItemsChanged: (([SwitcherItem]) -> Void)?
    var onActivationConfirmed: ((SwitcherHistoryIdentity, pid_t) -> Void)?

    var workspaceCapability: CapabilityStatus {
        workspaceProvider.status
    }

    init(
        base: AppSwitcher = AppSwitcher(),
        preferences: SwitcherPreferences = .shared,
        profileStore: SwitcherProfileStore = .shared,
        history: SwitcherHistoryStore = .shared,
        catalog: AXWindowCatalog = .shared,
        workspaceProvider: WindowWorkspaceProviding = WindowWorkspaceProvider.shared,
        actionProvider: ExactWindowActionProvider = .shared
    ) {
        self.base = base
        self.preferences = preferences
        self.profileStore = profileStore
        self.history = history
        self.catalog = catalog
        self.workspaceProvider = workspaceProvider
        self.actionProvider = actionProvider

        if let first = profileStore.profilesSnapshot().first(where: \.isEnabled),
           let configuration = profileStore.configuration(
               for: first.id,
               preferences: preferences
           ) {
            activeConfiguration = configuration
        } else {
            activeConfiguration = SwitcherSessionConfiguration(
                profileID: UUID(),
                profileName: "Default",
                style: preferences.switcherStyle,
                visibilityScope: preferences.windowVisibilityScope,
                includeMinimizedWindows: preferences.includeMinimizedWindows,
                displayPlacement: preferences.displayPlacement,
                appFilter: .all,
                releaseBehavior: .holdPrimaryModifier
            )
        }

        base.onItemsChanged = { [weak self] items in
            self?.scheduleEnrichment(from: items, forceCatalogRefresh: false)
        }
        base.onActivationConfirmed = { [weak self] identity, pid in
            guard let self else { return }
            if let descriptor = self.descriptor(for: identity) {
                self.history.noteActivation(identity, descriptor: descriptor)
            }
            self.onActivationConfirmed?(identity, pid)
        }
    }

    // MARK: Public facade

    func applySessionConfiguration(
        _ configuration: SwitcherSessionConfiguration
    ) {
        stateLock.lock()
        let changed = activeConfiguration != configuration
        activeConfiguration = configuration
        if changed {
            // Never expose items enriched for a different profile. Reuse only a
            // provably safe exact subset while the new async enrichment pass runs.
            cachedEnrichedItems = ProvisionalSwitcherPolicy.filteredEnrichedItems(
                cachedEnrichedItems,
                configuration: configuration
            )
            descriptorsByIdentity = descriptorsByIdentity.filter { identity, _ in
                cachedEnrichedItems.contains { $0.historyIdentity == identity }
            }
            enrichmentGate.invalidate()
        }
        stateLock.unlock()
        guard changed else { return }

        invalidateCatalogCache()
        let baseItems = base.getItems()
        scheduleEnrichment(from: baseItems, forceCatalogRefresh: true)
        base.warmCache(force: true)
    }

    func sessionConfiguration() -> SwitcherSessionConfiguration {
        stateLock.lock()
        let configuration = activeConfiguration
        stateLock.unlock()
        return configuration
    }

    /// Returns an immutable snapshot immediately. The getter never schedules AX
    /// work itself: base-window callbacks, configuration changes, topology changes,
    /// and explicit warmups are the only enrichment invalidation sources. This
    /// prevents `onItemsChanged -> getItems -> enrichment` feedback loops.
    func getItems() -> [SwitcherItem] {
        let baseItems = base.getItems()

        stateLock.lock()
        let cached = cachedEnrichedItems
        let configuration = activeConfiguration
        stateLock.unlock()
        return cached.isEmpty
            ? provisionalItems(from: baseItems, configuration: configuration)
            : cached
    }

    @discardableResult
    func primeCacheIfNeeded() -> [SwitcherItem] {
        let baseItems = base.primeCacheIfNeeded()
        scheduleEnrichment(from: baseItems, forceCatalogRefresh: true)

        stateLock.lock()
        let cached = cachedEnrichedItems
        let configuration = activeConfiguration
        stateLock.unlock()
        return cached.isEmpty
            ? provisionalItems(from: baseItems, configuration: configuration)
            : cached
    }

    func warmCache(force: Bool = false) {
        if force { invalidateCatalogCache() }
        stateLock.lock()
        let baseItems = latestBaseItems
        stateLock.unlock()
        if !baseItems.isEmpty {
            scheduleEnrichment(
                from: baseItems,
                forceCatalogRefresh: force
            )
        }
        base.warmCache(force: force)
    }

    func currentFrontmostIdentity() -> SwitcherHistoryIdentity? {
        base.currentFrontmostIdentity()
    }

    @discardableResult
    func reconcileCurrentFrontmostHistory() -> SwitcherHistoryIdentity? {
        guard let identity = base.reconcileCurrentFrontmostHistory() else {
            return nil
        }
        if let descriptor = descriptor(for: identity) {
            history.noteActivation(identity, descriptor: descriptor)
        }
        return identity
    }

    @discardableResult
    func performQuickAction(
        _ action: SwitcherQuickAction,
        on item: SwitcherItem
    ) -> Bool {
        base.performQuickAction(action, on: item)
    }

    func managementActionAvailability(
        _ action: WindowManagementAction,
        on item: SwitcherItem
    ) -> WindowActionAvailability {
        actionProvider.availability(
            for: action,
            ownerPID: item.ownerPID,
            windowID: item.windowID
        )
    }

    func performManagementAction(
        _ action: WindowManagementAction,
        on item: SwitcherItem
    ) -> WindowActionResult {
        let result = actionProvider.perform(
            action,
            ownerPID: item.ownerPID,
            windowID: item.windowID
        )
        if result.succeeded {
            invalidateCatalogCache()
            base.warmCache(force: true)
        }
        return result
    }

    // MARK: Non-blocking enrichment

    private func scheduleEnrichment(
        from baseItems: [SwitcherItem],
        forceCatalogRefresh: Bool
    ) {
        stateLock.lock()
        let configuration = activeConfiguration
        let signature = ProductionEnrichmentInputSignature(
            configuration: configuration,
            items: baseItems
        )
        latestBaseItems = baseItems
        guard enrichmentGate.shouldSchedule(
            signature,
            force: forceCatalogRefresh
        ) else {
            stateLock.unlock()
            return
        }
        enrichmentGeneration &+= 1
        let generation = enrichmentGeneration
        stateLock.unlock()

        enrichmentQueue.async { [weak self] in
            guard let self else { return }

            self.stateLock.lock()
            guard generation == self.enrichmentGeneration else {
                self.stateLock.unlock()
                return
            }
            let currentItems = self.latestBaseItems
            let currentConfiguration = self.activeConfiguration
            self.stateLock.unlock()

            let result = self.buildEnrichedItems(
                from: currentItems,
                configuration: currentConfiguration,
                forceCatalogRefresh: forceCatalogRefresh
            )

            self.stateLock.lock()
            guard generation == self.enrichmentGeneration,
                  currentConfiguration == self.activeConfiguration else {
                self.stateLock.unlock()
                return
            }
            self.cachedEnrichedItems = result.items
            self.descriptorsByIdentity = result.descriptors
            self.stateLock.unlock()

            self.history.reconcileLiveWindows(
                Array(result.descriptors.values)
            )
            DispatchQueue.main.async { [weak self] in
                self?.onItemsChanged?(result.items)
            }
        }
    }

    private func buildEnrichedItems(
        from baseItems: [SwitcherItem],
        configuration: SwitcherSessionConfiguration,
        forceCatalogRefresh: Bool
    ) -> EnrichmentResult {
        let applications = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular &&
                $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }
        let appByPID = Dictionary(
            applications.map { ($0.processIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let snapshot = catalogSnapshot(
            applications: applications,
            forceRefresh: forceCatalogRefresh
        )

        var represented = Set<SwitcherHistoryIdentity>()
        var descriptors: [SwitcherHistoryIdentity: LiveWindowHistoryDescriptor] = [:]
        var items: [SwitcherItem] = []
        items.reserveCapacity(baseItems.count + snapshot.allWindows.count)

        for item in baseItems {
            let bundleIdentifier = item.sourceAppIdentifier ??
                item.ownerPID.flatMap { appByPID[$0]?.bundleIdentifier } ?? ""
            guard configuration.includes(bundleIdentifier: bundleIdentifier) else {
                continue
            }

            if let pid = item.ownerPID,
               let windowID = item.windowID,
               let metadata = snapshot.metadata(
                   ownerPID: pid,
                   windowID: windowID
               ) {
                guard shouldInclude(
                    metadata,
                    configuration: configuration
                ) else {
                    continue
                }
                let descriptor = historyDescriptor(
                    metadata: metadata,
                    app: appByPID[pid],
                    fallbackTitle: item.title
                )
                descriptors[item.historyIdentity] = descriptor
                represented.insert(item.historyIdentity)
                items.append(
                    clone(
                        item,
                        metadata: metadata,
                        descriptor: descriptor,
                        activation: { [weak self] in
                            self?.prepareWorkspaceIfNeeded(metadata.workspace)
                            item.activate()
                        }
                    )
                )
            } else {
                represented.insert(item.historyIdentity)
                items.append(item)
            }
        }

        // Synthesize eligible minimized and off-space windows that the public CG
        // list omitted. A later membership finalizer removes any process fallback
        // that is now represented by an exact window.
        for metadata in snapshot.allWindows.sorted(by: metadataOrdering) {
            let identity = SwitcherHistoryIdentity.appWindow(
                pid: metadata.ownerPID,
                windowID: metadata.windowID
            )
            guard !represented.contains(identity),
                  metadata.isStandardSwitcherWindow,
                  shouldInclude(metadata, configuration: configuration),
                  let app = appByPID[metadata.ownerPID] else {
                continue
            }

            let bundleIdentifier = app.bundleIdentifier ??
                "app-\(metadata.ownerPID)"
            let appName = app.localizedName ?? "Application"
            guard configuration.includes(bundleIdentifier: bundleIdentifier),
                  !preferences.excludesApp(
                      identifier: bundleIdentifier,
                      appName: appName
                  ),
                  !preferences.excludesWindowTitle(metadata.title) else {
                continue
            }

            let title = metadata.title.isEmpty ? appName : metadata.title
            let descriptor = historyDescriptor(
                metadata: metadata,
                app: app,
                fallbackTitle: title
            )
            descriptors[identity] = descriptor
            represented.insert(identity)

            items.append(
                SwitcherItem(
                    title: title,
                    subtitle: appName,
                    icon: app.icon,
                    previewImage: nil,
                    backdropImage: nil,
                    backdropFrame: metadata.frame,
                    backdropSourceScreenFrame: nil,
                    previewCacheKey: syntheticPreviewKey(
                        identity: identity,
                        title: title,
                        frame: metadata.frame
                    ),
                    historyIdentity: identity,
                    sourceAppIdentifier: bundleIdentifier,
                    kind: .appWindow,
                    isMinimized: metadata.isMinimized,
                    isFullscreen: metadata.isFullscreen,
                    workspaceSnapshot: metadata.workspace,
                    historyDescriptor: descriptor
                ) { [weak self] in
                    self?.activateExactSyntheticWindow(
                        metadata: metadata,
                        descriptor: descriptor,
                        app: app,
                        attempt: 0
                    )
                }
            )
        }

        return EnrichmentResult(
            items: SwitcherMembershipPolicy
                .deduplicatedWithoutRepresentedFallbacks(items),
            descriptors: descriptors
        )
    }

    private func provisionalItems(
        from baseItems: [SwitcherItem],
        configuration: SwitcherSessionConfiguration
    ) -> [SwitcherItem] {
        ProvisionalSwitcherPolicy.filteredItems(
            baseItems,
            configuration: configuration,
            globalVisibility: preferences.windowVisibilityScope,
            globalIncludesMinimized: preferences.includeMinimizedWindows
        )
    }

    private func shouldInclude(
        _ metadata: AXWindowMetadata,
        configuration: SwitcherSessionConfiguration
    ) -> Bool {
        if metadata.isMinimized && !configuration.includeMinimizedWindows {
            return false
        }

        switch configuration.visibilityScope {
        case .allSpaces:
            return true
        case .visibleSpaces:
            return metadata.isOnScreen
        case .currentSpaceOnly:
            if !metadata.workspace.memberships.isEmpty,
               !metadata.workspace.currentSpaceIDs.isEmpty {
                return metadata.workspace.isOnCurrentManagedSpace
            }
            return metadata.isOnScreen
        }
    }

    private func clone(
        _ item: SwitcherItem,
        metadata: AXWindowMetadata,
        descriptor: LiveWindowHistoryDescriptor,
        activation: @escaping () -> Void
    ) -> SwitcherItem {
        SwitcherItem(
            title: item.title,
            subtitle: item.subtitle,
            icon: item.icon,
            previewImage: item.previewImage,
            backdropImage: item.backdropImage,
            backdropFrame: item.backdropFrame ?? metadata.frame,
            backdropSourceScreenFrame: item.backdropSourceScreenFrame,
            previewCacheKey: item.previewCacheKey,
            historyIdentity: item.historyIdentity,
            sourceAppIdentifier: item.sourceAppIdentifier,
            kind: item.kind,
            dedupeKey: item.dedupeKey,
            isMinimized: metadata.isMinimized,
            isFullscreen: metadata.isFullscreen,
            workspaceSnapshot: metadata.workspace,
            historyDescriptor: descriptor,
            activate: activation
        )
    }

    private func historyDescriptor(
        metadata: AXWindowMetadata,
        app: NSRunningApplication?,
        fallbackTitle: String
    ) -> LiveWindowHistoryDescriptor {
        let identity = SwitcherHistoryIdentity.appWindow(
            pid: metadata.ownerPID,
            windowID: metadata.windowID
        )
        return LiveWindowHistoryDescriptor(
            identity: identity,
            bundleIdentifier: app?.bundleIdentifier ??
                "app-\(metadata.ownerPID)",
            title: metadata.title.isEmpty
                ? fallbackTitle
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
    }

    private func descriptor(
        for identity: SwitcherHistoryIdentity
    ) -> LiveWindowHistoryDescriptor? {
        stateLock.lock()
        let descriptor = descriptorsByIdentity[identity]
        stateLock.unlock()
        return descriptor
    }

    private func catalogSnapshot(
        applications: [NSRunningApplication],
        forceRefresh: Bool
    ) -> AXWindowCatalogSnapshot {
        stateLock.lock()
        if !forceRefresh,
           let catalogCache,
           Date().timeIntervalSince(catalogCacheDate) <= catalogRefreshInterval {
            stateLock.unlock()
            return catalogCache
        }
        stateLock.unlock()

        let refreshed = catalog.snapshot(for: applications)
        stateLock.lock()
        catalogCache = refreshed
        catalogCacheDate = Date()
        stateLock.unlock()
        return refreshed
    }

    private func invalidateCatalogCache() {
        stateLock.lock()
        catalogCache = nil
        catalogCacheDate = .distantPast
        enrichmentGate.invalidate()
        enrichmentGeneration &+= 1
        stateLock.unlock()
    }

    // MARK: Exact activation

    private func prepareWorkspaceIfNeeded(
        _ snapshot: WindowWorkspaceSnapshot
    ) {
        guard !snapshot.isOnCurrentManagedSpace,
              let workspace = snapshot.primaryWorkspace else {
            return
        }
        _ = workspaceProvider.prepareActivation(of: workspace)
    }

    private func activateExactSyntheticWindow(
        metadata: AXWindowMetadata,
        descriptor: LiveWindowHistoryDescriptor,
        app: NSRunningApplication,
        attempt: Int
    ) {
        if attempt == 0 {
            prepareWorkspaceIfNeeded(metadata.workspace)
        }
        guard let window = AXWindowIdentityLookup.windowElement(
            ownerPID: metadata.ownerPID,
            windowID: metadata.windowID
        ) else {
            logActivationFailure(
                metadata,
                reason: "exact AX window is unavailable"
            )
            return
        }

        if metadata.isMinimized {
            let restoreResult = AXUIElementSetAttributeValue(
                window,
                kAXMinimizedAttribute as CFString,
                kCFBooleanFalse
            )
            guard restoreResult == .success else {
                logActivationFailure(
                    metadata,
                    reason: "restore failed with AX error \(restoreResult.rawValue)"
                )
                return
            }
        }

        app.unhide()
        _ = app.activate(options: [.activateIgnoringOtherApps])
        let axApp = AXUIElementCreateApplication(metadata.ownerPID)
        _ = AXUIElementSetAttributeValue(
            axApp,
            kAXFrontmostAttribute as CFString,
            kCFBooleanTrue
        )
        _ = AXUIElementSetAttributeValue(
            axApp,
            kAXMainWindowAttribute as CFString,
            window
        )
        _ = AXUIElementSetAttributeValue(
            axApp,
            kAXFocusedWindowAttribute as CFString,
            window
        )
        _ = AXUIElementSetAttributeValue(
            window,
            kAXMainAttribute as CFString,
            kCFBooleanTrue
        )
        _ = AXUIElementSetAttributeValue(
            window,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
        _ = AXUIElementPerformAction(
            window,
            kAXRaiseAction as CFString
        )

        if isExactWindowFrontmost(metadata) {
            history.noteActivation(
                descriptor.identity,
                descriptor: descriptor
            )
            onActivationConfirmed?(
                descriptor.identity,
                metadata.ownerPID
            )
            invalidateCatalogCache()
            base.warmCache(force: true)
            return
        }

        guard attempt < 8 else {
            logActivationFailure(
                metadata,
                reason: "exact focus verification timed out"
            )
            return
        }
        let delay = 0.05 + Double(attempt) * 0.08
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.activateExactSyntheticWindow(
                metadata: metadata,
                descriptor: descriptor,
                app: app,
                attempt: attempt + 1
            )
        }
    }

    private func isExactWindowFrontmost(
        _ metadata: AXWindowMetadata
    ) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?
            .processIdentifier == metadata.ownerPID else {
            return false
        }
        let axApp = AXUIElementCreateApplication(metadata.ownerPID)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedWindowAttribute as CFString,
            &value
        ) == .success,
        let value else {
            return false
        }
        let focused = unsafeBitCast(value, to: AXUIElement.self)
        return AXWindowIdentityLookup.windowID(for: focused) ==
            metadata.windowID
    }

    private func logActivationFailure(
        _ metadata: AXWindowMetadata,
        reason: String
    ) {
        os_log(
            .error,
            log: productionSwitcherLog,
            "Exact synthetic activation failed (pid=%{public}d window=%{public}u reason=%{public}@)",
            metadata.ownerPID,
            metadata.windowID,
            reason
        )
    }

    private func syntheticPreviewKey(
        identity: SwitcherHistoryIdentity,
        title: String,
        frame: CGRect?
    ) -> String {
        let frame = frame ?? .zero
        return [
            identity.stableKey,
            title.lowercased(),
            Int(frame.minX.rounded()).description,
            Int(frame.minY.rounded()).description,
            Int(frame.width.rounded()).description,
            Int(frame.height.rounded()).description,
        ].joined(separator: "|")
    }

    private func metadataOrdering(
        _ lhs: AXWindowMetadata,
        _ rhs: AXWindowMetadata
    ) -> Bool {
        let lhsRank = history.rank(
            of: .appWindow(
                pid: lhs.ownerPID,
                windowID: lhs.windowID
            )
        )
        let rhsRank = history.rank(
            of: .appWindow(
                pid: rhs.ownerPID,
                windowID: rhs.windowID
            )
        )
        switch (lhsRank, rhsRank) {
        case let (.some(left), .some(right)) where left != right:
            return left < right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            if lhs.isMinimized != rhs.isMinimized {
                return !lhs.isMinimized
            }
            if lhs.ownerPID != rhs.ownerPID {
                return lhs.ownerPID < rhs.ownerPID
            }
            return lhs.windowID < rhs.windowID
        }
    }
}
