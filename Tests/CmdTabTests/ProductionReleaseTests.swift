import XCTest
@testable import CmdTab

final class ProductionReleaseTests: XCTestCase {
    func testDiagnosticSnapshotRoundTripsThroughJSON() throws {
        let snapshot = DiagnosticSnapshot(
            schemaVersion: 1,
            appVersion: "1.0.0",
            buildNumber: "1",
            bundleIdentifier: "net.cmdtab.app",
            macOSVersion: "Version 14.0",
            architecture: "arm64",
            eventTapHealthy: true,
            eventTapHealthSource: "activeProbe",
            permissions: .init(
                accessibilityGranted: true,
                screenRecordingGranted: false,
                secureInputEnabled: false
            )
        )

        let encoded = try JSONEncoder().encode(snapshot)
        XCTAssertEqual(try JSONDecoder().decode(DiagnosticSnapshot.self, from: encoded), snapshot)
    }

    func testPermissionOnboardingOnlyPresentsOnceWhenPermissionIsMissing() {
        XCTAssertFalse(PermissionOnboardingPolicy.shouldPresent(
            hasPresentedAccessibility: false,
            hasPresentedScreenRecording: false,
            accessibilityGranted: true,
            screenRecordingGranted: true
        ))
        XCTAssertTrue(PermissionOnboardingPolicy.shouldPresent(
            hasPresentedAccessibility: false,
            hasPresentedScreenRecording: false,
            accessibilityGranted: false,
            screenRecordingGranted: true
        ))
        XCTAssertTrue(PermissionOnboardingPolicy.shouldPresent(
            hasPresentedAccessibility: false,
            hasPresentedScreenRecording: false,
            accessibilityGranted: true,
            screenRecordingGranted: false
        ))
        XCTAssertFalse(PermissionOnboardingPolicy.shouldPresent(
            hasPresentedAccessibility: true,
            hasPresentedScreenRecording: true,
            accessibilityGranted: false,
            screenRecordingGranted: false
        ))
    }

    func testPermissionOnboardingOpensOnlyFirstMissingPermission() {
        XCTAssertEqual(
            PermissionOnboardingPolicy.action(
                hasPresentedAccessibility: false,
                hasPresentedScreenRecording: false,
                accessibilityGranted: false,
                screenRecordingGranted: false
            ),
            .openAccessibilitySettings
        )
        XCTAssertEqual(
            PermissionOnboardingPolicy.action(
                hasPresentedAccessibility: true,
                hasPresentedScreenRecording: false,
                accessibilityGranted: false,
                screenRecordingGranted: false
            ),
            .none
        )
        XCTAssertEqual(
            PermissionOnboardingPolicy.action(
                hasPresentedAccessibility: true,
                hasPresentedScreenRecording: false,
                accessibilityGranted: true,
                screenRecordingGranted: false
            ),
            .openScreenRecordingSettings
        )
        XCTAssertEqual(
            PermissionOnboardingPolicy.action(
                hasPresentedAccessibility: true,
                hasPresentedScreenRecording: true,
                accessibilityGranted: true,
                screenRecordingGranted: false
            ),
            .none
        )
    }

    func testLaunchAtLoginRequiresExplicitOptIn() {
        XCTAssertFalse(SwitcherPreferences.launchAtLoginValue(storedValue: nil))
        XCTAssertFalse(SwitcherPreferences.launchAtLoginValue(storedValue: false))
        XCTAssertTrue(SwitcherPreferences.launchAtLoginValue(storedValue: true))
    }

    func testLegacyIdentityMigrationIsAllowlistedAndPreservesCurrentValues() {
        let legacy: [String: Any] = [
            "switcherStyle": "radialMenu",
            "alternateTrigger": "leftCommandDoubleTap",
            "launchAtLogin": true,
            "unknownKey": "do-not-copy"
        ]
        let current: [String: Any] = ["switcherStyle": "classicGrid"]

        let migrated = LegacyAppIdentityMigration.valuesToMigrate(
            legacyValues: legacy,
            currentValues: current
        )

        XCTAssertNil(migrated["switcherStyle"])
        XCTAssertEqual(migrated["alternateTrigger"] as? String, "leftCommandDoubleTap")
        XCTAssertNil(migrated["launchAtLogin"])
        XCTAssertNil(migrated["unknownKey"])
    }

    func testEventTapProbeDoesNotCreateTapWithoutListenAccess() {
        var didAttemptCreation = false
        let healthy = EventTapHealthProbe.evaluate(
            accessGranted: false,
            createTap: {
                didAttemptCreation = true
                return NSObject()
            },
            enable: { _ in },
            isEnabled: { _ in true },
            invalidate: { _ in }
        )

        XCTAssertFalse(healthy)
        XCTAssertFalse(didAttemptCreation)
    }

    func testEventTapProbeInvalidatesSuccessfulProbe() {
        let tap = NSObject()
        var invalidatedTap: NSObject?
        let healthy = EventTapHealthProbe.evaluate(
            accessGranted: true,
            createTap: { tap },
            enable: { _ in },
            isEnabled: { _ in true },
            invalidate: { invalidatedTap = $0 }
        )

        XCTAssertTrue(healthy)
        XCTAssertTrue(invalidatedTap === tap)
    }

    func testEventTapProbeRejectsDisabledTap() {
        let tap = NSObject()
        var invalidated = false
        let healthy = EventTapHealthProbe.evaluate(
            accessGranted: true,
            createTap: { tap },
            enable: { _ in },
            isEnabled: { _ in false },
            invalidate: { _ in invalidated = true }
        )

        XCTAssertFalse(healthy)
        XCTAssertTrue(invalidated)
    }

    func testDeniedCaptureDisplaysOnlyPreviewlessSkeletonCandidates() {
        XCTAssertTrue(AppSwitcher.shouldDisplayWindowItem(
            previewImage: nil,
            capturePreviews: false,
            allowPreviewlessItems: true
        ))
        XCTAssertFalse(AppSwitcher.shouldDisplayWindowItem(
            previewImage: nil,
            capturePreviews: true,
            allowPreviewlessItems: false
        ))
        XCTAssertTrue(AppSwitcher.shouldDisplayWindowItem(
            previewImage: nil,
            capturePreviews: true,
            allowPreviewlessItems: true
        ))
    }
}
