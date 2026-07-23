import CoreGraphics
import CryptoKit
import Foundation

struct RoundedWindowBounds: Codable, Equatable, Hashable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    init(_ rect: CGRect?) {
        let rect = rect ?? .zero
        x = Int((rect.minX / 24).rounded()) * 24
        y = Int((rect.minY / 24).rounded()) * 24
        width = Int((rect.width / 24).rounded()) * 24
        height = Int((rect.height / 24).rounded()) * 24
    }

    func distance(to other: RoundedWindowBounds) -> Int {
        abs(x - other.x) + abs(y - other.y) + abs(width - other.width) + abs(height - other.height)
    }
}

struct LiveWindowHistoryDescriptor: Equatable {
    let identity: SwitcherHistoryIdentity
    let bundleIdentifier: String
    let title: String
    let documentURL: URL?
    let role: String?
    let subrole: String?
    let bounds: CGRect?
    let displayIdentifier: String?
    let workspaceKey: String?

    init(
        identity: SwitcherHistoryIdentity,
        bundleIdentifier: String,
        title: String,
        documentURL: URL? = nil,
        role: String? = nil,
        subrole: String? = nil,
        bounds: CGRect? = nil,
        displayIdentifier: String? = nil,
        workspaceKey: String? = nil
    ) {
        self.identity = identity
        self.bundleIdentifier = bundleIdentifier
        self.title = title
        self.documentURL = documentURL
        self.role = role
        self.subrole = subrole
        self.bounds = bounds
        self.displayIdentifier = displayIdentifier
        self.workspaceKey = workspaceKey
    }
}

struct DurableWindowHistoryRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let bundleIdentifier: String
    let titleHash: String?
    let documentURLHash: String?
    let role: String?
    let subrole: String?
    let bounds: RoundedWindowBounds
    let displayIdentifier: String?
    let workspaceKey: String?
    var lastActivatedAt: Date
    var lastSeenAt: Date

    init(
        id: UUID = UUID(),
        descriptor: LiveWindowHistoryDescriptor,
        activatedAt: Date
    ) {
        self.id = id
        bundleIdentifier = descriptor.bundleIdentifier.lowercased()
        titleHash = DurableHistoryPrivacy.hashNormalizedText(descriptor.title)
        documentURLHash = DurableHistoryPrivacy.hashDocumentURL(descriptor.documentURL)
        role = descriptor.role
        subrole = descriptor.subrole
        bounds = RoundedWindowBounds(descriptor.bounds)
        displayIdentifier = descriptor.displayIdentifier
        workspaceKey = descriptor.workspaceKey
        lastActivatedAt = activatedAt
        lastSeenAt = activatedAt
    }
}

struct DurableWindowHistoryFile: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    var records: [DurableWindowHistoryRecord]

    init(records: [DurableWindowHistoryRecord]) {
        schemaVersion = Self.currentSchemaVersion
        self.records = records
    }
}

enum DurableHistoryPrivacy {
    static func hashNormalizedText(_ text: String) -> String? {
        let normalized = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !normalized.isEmpty else { return nil }
        return sha256(normalized)
    }

