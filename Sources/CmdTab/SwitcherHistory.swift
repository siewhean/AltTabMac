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

    var ownerPID: pid_t? {
        switch self {
        case let .appWindow(pid, _): return pid
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
            if let bundleID,
               identityBundleID.caseInsensitiveCompare(bundleID) == .orderedSame {
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

    /// Diagnostic label for where an identity's rank comes from: an activation
    /// observed in this process, a record restored from durable history, or none.
    func rankSource(of identity: SwitcherHistoryIdentity) -> String {
        queue.sync {
            if let index = entries.firstIndex(of: identity) { return "session#\(index)" }
            if let index = restoredEntries.firstIndex(of: identity) { return "restored#\(index)" }
            return "none"
        }
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
            guard case let .appFallback(existingBundleID, existingPID) = existing else {
                return false
            }
            if let pid, existingPID == pid {
                return true
            }
            return existingBundleID.caseInsensitiveCompare(bundleID) == .orderedSame
        }
    }
}

enum SwitcherMembershipPolicy {
    /// The switcher lists windows, not applications. An app with no includable
    /// window (for example Calendar after its window is closed, which keeps the
    /// app running) is not shown. Application-only items are still produced
    /// upstream because enrichment uses them to define eligible processes.
    static func excludingApplicationOnlyItems(_ items: [SwitcherItem]) -> [SwitcherItem] {
        items.filter { $0.kind != .appFallback }
    }

    /// Removes duplicate identities and suppresses an app fallback whenever an
    /// exact window for the same process is present. The production AX synthesis
    /// path can discover windows that the original Core Graphics pass omitted;
    /// without this finalization, a minimized-only app would show both a fallback
    /// tile and its exact minimized window.
    static func deduplicatedWithoutRepresentedFallbacks(
        _ items: [SwitcherItem]
    ) -> [SwitcherItem] {
        let representedPIDs = Set(
            items
                .filter { $0.kind == .appWindow }
                .compactMap(\.ownerPID)
        )
        var seen = Set<String>()
        return items.filter { item in
            guard seen.insert(item.id).inserted else { return false }
            if item.kind == .appFallback,
               let pid = item.ownerPID,
               representedPIDs.contains(pid) {
                return false
            }
            return true
        }
    }

    /// Applies the existing global per-application cap after exact-window MRU
    /// ordering. The frontmost exact window is always retained and counts toward
    /// the cap, so adding AX-synthesized windows cannot silently bypass an
    /// established user preference or remove the active-window anchor.
    static func applyingPerApplicationLimit(
        _ orderedItems: [SwitcherItem],
        limit: Int,
        currentFrontmost: SwitcherHistoryIdentity?
    ) -> [SwitcherItem] {
        guard limit > 0 else { return orderedItems }

        let frontmostItem = currentFrontmost.flatMap { identity in
            orderedItems.first { $0.historyIdentity == identity }
        }
        let frontmostAppKey = frontmostItem.map(applicationKey)

        var countByApp: [String: Int] = [:]
        if let frontmostAppKey {
            countByApp[frontmostAppKey] = 1
        }

        var result: [SwitcherItem] = []
        result.reserveCapacity(orderedItems.count)
        for item in orderedItems {
            if item.historyIdentity == currentFrontmost {
                continue
            }
            guard item.kind == .appWindow else {
                result.append(item)
                continue
            }
            let key = applicationKey(item)
            let count = countByApp[key, default: 0]
            guard count < limit else { continue }
            countByApp[key] = count + 1
            result.append(item)
        }

        if let frontmostItem {
            result.append(frontmostItem)
        }
        return result
    }

    private static func applicationKey(_ item: SwitcherItem) -> String {
        if let identifier = item.sourceAppIdentifier, !identifier.isEmpty {
            return identifier.lowercased()
        }
        if let pid = item.ownerPID {
            return "pid:\(pid)"
        }
        return item.id
    }
}

enum SwitcherOrdering {
    static func orderedItems(
        _ items: [SwitcherItem],
        historyEntries: [SwitcherHistoryIdentity],
        currentFrontmost: SwitcherHistoryIdentity?
    ) -> [SwitcherItem] {
        recencyOrdered(
            SwitcherMembershipPolicy.deduplicatedWithoutRepresentedFallbacks(items),
            historyEntries: historyEntries,
            currentFrontmost: currentFrontmost,
            ranksFallbackItemsByApplication: false
        )
    }

    static func orderedItems(
        _ items: [SwitcherItem],
        history: SwitcherHistoryStore,
        currentFrontmost: SwitcherHistoryIdentity?
    ) -> [SwitcherItem] {
        let ordered = recencyOrdered(
            SwitcherMembershipPolicy.deduplicatedWithoutRepresentedFallbacks(items),
            historyEntries: history.snapshot(),
            currentFrontmost: currentFrontmost,
            ranksFallbackItemsByApplication: true
        )
        return SwitcherMembershipPolicy.applyingPerApplicationLimit(
            ordered,
            limit: SwitcherPreferences.shared.maxWindowsPerApp,
            currentFrontmost: currentFrontmost
        )
    }

    /// Effective recency rank of each item (by position in `items`).
    ///
    /// Exact window identities rank by their own history entry. An
    /// application-level entry is recorded when an app was activated but its
    /// focused window could not be resolved in time (a slow or busy app, an
    /// Accessibility timeout, a window still opening). That entry still means
    /// "this app was used then", so it carries over to exactly one of the
    /// app's windows: the one that was already most recent, else the first
    /// listed. Without this, using A, then B through such an activation, then
    /// C ranked A's window above B's and Command-Tab from C returned to A.
    /// Only one window inherits the rank, so repeated apps are never grouped.
    static func effectiveRanks(
        items: [SwitcherItem],
        historyEntries: [SwitcherHistoryIdentity]
    ) -> [Int?] {
        var exactRank: [SwitcherHistoryIdentity: Int] = [:]
        var applicationRankByPID: [pid_t: Int] = [:]
        var applicationRankByBundle: [String: Int] = [:]
        for (offset, entry) in historyEntries.enumerated() {
            if exactRank[entry] == nil { exactRank[entry] = offset }
            guard case let .appFallback(bundleID, pid) = entry else { continue }
            if let pid {
                if applicationRankByPID[pid] == nil { applicationRankByPID[pid] = offset }
            } else {
                let key = bundleID.lowercased()
                if applicationRankByBundle[key] == nil { applicationRankByBundle[key] = offset }
            }
        }

        var ranks: [Int?] = items.map { exactRank[$0.historyIdentity] }
        guard !applicationRankByPID.isEmpty || !applicationRankByBundle.isEmpty else {
            return ranks
        }

        var representativeByPID: [pid_t: Int] = [:]
        for (offset, item) in items.enumerated() where item.kind == .appWindow {
            guard let pid = item.ownerPID else { continue }
            guard let current = representativeByPID[pid] else {
                representativeByPID[pid] = offset
                continue
            }
            if (ranks[offset] ?? Int.max) < (ranks[current] ?? Int.max) {
                representativeByPID[pid] = offset
            }
        }

        for (pid, offset) in representativeByPID {
            let bundleRank = items[offset].sourceAppIdentifier
                .flatMap { applicationRankByBundle[$0.lowercased()] }
            let candidates = [applicationRankByPID[pid], bundleRank].compactMap { $0 }
            guard let applicationRank = candidates.min(),
                  applicationRank < (ranks[offset] ?? Int.max) else { continue }
            ranks[offset] = applicationRank
        }
        return ranks
    }

    private static func recencyOrdered(
        _ items: [SwitcherItem],
        historyEntries: [SwitcherHistoryIdentity],
        currentFrontmost: SwitcherHistoryIdentity?,
        ranksFallbackItemsByApplication: Bool
    ) -> [SwitcherItem] {
        var ranks = effectiveRanks(items: items, historyEntries: historyEntries)
        if ranksFallbackItemsByApplication {
            for (offset, item) in items.enumerated() where ranks[offset] == nil {
                guard item.kind == .appFallback,
                      let pid = item.historyIdentity.ownerPID else { continue }
                ranks[offset] = historyEntries.firstIndex {
                    $0.matches(bundleID: item.sourceAppIdentifier, pid: pid)
                }
            }
        }

        let ranked = items.indices.sorted { lhs, rhs in
            switch (ranks[lhs], ranks[rhs]) {
            case let (.some(lhsRank), .some(rhsRank)):
                if lhsRank != rhsRank { return lhsRank < rhsRank }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
            return lhs < rhs
        }

        var ordered = ranked.map { items[$0] }
        if let currentFrontmost,
           let currentIndex = ordered.firstIndex(where: {
               $0.historyIdentity == currentFrontmost
           }) {
            let activeItem = ordered.remove(at: currentIndex)
            ordered.append(activeItem)
        }
        return ordered
    }

    /// Keeps the order the user is already looking at while a session is open.
    ///
    /// Later publications (the capture pass, Accessibility enrichment) refresh
    /// each tile's content, drop windows that closed, and append windows that
    /// appeared, but never move existing tiles. Re-sorting mid-session inserted
    /// late-discovered windows (for example minimized ones) ahead of the
    /// selection, so the next Tab landed on a different window than the user
    /// was counting towards. The current window stays last.
    static func stableSessionOrder(
        current: [SwitcherItem],
        refreshed: [SwitcherItem],
        currentFrontmost: SwitcherHistoryIdentity?
    ) -> [SwitcherItem] {
        var refreshedByIdentity: [SwitcherHistoryIdentity: SwitcherItem] = [:]
        for item in refreshed where refreshedByIdentity[item.historyIdentity] == nil {
            refreshedByIdentity[item.historyIdentity] = item
        }
        var seen = Set<SwitcherHistoryIdentity>()
        var result: [SwitcherItem] = []
        result.reserveCapacity(refreshed.count)
        for item in current {
            guard let updated = refreshedByIdentity[item.historyIdentity],
                  seen.insert(item.historyIdentity).inserted else { continue }
            result.append(updated)
        }
        for item in refreshed where seen.insert(item.historyIdentity).inserted {
            result.append(item)
        }
        if let currentFrontmost,
           let index = result.firstIndex(where: { $0.historyIdentity == currentFrontmost }),
           index != result.count - 1 {
            result.append(result.remove(at: index))
        }
        return result
    }
}
