import Foundation
import XCTest
@testable import CmdTab

final class DurableSwitcherHistoryTests: XCTestCase {
    func testPrivacyHashNeverContainsRawTitleOrURL() throws {
        let descriptor = LiveWindowHistoryDescriptor(
            identity: .appWindow(pid: 100, windowID: 7),
            bundleIdentifier: "com.example.Editor",
            title: "Secret Customer Roadmap",
            documentURL: URL(fileURLWithPath: "/Users/test/Secret/Customer-Roadmap.txt"),
            role: "AXWindow",
            subrole: "AXStandardWindow",
            bounds: CGRect(x: 10, y: 20, width: 900, height: 700),
            displayIdentifier: "display-1",
            workspaceKey: "workspace:display-1:1:user"
        )
        let record = DurableWindowHistoryRecord(
            descriptor: descriptor,
            activatedAt: Date(timeIntervalSince1970: 100)
        )
        let data = try JSONEncoder().encode(DurableWindowHistoryFile(records: [record]))
        let text = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(text.contains("Secret Customer Roadmap"))
        XCTAssertFalse(text.contains("Customer-Roadmap.txt"))
        XCTAssertNotNil(record.titleHash)
        XCTAssertNotNil(record.documentURLHash)
        XCTAssertEqual(record.titleHash?.count, 64)
    }

    func testUniqueDocumentURLRestoresExactIdentity() {
        let now = Date(timeIntervalSince1970: 1_000)
        let oldDescriptor = descriptor(
            identity: .appWindow(pid: 10, windowID: 1),
            title: "Document",
            url: URL(fileURLWithPath: "/tmp/document.txt"),
            x: 0
        )
        let record = DurableWindowHistoryRecord(
            descriptor: oldDescriptor,
            activatedAt: now.addingTimeInterval(-60)
        )
        let newIdentity = SwitcherHistoryIdentity.appWindow(pid: 22, windowID: 99)
        let live = descriptor(
            identity: newIdentity,
            title: "Renamed by App",
            url: URL(fileURLWithPath: "/tmp/document.txt"),
            x: 400
        )

        let matches = DurableHistoryMatcher.matches(
            records: [record],
            liveDescriptors: [live],
            now: now,
            expirationInterval: 10_000
        )

        XCTAssertEqual(matches.map(\.identity), [newIdentity])
        XCTAssertGreaterThan(matches[0].confidence, 150)
        XCTAssertEqual(
            DurableHistoryWriteMatcher.reusableRecordID(
                records: [record],
                descriptor: live,
                preferredRecordID: record.id,
                unavailableRecordIDs: []
            ),
            record.id,
            "An exact live mapping must survive mutable title, frame, or document metadata."
        )
    }

    func testDuplicateTitleIsRejectedAsAmbiguous() {
        let now = Date(timeIntervalSince1970: 1_000)
        let oldDescriptors = [
            descriptor(
                identity: .appWindow(pid: 10, windowID: 1),
                title: "WindowLab — Duplicate",
                url: nil,
                x: 80,
                y: 80
            ),
            descriptor(
                identity: .appWindow(pid: 10, windowID: 2),
                title: "WindowLab — Duplicate",
                url: nil,
                x: 104,
                y: 104
            ),
        ]
        let records = oldDescriptors.map {
            DurableWindowHistoryRecord(
                descriptor: $0,
                activatedAt: now.addingTimeInterval(-10)
            )
        }
        let live = [
            descriptor(
                identity: .appWindow(pid: 20, windowID: 101),
                title: "WindowLab — Duplicate",
                url: nil,
                x: 80,
                y: 80
            ),
            descriptor(
                identity: .appWindow(pid: 20, windowID: 102),
                title: "WindowLab — Duplicate",
                url: nil,
                x: 104,
                y: 104
            ),
        ]

        XCTAssertTrue(records.allSatisfy { $0.documentURLHash == nil })
        XCTAssertTrue(
            DurableHistoryMatcher.matches(
                records: records,
                liveDescriptors: live,
                now: now,
                expirationInterval: 10_000
            ).isEmpty,
            "Both nearby same-title records must remain ambiguous after identity churn."
        )

        let midpoint = descriptor(
            identity: .appWindow(pid: 20, windowID: 103),
            title: "WindowLab — Duplicate",
            url: nil,
            x: 92,
            y: 92
        )
        XCTAssertNil(
            DurableHistoryWriteMatcher.reusableRecordID(
                records: records,
                descriptor: midpoint,
                preferredRecordID: nil,
                unavailableRecordIDs: []
            ),
            "An ambiguous write must create a new record instead of collapsing two windows."
        )
        XCTAssertNil(
            DurableHistoryWriteMatcher.reusableRecordID(
                records: [records[0]],
                descriptor: live[0],
                preferredRecordID: nil,
                unavailableRecordIDs: [records[0].id]
            ),
            "A record already owned by a sibling live identity cannot be reused."
        )
    }

