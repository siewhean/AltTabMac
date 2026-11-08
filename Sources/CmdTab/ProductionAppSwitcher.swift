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
    private var lastScheduledAt = Date.distantPast

    mutating func shouldSchedule(
        _ signature: ProductionEnrichmentInputSignature,
        force: Bool,
        now: Date = Date(),
        maximumAge: TimeInterval = 0.35
    ) -> Bool {
        if force || signature != lastScheduled || now.timeIntervalSince(lastScheduledAt) >= maximumAge {
            lastScheduled = signature
            lastScheduledAt = now
            return true
        }
        return false
    }

    mutating func invalidate() {
        lastScheduled = nil
        lastScheduledAt = .distantPast
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
                (configuration.includeMinimizedWindows || !item.isMinimized) &&
                (item.kind != .appFallback || configuration.visibilityScope == .allSpaces)
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

/// Final publication boundary shared by live enrichment and permission-free tests.
/// Missing AX rows alone are unknown. The raw AppSwitcher boundary may exclude
/// internally hidden surfaces using fresh AX siblings and exact desktop evidence.
/// Application fallbacks are computed after every exact-window filter has run.
enum ProductionMembershipFinalizer {
    static func items(
        _ candidates: [SwitcherItem],
        fallbackItems: [SwitcherItem],
        metadataByIdentity: [SwitcherHistoryIdentity: AXWindowMetadata],
        configuration: SwitcherSessionConfiguration,
        globalVisibility: WindowVisibilityScope,
        globalIncludesMinimized: Bool
    ) -> [SwitcherItem] {
        // Factories include only eligible running applications and honor global
        // exclusions. Use the same process set for exact and fallback items.
        let eligiblePIDs = Set(fallbackItems.compactMap(\.ownerPID))
        let filtered = candidates.filter { item in
            guard let pid = item.ownerPID, eligiblePIDs.contains(pid),
                  configuration.includes(bundleIdentifier: item.sourceAppIdentifier ?? "") else {
                return false
            }
            guard item.kind == .appWindow else {
                return configuration.visibilityScope == .allSpaces
            }
            if let metadata = metadataByIdentity[item.historyIdentity] {
                return metadata.isStandardSwitcherWindow && includes(metadata, configuration: configuration)
            }
            // Preserve eligible CG windows when AX silently omits them, while
            // retaining the fail-closed contract for a narrower profile.
            return ProvisionalSwitcherPolicy.permitsBaseSnapshot(
                profileVisibility: configuration.visibilityScope,
                globalVisibility: globalVisibility,
                profileIncludesMinimized: configuration.includeMinimizedWindows,
                globalIncludesMinimized: globalIncludesMinimized
            ) && (configuration.includeMinimizedWindows || !item.isMinimized)
        }
        let fallbacks = configuration.visibilityScope == .allSpaces
            ? fallbackItems.filter {
                configuration.includes(bundleIdentifier: $0.sourceAppIdentifier ?? "")
            }
            : []
        return SwitcherMembershipPolicy.deduplicatedWithoutRepresentedFallbacks(filtered + fallbacks)
    }

    static func includes(
        _ metadata: AXWindowMetadata,
        configuration: SwitcherSessionConfiguration
    ) -> Bool {
        guard configuration.includeMinimizedWindows || !metadata.isMinimized else { return false }
        switch configuration.visibilityScope {
        case .allSpaces:
            return true
        case .visibleSpaces:
            return metadata.isOnScreen
        case .currentSpaceOnly:
            if !metadata.workspace.memberships.isEmpty, !metadata.workspace.currentSpaceIDs.isEmpty {
                return metadata.workspace.isOnCurrentManagedSpace
            }
            return metadata.isOnScreen
        }
    }
}

/// Last published inventory for each recently used profile configuration.
///
/// Switching between shortcut profiles used to discard the only enriched
/// inventory, so the next switcher waited for a whole-desktop Accessibility
/// walk before it could appear (and a quick tap during that walk did nothing).
/// Each entry was enriched for exactly that configuration, so restoring it
/// never exposes items filtered for a different profile; it is bounded in age
/// so a long-unused profile still waits for fresh membership.
struct ProductionInventoryCache {
    struct Entry {
        let configuration: SwitcherSessionConfiguration
        let items: [SwitcherItem]
        let descriptors: [SwitcherHistoryIdentity: LiveWindowHistoryDescriptor]
        let suppressed: Set<SwitcherHistoryIdentity>
        let publishedAt: TimeInterval
    }

    static let maximumAge: TimeInterval = 60
    static let capacity = 4

    private(set) var entries: [Entry] = []

    mutating func store(_ entry: Entry) {
        entries.removeAll { $0.configuration == entry.configuration }
        entries.insert(entry, at: 0)
        if entries.count > Self.capacity {
            entries.removeLast(entries.count - Self.capacity)
        }
    }

    func entry(
        for configuration: SwitcherSessionConfiguration,
        now: TimeInterval
    ) -> Entry? {
        guard let entry = entries.first(where: { $0.configuration == configuration }) else {
            return nil
        }
        let age = now - entry.publishedAt
        return age >= 0 && age <= Self.maximumAge ? entry : nil
    }

    mutating func removeAll() { entries.removeAll() }
}

/// Reuses AX-only (minimized or off-Space) window captures between enrichment
/// passes. Every base publication triggers enrichment, and each pass used to
/// recapture every such window. A minimized window's content cannot change
/// while it stays in the Dock; other AX-only windows are reused briefly.
struct SyntheticPreviewCache {
    struct Entry {
        let assets: AppSwitcher.PreviewAssets
        let capturedAt: Date
        let frame: CGRect?
        let isMinimized: Bool
    }

    static let minimizedMaximumAge: TimeInterval = 60
    static let visibleMaximumAge: TimeInterval = 3

    private var entries: [SwitcherHistoryIdentity: Entry] = [:]

    func reusableAssets(
        for identity: SwitcherHistoryIdentity,
        frame: CGRect?,
        isMinimized: Bool,
        now: Date
    ) -> Entry? {
        guard let entry = entries[identity],
              entry.isMinimized == isMinimized,
              entry.frame == frame else { return nil }
        let age = now.timeIntervalSince(entry.capturedAt)
        let limit = isMinimized ? Self.minimizedMaximumAge : Self.visibleMaximumAge
        return age >= 0 && age <= limit ? entry : nil
    }

    mutating func store(_ entry: Entry, for identity: SwitcherHistoryIdentity) {
        entries[identity] = entry
    }

    /// Drops windows that are no longer part of the inventory.
    mutating func retain(only identities: Set<SwitcherHistoryIdentity>) {
        entries = entries.filter { identities.contains($0.key) }
    }

    var count: Int { entries.count }
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
        let suppressedBaseWindowIdentities: Set<SwitcherHistoryIdentity>
    }

    private let base: AppSwitcher
    private let inventoryProvider: (([SwitcherItem], SwitcherSessionConfiguration) -> [SwitcherItem])?
    private let preferences: SwitcherPreferences
    private let windowInventoryProvider: (() -> ([NSRunningApplication], AXWindowCatalogSnapshot))?
    private let previewCapture: ((pid_t, CGWindowID, CGRect) -> AppSwitcher.PreviewAssets?)?
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
    private var hasPublishedInventory = false
    private var suppressedBaseWindowIdentities = Set<SwitcherHistoryIdentity>()
    /// Coalesces queued enrichment work: a pass that has not started yet is
    /// skipped when a newer one was scheduled.
    private var enrichmentGeneration: UInt64 = 0
    /// Bumped only when in-flight results become wrong (a window was closed or
    /// quit by a switcher action). A newer *scheduled* pass no longer discards
    /// a finished one: under steady base publications that starved
    /// publication, leaving a stale or empty inventory on screen.
    private var invalidationEpoch: UInt64 = 0
    private var enrichmentGate = ProductionEnrichmentGate()
    private var inventoryCache = ProductionInventoryCache()
    private var syntheticPreviews = SyntheticPreviewCache()
    private var lastEnrichedMembershipKeys: [String]?

    private var catalogCache: AXWindowCatalogSnapshot?
    private var catalogCacheDate = Date.distantPast
    private let catalogRefreshInterval: TimeInterval = 0.35
    /// A publication that only changes previews (the base capture pass) does
    /// not need a new whole-desktop Accessibility walk.
    static let previewOnlyCatalogMaximumAge: TimeInterval = 2.0

    var onItemsChanged: (([SwitcherItem]) -> Void)?
    var onActivationConfirmed: ((SwitcherHistoryIdentity, pid_t) -> Void)?

    var hasCompleteInventory: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return hasPublishedInventory
    }

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
        actionProvider: ExactWindowActionProvider = .shared,
        initialConfiguration: SwitcherSessionConfiguration? = nil,
        inventoryProvider: (([SwitcherItem], SwitcherSessionConfiguration) -> [SwitcherItem])? = nil,
        windowInventoryProvider: (() -> ([NSRunningApplication], AXWindowCatalogSnapshot))? = nil,
        previewCapture: ((pid_t, CGWindowID, CGRect) -> AppSwitcher.PreviewAssets?)? = nil
    ) {
        self.base = base
        self.inventoryProvider = inventoryProvider
        self.windowInventoryProvider = windowInventoryProvider
        self.previewCapture = previewCapture
        self.preferences = preferences
        self.profileStore = profileStore
        self.history = history
        self.catalog = catalog
        self.workspaceProvider = workspaceProvider
        self.actionProvider = actionProvider

        if let initialConfiguration {
            activeConfiguration = initialConfiguration
        } else if let first = profileStore.profilesSnapshot().first(where: \.isEnabled),
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
            if let cached = inventoryCache.entry(
                for: configuration,
                now: ProcessInfo.processInfo.systemUptime
            ) {
                // Published for exactly this configuration moments ago.
                cachedEnrichedItems = cached.items
                descriptorsByIdentity = cached.descriptors
                suppressedBaseWindowIdentities = cached.suppressed
                hasPublishedInventory = true
            } else {
                // Never expose items enriched for a different profile. Reuse only a
                // provably safe exact subset while the new async enrichment pass runs.
                cachedEnrichedItems = ProvisionalSwitcherPolicy.filteredEnrichedItems(
                    cachedEnrichedItems,
                    configuration: configuration
                )
                hasPublishedInventory = false
                suppressedBaseWindowIdentities.removeAll()
                descriptorsByIdentity = descriptorsByIdentity.filter { identity, _ in
                    cachedEnrichedItems.contains { $0.historyIdentity == identity }
                }
            }
            lastEnrichedMembershipKeys = nil
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
        let baseItems = base.getCachedItems()

        stateLock.lock()
        let cached = cachedEnrichedItems
        let isComplete = hasPublishedInventory
        let suppressed = suppressedBaseWindowIdentities
        let configuration = activeConfiguration
        stateLock.unlock()
        let published = Self.publishedItems(
            cached, hasPublishedInventory: isComplete,
            provisionalItems: provisionalItems(from: baseItems, configuration: configuration),
            suppressedIdentities: suppressed
        )
        SnapshotDiagnosticsTracker.shared.recordPublishedPreviewStates(published)
        return published
    }

    @discardableResult
    func primeCacheIfNeeded() -> [SwitcherItem] {
        let baseItems = base.primeCacheIfNeeded()
        scheduleEnrichment(from: baseItems, forceCatalogRefresh: true)

        stateLock.lock()
        let cached = cachedEnrichedItems
        let isComplete = hasPublishedInventory
        let suppressed = suppressedBaseWindowIdentities
        let configuration = activeConfiguration
        stateLock.unlock()
        let published = Self.publishedItems(
            cached, hasPublishedInventory: isComplete,
            provisionalItems: provisionalItems(from: baseItems, configuration: configuration),
            suppressedIdentities: suppressed
        )
        SnapshotDiagnosticsTracker.shared.recordPublishedPreviewStates(published)
        return published
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

    func publishRecoveredPreview(windowID: CGWindowID) {
        base.publishRecoveredPreview(windowID: windowID)
    }

    func currentFrontmostIdentity() -> SwitcherHistoryIdentity? {
        base.currentFrontmostIdentity()
    }

    @discardableResult
    func reconcileCurrentFrontmostHistory() -> SwitcherHistoryIdentity? {
        guard let identity = base.currentFrontmostIdentity() else {
            return nil
        }
        reconcileFrontmostHistory(identity)
        return identity
    }

    /// Records an already resolved frontmost identity as the most recent use,
    /// so a presentation resolves the frontmost window once instead of once
    /// per caller.
    func reconcileFrontmostHistory(_ identity: SwitcherHistoryIdentity) {
        history.noteActivation(identity, descriptor: descriptor(for: identity))
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
            invalidateInFlightEnrichment()
            base.warmCache(force: true)
        }
        return result
    }

    // MARK: Non-blocking enrichment

    func scheduleEnrichment(
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
        let epoch = invalidationEpoch
        stateLock.unlock()

        enrichmentQueue.async { [weak self] in
            guard let self else { return }

            self.stateLock.lock()
            guard generation == self.enrichmentGeneration else {
                // A newer pass is queued behind this one; let it do the work.
                self.stateLock.unlock()
                return
            }
            let currentItems = self.latestBaseItems
            let currentConfiguration = self.activeConfiguration
            let catalogMaximumAge = Self.catalogMaximumAge(
                forcedRefresh: forceCatalogRefresh,
                membershipKeys: currentItems.map(\.id),
                lastEnrichedMembershipKeys: self.lastEnrichedMembershipKeys,
                defaultMaximumAge: self.catalogRefreshInterval
            )
            self.stateLock.unlock()

            let result = self.buildEnrichedItems(
                from: currentItems,
                configuration: currentConfiguration,
                forceCatalogRefresh: forceCatalogRefresh,
                catalogMaximumAge: catalogMaximumAge
            )

            self.stateLock.lock()
            guard Self.mayPublishEnrichment(
                epoch: epoch,
                currentEpoch: self.invalidationEpoch,
                configuration: currentConfiguration,
                activeConfiguration: self.activeConfiguration
            ) else {
                self.stateLock.unlock()
                return
            }
            self.hasPublishedInventory = true
            self.cachedEnrichedItems = result.items
            self.descriptorsByIdentity = result.descriptors
            self.suppressedBaseWindowIdentities = result.suppressedBaseWindowIdentities
            self.lastEnrichedMembershipKeys = currentItems.map(\.id)
            self.inventoryCache.store(.init(
                configuration: currentConfiguration,
                items: result.items,
                descriptors: result.descriptors,
                suppressed: result.suppressedBaseWindowIdentities,
                publishedAt: ProcessInfo.processInfo.systemUptime
            ))
            self.stateLock.unlock()

            self.history.reconcileLiveWindows(
                Array(result.descriptors.values)
            )
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.stateLock.lock()
                let isCurrent = Self.mayPublishEnrichment(
                    epoch: epoch,
                    currentEpoch: self.invalidationEpoch,
                    configuration: currentConfiguration,
                    activeConfiguration: self.activeConfiguration
                )
                self.stateLock.unlock()
                guard isCurrent else { return }
                SnapshotDiagnosticsTracker.shared.recordPublishedPreviewStates(result.items)
                self.onItemsChanged?(result.items)
            }
        }
    }

    /// A finished enrichment pass is published unless the inventory it was
    /// built from was explicitly invalidated or the profile changed meanwhile.
    static func mayPublishEnrichment(
        epoch: UInt64,
        currentEpoch: UInt64,
        configuration: SwitcherSessionConfiguration,
        activeConfiguration: SwitcherSessionConfiguration
    ) -> Bool {
        epoch == currentEpoch && configuration == activeConfiguration
    }

    /// The Accessibility catalogue must be fresh when membership may have
    /// changed. When the base publication lists exactly the windows the last
    /// enrichment saw (the capture pass only replaced previews), the recent
    /// catalogue is reused instead of walking every application again.
    static func catalogMaximumAge(
        forcedRefresh: Bool,
        membershipKeys: [String],
        lastEnrichedMembershipKeys: [String]?,
        defaultMaximumAge: TimeInterval
    ) -> TimeInterval {
        guard !forcedRefresh else { return 0 }
        guard let lastEnrichedMembershipKeys, lastEnrichedMembershipKeys == membershipKeys else {
            return defaultMaximumAge
        }
        return max(defaultMaximumAge, previewOnlyCatalogMaximumAge)
    }

    private func buildEnrichedItems(
        from baseItems: [SwitcherItem],
        configuration: SwitcherSessionConfiguration,
        forceCatalogRefresh: Bool,
        catalogMaximumAge: TimeInterval
    ) -> EnrichmentResult {
        if let inventoryProvider {
            let items = inventoryProvider(baseItems, configuration)
            return EnrichmentResult(items: items, descriptors: [:], suppressedBaseWindowIdentities: [])
        }
        let suppliedInventory = windowInventoryProvider?()
        let applications = suppliedInventory?.0 ?? NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular &&
                $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }
        let appByPID = Dictionary(
            applications.map { ($0.processIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let snapshot = suppliedInventory?.1 ?? catalogSnapshot(
            applications: applications,
            forceRefresh: forceCatalogRefresh,
            maximumAge: catalogMaximumAge
        )

        let knownLiveWindowIDsByPID = Dictionary(grouping: baseItems.compactMap { item -> (pid_t, CGWindowID)? in
            guard item.kind == .appWindow,
                  let pid = item.ownerPID,
                  let windowID = item.windowID else { return nil }
            return (pid, windowID)
        }, by: { $0.0 }).mapValues { Set($0.map { $0.1 }) }
        SwitcherPreviewContinuityStore.observe(
            snapshot: snapshot,
            knownLiveWindowIDsByPID: knownLiveWindowIDsByPID
        )

        var represented = Set<SwitcherHistoryIdentity>()
        var capturedSyntheticIdentities = Set<SwitcherHistoryIdentity>()
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
                let descriptor = historyDescriptor(
                    metadata: metadata,
                    app: appByPID[pid],
                    fallbackTitle: item.title
                )
                descriptors[item.historyIdentity] = descriptor
                represented.insert(item.historyIdentity)
                items.append(
                    Self.clone(
                        item,
                        metadata: metadata,
                        descriptor: descriptor,
                        activation: { [weak self] in
                            self?.prepareWorkspaceForActivation(
                                ownerPID: metadata.ownerPID,
                                windowID: metadata.windowID
                            )
                            item.activate()
                        }
                    )
                )
            } else {
                represented.insert(item.historyIdentity)
                // AX can omit an off-Space fullscreen window even while CG
                // still lists its exact ID. Keep that CG card, but prepare its
                // live Space before the base switcher tries to focus it.
                items.append(Self.preparedBaseItem(
                    item,
                    workspaceProvider: workspaceProvider,
                    isOnScreen: ExactWindowActivationPolicy.isTargetOnScreen
                ))
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

            // The base capture pass cannot see AX-only/minimized windows.
            // Capture their exact drawable here before falling back to deferred
            // ScreenCaptureKit recovery, which may omit minimized windows.
            let assets = syntheticPreviewAssets(for: metadata, identity: identity)
            capturedSyntheticIdentities.insert(identity)
            items.append(
                SwitcherPreviewResolver.item(
                    title: title,
                    subtitle: appName,
                    icon: app.icon,
                    previewImage: assets?.assets.thumbnail,
                    previewCaptureIsFresh: assets?.isFresh ?? false,
                    previewCapturedAt: assets?.capturedAt,
                    // A reused frame already went through recovery admission
                    // when it was captured; asking again every pass would
                    // turn each enrichment into a ScreenCaptureKit request.
                    allowsPreviewRecovery: assets.map { $0.isFresh } ?? true,
                    backdropImage: assets?.assets.backdrop,
                    backdropFrame: metadata.frame,
                    backdropSourceScreenFrame: nil,
                    previewCacheKey: syntheticPreviewKey(
                        identity: identity,
                        title: title,
                        frame: metadata.frame,
                        sourceAppIdentifier: bundleIdentifier
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

        let metadataByIdentity = Dictionary(
            snapshot.allWindows.map { metadata in
                (SwitcherHistoryIdentity.appWindow(pid: metadata.ownerPID, windowID: metadata.windowID), metadata)
            },
            uniquingKeysWith: { first, _ in first }
        )
        let finalizedItems = ProductionMembershipFinalizer.items(
            items,
            fallbackItems: applications.compactMap { base.makeFallbackItem(for: $0) },
            metadataByIdentity: metadataByIdentity,
            configuration: configuration,
            globalVisibility: preferences.windowVisibilityScope,
            globalIncludesMinimized: preferences.includeMinimizedWindows
        )
        let finalizedIdentities = Set(finalizedItems.map(\.historyIdentity))
        stateLock.lock()
        syntheticPreviews.retain(only: capturedSyntheticIdentities)
        stateLock.unlock()
        let suppressed = Set(baseItems.filter {
            $0.kind == .appWindow && !finalizedIdentities.contains($0.historyIdentity)
        }.map(\.historyIdentity))
        return EnrichmentResult(
            items: finalizedItems,
            descriptors: descriptors.filter { finalizedIdentities.contains($0.key) },
            suppressedBaseWindowIdentities: suppressed
        )
    }

    static func publishedItems(
        _ inventory: [SwitcherItem],
        hasPublishedInventory: Bool,
        provisionalItems: [SwitcherItem],
        suppressedIdentities: Set<SwitcherHistoryIdentity>
    ) -> [SwitcherItem] {
        // An empty complete inventory is authoritative too. Base callbacks must
        // pass through enrichment before they can alter a published session.
        // Cold discovery is asynchronous. Never activate a provisional app
        // fallback before AX has supplied that application's exact siblings.
        _ = provisionalItems
        _ = suppressedIdentities
        return hasPublishedInventory ? inventory : []
    }

    static func mergingCachedItems(
        _ cached: [SwitcherItem],
        baseItems: [SwitcherItem],
        suppressedIdentities: Set<SwitcherHistoryIdentity>
    ) -> [SwitcherItem] {
        let cachedIdentities = Set(cached.map(\.historyIdentity))
        let missingBaseItems = baseItems.filter {
            shouldAppendBaseItemToCachedItems(
                identity: $0.historyIdentity,
                cachedIdentities: cachedIdentities,
                suppressedIdentities: suppressedIdentities
            )
        }
        return SwitcherMembershipPolicy.deduplicatedWithoutRepresentedFallbacks(cached + missingBaseItems)
    }

    static func shouldAppendBaseItemToCachedItems(
        identity: SwitcherHistoryIdentity,
        cachedIdentities: Set<SwitcherHistoryIdentity>,
        suppressedIdentities: Set<SwitcherHistoryIdentity>
    ) -> Bool {
        !cachedIdentities.contains(identity) && !suppressedIdentities.contains(identity)
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
        ProductionMembershipFinalizer.includes(metadata, configuration: configuration)
    }

    static func clone(
        _ item: SwitcherItem,
        metadata: AXWindowMetadata,
        descriptor: LiveWindowHistoryDescriptor,
        activation: @escaping () -> Void
    ) -> SwitcherItem {
        SwitcherPreviewResolver.item(
            title: item.title,
            subtitle: item.subtitle,
            icon: item.icon,
            previewImage: item.previewImage,
            previewCaptureIsFresh: false, // Enrichment reuses an image; it is not a new capture.
            previewCapturedAt: item.previewCapturedAt,
            // The base item already admitted recovery when its capture failed.
            // An enrichment clone reuses that frame; scheduling here would turn
            // every AX publication into another ScreenCaptureKit request.
            allowsPreviewRecovery: false,
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

    /// Enrichment queue. Returns a recent capture of an AX-only window when one
    /// is still valid, otherwise captures it now and remembers the result.
    private func syntheticPreviewAssets(
        for metadata: AXWindowMetadata,
        identity: SwitcherHistoryIdentity
    ) -> (assets: AppSwitcher.PreviewAssets, capturedAt: Date, isFresh: Bool)? {
        let now = Date()
        stateLock.lock()
        let reusable = syntheticPreviews.reusableAssets(
            for: identity,
            frame: metadata.frame,
            isMinimized: metadata.isMinimized,
            now: now
        )
        stateLock.unlock()
        if let reusable {
            return (reusable.assets, reusable.capturedAt, false)
        }

        let captured: AppSwitcher.PreviewAssets?
        if let previewCapture {
            captured = previewCapture(metadata.ownerPID, metadata.windowID, metadata.frame ?? .zero)
        } else {
            captured = base.captureExactPreviewAssets(
                ownerPID: metadata.ownerPID, windowID: metadata.windowID,
                bounds: metadata.frame ?? .zero
            )
        }
        guard let captured else { return nil }
        stateLock.lock()
        syntheticPreviews.store(
            .init(assets: captured, capturedAt: now, frame: metadata.frame, isMinimized: metadata.isMinimized),
            for: identity
        )
        stateLock.unlock()
        return (captured, now, true)
    }

    private func catalogSnapshot(
        applications: [NSRunningApplication],
        forceRefresh: Bool,
        maximumAge: TimeInterval
    ) -> AXWindowCatalogSnapshot {
        stateLock.lock()
        if !forceRefresh,
           let catalogCache,
           Date().timeIntervalSince(catalogCacheDate) <= maximumAge {
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
        lastEnrichedMembershipKeys = nil
        enrichmentGate.invalidate()
        stateLock.unlock()
    }

    /// Discards enrichment results that are still being built: they may list a
    /// window that a switcher action has just closed or quit.
    private func invalidateInFlightEnrichment() {
        stateLock.lock()
        invalidationEpoch &+= 1
        stateLock.unlock()
    }

    // MARK: Exact activation

    static func preparedBaseItem(
        _ item: SwitcherItem,
        workspaceProvider: WindowWorkspaceProviding,
        isOnScreen: @escaping (pid_t, CGWindowID) -> Bool
    ) -> SwitcherItem {
        guard item.kind == .appWindow,
              let ownerPID = item.ownerPID,
              let windowID = item.windowID else { return item }
        return SwitcherPreviewResolver.item(
            title: item.title,
            subtitle: item.subtitle,
            icon: item.icon,
            previewImage: item.previewImage,
            previewCaptureIsFresh: false,
            previewCapturedAt: item.previewCapturedAt,
            // This wrapper also reuses a base item that owns any recovery.
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
            historyDescriptor: item.historyDescriptor
        ) {
            Self.prepareWorkspaceForActivation(
                ownerPID: ownerPID,
                windowID: windowID,
                workspaceProvider: workspaceProvider,
                isOnScreen: isOnScreen
            )
            item.activate()
        }
    }

    private func prepareWorkspaceForActivation(ownerPID: pid_t, windowID: CGWindowID) {
        Self.prepareWorkspaceForActivation(
            ownerPID: ownerPID,
            windowID: windowID,
            workspaceProvider: workspaceProvider,
            isOnScreen: ExactWindowActivationPolicy.isTargetOnScreen
        )
    }

    /// Inventory metadata can predate a fullscreen transition. Resolve the
    /// selected window's Space at commit time, while the switcher is still
    /// active, so an AX focus on a hidden Space is never mistaken for a switch.
    static func shouldPrepareWorkspace(
        _ snapshot: WindowWorkspaceSnapshot,
        isOnScreen: Bool
    ) -> Bool {
        if !snapshot.memberships.isEmpty && !snapshot.currentSpaceIDs.isEmpty {
            return !snapshot.isOnCurrentManagedSpace
        }
        // Core Graphics can report windows from two Spaces as onscreen at
        // once. Use that bit only when managed Space identity is unavailable.
        return !isOnScreen
    }

    static func prepareWorkspaceForActivation(
        ownerPID: pid_t,
        windowID: CGWindowID,
        workspaceProvider: WindowWorkspaceProviding,
        isOnScreen: (pid_t, CGWindowID) -> Bool
    ) {
        let onScreen = isOnScreen(ownerPID, windowID)
        workspaceProvider.refresh()
        let snapshot = workspaceProvider.snapshot(for: windowID, isOnScreen: onScreen)
        guard shouldPrepareWorkspace(snapshot, isOnScreen: onScreen) else { return }
        guard let workspace = snapshot.primaryWorkspace else {
            os_log(.info, log: productionSwitcherLog,
                   "Target Space membership unavailable; using exact focus fallback (pid=%{public}d window=%{public}u)",
                   ownerPID, windowID)
            return
        }
        let didPrepare = workspaceProvider.prepareActivation(of: workspace)
        os_log(didPrepare ? .info : .error, log: productionSwitcherLog,
               "Target Space preparation %{public}@ (pid=%{public}d window=%{public}u space=%{public}llu cgOnscreen=%{public}d)",
               didPrepare ? "accepted" : "failed", ownerPID, windowID, workspace.spaceID, onScreen ? 1 : 0)
    }

    /// Activates an AX-only (minimized or off-Space) window. Shares the base
    /// switcher's request ledger, so any newer switch cancels this chain.
    /// Workspace preparation and NSRunningApplication activation run on the
    /// main thread; Accessibility lookups, restores, raises, and verification
    /// run on the base activation queue.
    private func activateExactSyntheticWindow(
        metadata: AXWindowMetadata,
        descriptor: LiveWindowHistoryDescriptor,
        app: NSRunningApplication,
        attempt: Int,
        token existingToken: ActivationRequestLedger.Token? = nil
    ) {
        let requests = base.activationRequests
        let token = existingToken ?? requests.begin(pid: metadata.ownerPID)
        guard requests.isCurrent(token) else { return }
        if attempt == 0 {
            ActivationOutcomeTracker.shared.recordRequested()
            prepareWorkspaceForActivation(
                ownerPID: metadata.ownerPID,
                windowID: metadata.windowID
            )
        }

        base.activationQueue.async { [weak self] in
            guard let self, requests.isCurrent(token) else { return }
            guard let window = AXWindowIdentityLookup.windowElement(
                ownerPID: metadata.ownerPID,
                windowID: metadata.windowID
            ) else {
                DispatchQueue.main.async { [weak self] in
                    guard let self, requests.isCurrent(token) else { return }
                    ActivationOutcomeTracker.shared.record(
                        AXIsProcessTrusted() ? .targetDisappeared : .accessibilityUnavailable
                    )
                    self.logActivationFailure(metadata, reason: "exact AX window is unavailable")
                }
                return
            }

            if metadata.isMinimized {
                let restoreResult = AXUIElementSetAttributeValue(
                    window,
                    kAXMinimizedAttribute as CFString,
                    kCFBooleanFalse
                )
                guard restoreResult == .success else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self, requests.isCurrent(token) else { return }
                        ActivationOutcomeTracker.shared.record(.failure)
                        self.logActivationFailure(
                            metadata,
                            reason: "restore failed with AX error \(restoreResult.rawValue)"
                        )
                    }
                    return
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, requests.isCurrent(token) else { return }
                app.unhide()
                _ = app.activate(options: [.activateIgnoringOtherApps])

                self.base.activationQueue.async { [weak self] in
                    guard let self, requests.isCurrent(token) else { return }
                    Self.raiseSyntheticWindow(window, ownerPID: metadata.ownerPID)
                    let verified = self.isExactWindowFrontmost(metadata)

                    DispatchQueue.main.async { [weak self] in
                        guard let self, requests.isCurrent(token) else { return }
                        if verified {
                            ActivationOutcomeTracker.shared.record(.exactVerified)
                            self.history.noteActivation(
                                descriptor.identity,
                                descriptor: descriptor
                            )
                            self.onActivationConfirmed?(
                                descriptor.identity,
                                metadata.ownerPID
                            )
                            self.invalidateCatalogCache()
                            self.base.scheduleBackgroundRefresh()
                            return
                        }

                        guard attempt < 8 else {
                            ActivationOutcomeTracker.shared.record(.failure)
                            self.logActivationFailure(
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
                                attempt: attempt + 1,
                                token: token
                            )
                        }
                    }
                }
            }
        }
    }

    /// Activation queue. Makes the AX window main, focused, and raised.
    private static func raiseSyntheticWindow(_ window: AXUIElement, ownerPID: pid_t) {
        let axApp = AXUIElementCreateApplication(ownerPID)
        _ = AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementSetAttributeValue(axApp, kAXMainWindowAttribute as CFString, window)
        _ = AXUIElementSetAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, window)
        _ = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
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
        return ExactWindowActivationPolicy.mayConfirm(
            frontmostPID: metadata.ownerPID,
            focusedWindowID: AXWindowIdentityLookup.windowID(for: focused),
            targetPID: metadata.ownerPID,
            targetWindowID: metadata.windowID,
            isOnScreen: ExactWindowActivationPolicy.isTargetOnScreen(
                ownerPID: metadata.ownerPID,
                windowID: metadata.windowID
            )
        )
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
        frame: CGRect?,
        sourceAppIdentifier: String
    ) -> String {
        AppSwitcher.previewCacheKey(
            for: identity,
            title: title,
            bounds: frame ?? .zero,
            sourceAppIdentifier: sourceAppIdentifier
        )
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
