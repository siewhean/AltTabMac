import CoreGraphics
import XCTest
@testable import CmdTab

final class SwitcherProfileTests: XCTestCase {
    func testShortcutModifierMaskRoundTripsCGFlags() {
        let mask = ShortcutModifierMask(eventFlags: [.maskCommand, .maskShift])
        XCTAssertEqual(mask, [.command, .shift])
        XCTAssertEqual(mask.primaryReleaseModifier, .command)
        XCTAssertEqual(mask.displayLabel, "⇧⌘")
    }

    func testDuplicateEnabledShortcutIsRejected() {
        let first = profile(
            id: UUID(),
            name: "One",
            shortcut: .commandTab,
            enabled: true
        )
        let second = profile(
            id: UUID(),
            name: "Two",
            shortcut: .commandTab,
            enabled: true
        )

        let issues = SwitcherProfileValidator.issues(in: [first, second])
        XCTAssertTrue(
            issues.contains {
                if case .duplicateShortcut = $0 { return true }
                return false
            }
        )
    }

    func testDisabledProfileMayTemporarilyShareShortcutDuringEditing() {
        let first = profile(
            id: UUID(),
            name: "One",
            shortcut: .commandTab,
            enabled: true
        )
        let second = profile(
            id: UUID(),
            name: "Draft",
            shortcut: .commandTab,
            enabled: false
        )

        XCTAssertTrue(SwitcherProfileValidator.issues(in: [first, second]).isEmpty)
    }

    func testReservedCommitAndCancelKeysAreRejected() {
        XCTAssertNotNil(
            SwitcherProfileValidator.invalidReason(
                for: RecordedShortcut(keyCode: 53, modifiers: [.command], keyLabel: "Esc")
            )
        )
        XCTAssertNotNil(
            SwitcherProfileValidator.invalidReason(
                for: RecordedShortcut(keyCode: 36, modifiers: [.command], keyLabel: "Return")
            )
        )
    }

    func testAppFilterNormalizesAndAppliesIncludeExcludeModes() {
        var include = SwitcherProfileAppFilter(
            mode: .includeOnly,
            bundleIdentifiers: [" COM.Example.App ", "com.example.app", "com.other.App"]
        )
        include.normalize()
        XCTAssertEqual(include.bundleIdentifiers, ["com.example.app", "com.other.app"])
        XCTAssertTrue(include.includes(bundleIdentifier: "com.example.app"))
        XCTAssertFalse(include.includes(bundleIdentifier: "com.third.app"))

        let exclude = SwitcherProfileAppFilter(
            mode: .exclude,
            bundleIdentifiers: ["com.example.app"]
        )
        XCTAssertFalse(exclude.includes(bundleIdentifier: "COM.EXAMPLE.APP"))
        XCTAssertTrue(exclude.includes(bundleIdentifier: "com.other.app"))
    }

    func testProfileDocumentRoundTripsVersionedJSON() throws {
        let original = SwitcherProfileDocument(
            profiles: [
                profile(
                    id: UUID(uuidString: "C815DB3D-F4AA-4D17-A70E-73F0BC25FBB9")!,
                    name: "Work",
                    shortcut: RecordedShortcut(
                        keyCode: 49,
                        modifiers: [.control, .option],
                        keyLabel: "Space"
                    ),
                    enabled: true
                )
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SwitcherProfileDocument.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.schemaVersion, SwitcherProfileDocument.currentSchemaVersion)
    }

    func testStoreMatchesForwardAndReverseProfileShortcuts() {
        let suite = "SwitcherProfileTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SwitcherProfileStore(defaults: defaults)
        let command = store.profilesSnapshot().first { $0.name == "Command-Tab" }!

        XCTAssertEqual(
            store.match(keyCode: 48, flags: [.maskCommand])?.profileID,
            command.id
        )
        let reverse = store.match(
            keyCode: 48,
            flags: [.maskCommand, .maskShift]
        )
        XCTAssertEqual(reverse?.profileID, command.id)
        XCTAssertEqual(reverse?.reverse, true)
    }

    func testScopedConfigurationDoesNotLeakGlobalSettings() {
        let profile = SwitcherShortcutProfile(
            id: UUID(),
            name: "Scoped",
            isEnabled: true,
            forwardShortcut: RecordedShortcut(
                keyCode: 49,
                modifiers: [.control, .option],
                keyLabel: "Space"
            ),
            reverseShortcut: nil,
            releaseBehavior: .pressToToggle,
            inheritsGlobalSettings: false,
            style: .radialMenu,
            visibilityScope: .currentSpaceOnly,
            includeMinimizedWindows: true,
            displayPlacement: .cursorDisplay,
            appFilter: SwitcherProfileAppFilter(
                mode: .includeOnly,
                bundleIdentifiers: ["com.example.app"]
            )
        )
        let configuration = SwitcherSessionConfiguration(
            profileID: profile.id,
            profileName: profile.name,
            style: profile.style,
            visibilityScope: profile.visibilityScope,
            includeMinimizedWindows: profile.includeMinimizedWindows,
            displayPlacement: profile.displayPlacement,
            appFilter: profile.appFilter,
            releaseBehavior: profile.releaseBehavior
        )

        XCTAssertEqual(configuration.style, .radialMenu)
        XCTAssertEqual(configuration.visibilityScope, .currentSpaceOnly)
        XCTAssertTrue(configuration.includeMinimizedWindows)
        XCTAssertEqual(configuration.displayPlacement, .cursorDisplay)
        XCTAssertTrue(configuration.includes(bundleIdentifier: "com.example.app"))
        XCTAssertFalse(configuration.includes(bundleIdentifier: "com.other.app"))
    }

    private func profile(
        id: UUID,
        name: String,
        shortcut: RecordedShortcut,
        enabled: Bool
    ) -> SwitcherShortcutProfile {
        SwitcherShortcutProfile(
            id: id,
            name: name,
            isEnabled: enabled,
            forwardShortcut: shortcut,
            reverseShortcut: nil,
            releaseBehavior: .pressToToggle,
            inheritsGlobalSettings: false,
            style: .classicGrid,
            visibilityScope: .visibleSpaces,
            includeMinimizedWindows: false,
            displayPlacement: .activeWindowDisplay,
            appFilter: .all
        )
    }
}
