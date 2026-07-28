import Foundation
import XCTest
@testable import CmdTab

@MainActor
final class OnboardingCoordinatorTests: XCTestCase {
    func testNewInstallStartsAtWelcomeWithoutRequestingPermissions() {
        let store = MemoryOnboardingProgressStore()
        let permissions = FakeOnboardingPermissionManager()
        let coordinator = makeCoordinator(store: store, permissions: permissions)

        XCTAssertEqual(coordinator.step, .welcome)
        XCTAssertTrue(coordinator.shouldPresentAutomatically)
        XCTAssertEqual(permissions.requestedPermissions, [])
        XCTAssertEqual(store.progress?.version, OnboardingCoordinator.currentVersion)
    }

    func testIncompleteCurrentVersionResumesSavedStepAndPracticeState() {
        let store = MemoryOnboardingProgressStore(
            progress: OnboardingProgress(
                version: OnboardingCoordinator.currentVersion,
                step: .practice,
                completedVersion: 0,
                attemptedPractice: true
            )
        )
        let coordinator = makeCoordinator(
            store: store,
            permissions: FakeOnboardingPermissionManager(accessibilityGranted: true)
        )

        XCTAssertEqual(coordinator.step, .practice)
        XCTAssertTrue(coordinator.attemptedPractice)
        XCTAssertTrue(coordinator.canContinue)
        XCTAssertTrue(coordinator.shouldPresentAutomatically)
    }

    func testNewOnboardingVersionRestartsSafelyWithoutLosingCompletionHistory() {
        let store = MemoryOnboardingProgressStore(
            progress: OnboardingProgress(
                version: OnboardingCoordinator.currentVersion - 1,
                step: .completion,
                completedVersion: OnboardingCoordinator.currentVersion - 1,
                attemptedPractice: true
            )
        )
        let coordinator = makeCoordinator(store: store)

        XCTAssertEqual(coordinator.step, .welcome)
        XCTAssertFalse(coordinator.attemptedPractice)
        XCTAssertTrue(coordinator.shouldPresentAutomatically)
        XCTAssertEqual(
            store.progress?.completedVersion,
            OnboardingCoordinator.currentVersion - 1
        )
    }

    func testAccessibilityIsRequiredAndRequestedOnlyFromItsContextualStep() {
        let permissions = FakeOnboardingPermissionManager()
        let coordinator = makeCoordinator(permissions: permissions)

        XCTAssertTrue(coordinator.advance())
        XCTAssertEqual(coordinator.step, .accessibility)
        XCTAssertFalse(coordinator.advance())
        XCTAssertEqual(permissions.requestedPermissions, [])

        permissions.grantAccessibilityWhenRequested = true
        coordinator.requestAccessibility()

        XCTAssertEqual(permissions.requestedPermissions, [.accessibility])
        XCTAssertTrue(coordinator.isAccessibilityGranted)
        XCTAssertTrue(coordinator.advance())
        XCTAssertEqual(coordinator.step, .screenRecording)
        XCTAssertEqual(permissions.requestedPermissions, [.accessibility])
    }

    func testScreenRecordingIsOptionalAndSkipResumesAtAccessStep() {
        let store = MemoryOnboardingProgressStore()
        let coordinator = makeCoordinator(
            store: store,
            permissions: FakeOnboardingPermissionManager(accessibilityGranted: true)
        )

        XCTAssertTrue(coordinator.advance())
        XCTAssertTrue(coordinator.advance())
        XCTAssertEqual(coordinator.step, .screenRecording)

        coordinator.skipScreenRecording()

        XCTAssertEqual(coordinator.step, .access)
        XCTAssertEqual(store.progress?.step, .access)
    }

    func testAccessAndPracticeMustCompleteBeforeOnboardingCompletion() {
        let coordinator = makeCoordinator(
            permissions: FakeOnboardingPermissionManager(accessibilityGranted: true),
            withActiveTrial: true
        )

        XCTAssertTrue(coordinator.advance())
        XCTAssertTrue(coordinator.advance())
        coordinator.skipScreenRecording()
        XCTAssertTrue(coordinator.advance())
        XCTAssertEqual(coordinator.step, .practice)
        XCTAssertFalse(coordinator.advance())

        coordinator.attemptPractice({})

        XCTAssertTrue(coordinator.advance())
        XCTAssertEqual(coordinator.step, .completion)
        XCTAssertFalse(coordinator.shouldPresentAutomatically)
    }

    func testPracticeIsRecordedOnlyAfterTheInvocationReturns() {
        let coordinator = makeCoordinator(
            permissions: FakeOnboardingPermissionManager(accessibilityGranted: true),
            withActiveTrial: true
        )
        XCTAssertTrue(coordinator.advance())
        XCTAssertTrue(coordinator.advance())
        coordinator.skipScreenRecording()
        XCTAssertTrue(coordinator.advance())

        var wasRecordedDuringInvocation = true
        coordinator.attemptPractice {
            wasRecordedDuringInvocation = coordinator.attemptedPractice
        }

        XCTAssertFalse(wasRecordedDuringInvocation)
        XCTAssertTrue(coordinator.attemptedPractice)
    }

