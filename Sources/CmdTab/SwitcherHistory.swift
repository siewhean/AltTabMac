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
        let items = SwitcherMembershipPolicy.deduplicatedWithoutRepresentedFallbacks(items)
        let rankByIdentity = Dictionary(
            uniqueKeysWithValues: historyEntries.enumerated().map { ($0.element, $0.offset) }
        )

        let ranked = items.enumerated().sorted { lhs, rhs in
            let lhsRank = rankByIdentity[lhs.element.historyIdentity]
            let rhsRank = rankByIdentity[rhs.element.historyIdentity]

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
           let currentIndex = ordered.firstIndex(where: {
               $0.historyIdentity == currentFrontmost
           }) {
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
        let items = SwitcherMembershipPolicy.deduplicatedWithoutRepresentedFallbacks(items)
        let historyEntries = history.snapshot()
        let rankByIdentity = Dictionary(
            uniqueKeysWithValues: historyEntries.enumerated().map { ($0.element, $0.offset) }
        )

        func appRank(bundleID: String?, pid: Int32?) -> Int? {
            historyEntries.firstIndex { $0.matches(bundleID: bundleID, pid: pid) }
        }

        func rank(for item: SwitcherItem) -> Int? {
            if let exact = rankByIdentity[item.historyIdentity] {
                return exact
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
           let currentIndex = ordered.firstIndex(where: {
               $0.historyIdentity == currentFrontmost
           }) {
            let activeItem = ordered.remove(at: currentIndex)
            ordered.append(activeItem)
        }

        return SwitcherMembershipPolicy.applyingPerApplicationLimit(
            ordered,
            limit: SwitcherPreferences.shared.maxWindowsPerApp,
            currentFrontmost: currentFrontmost
        )
    }
}