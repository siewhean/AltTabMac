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
}