    func testCompletedFlowDoesNotAutoPresentButManualReviewStartsAtWelcome() {
        let store = MemoryOnboardingProgressStore(
            progress: OnboardingProgress(
                version: OnboardingCoordinator.currentVersion,
                step: .completion,
                completedVersion: OnboardingCoordinator.currentVersion,
                attemptedPractice: true
            )
        )
        let coordinator = makeCoordinator(store: store)

        XCTAssertFalse(coordinator.prepareForPresentation(isAutomatic: true))
        XCTAssertTrue(coordinator.prepareForPresentation(isAutomatic: false))
        XCTAssertEqual(coordinator.step, .welcome)
        XCTAssertFalse(coordinator.attemptedPractice)
        XCTAssertFalse(coordinator.shouldPresentAutomatically)
    }

    func testIncompleteManualReviewResumesInsteadOfRestartingAgain() {
        let store = MemoryOnboardingProgressStore(
            progress: OnboardingProgress(
                version: OnboardingCoordinator.currentVersion,
                step: .completion,
                completedVersion: OnboardingCoordinator.currentVersion,
                attemptedPractice: true
            )
        )
        let coordinator = makeCoordinator(
            store: store,
            permissions: FakeOnboardingPermissionManager(accessibilityGranted: true)
        )

        XCTAssertTrue(coordinator.prepareForPresentation(isAutomatic: false))
        XCTAssertTrue(coordinator.advance())
        XCTAssertEqual(coordinator.step, .accessibility)

        XCTAssertTrue(coordinator.prepareForPresentation(isAutomatic: false))
        XCTAssertEqual(coordinator.step, .accessibility)
        XCTAssertEqual(store.progress?.step, .accessibility)
    }

    private func makeCoordinator(
        store: MemoryOnboardingProgressStore = MemoryOnboardingProgressStore(),
        permissions: FakeOnboardingPermissionManager = FakeOnboardingPermissionManager(),
        withActiveTrial: Bool = false
    ) -> OnboardingCoordinator {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let claimStore = UserDefaultsTrialClaimStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        if withActiveTrial {
            let formatter = ISO8601DateFormatter()
            claimStore.saveClaim(
                TrialClaimRecord(
                    id: "trial-onboarding",
                    email: "onboarding@example.com",
                    installID: "install-onboarding",
                    startedAt: formatter.string(from: now),
                    endsAt: formatter.string(
                        from: now.addingTimeInterval(14 * 24 * 60 * 60)
                    ),
                    appVersion: nil,
                    osVersion: nil
                )
            )
        }
        let developerSettings = DeveloperSettings(
            defaults: defaults,
            keyPrefix: "CmdTab.onboarding.tests"
        )
        let licensingController = LicensingController(
            trialStore: UserDefaultsTrialStartDateStore(defaults: defaults),
            trialClaimStore: claimStore,
            licenseStore: OnboardingTestLicenseKeyStore(),
            activationMetadataStore: UserDefaultsLicenseActivationMetadataStore(defaults: defaults),
            payloadCacheStore: UserDefaultsLicensedPayloadCacheStore(defaults: defaults),
            installIDStore: UserDefaultsAppInstallIDStore(defaults: defaults),
            trialClaimAuthenticator: OnboardingTrustingTrialClaimAuthenticator(),
            serverClient: OnboardingTestServerClient(),
            currentDate: { now },
            publicKeyDERBase64: "",
            developerSettings: developerSettings
        )
        return OnboardingCoordinator(
            store: store,
            permissionManager: permissions,
            licensingController: licensingController
        )
    }
}

private struct OnboardingTrustingTrialClaimAuthenticator: TrialClaimAuthenticating {
    func validates(_ claim: TrialClaimRecord, installID: String) -> Bool {
        true
    }
}

private final class MemoryOnboardingProgressStore: OnboardingProgressStoring {
    var progress: OnboardingProgress?

    init(progress: OnboardingProgress? = nil) {
        self.progress = progress
    }

    func load() -> OnboardingProgress? {
        progress
    }

    func save(_ progress: OnboardingProgress) {
        self.progress = progress
    }
}

private final class FakeOnboardingPermissionManager: OnboardingPermissionManaging {
    enum RequestedPermission: Equatable {
        case accessibility
        case screenRecording
    }

    var isAccessibilityGranted: Bool
    var isScreenRecordingGranted: Bool
    var grantAccessibilityWhenRequested = false
    var grantScreenRecordingWhenRequested = false
    private(set) var requestedPermissions: [RequestedPermission] = []
    private(set) var openedAccessibilitySettings = false
    private(set) var openedScreenRecordingSettings = false

    init(
        accessibilityGranted: Bool = false,
        screenRecordingGranted: Bool = false
    ) {
        isAccessibilityGranted = accessibilityGranted
        isScreenRecordingGranted = screenRecordingGranted
    }

    func requestAccessibility() {
        requestedPermissions.append(.accessibility)
        if grantAccessibilityWhenRequested {
            isAccessibilityGranted = true
        }
    }

    func requestScreenRecording() {
        requestedPermissions.append(.screenRecording)
        if grantScreenRecordingWhenRequested {
            isScreenRecordingGranted = true
        }
    }

    func openAccessibilitySettings() {
        openedAccessibilitySettings = true
    }

    func openScreenRecordingSettings() {
        openedScreenRecordingSettings = true
    }
}

private final class OnboardingTestServerClient: CmdTabServerClient {
    func startTrial(
        email: String,
        installID: String,
        appVersion: String,
        osVersion: String
    ) async throws -> TrialClaimRecord {
        throw CmdTabServerClientError.invalidResponse
    }
}

private final class OnboardingTestLicenseKeyStore: LicenseKeyStore {
    func loadLicenseKey() -> String? { nil }
    func saveLicenseKey(_ value: String) throws {}
    func clearLicenseKey() throws {}
}
