import Foundation

enum SwitcherHistoryIdentity: Hashable, Sendable {
    case appWindow(pid: Int32, windowID: UInt32)
    case appFallback(bundleID: String, pid: Int32?)

    var stableKey: String {
        switch self {
        case let .appWindow(pid, windowID):
            return "app-window:\(pid):\(windowID)"
        case let .appFallback(bundleID, pid):
            return "app-fallback:\(bundleID.lowercased()):\(pid ?? -1)"
        }
    }

    var sourceAppIdentifier: String? {
        switch self {
        case .appWindow:
            return nil
        case let .appFallback(bundleID, _):
            return bundleID
        }
    }

    /// The process ID associated with this identity, if any.
    var ownerPID: pid_t? {
        switch self {
        case let .appWindow(pid, _):   return pid
        case let .appFallback(_, pid): return pid
        }
    }

    var windowID: UInt32? {
        guard case let .appWindow(_, windowID) = self else { return nil }
        return windowID
    }

    func matches(bundleID: String?, pid: Int32?) -> Bool {
        switch self {
        case let .appWindow(identityPID, _):
            return pid == identityPID
        case let .appFallback(identityBundleID, identityPID):
            if let bundleID, identityBundleID.caseInsensitiveCompare(bundleID) == .orderedSame {
                return true
            }
            if let pid, let identityPID, identityPID == pid {
                return true
            }
            return false
        }
    }
}

final class SwitcherHistoryStore {
    static let shared = SwitcherHistoryStore()

    private let queue = DispatchQueue(label: "CmdTab.SwitcherHistoryStore")
    private let durableStore: DurableSwitcherHistoryStore
    private var entries: [SwitcherHistoryIdentity] = []
    private var restoredEntries: [SwitcherHistoryIdentity] = []
    private let maxEntries = 256

    init(durableStore: DurableSwitcherHistoryStore = .shared) {
        self.durableStore = durableStore
    }

    func noteActivation(_ identity: SwitcherHistoryIdentity) {
        noteActivation(identity, descriptor: nil)
    }

    func noteActivation(
        _ identity: SwitcherHistoryIdentity,
        descriptor: LiveWindowHistoryDescriptor?
    ) {
        queue.sync {
            entries.removeAll {
                $0 == identity || Self.isSupersededHistoryEntry($0, by: identity)
            }
            restoredEntries.removeAll {
                $0 == identity || Self.isSupersededHistoryEntry($0, by: identity)
            }
            entries.insert(identity, at: 0)
            if entries.count > maxEntries {
                entries.removeLast(entries.count - maxEntries)
            }
        }

        if let descriptor {
            durableStore.noteActivation(descriptor: descriptor)
        }
    }

    /// Matches persisted privacy-minimised records against the current live
    /// catalogue. Current-session observations always remain above restored
    /// ranks and one persisted record may map to at most one live identity.
    func reconcileLiveWindows(_ descriptors: [LiveWindowHistoryDescriptor]) {
        let restored = durableStore.restoredIdentities(for: descriptors)
        queue.sync {
            let current = Set(entries)
            restoredEntries = restored.filter { !current.contains($0) }
            if restoredEntries.count > maxEntries {
                restoredEntries.removeLast(restoredEntries.count - maxEntries)
            }
        }
    }

    func rank(of identity: SwitcherHistoryIdentity) -> Int? {
        queue.sync {
            combinedEntriesLocked().firstIndex(of: identity)
        }
    }

    func rankForApp(bundleID: String?, pid: Int32?) -> Int? {
        queue.sync {
            combinedEntriesLocked().firstIndex { $0.matches(bundleID: bundleID, pid: pid) }
        }
    }

    func snapshot() -> [SwitcherHistoryIdentity] {
        queue.sync { combinedEntriesLocked() }
    }

    func resetDurableHistory() {
        durableStore.reset()
        queue.sync {
            restoredEntries.removeAll()
        }
    }

