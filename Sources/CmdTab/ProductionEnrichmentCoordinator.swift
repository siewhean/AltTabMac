import Foundation

/// Compatibility signature retained for existing focused regression coverage.
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
}

/// Compatibility gate retained for existing tests. The production facade uses
/// `ProductionEnrichmentCoordinator`, which additionally tracks in-flight work,
/// freshness, invalidation generations, and published material signatures.
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

/// Shared fail-closed profile membership policy.
enum ProvisionalSwitcherPolicy {
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
                return configuration.visibilityScope == .allSpaces
            }
            switch configuration.visibilityScope {
            case .allSpaces:
                return true
            case .visibleSpaces:
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

struct ProductionEnrichmentFingerprint: Equatable {
    let baseItemKeys: [String]
    let configuration: SwitcherSessionConfiguration
    let invalidationEpoch: UInt64
}

struct ProductionEnrichmentTicket: Equatable {
    let generation: UInt64
    let fingerprint: ProductionEnrichmentFingerprint
}

/// Coalesces asynchronous Accessibility/workspace enrichment requests.
///
/// UI reads are side-effect free. Explicit base-window, profile, permission,
/// display, action, and refresh events request enrichment. Identical in-flight or
/// fresh requests are dropped, stale generations cannot install cache data, and
/// unchanged material results are not republished to the controller.
enum ProductionEnrichmentCompletion: Equatable {
    case stale
    case accepted(shouldPublish: Bool)
}

final class ProductionEnrichmentCoordinator {
    private let lock = NSLock()
    private let freshnessInterval: TimeInterval

    private var invalidationEpoch: UInt64 = 0
    private var nextGeneration: UInt64 = 0
    private var inFlight: ProductionEnrichmentTicket?
    private var lastCompletedFingerprint: ProductionEnrichmentFingerprint?
    private var lastCompletedAt = Date.distantPast
    private var lastPublishedSignature: [String] = []

    init(freshnessInterval: TimeInterval = 0.35) {
        self.freshnessInterval = freshnessInterval
    }

    func request(
        baseItemKeys: [String],
        configuration: SwitcherSessionConfiguration,
        force: Bool,
        now: Date = Date()
    ) -> ProductionEnrichmentTicket? {
        lock.lock()
        defer { lock.unlock() }

        let fingerprint = ProductionEnrichmentFingerprint(
            baseItemKeys: baseItemKeys,
            configuration: configuration,
            invalidationEpoch: invalidationEpoch
        )
        if inFlight?.fingerprint == fingerprint {
            return nil
        }
        if !force,
           lastCompletedFingerprint == fingerprint,
           now.timeIntervalSince(lastCompletedAt) <= freshnessInterval {
            return nil
        }

        nextGeneration &+= 1
        let ticket = ProductionEnrichmentTicket(
            generation: nextGeneration,
            fingerprint: fingerprint
        )
        inFlight = ticket
        return ticket
    }

    func complete(
        _ ticket: ProductionEnrichmentTicket,
        materialSignature: [String],
        now: Date = Date()
    ) -> ProductionEnrichmentCompletion {
        lock.lock()
        defer { lock.unlock() }

        guard inFlight == ticket,
              ticket.fingerprint.invalidationEpoch == invalidationEpoch else {
            return .stale
        }
        inFlight = nil
        lastCompletedFingerprint = ticket.fingerprint
        lastCompletedAt = now

        guard lastPublishedSignature != materialSignature else {
            return .accepted(shouldPublish: false)
        }
        lastPublishedSignature = materialSignature
        return .accepted(shouldPublish: true)
    }

    func abandon(_ ticket: ProductionEnrichmentTicket) {
        lock.lock()
        if inFlight == ticket { inFlight = nil }
        lock.unlock()
    }

    func invalidate() {
        lock.lock()
        invalidationEpoch &+= 1
        inFlight = nil
        lastCompletedFingerprint = nil
        lastCompletedAt = .distantPast
        lock.unlock()
    }

    struct Snapshot: Equatable {
        let hasInFlightRequest: Bool
        let invalidationEpoch: UInt64
        let lastPublishedSignature: [String]
    }

    func snapshotForTesting() -> Snapshot {
        lock.lock()
        let value = Snapshot(
            hasInFlightRequest: inFlight != nil,
            invalidationEpoch: invalidationEpoch,
            lastPublishedSignature: lastPublishedSignature
        )
        lock.unlock()
        return value
    }
}
