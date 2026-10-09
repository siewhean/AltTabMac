import XCTest
@testable import CmdTab

final class FrontmostIdentityCacheTests: XCTestCase {
    private let window = SwitcherHistoryIdentity.appWindow(pid: 42, windowID: 7)

    func testCompletedRefreshServesOnlyTheSameFrontmostProcess() {
        let cache = FrontmostIdentityCache()
        let generation = cache.beginRefresh()
        cache.finishRefresh(generation: generation, pid: 42, identity: window)

        XCTAssertEqual(cache.validIdentity(for: 42)?.identity, window)
        XCTAssertNil(cache.validIdentity(for: 43), "Another app is frontmost: use the exact lookup.")
    }

    func testPendingFocusChangeForcesTheExactLookup() {
        let cache = FrontmostIdentityCache()
        let first = cache.beginRefresh()
        cache.finishRefresh(generation: first, pid: 42, identity: window)
        _ = cache.beginRefresh()

        XCTAssertNil(
            cache.validIdentity(for: 42),
            "While a newer focus change is processed the cached window may be wrong."
        )
    }

    func testSupersededBackgroundResultIsDiscarded() {
        let cache = FrontmostIdentityCache()
        let older = cache.beginRefresh()
        let newer = cache.beginRefresh()
        cache.finishRefresh(generation: older, pid: 42, identity: window)
        XCTAssertNil(cache.validIdentity(for: 42))

        let current = SwitcherHistoryIdentity.appWindow(pid: 42, windowID: 8)
        cache.finishRefresh(generation: newer, pid: 42, identity: current)
        XCTAssertEqual(cache.validIdentity(for: 42)?.identity, current)
    }

    func testAnExactNilResultIsCachedRatherThanRecomputed() {
        let cache = FrontmostIdentityCache()
        let generation = cache.beginRefresh()
        cache.finishRefresh(generation: generation, pid: 42, identity: nil)

        let entry = cache.validIdentity(for: 42)
        XCTAssertNotNil(entry, "A completed lookup that found no window is still a valid answer.")
        XCTAssertNil(entry?.identity)
    }
}