    private func combinedEntriesLocked() -> [SwitcherHistoryIdentity] {
        var seen = Set<SwitcherHistoryIdentity>()
        return (entries + restoredEntries).filter { seen.insert($0).inserted }
    }

    private static func isSupersededHistoryEntry(
        _ existing: SwitcherHistoryIdentity,
        by activated: SwitcherHistoryIdentity
    ) -> Bool {
        switch activated {
        case let .appWindow(pid, _):
            guard case let .appFallback(_, fallbackPID) = existing else { return false }
            return fallbackPID == pid

        case let .appFallback(bundleID, pid):
            guard case let .appFallback(existingBundleID, existingPID) = existing else { return false }
            if let pid, existingPID == pid {
                return true
            }
            return existingBundleID.caseInsensitiveCompare(bundleID) == .orderedSame
        }
    }
}

enum SwitcherOrdering {
    static func orderedItems(
        _ items: [SwitcherItem],
        historyEntries: [SwitcherHistoryIdentity],
        currentFrontmost: SwitcherHistoryIdentity?
    ) -> [SwitcherItem] {
        let rankByIdentity = Dictionary(
            uniqueKeysWithValues: historyEntries.enumerated().map { ($0.element, $0.offset) }
        )

        let ranked = items.enumerated().sorted { lhs, rhs in
            let lhsRank = rankByIdentity[lhs.element.historyIdentity]
            let rhsRank = rankByIdentity[rhs.element.historyIdentity]

            switch (lhsRank, rhsRank) {
            case let (.some(lhsRank), .some(rhsRank)):
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }

            return lhs.offset < rhs.offset
        }

        var ordered = ranked.map(\.element)
        if let currentFrontmost,
           let currentIndex = ordered.firstIndex(where: { $0.historyIdentity == currentFrontmost }) {
            let activeItem = ordered.remove(at: currentIndex)
            ordered.append(activeItem)
        }

        return ordered
    }

    static func orderedItems(
        _ items: [SwitcherItem],
        history: SwitcherHistoryStore,
        currentFrontmost: SwitcherHistoryIdentity?
    ) -> [SwitcherItem] {
        let historyEntries = history.snapshot()
        let rankByIdentity = Dictionary(
            uniqueKeysWithValues: historyEntries.enumerated().map { ($0.element, $0.offset) }
        )
        let visibleCountByPID = Dictionary(grouping: items.compactMap(\.historyIdentity.ownerPID), by: { $0 })
            .mapValues(\.count)

        // For real window tiles, preserve exact window recency only. Falling back
        // to an app-level rank for several windows would collapse them into one
        // recency bucket. App-level continuity is safe only for a true fallback
        // tile or the sole visible window for that running application.
        func appRank(bundleID: String?, pid: Int32?) -> Int? {
            historyEntries.firstIndex { $0.matches(bundleID: bundleID, pid: pid) }
        }

        func rank(for item: SwitcherItem) -> Int? {
            if let exact = rankByIdentity[item.historyIdentity] {
                return exact
            }
            if item.kind == .appWindow,
               let pid = item.historyIdentity.ownerPID,
               visibleCountByPID[pid] == 1 {
                return appRank(bundleID: item.sourceAppIdentifier, pid: pid)
            }
            if item.kind == .appFallback,
               let pid = item.historyIdentity.ownerPID {
                return appRank(bundleID: item.sourceAppIdentifier, pid: pid)
            }
            return nil
        }

        let ranked = items.enumerated().sorted { lhs, rhs in
            let lhsRank = rank(for: lhs.element)
            let rhsRank = rank(for: rhs.element)

            switch (lhsRank, rhsRank) {
            case let (.some(lhsRank), .some(rhsRank)):
                if lhsRank != rhsRank { return lhsRank < rhsRank }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }

            return lhs.offset < rhs.offset
        }

        var ordered = ranked.map(\.element)
        if let currentFrontmost,
           let currentIndex = ordered.firstIndex(where: { $0.historyIdentity == currentFrontmost }) {
            let activeItem = ordered.remove(at: currentIndex)
            ordered.append(activeItem)
        }

        return ordered
    }
}
