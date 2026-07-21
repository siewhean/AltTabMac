import Foundation

enum SwitcherHistoryIdentity: Hashable {
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
    private var entries: [SwitcherHistoryIdentity] = []
    private let maxEntries = 256

    func noteActivation(_ identity: SwitcherHistoryIdentity) {
        queue.sync {
            entries.removeAll {
                $0 == identity || Self.isSupersededHistoryEntry($0, by: identity)
            }
            entries.insert(identity, at: 0)
            if entries.count > maxEntries {
                entries.removeLast(entries.count - maxEntries)
            }
        }
    }

    func rank(of identity: SwitcherHistoryIdentity) -> Int? {
        queue.sync {
            entries.firstIndex(of: identity)
        }
    }

    func rankForApp(bundleID: String?, pid: Int32?) -> Int? {
        queue.sync {
            entries.firstIndex { $0.matches(bundleID: bundleID, pid: pid) }
        }
    }

    func snapshot() -> [SwitcherHistoryIdentity] {
        queue.sync { entries }
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
        let ranked = items.enumerated().sorted { lhs, rhs in
            let lhsRank = historyEntries.firstIndex(of: lhs.element.historyIdentity)
            let rhsRank = historyEntries.firstIndex(of: rhs.element.historyIdentity)

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

        let ranked = items.enumerated().sorted { lhs, rhs in
            let lhsRank = historyEntries.firstIndex(of: lhs.element.historyIdentity)
            let rhsRank = historyEntries.firstIndex(of: rhs.element.historyIdentity)

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
