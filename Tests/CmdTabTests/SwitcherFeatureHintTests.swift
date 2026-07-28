import XCTest
@testable import CmdTab

@MainActor
final class SwitcherFeatureHintTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SwitcherFeatureHintTests")
        defaults.removePersistentDomain(forName: "SwitcherFeatureHintTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "SwitcherFeatureHintTests")
        defaults = nil
        super.tearDown()
    }

    func testEachStyleHasSpecificDiscoverabilityCopy() {
        XCTAssertEqual(
            SwitcherFeatureHintStore.hint(for: .classicGrid).id,
            "classic-grid-quick-actions"
        )
        XCTAssertTrue(
            SwitcherFeatureHintStore.hint(for: .commandPalette)
                .message.contains("Start typing")
        )
        XCTAssertTrue(
            SwitcherFeatureHintStore.hint(for: .radialMenu)
                .message.contains("ring")
        )
    }

    func testHintAppearsTwiceThenStops() {
        let store = SwitcherFeatureHintStore(
            defaults: defaults,
            keyPrefix: "testHints",
            maximumPresentations: 2
        )

        store.presentHint(for: .classicGrid)
        XCTAssertNotNil(store.visibleHint)
        store.dismiss()

        store.presentHint(for: .classicGrid)
        XCTAssertNotNil(store.visibleHint)
        store.dismiss()

        store.presentHint(for: .classicGrid)
        XCTAssertNil(store.visibleHint)
    }

    func testPresentationCountsAreIndependentByStyle() {
        let store = SwitcherFeatureHintStore(
            defaults: defaults,
            keyPrefix: "testHints",
            maximumPresentations: 1
        )

        store.presentHint(for: .classicGrid)
        XCTAssertEqual(store.visibleHint?.id, "classic-grid-quick-actions")
        store.dismiss()

        store.presentHint(for: .commandPalette)
        XCTAssertEqual(store.visibleHint?.id, "command-palette-search")
        store.dismiss()

        store.presentHint(for: .classicGrid)
        XCTAssertNil(store.visibleHint)
    }

    func testResetClearsPresentationHistory() {
        let store = SwitcherFeatureHintStore(
            defaults: defaults,
            keyPrefix: "testHints",
            maximumPresentations: 1
        )
        store.presentHint(for: .radialMenu)
        store.dismiss()
        store.presentHint(for: .radialMenu)
        XCTAssertNil(store.visibleHint)

        store.resetForTesting()
        store.presentHint(for: .radialMenu)
        XCTAssertNotNil(store.visibleHint)
    }
}