    func testDifferentBundleNeverInheritsRank() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let record = DurableWindowHistoryRecord(
            descriptor: descriptor(
                identity: .appWindow(pid: 10, windowID: 1),
                bundle: "com.example.first",
                title: "Shared Title",
                url: nil,
                x: 0
            ),
            activatedAt: now
        )
        let live = descriptor(
            identity: .appWindow(pid: 10, windowID: 1),
            bundle: "com.example.second",
            title: "Shared Title",
            url: nil,
            x: 0
        )

        XCTAssertTrue(
            DurableHistoryMatcher.matches(
                records: [record],
                liveDescriptors: [live],
                now: now,
                expirationInterval: 10_000
            ).isEmpty
        )
        XCTAssertNil(
            DurableHistoryWriteMatcher.reusableRecordID(
                records: [record],
                descriptor: live,
                preferredRecordID: record.id,
                unavailableRecordIDs: []
            )
        )

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DurableHistoryCollisionTests-\(UUID().uuidString)", isDirectory: true)
        let file = directory.appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DurableSwitcherHistoryStore(
            fileURL: file,
            maximumRecords: 20,
            expirationInterval: 10_000
        )
        let first = descriptor(
            identity: .appWindow(pid: 31, windowID: 1),
            bundle: "com.example.first",
            title: "Shared Title",
            url: URL(fileURLWithPath: "/tmp/shared.txt"),
            x: 0
        )
        let second = descriptor(
            identity: .appWindow(pid: 32, windowID: 2),
            bundle: "com.example.second",
            title: "Shared Title",
            url: URL(fileURLWithPath: "/tmp/shared.txt"),
            x: 0
        )
        store.noteActivation(descriptor: first, now: Date())
        store.noteActivation(descriptor: second, now: Date().addingTimeInterval(1))
        store.waitForPendingWrites()
        XCTAssertEqual(Set(store.snapshot().map(\.bundleIdentifier)), [
            "com.example.first",
            "com.example.second",
        ])

        store.noteActivation(descriptor: second, now: Date().addingTimeInterval(2))
        store.waitForPendingWrites()
        XCTAssertEqual(store.snapshot().count, 2)

        let sameTitleSibling = descriptor(
            identity: .appWindow(pid: 32, windowID: 3),
            bundle: "com.example.second",
            title: "Shared Title",
            url: URL(fileURLWithPath: "/tmp/shared.txt"),
            x: 0
        )
        store.noteActivation(descriptor: sameTitleSibling, now: Date().addingTimeInterval(3))
        store.waitForPendingWrites()
        XCTAssertEqual(
            store.snapshot().filter { $0.bundleIdentifier == "com.example.second" }.count,
            2,
            "Two exact same-title windows in one app must retain separate durable records."
        )
    }

    func testStaleRecordExpires() {
        let now = Date(timeIntervalSince1970: 10_000)
        let record = DurableWindowHistoryRecord(
            descriptor: descriptor(
                identity: .appWindow(pid: 10, windowID: 1),
                title: "Old",
                url: nil,
                x: 0
            ),
            activatedAt: Date(timeIntervalSince1970: 1)
        )

        XCTAssertTrue(
            DurableHistoryMatcher.matches(
                records: [record],
                liveDescriptors: [
                    descriptor(
                        identity: .appWindow(pid: 20, windowID: 2),
                        title: "Old",
                        url: nil,
                        x: 0
                    )
                ],
                now: now,
                expirationInterval: 100
            ).isEmpty
        )
    }

    func testStoreWritesVersionedFileWithOwnerOnlyPermissions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DurableHistoryTests-\(UUID().uuidString)", isDirectory: true)
        let file = directory.appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = DurableSwitcherHistoryStore(
            fileURL: file,
            maximumRecords: 10,
            expirationInterval: 10_000
        )
        store.noteActivation(
            descriptor: descriptor(
                identity: .appWindow(pid: 11, windowID: 12),
                title: "Private Title",
                url: nil,
                x: 24
            ),
            now: Date(timeIntervalSince1970: 100)
        )
        store.waitForPendingWrites()

        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        let data = try Data(contentsOf: file)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DurableWindowHistoryFile.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, DurableWindowHistoryFile.currentSchemaVersion)
        XCTAssertEqual(decoded.records.count, 1)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("Private Title"))
    }

    private func descriptor(
        identity: SwitcherHistoryIdentity,
        bundle: String = "com.example.Editor",
        title: String,
        url: URL?,
        x: CGFloat,
        y: CGFloat = 0
    ) -> LiveWindowHistoryDescriptor {
        LiveWindowHistoryDescriptor(
            identity: identity,
            bundleIdentifier: bundle,
            title: title,
            documentURL: url,
            role: "AXWindow",
            subrole: "AXStandardWindow",
            bounds: CGRect(x: x, y: y, width: 800, height: 600),
            displayIdentifier: "display-1",
            workspaceKey: "workspace:display-1:1:user"
        )
    }
}
