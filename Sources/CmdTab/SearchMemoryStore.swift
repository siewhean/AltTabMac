import Foundation

final class SearchMemoryStore {
    static let shared = SearchMemoryStore()

    private struct RememberedSelection: Codable {
        var stableKey: String
        var count: Int
        var lastUsedAt: Date
    }

    private let queue = DispatchQueue(label: "CmdTab.SearchMemoryStore")
    private let defaults: UserDefaults
    private let defaultsKey: String
    private let maxEntries = 128
    private var entries: [String: RememberedSelection]

    init(
        defaults: UserDefaults = .standard,
        defaultsKey: String = "paletteSearchMemory"
    ) {
        self.defaults = defaults
        self.defaultsKey = defaultsKey

        if let data = defaults.data(forKey: defaultsKey) {
            do {
                self.entries = try JSONDecoder().decode([String: RememberedSelection].self, from: data)
            } catch {
                NSLog("[CmdTab] SearchMemoryStore decode error: \(error)")
                self.entries = [:]
            }
        } else {
            self.entries = [:]
        }
    }

    func rememberedStableKey(for query: String) -> String? {
        let normalizedQuery = normalizedMemoryQuery(query)
        guard !normalizedQuery.isEmpty else { return nil }

        return queue.sync {
            entries[normalizedQuery]?.stableKey
        }
    }

    func noteSelection(query: String, identity: SwitcherHistoryIdentity) {
        let normalizedQuery = normalizedMemoryQuery(query)
        guard !normalizedQuery.isEmpty else { return }

        queue.sync {
            let existing = entries[normalizedQuery]
            entries[normalizedQuery] = RememberedSelection(
                stableKey: identity.stableKey,
                count: (existing?.count ?? 0) + 1,
                lastUsedAt: Date()
            )
            pruneIfNeeded()
            persistLocked()
        }
    }

    private func pruneIfNeeded() {
        guard entries.count > maxEntries else { return }

        let overflow = entries.count - maxEntries
        let staleKeys = entries
            .sorted {
                if $0.value.count != $1.value.count {
                    return $0.value.count < $1.value.count
                }
                return $0.value.lastUsedAt < $1.value.lastUsedAt
            }
            .prefix(overflow)
            .map(\.key)

        for key in staleKeys {
            entries.removeValue(forKey: key)
        }
    }

    private func persistLocked() {
        do {
            let data = try JSONEncoder().encode(entries)
            defaults.set(data, forKey: defaultsKey)
        } catch {
            NSLog("[CmdTab] SearchMemoryStore encode error: \(error)")
        }
    }

    private func normalizedMemoryQuery(_ query: String) -> String {
        let filteredScalars = query.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(filteredScalars)).lowercased()
    }
}
