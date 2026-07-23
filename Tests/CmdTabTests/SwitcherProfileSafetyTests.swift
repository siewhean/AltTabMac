import Foundation
import XCTest
@testable import CmdTab

final class SwitcherProfileSafetyTests: XCTestCase {
    func testAtLeastOneProfileMustRemainEnabled() {
        let disabled = SwitcherShortcutProfile(
            id: UUID(),
            name: "Disabled",
            isEnabled: false,
            forwardShortcut: RecordedShortcut(
                keyCode: 49,
                modifiers: [.control],
                keyLabel: "Space"
            ),
            reverseShortcut: nil,
            releaseBehavior: .pressToToggle,
            inheritsGlobalSettings: false,
            style: .classicGrid,
            visibilityScope: .visibleSpaces,
            includeMinimizedWindows: false,
            displayPlacement: .activeWindowDisplay,
            appFilter: .all
        )

        XCTAssertTrue(
            SwitcherProfileValidator.issues(in: [disabled]).contains(.noEnabledProfiles)
        )
    }

    func testHoldProfileRequiresCommandOrOptionPrimaryModifier() {
        let profile = SwitcherShortcutProfile(
            id: UUID(),
            name: "Invalid Hold",
            isEnabled: true,
            forwardShortcut: RecordedShortcut(
                keyCode: 49,
                modifiers: [.control],
                keyLabel: "Space"
            ),
            reverseShortcut: nil,
            releaseBehavior: .holdPrimaryModifier,
            inheritsGlobalSettings: false,
            style: .classicGrid,
            visibilityScope: .visibleSpaces,
            includeMinimizedWindows: false,
            displayPlacement: .activeWindowDisplay,
            appFilter: .all
        )

        XCTAssertTrue(
            SwitcherProfileValidator.issues(in: [profile]).contains {
                if case let .invalidShortcut(_, message) = $0 {
                    return message.contains("Command or Option")
                }
                return false
            }
        )

        let profileID = UUID()
        let forward = ShortcutProfileMatch(
            profileID: profileID,
            reverse: false,
            releaseBehavior: .holdPrimaryModifier,
            primaryModifier: .command
        )
        let reverse = ShortcutProfileMatch(
            profileID: profileID,
            reverse: true,
            releaseBehavior: .holdPrimaryModifier,
            primaryModifier: .command
        )

        var quick = ProfileHotkeyTriggerCoordinator()
        XCTAssertEqual(
            quick.registerHiddenTrigger(match: forward, startedAtUptime: 10),
            .scheduleReveal(atUptime: 10)
        )
        XCTAssertEqual(
            quick.handleModifierRelease(.command, switcherVisible: false),
            .quickSwitch(forward)
        )
        XCTAssertFalse(quick.hasPendingTrigger)

        var held = ProfileHotkeyTriggerCoordinator()
        _ = held.registerHiddenTrigger(match: reverse, startedAtUptime: 20)
        XCTAssertEqual(
            held.handleRevealDeadline(now: 20, heldModifiers: [.command]),
            .showOverlay(reverse)
        )
        XCTAssertEqual(
            held.handleModifierRelease(.command, switcherVisible: true),
            .confirmSelection(reverse)
        )

        var repeated = ProfileHotkeyTriggerCoordinator()
        _ = repeated.registerHiddenTrigger(match: forward, startedAtUptime: 30)
        XCTAssertNil(
            repeated.registerHiddenTrigger(match: reverse, startedAtUptime: 30.05),
            "A repeated hidden Command trigger must not replace the original direction."
        )
        XCTAssertEqual(repeated.pendingMatch, forward)
        repeated.cancel()
        XCTAssertFalse(repeated.hasPendingTrigger)
        XCTAssertNil(repeated.pendingMatch)
    }

    func testRejectedRemovalDoesNotMutateStore() {
        let suite = "SwitcherProfileSafetyTests.remove.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SwitcherProfileStore(defaults: defaults)
        let enabled = store.profilesSnapshot().filter(\.isEnabled)
        XCTAssertEqual(enabled.count, 2)

        XCTAssertTrue(store.remove(profileID: enabled[0].id))
        let remainingEnabled = store.profilesSnapshot().filter(\.isEnabled)
        XCTAssertEqual(remainingEnabled.count, 1)

        XCTAssertFalse(store.remove(profileID: remainingEnabled[0].id))
        XCTAssertEqual(store.profilesSnapshot().filter(\.isEnabled).count, 1)
        XCTAssertNotNil(store.profile(id: remainingEnabled[0].id))
    }

    func testFutureSchemaImportIsRejectedAtomically() throws {
        let suite = "SwitcherProfileSafetyTests.import.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SwitcherProfileStore(defaults: defaults)
        let before = store.profilesSnapshot()

        let validData = try store.exportDocument()
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: validData) as? [String: Any]
        )
        object["schemaVersion"] = SwitcherProfileDocument.currentSchemaVersion + 1
        let future = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try store.importDocument(future))
        XCTAssertEqual(store.profilesSnapshot(), before)
    }

    func testInvalidImportDoesNotReplaceSnapshot() throws {
        let suite = "SwitcherProfileSafetyTests.invalid.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SwitcherProfileStore(defaults: defaults)
        let before = store.profilesSnapshot()

        let duplicate = SwitcherProfileDocument(
            profiles: [before[0], before[0]]
        )
        let data = try JSONEncoder().encode(duplicate)

        XCTAssertThrowsError(try store.importDocument(data))
        XCTAssertEqual(store.profilesSnapshot(), before)
    }
}
