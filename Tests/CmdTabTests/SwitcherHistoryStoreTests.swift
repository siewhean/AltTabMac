import XCTest
@testable import CmdTab

final class SwitcherHistoryStoreTests: XCTestCase {
    func testWindowActivationReplacesFallbackEntryForSameRunningApp() {
        let store = SwitcherHistoryStore()
        store.noteActivation(.appFallback(bundleID: "com.apple.finder", pid: 101))
        store.noteActivation(.appWindow(pid: 101, windowID: 11))

        XCTAssertEqual(
            store.snapshot(),
            [.appWindow(pid: 101, windowID: 11)]
        )
    }

    func testFallbackActivationDeduplicatesPreviousFallbackForSameApp() {
        let store = SwitcherHistoryStore()
        store.noteActivation(.appFallback(bundleID: "com.apple.finder", pid: 101))
        store.noteActivation(.appFallback(bundleID: "com.apple.finder", pid: 101))

        XCTAssertEqual(
            store.snapshot(),
            [.appFallback(bundleID: "com.apple.finder", pid: 101)]
        )
    }

    func testMostRecentActivationMovesToFrontWithoutRemovingSiblingWindows() {
        let store = SwitcherHistoryStore()
        let first = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 11)
        let second = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 12)
        let other = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 21)

        store.noteActivation(first)
        store.noteActivation(second)
        store.noteActivation(other)
        store.noteActivation(first)

        XCTAssertEqual(store.snapshot(), [first, other, second])
        XCTAssertEqual(store.rank(of: first), 0)
        XCTAssertEqual(store.rank(of: second), 2)
    }

    func testFallbackMatchingIsCaseInsensitiveAndCanMatchPID() {
        let bundleFallback = SwitcherHistoryIdentity.appFallback(
            bundleID: "Com.Example.Editor",
            pid: nil
        )
        let pidFallback = SwitcherHistoryIdentity.appFallback(
            bundleID: "com.example.other",
            pid: 404
        )

        XCTAssertTrue(
            bundleFallback.matches(bundleID: "com.example.editor", pid: nil)
        )
        XCTAssertTrue(pidFallback.matches(bundleID: nil, pid: 404))
        XCTAssertFalse(pidFallback.matches(bundleID: nil, pid: 405))
    }

    func testRankForAppFindsExactWindowByPID() {
        let store = SwitcherHistoryStore()
        store.noteActivation(.appWindow(pid: 101, windowID: 11))
        store.noteActivation(.appWindow(pid: 202, windowID: 22))

        XCTAssertEqual(store.rankForApp(bundleID: nil, pid: 202), 0)
        XCTAssertEqual(store.rankForApp(bundleID: nil, pid: 101), 1)
        XCTAssertNil(store.rankForApp(bundleID: nil, pid: 999))
    }

    func testHistoryIsBoundedToMostRecent256Entries() {
        let store = SwitcherHistoryStore()
        for index in 0..<300 {
            store.noteActivation(
                .appWindow(
                    pid: Int32(1_000 + index),
                    windowID: UInt32(10_000 + index)
                )
            )
        }

        let snapshot = store.snapshot()
        XCTAssertEqual(snapshot.count, 256)
        XCTAssertEqual(
            snapshot.first,
            .appWindow(pid: 1_299, windowID: 10_299)
        )
        XCTAssertEqual(
            snapshot.last,
            .appWindow(pid: 1_044, windowID: 10_044)
        )
    }
}
