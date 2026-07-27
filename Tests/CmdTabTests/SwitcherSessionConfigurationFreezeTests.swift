import Foundation
import XCTest
@testable import CmdTab

final class SwitcherSessionConfigurationFreezeTests: XCTestCase {
    private let freeze = SwitcherSessionConfigurationFreeze.shared

    override func setUp() {
        super.setUp()
        freeze.end()
    }

    override func tearDown() {
        freeze.end()
        super.tearDown()
    }

    func testResolvedConfigurationRemainsFrozenUntilSessionEnds() {
        let profileID = UUID()
        let initial = configuration(
            profileID: profileID,
            style: .classicGrid,
            visibility: .visibleSpaces,
            includeMinimized: false
        )
        let changed = configuration(
            profileID: profileID,
            style: .radialMenu,
            visibility: .allSpaces,
            includeMinimized: true
        )

        freeze.begin(profileID: profileID, preserveExisting: false)
        XCTAssertEqual(freeze.resolve(profileID: profileID, proposed: initial), initial)
        XCTAssertEqual(freeze.resolve(profileID: profileID, proposed: changed), initial)

        freeze.end()
        XCTAssertEqual(freeze.resolve(profileID: profileID, proposed: changed), changed)
    }

    func testRepeatedTriggerPreservesExistingFrozenConfiguration() {
        let profileID = UUID()
        let initial = configuration(
            profileID: profileID,
            style: .commandPalette,
            visibility: .currentSpaceOnly,
            includeMinimized: false
        )
        let changed = configuration(
            profileID: profileID,
            style: .radialMenu,
            visibility: .allSpaces,
            includeMinimized: true
        )

        freeze.begin(profileID: profileID, preserveExisting: false)
        _ = freeze.resolve(profileID: profileID, proposed: initial)
        freeze.begin(profileID: profileID, preserveExisting: true)

        XCTAssertEqual(freeze.resolve(profileID: profileID, proposed: changed), initial)
    }

    func testNewHiddenSessionReplacesStaleFreezeForSameProfile() {
        let profileID = UUID()
        let initial = configuration(
            profileID: profileID,
            style: .classicGrid,
            visibility: .visibleSpaces,
            includeMinimized: false
        )
        let changed = configuration(
            profileID: profileID,
            style: .radialMenu,
            visibility: .allSpaces,
            includeMinimized: true
        )

        freeze.begin(profileID: profileID, preserveExisting: false)
        _ = freeze.resolve(profileID: profileID, proposed: initial)
        freeze.begin(profileID: profileID, preserveExisting: false)

        XCTAssertEqual(freeze.resolve(profileID: profileID, proposed: changed), changed)
    }

    func testDifferentProfileNeverReceivesAnotherProfilesFrozenConfiguration() {
        let firstID = UUID()
        let secondID = UUID()
        let first = configuration(
            profileID: firstID,
            style: .classicGrid,
            visibility: .visibleSpaces,
            includeMinimized: false
        )
        let second = configuration(
            profileID: secondID,
            style: .radialMenu,
            visibility: .allSpaces,
            includeMinimized: true
        )

        freeze.begin(profileID: firstID, preserveExisting: false)
        _ = freeze.resolve(profileID: firstID, proposed: first)

        XCTAssertEqual(freeze.resolve(profileID: secondID, proposed: second), second)
    }

    func testProfileStoreReturnsFrozenValuesUntilSessionEnds() throws {
        let suite = "SwitcherSessionConfigurationFreezeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SwitcherProfileStore(defaults: defaults)
        var profile = try XCTUnwrap(store.profilesSnapshot().first)
        profile.inheritsGlobalSettings = false
        profile.style = .classicGrid
        profile.visibilityScope = .visibleSpaces
        profile.includeMinimizedWindows = false
        XCTAssertTrue(store.update(profile))

        freeze.begin(profileID: profile.id, preserveExisting: false)
        let first = try XCTUnwrap(store.configuration(for: profile.id))
        XCTAssertEqual(first.style, .classicGrid)
        XCTAssertFalse(first.includeMinimizedWindows)

        profile.style = .radialMenu
        profile.visibilityScope = .allSpaces
        profile.includeMinimizedWindows = true
        XCTAssertTrue(store.update(profile))

        let stillFrozen = try XCTUnwrap(store.configuration(for: profile.id))
        XCTAssertEqual(stillFrozen, first)

        freeze.end()
        let nextSession = try XCTUnwrap(store.configuration(for: profile.id))
        XCTAssertEqual(nextSession.style, .radialMenu)
        XCTAssertEqual(nextSession.visibilityScope, .allSpaces)
        XCTAssertTrue(nextSession.includeMinimizedWindows)
    }

    func testEnabledIncludeOnlyProfileRequiresAtLeastOneBundleIdentifier() {
        let profile = SwitcherShortcutProfile(
            id: UUID(),
            name: "Empty Include",
            isEnabled: true,
            forwardShortcut: RecordedShortcut(
                keyCode: 49,
                modifiers: [.control, .option],
                keyLabel: "Space"
            ),
            reverseShortcut: nil,
            releaseBehavior: .pressToToggle,
            inheritsGlobalSettings: false,
            style: .classicGrid,
            visibilityScope: .visibleSpaces,
            includeMinimizedWindows: false,
            displayPlacement: .activeWindowDisplay,
            appFilter: SwitcherProfileAppFilter(
                mode: .includeOnly,
                bundleIdentifiers: []
            )
        )

        XCTAssertTrue(
            SwitcherProfileValidator.issues(in: [profile]).contains {
                if case let .invalidFilter(_, message) = $0 {
                    return message.contains("at least one bundle identifier")
                }
                return false
            }
        )
    }

    private func configuration(
        profileID: UUID,
        style: SwitcherStyle,
        visibility: WindowVisibilityScope,
        includeMinimized: Bool
    ) -> SwitcherSessionConfiguration {
        SwitcherSessionConfiguration(
            profileID: profileID,
            profileName: "Test",
            style: style,
            visibilityScope: visibility,
            includeMinimizedWindows: includeMinimized,
            displayPlacement: .activeWindowDisplay,
            appFilter: .all,
            releaseBehavior: .holdPrimaryModifier
        )
    }
}