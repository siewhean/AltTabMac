import Foundation
import XCTest
@testable import CmdTab

@MainActor
final class SecureTrialClockPersistenceTests: XCTestCase {
    func testBlockedWriteDoesNotBlockCallerAndReadSeesHighWaterDate() {
        let backing = ClockMemoryStore(value: "100")
        let queue = DispatchQueue(label: "ClockPersistenceTests.blocked")
        let store = KeychainSecureTrialClockStore(store: backing, persistenceQueue: queue)
        let writeStarted = expectation(description: "Background write started")
        let release = DispatchSemaphore(value: 0)
        backing.beforeSave = { writeStarted.fulfill(); release.wait() }
        defer { release.signal() }

        let started = Date()
        store.saveLastSeenDate(Date(timeIntervalSince1970: 200))
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.1)
        wait(for: [writeStarted], timeout: 1)
        XCTAssertEqual(store.loadLastSeenDate(), Date(timeIntervalSince1970: 200))
        release.signal()
        let persisted = expectation(description: "Write persisted")
        queue.async { persisted.fulfill() }
        wait(for: [persisted], timeout: 1)
        XCTAssertEqual(backing.value, "200.000")
    }

    func testPersistenceMergesFutureStoredDateAndNeverMovesBackwards() {
        let backing = ClockMemoryStore(value: "300")
        let queue = DispatchQueue(label: "ClockPersistenceTests.monotonic")
        let store = KeychainSecureTrialClockStore(store: backing, persistenceQueue: queue)
        store.saveLastSeenDate(Date(timeIntervalSince1970: 200))
        store.saveLastSeenDate(Date(timeIntervalSince1970: 150))
        let persisted = expectation(description: "Both writes completed")
        queue.async { persisted.fulfill() }
        wait(for: [persisted], timeout: 1)
        XCTAssertEqual(backing.value, "300.000")
        XCTAssertEqual(store.loadLastSeenDate(), Date(timeIntervalSince1970: 300))
    }

    func testClearIsOrderedBetweenBlockedOldWriteAndNewSave() {
        let backing = ClockMemoryStore(value: "100")
        let queue = DispatchQueue(label: "ClockPersistenceTests.clear")
        let store = KeychainSecureTrialClockStore(store: backing, persistenceQueue: queue)
        let writeStarted = expectation(description: "Old write started")
        let release = DispatchSemaphore(value: 0)
        let hookLock = NSLock()
        var firstWrite = true
        backing.beforeSave = {
            hookLock.lock()
            let shouldBlock = firstWrite
            firstWrite = false
            hookLock.unlock()
            if shouldBlock { writeStarted.fulfill(); release.wait() }
        }
        defer { release.signal() }
        store.saveLastSeenDate(Date(timeIntervalSince1970: 200))
        wait(for: [writeStarted], timeout: 1)
        store.clearLastSeenDate()
        XCTAssertNil(store.loadLastSeenDate(), "A pending clear must not reload the old date")
        store.saveLastSeenDate(Date(timeIntervalSince1970: 50))
        XCTAssertEqual(store.loadLastSeenDate(), Date(timeIntervalSince1970: 50))
        release.signal()
        let persisted = expectation(description: "Clear and new save completed")
        queue.async { persisted.fulfill() }
        wait(for: [persisted], timeout: 1)
        XCTAssertEqual(backing.value, "50.000")
        XCTAssertEqual(store.loadLastSeenDate(), Date(timeIntervalSince1970: 50))
    }
}

private final class ClockMemoryStore: LicenseKeyStore {
    private let lock = NSLock()
    private var storedValue: String?
    var beforeSave: (() -> Void)?

    init(value: String?) { storedValue = value }

    var value: String? {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func loadLicenseKey() -> String? { value }
    func loadLicenseKeySilently() -> String? { value }
    func saveLicenseKey(_ value: String) throws {
        beforeSave?()
        lock.lock()
        storedValue = value
        lock.unlock()
    }
    func clearLicenseKey() throws {
        lock.lock()
        storedValue = nil
        lock.unlock()
    }
}
