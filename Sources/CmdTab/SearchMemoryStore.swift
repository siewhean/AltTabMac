import Foundation
import CryptoKit
import os.log

private let searchMemoryLog = OSLog(
    subsystem: "CmdTab",
    category: "SearchMemoryStore"
)

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

        guard let data = defaults.data(forKey: defaultsKey) else {
            self.entries = [:]
            return
        }
        do {
            let decoded = try JSONDecoder().decode(
                [String: RememberedSelection].self,
                from: data
            )
            // Migrate any plaintext keys to SHA-256 hashes if necessary
            var migrated: [String: RememberedSelection] = [:]
            var didMigrate = false
            for (k, v) in decoded {
                let normalized = Self.normalizedMemoryQuery(k)
                guard !normalized.isEmpty else {
                    didMigrate = true
                    continue
                }
                let hashed = Self.hashKey(normalized)
                if hashed != k {
                    didMigrate = true
                }
                migrated[hashed] = v
            }
            self.entries = migrated
            if didMigrate {
                // Initialisation is single-threaded and `entries` is fully set
                // above, so persist directly. Dispatching onto `queue` and then
                // synchronously dispatching to that same queue traps at launch.
                persistLocked()
            }
        } catch {
            self.entries = [:]
            os_log(
                .error,
                log: searchMemoryLog,
                "Discarded invalid search-memory data (bytes=%{public}d, error=%{public}@)",
                data.count,
                String(describing: error)
            )
        }
    }

    func rememberedStableKey(for query: String) -> String? {
        guard let key = hashedKey(for: query) else { return nil }

        return queue.sync {
            entries[key]?.stableKey
        }
    }

    func clearMemory() {
        queue.sync {
            entries.removeAll()
            defaults.removeObject(forKey: defaultsKey)
        }
    }

    func noteSelection(query: String, identity: SwitcherHistoryIdentity) {
        guard let key = hashedKey(for: query) else { return }

        queue.sync {
            let existing = entries[key]
            entries[key] = RememberedSelection(
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
            defaults.set(try JSONEncoder().encode(entries), forKey: defaultsKey)
        } catch {
            os_log(
                .error,
                log: searchMemoryLog,
                "Could not persist search memory (entries=%{public}d, error=%{public}@)",
                entries.count,
                String(describing: error)
            )
        }
    }

    private func hashedKey(for query: String) -> String? {
        let normalized = Self.normalizedMemoryQuery(query)
        guard !normalized.isEmpty else { return nil }
        return Self.hashKey(normalized)
    }

    private static func hashKey(_ input: String) -> String {
        // If it's already a 64-char hex string, don't double-hash
        if input.count == 64 && input.allSatisfy({ $0.isHexDigit }) {
            return input
        }
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func normalizedMemoryQuery(_ query: String) -> String {
        let filteredScalars = query.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }
        return String(String.UnicodeScalarView(filteredScalars)).lowercased()
    }
}
