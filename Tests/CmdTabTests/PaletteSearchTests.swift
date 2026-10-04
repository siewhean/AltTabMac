import XCTest
@testable import CmdTab

final class PaletteSearchTests: XCTestCase {
    func testPaletteSearchMatchesAcronymLikeAltTab() {
        let items = [
            makeItem(windowTitle: "System Settings", appName: "System Settings", appID: "com.apple.systempreferences", identity: .appWindow(pid: 101, windowID: 1)),
            makeItem(windowTitle: "Safari", appName: "Safari", appID: "com.apple.Safari", identity: .appWindow(pid: 202, windowID: 2)),
            makeItem(windowTitle: "Slack", appName: "Slack", appID: "com.tinyspeck.slackmacgap", identity: .appWindow(pid: 303, windowID: 3)),
        ]

        let ssResults = SwitcherWindowController.paletteFilteredItems(items, query: "ss").map(\.subtitle)
        XCTAssertEqual(ssResults.first, "System Settings")
        XCTAssertTrue(ssResults.contains("Safari"))

        let slResults = SwitcherWindowController.paletteFilteredItems(items, query: "sl").map(\.subtitle)
        XCTAssertEqual(slResults.first, "Slack")
    }

    func testPaletteSearchIncludesCurrentAppWhenItMatchesQuery() {
        let codex = makeItem(
            windowTitle: "Workspace",
            appName: "OpenAI Codex",
            appID: "com.openai.codex",
            identity: .appWindow(pid: 404, windowID: 4)
        )
        let mimestream = makeItem(
            windowTitle: "Inbox",
            appName: "Mimestream",
            appID: "com.mimestream.Mimestream",
            identity: .appWindow(pid: 505, windowID: 5)
        )

        XCTAssertEqual(
            SwitcherWindowController.paletteFilteredItems([mimestream, codex], query: "codex").map(\.subtitle),
            ["OpenAI Codex"]
        )
    }

    func testPaletteSearchMatchesJoinedWordQueryAgainstSpacedAppName() {
        let antiGravity = makeItem(
            windowTitle: "With reference to my code…",
            appName: "Anti Gravity Agent",
            appID: "com.antigravity.agent",
            identity: .appWindow(pid: 404, windowID: 4)
        )
        let notebook = makeItem(
            windowTitle: "NotebookLM",
            appName: "Google NotebookLM",
            appID: "com.google.notebooklm",
            identity: .appWindow(pid: 505, windowID: 5)
        )

        XCTAssertEqual(
            SwitcherWindowController.paletteFilteredItems([antiGravity, notebook], query: "AntiGravity").first?.subtitle,
            "Anti Gravity Agent"
        )
    }

    func testPaletteSearchUsesRecencyAsTieBreakerWhenScoresMatch() {
        let chrome = makeItem(
            windowTitle: "Chrome",
            appName: "Google Chrome",
            appID: "com.google.Chrome",
            identity: .appWindow(pid: 101, windowID: 1)
        )
        let chat = makeItem(
            windowTitle: "Chat",
            appName: "Chat",
            appID: "com.openai.chat",
            identity: .appWindow(pid: 202, windowID: 2)
        )

        XCTAssertEqual(
            SwitcherWindowController.paletteFilteredItems([chrome, chat], query: "ch").map(\.subtitle),
            ["Google Chrome", "Chat"]
        )
    }

    func testPaletteSearchPrioritizesRememberedSelection() {
        let chrome = makeItem(
            windowTitle: "Chrome",
            appName: "Google Chrome",
            appID: "com.google.Chrome",
            identity: .appWindow(pid: 101, windowID: 1)
        )
        let chat = makeItem(
            windowTitle: "Chat",
            appName: "Chat",
            appID: "com.openai.chat",
            identity: .appWindow(pid: 202, windowID: 2)
        )

        let remembered = SwitcherWindowController.paletteFilteredItems(
            [chrome, chat],
            query: "ch",
            rememberedStableKey: chat.historyIdentity.stableKey
        )

        XCTAssertEqual(remembered.first?.historyIdentity.stableKey, chat.historyIdentity.stableKey)
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

    func testSearchMemoryStoreMigratesLegacyPlaintextKeysWithoutQueueReentry() {
        let suiteName = "CmdTab.SearchMemoryStoreMigrationTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let defaultsKey = "paletteSearchMemoryTests"
        let identity = SwitcherHistoryIdentity.appWindow(pid: 222, windowID: 84)
        let legacyEntries: [String: Any] = [
            "System Preferences": [
                "stableKey": identity.stableKey,
                "count": 1,
                "lastUsedAt": Date().timeIntervalSinceReferenceDate,
            ],
        ]
        defaults.set(try! JSONSerialization.data(withJSONObject: legacyEntries), forKey: defaultsKey)

        let store = SearchMemoryStore(defaults: defaults, defaultsKey: defaultsKey)

        XCTAssertEqual(store.rememberedStableKey(for: "system-preferences"), identity.stableKey)
        let persistedKeys = try! JSONSerialization.jsonObject(
            with: defaults.data(forKey: defaultsKey)!
        ) as! [String: Any]
        XCTAssertNil(persistedKeys["System Preferences"])
        XCTAssertEqual(persistedKeys.keys.first?.count, 64)
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

    private func makeItem(
        windowTitle: String,
        appName: String,
        appID: String,
        identity: SwitcherHistoryIdentity
    ) -> SwitcherItem {
        SwitcherItem(
            title: windowTitle,
            subtitle: appName,
            icon: nil,
            previewImage: nil,
            historyIdentity: identity,
            sourceAppIdentifier: appID,
            kind: .appWindow
        ) {}
    }
}
