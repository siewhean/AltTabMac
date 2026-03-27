import XCTest
@testable import CmdTab

final class PaletteSearchTests: XCTestCase {
    func testPaletteSearchMatchesAcronym() {
        let items = [
            makeItem(title: "System Settings", appID: "com.apple.systempreferences", identity: .appWindow(pid: 101, windowID: 1)),
            makeItem(title: "Safari", appID: "com.apple.Safari", identity: .appWindow(pid: 202, windowID: 2)),
            makeItem(title: "Slack", appID: "com.tinyspeck.slackmacgap", identity: .appWindow(pid: 303, windowID: 3)),
        ]

        XCTAssertEqual(
            SwitcherWindowController.paletteFilteredItems(items, query: "ss").map(\.title),
            ["System Settings"]
        )
        XCTAssertEqual(
            SwitcherWindowController.paletteFilteredItems(items, query: "sl").map(\.title),
            ["Slack"]
        )
    }

    func testPaletteSearchUsesRememberedSelection() {
        let calendar = makeItem(
            title: "Calendar",
            appID: "com.apple.iCal",
            identity: .appWindow(pid: 101, windowID: 1)
        )
        let calculator = makeItem(
            title: "Calculator",
            appID: "com.apple.calculator",
            identity: .appWindow(pid: 202, windowID: 2)
        )

        let ranked = SwitcherWindowController.paletteFilteredItems(
            [calendar, calculator],
            query: "cal",
            rememberedStableKey: calculator.historyIdentity.stableKey
        )

        XCTAssertEqual(ranked.first?.title, "Calculator")
    }

    func testSearchMemoryStoreNormalizesQueries() {
        let defaults = UserDefaults(suiteName: "CmdTab.SearchMemoryStoreTests")!
        defaults.removePersistentDomain(forName: "CmdTab.SearchMemoryStoreTests")

        let store = SearchMemoryStore(
            defaults: defaults,
            defaultsKey: "paletteSearchMemoryTests"
        )
        let identity = SwitcherHistoryIdentity.appWindow(pid: 111, windowID: 42)

        store.noteSelection(query: "System Preferences", identity: identity)

        XCTAssertEqual(
            store.rememberedStableKey(for: "system-preferences"),
            identity.stableKey
        )
    }

    func testWindowExclusionRulesMatchAppIdentifiersAndTitles() {
        let entries = WindowExclusionRules.normalizedEntries(from: "com.apple.finder\nMusic")

        XCTAssertTrue(WindowExclusionRules.matchesApp(
            identifier: "com.apple.finder",
            appName: "Finder",
            entries: entries
        ))
        XCTAssertTrue(WindowExclusionRules.matchesApp(
            identifier: "com.apple.Music",
            appName: "Music",
            entries: entries
        ))
        XCTAssertFalse(WindowExclusionRules.matchesApp(
            identifier: "com.apple.Safari",
            appName: "Safari",
            entries: entries
        ))

        let titleEntries = WindowExclusionRules.normalizedEntries(from: "Picture in Picture, Color Picker")
        XCTAssertTrue(WindowExclusionRules.matchesWindowTitle("Picture in Picture — Safari", entries: titleEntries))
        XCTAssertTrue(WindowExclusionRules.matchesWindowTitle("Shared Color Picker", entries: titleEntries))
        XCTAssertFalse(WindowExclusionRules.matchesWindowTitle("Inbox", entries: titleEntries))
    }

    private func makeItem(title: String, appID: String, identity: SwitcherHistoryIdentity) -> SwitcherItem {
        SwitcherItem(
            title: title,
            subtitle: appID,
            icon: nil,
            previewImage: nil,
            historyIdentity: identity,
            sourceAppIdentifier: appID,
            kind: .appWindow
        ) {}
    }
}