    static func hashDocumentURL(_ url: URL?) -> String? {
        guard let url else { return nil }
        var components = URLComponents(url: url.standardizedFileURL, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        let stable = components?.string ?? url.standardizedFileURL.absoluteString
        guard !stable.isEmpty else { return nil }
        return sha256(stable)
    }

    static func sha256(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct DurableHistoryMatch: Equatable {
    let recordID: UUID
    let identity: SwitcherHistoryIdentity
    let confidence: Int
}

enum DurableHistoryMatcher {
    static let minimumConfidence = 70
    static let ambiguityMargin = 12

    private struct Candidate {
        let descriptor: LiveWindowHistoryDescriptor
        let titleHash: String?
        let documentHash: String?
        let bounds: RoundedWindowBounds
    }

    static func matches(
        records: [DurableWindowHistoryRecord],
        liveDescriptors: [LiveWindowHistoryDescriptor],
        now: Date,
        expirationInterval: TimeInterval
    ) -> [DurableHistoryMatch] {
        let live = liveDescriptors.map {
            Candidate(
                descriptor: $0,
                titleHash: DurableHistoryPrivacy.hashNormalizedText($0.title),
                documentHash: DurableHistoryPrivacy.hashDocumentURL($0.documentURL),
                bounds: RoundedWindowBounds($0.bounds)
            )
        }

        var usedIdentities = Set<SwitcherHistoryIdentity>()
        var results: [DurableHistoryMatch] = []

        let orderedRecords = records
            .filter { now.timeIntervalSince($0.lastSeenAt) <= expirationInterval }
            .sorted {
                if $0.lastActivatedAt != $1.lastActivatedAt {
                    return $0.lastActivatedAt > $1.lastActivatedAt
                }
                return $0.id.uuidString < $1.id.uuidString
            }

        for record in orderedRecords {
            let candidates = live.filter {
                !usedIdentities.contains($0.descriptor.identity) &&
                $0.descriptor.bundleIdentifier.caseInsensitiveCompare(record.bundleIdentifier) == .orderedSame
            }
            guard !candidates.isEmpty else { continue }

            let scored = candidates
                .compactMap { candidate -> (Candidate, Int)? in
                    guard let score = score(record: record, candidate: candidate) else { return nil }
                    return (candidate, score)
                }
                .sorted {
                    if $0.1 != $1.1 { return $0.1 > $1.1 }
                    return $0.0.descriptor.identity.stableKey < $1.0.descriptor.identity.stableKey
                }

            guard let best = scored.first, best.1 >= minimumConfidence else { continue }
            if scored.count > 1, scored[1].1 >= best.1 - ambiguityMargin {
                // Ambiguous candidates must not inherit durable rank.
                continue
            }

            usedIdentities.insert(best.0.descriptor.identity)
            results.append(
                DurableHistoryMatch(
                    recordID: record.id,
                    identity: best.0.descriptor.identity,
                    confidence: best.1
                )
            )
        }

        return results
    }

    static func score(
        record: DurableWindowHistoryRecord,
        descriptor: LiveWindowHistoryDescriptor
    ) -> Int? {
        score(
            record: record,
            candidate: Candidate(
                descriptor: descriptor,
                titleHash: DurableHistoryPrivacy.hashNormalizedText(descriptor.title),
                documentHash: DurableHistoryPrivacy.hashDocumentURL(descriptor.documentURL),
                bounds: RoundedWindowBounds(descriptor.bounds)
            )
        )
    }

    private static func score(
        record: DurableWindowHistoryRecord,
        candidate: Candidate
    ) -> Int? {
        var score = 0

        if let documentHash = record.documentURLHash {
            guard candidate.documentHash == documentHash else { return nil }
            score += 160
        } else if let titleHash = record.titleHash {
            guard candidate.titleHash == titleHash else { return nil }
            score += 85
        } else {
            // App windows with neither a document URL nor a title cannot be
            // restored safely. App-fallback entries remain session-only.
            return nil
        }

        if let role = record.role {
            guard candidate.descriptor.role == role else { return nil }
            score += 18
        }
        if let subrole = record.subrole {
            guard candidate.descriptor.subrole == subrole else { return nil }
            score += 18
        }

        let boundsDistance = record.bounds.distance(to: candidate.bounds)
        if boundsDistance == 0 {
            score += 30
        } else if boundsDistance <= 96 {
            score += 20
        } else if boundsDistance <= 288 {
            score += 8
        }

        if let display = record.displayIdentifier,
           display == candidate.descriptor.displayIdentifier {
            score += 12
        }
        if let workspaceKey = record.workspaceKey,
           workspaceKey == candidate.descriptor.workspaceKey {
            score += 10
        }

        return score
    }
}

/// Chooses an existing durable record only when the write can be attributed to
/// one exact live identity. This is deliberately stricter than a best-effort
/// metadata match: cross-app and ambiguous writes create new records instead of
/// silently stealing another window's rank.
enum DurableHistoryWriteMatcher {
    static func reusableRecordID(
        records: [DurableWindowHistoryRecord],
        descriptor: LiveWindowHistoryDescriptor,
        preferredRecordID: UUID?,
        unavailableRecordIDs: Set<UUID>
    ) -> UUID? {
        let bundleIdentifier = descriptor.bundleIdentifier.lowercased()

        if let preferredRecordID,
           let preferred = records.first(where: { $0.id == preferredRecordID }),
           preferred.bundleIdentifier == bundleIdentifier,
           !unavailableRecordIDs.contains(preferredRecordID) {
            // The in-memory one-to-one live mapping is stronger than mutable
            // title, URL, frame, display, or Space metadata.
            return preferredRecordID
        }

        let scored = records
            .filter {
                $0.bundleIdentifier == bundleIdentifier &&
                    !unavailableRecordIDs.contains($0.id)
            }
            .compactMap { record -> (UUID, Int)? in
                guard let score = DurableHistoryMatcher.score(
                    record: record,
                    descriptor: descriptor
                ), score >= DurableHistoryMatcher.minimumConfidence else {
                    return nil
                }
                return (record.id, score)
            }
            .sorted {
                if $0.1 != $1.1 { return $0.1 > $1.1 }
                return $0.0.uuidString < $1.0.uuidString
            }

        guard let best = scored.first else { return nil }
        if scored.count > 1,
           scored[1].1 >= best.1 - DurableHistoryMatcher.ambiguityMargin {
            return nil
        }
        return best.0
    }
}

final class DurableSwitcherHistoryStore {
    static let shared = DurableSwitcherHistoryStore()

    private let queue = DispatchQueue(label: "CmdTab.DurableSwitcherHistoryStore")
    private let fileURL: URL
    private let maximumRecords: Int
    private let expirationInterval: TimeInterval
    private var records: [DurableWindowHistoryRecord]
    private var recordIDByLiveIdentity: [SwitcherHistoryIdentity: UUID] = [:]
    private var liveIdentityByRecordID: [UUID: SwitcherHistoryIdentity] = [:]

    init(
        fileURL: URL? = nil,
        maximumRecords: Int = 256,
        expirationInterval: TimeInterval = 60 * 60 * 24 * 45
    ) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.maximumRecords = maximumRecords
        self.expirationInterval = expirationInterval
        records = Self.load(from: self.fileURL, expirationInterval: expirationInterval)
    }

    func restoredIdentities(
        for liveDescriptors: [LiveWindowHistoryDescriptor],
        now: Date = Date()
    ) -> [SwitcherHistoryIdentity] {
        queue.sync {
            let matches = DurableHistoryMatcher.matches(
                records: records,
                liveDescriptors: liveDescriptors,
                now: now,
                expirationInterval: expirationInterval
            )
            let descriptorByIdentity = Dictionary(
                uniqueKeysWithValues: liveDescriptors.map { ($0.identity, $0) }
            )
            let matchedRecordIDs = Set(matches.map(\.recordID))
            let matchedIdentityByRecord = Dictionary(
                uniqueKeysWithValues: matches.map { ($0.recordID, $0.identity) }
            )

            records = records.compactMap { record in
                guard now.timeIntervalSince(record.lastSeenAt) <= expirationInterval else {
                    return nil
                }
                guard matchedRecordIDs.contains(record.id),
                      let identity = matchedIdentityByRecord[record.id],
                      descriptorByIdentity[identity] != nil else {
                    return record
                }
                var updated = record
                updated.lastSeenAt = now
                return updated
            }

            let liveIdentities = Set(descriptorByIdentity.keys)
            recordIDByLiveIdentity = recordIDByLiveIdentity.filter { identity, recordID in
                liveIdentities.contains(identity) &&
                    records.contains(where: { $0.id == recordID })
            }
            liveIdentityByRecordID = Dictionary(
                uniqueKeysWithValues: recordIDByLiveIdentity.map { ($0.value, $0.key) }
            )
            for match in matches {
                guard liveIdentityByRecordID[match.recordID] == nil ||
                        liveIdentityByRecordID[match.recordID] == match.identity else {
                    continue
                }
                recordIDByLiveIdentity[match.identity] = match.recordID
                liveIdentityByRecordID[match.recordID] = match.identity
            }
            pruneIdentityMappingsLocked()
            persistLocked()

            return matches.map(\.identity)
        }
    }

    func noteActivation(
        descriptor: LiveWindowHistoryDescriptor,
        now: Date = Date()
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            self.records.removeAll {
                now.timeIntervalSince($0.lastSeenAt) > self.expirationInterval
            }
            self.pruneIdentityMappingsLocked()

            let unavailableRecordIDs = Set(
                self.liveIdentityByRecordID.compactMap { recordID, identity in
                    identity == descriptor.identity ? nil : recordID
                }
            )
            let matchingID = DurableHistoryWriteMatcher.reusableRecordID(
                records: self.records,
                descriptor: descriptor,
                preferredRecordID: self.recordIDByLiveIdentity[descriptor.identity],
                unavailableRecordIDs: unavailableRecordIDs
            )
            let recordID = matchingID ?? UUID()

            if let previousRecordID = self.recordIDByLiveIdentity[descriptor.identity],
               previousRecordID != recordID {
                self.liveIdentityByRecordID.removeValue(forKey: previousRecordID)
            }
            if let previousIdentity = self.liveIdentityByRecordID[recordID],
               previousIdentity != descriptor.identity {
                self.recordIDByLiveIdentity.removeValue(forKey: previousIdentity)
            }
            self.recordIDByLiveIdentity[descriptor.identity] = recordID
            self.liveIdentityByRecordID[recordID] = descriptor.identity

            let record = DurableWindowHistoryRecord(
                id: recordID,
                descriptor: descriptor,
                activatedAt: now
            )
            if let index = self.records.firstIndex(where: { $0.id == recordID }) {
                self.records[index] = record
            } else {
                self.records.insert(record, at: 0)
            }

            self.records.sort {
                if $0.lastActivatedAt != $1.lastActivatedAt {
                    return $0.lastActivatedAt > $1.lastActivatedAt
                }
                return $0.id.uuidString < $1.id.uuidString
            }
            if self.records.count > self.maximumRecords {
                self.records.removeLast(self.records.count - self.maximumRecords)
            }
            self.pruneIdentityMappingsLocked()
            self.persistLocked()
        }
    }

    func waitForPendingWrites() {
        queue.sync {}
    }

    func reset() {
        queue.sync {
            records.removeAll()
            recordIDByLiveIdentity.removeAll()
            liveIdentityByRecordID.removeAll()
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    func snapshot() -> [DurableWindowHistoryRecord] {
        queue.sync { records }
    }

    private func pruneIdentityMappingsLocked() {
        let recordIDs = Set(records.map(\.id))
        recordIDByLiveIdentity = recordIDByLiveIdentity.filter { _, recordID in
            recordIDs.contains(recordID)
        }
        liveIdentityByRecordID = liveIdentityByRecordID.filter { recordID, identity in
            recordIDs.contains(recordID) &&
                recordIDByLiveIdentity[identity] == recordID
        }
    }

    private func persistLocked() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(DurableWindowHistoryFile(records: records))
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
        } catch {
            // In-memory history remains authoritative when persistence fails.
        }
    }

    private static func load(
        from fileURL: URL,
        expirationInterval: TimeInterval,
        now: Date = Date()
    ) -> [DurableWindowHistoryRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(DurableWindowHistoryFile.self, from: data),
              file.schemaVersion == DurableWindowHistoryFile.currentSchemaVersion else {
            return []
        }
        return file.records
            .filter { now.timeIntervalSince($0.lastSeenAt) <= expirationInterval }
            .sorted {
                if $0.lastActivatedAt != $1.lastActivatedAt {
                    return $0.lastActivatedAt > $1.lastActivatedAt
                }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        return base
            .appendingPathComponent("CmdTab", isDirectory: true)
            .appendingPathComponent("window-history-v1.json", isDirectory: false)
    }
}
