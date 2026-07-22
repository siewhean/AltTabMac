import Foundation
import Security
import XCTest
@testable import CmdTab

final class BundleIdentityMigrationTests: XCTestCase {
    private var suites: [String] = []

    override func tearDown() {
        for suite in suites {
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        suites.removeAll()
        super.tearDown()
    }

    func testMigrationCopiesOnlyMaintainedDefaultsAndMarksCompletion() {
        let defaults = makeDefaults()
        let legacy: [String: Any] = [
            "launchAtLogin": false,
            "windowVisibilityScope": "allSpaces",
            "paletteSearchMemory": Data([1, 2, 3]),
            "unrelatedSystemValue": "do-not-copy",
        ]

        let result = BundleIdentityMigration.migrateIfNeeded(
            currentBundleIdentifier: CmdTabBundleIdentity.currentIdentifier,
            currentDefaults: defaults,
            legacyDomain: legacy,
            keychainMigrator: { .legacyItemMissing }
        )

        XCTAssertEqual(
            result,
            .completed(defaultsCopied: 3, keychain: .legacyItemMissing)
        )
        XCTAssertEqual(defaults.object(forKey: "launchAtLogin") as? Bool, false)
        XCTAssertEqual(defaults.string(forKey: "windowVisibilityScope"), "allSpaces")
        XCTAssertEqual(defaults.data(forKey: "paletteSearchMemory"), Data([1, 2, 3]))
        XCTAssertNil(defaults.object(forKey: "unrelatedSystemValue"))
        XCTAssertTrue(defaults.bool(forKey: BundleIdentityMigration.markerKey))
    }

    func testMigrationNeverOverwritesCurrentDomainValues() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "launchAtLogin")

        let result = BundleIdentityMigration.migrateIfNeeded(
            currentBundleIdentifier: CmdTabBundleIdentity.currentIdentifier,
            currentDefaults: defaults,
            legacyDomain: ["launchAtLogin": false],
            keychainMigrator: { .currentItemExists }
        )

        XCTAssertEqual(
            result,
            .completed(defaultsCopied: 0, keychain: .currentItemExists)
        )
        XCTAssertTrue(defaults.bool(forKey: "launchAtLogin"))
    }

    func testMigrationIsIdempotent() {
        let defaults = makeDefaults()
        var keychainCalls = 0

        let first = BundleIdentityMigration.migrateIfNeeded(
            currentBundleIdentifier: CmdTabBundleIdentity.currentIdentifier,
            currentDefaults: defaults,
            legacyDomain: ["switcherStyle": "radialMenu"],
            keychainMigrator: {
                keychainCalls += 1
                return .copied
            }
        )
        let second = BundleIdentityMigration.migrateIfNeeded(
            currentBundleIdentifier: CmdTabBundleIdentity.currentIdentifier,
            currentDefaults: defaults,
            legacyDomain: ["switcherStyle": "classicGrid"],
            keychainMigrator: {
                keychainCalls += 1
                return .copied
            }
        )

        XCTAssertEqual(first, .completed(defaultsCopied: 1, keychain: .copied))
        XCTAssertEqual(second, .alreadyCompleted)
        XCTAssertEqual(defaults.string(forKey: "switcherStyle"), "radialMenu")
        XCTAssertEqual(keychainCalls, 1)
    }

    func testTemporaryKeychainFailureLeavesMigrationRetryable() {
        let defaults = makeDefaults()

        let result = BundleIdentityMigration.migrateIfNeeded(
            currentBundleIdentifier: CmdTabBundleIdentity.currentIdentifier,
            currentDefaults: defaults,
            legacyDomain: ["maxWindowsPerApp": 0],
            keychainMigrator: { .failed(errSecInteractionNotAllowed) }
        )

        XCTAssertEqual(
            result,
            .deferred(defaultsCopied: 1, keychainStatus: errSecInteractionNotAllowed)
        )
        XCTAssertFalse(defaults.bool(forKey: BundleIdentityMigration.markerKey))
        XCTAssertEqual(defaults.integer(forKey: "maxWindowsPerApp"), 0)
    }

    func testMigrationDoesNotRunForAnotherBundleIdentifier() {
        let defaults = makeDefaults()
        var keychainCalled = false

        let result = BundleIdentityMigration.migrateIfNeeded(
            currentBundleIdentifier: CmdTabBundleIdentity.legacyIdentifier,
            currentDefaults: defaults,
            legacyDomain: ["launchAtLogin": false],
            keychainMigrator: {
                keychainCalled = true
                return .copied
            }
        )

        XCTAssertEqual(result, .notApplicable)
        XCTAssertNil(defaults.object(forKey: "launchAtLogin"))
        XCTAssertFalse(keychainCalled)
    }

    func testBundleIdentityContractKeepsLegacyStorageIdentityExplicit() {
        XCTAssertEqual(CmdTabBundleIdentity.currentIdentifier, "net.cmdtab.CmdTab")
        XCTAssertEqual(CmdTabBundleIdentity.legacyIdentifier, "com.user.CmdTab")
        XCTAssertEqual(
            CmdTabBundleIdentity.legacyLicenseKeychainAccount,
            CmdTabBundleIdentity.legacyIdentifier
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "CmdTab.BundleIdentityMigrationTests.\(UUID().uuidString)"
        suites.append(suite)
        UserDefaults.standard.removePersistentDomain(forName: suite)
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("Could not create isolated UserDefaults suite")
        }
        return defaults
    }
}
