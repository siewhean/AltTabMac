import CryptoKit
import Foundation
import Security
import XCTest
@testable import CmdTab

@MainActor
final class LicensingControllerTests: XCTestCase {
    func testDeniedShortcutDoesNotOpenLicensingButExplicitActionStillDoes() {
        let controller = makeController(publicKeyBase64: makeSigningMaterials().publicKeyBase64)
        var presentations = 0
        XCTAssertFalse(controller.ensureUsageAllowed(presentLicensing: false) { presentations += 1 })
        XCTAssertEqual(presentations, 0)
        XCTAssertFalse(controller.ensureUsageAllowed { presentations += 1 })
        XCTAssertEqual(presentations, 1)
    }

    func testEventTapShortcutDoesNotReadStoresAndCoalescesRefresh() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var uptime: TimeInterval = 100
        let licenseStore = MemoryLicenseKeyStore()
        let controller = makeController(
            trialClaimStore: MemoryTrialClaimStore(claim: makeTrialClaim(
                email: "trial@example.com", installID: "event-tap", startedAt: now
            )),
            licenseStore: licenseStore,
            currentDate: { now },
            currentUptime: { uptime },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )
        let initialReads = licenseStore.silentLoadCount
        for _ in 0..<50 {
            XCTAssertTrue(controller.shouldHandleEventTapShortcut())
        }
        XCTAssertEqual(licenseStore.silentLoadCount, initialReads)

        uptime += 6
        for _ in 0..<50 {
            XCTAssertTrue(controller.shouldHandleEventTapShortcut())
        }
        XCTAssertEqual(licenseStore.silentLoadCount, initialReads,
                       "An event callback must not synchronously refresh licensing")
        let refreshed = expectation(description: "Coalesced licensing refresh")
        DispatchQueue.main.async {
            XCTAssertEqual(licenseStore.silentLoadCount, initialReads + 1)
            refreshed.fulfill()
        }
        wait(for: [refreshed], timeout: 1)
    }

    func testEventTapShortcutRejectsExpiredSnapshotUntilRevalidated() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var uptime: TimeInterval = 100
        let controller = makeController(
            trialClaimStore: MemoryTrialClaimStore(claim: makeTrialClaim(
                email: "trial@example.com", installID: "event-tap", startedAt: now
            )),
            currentDate: { now }, currentUptime: { uptime },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )
        XCTAssertTrue(controller.shouldHandleEventTapShortcut())
        uptime += 30
        XCTAssertFalse(controller.shouldHandleEventTapShortcut())
        controller.refreshStatus()
        XCTAssertTrue(controller.shouldHandleEventTapShortcut())
    }

    func testEventTapLicensingRefreshesWhileIdleWithoutAKeyboardEvent() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let licenseStore = MemoryLicenseKeyStore()
        let controller = makeController(
            trialClaimStore: MemoryTrialClaimStore(claim: makeTrialClaim(
                email: "trial@example.com", installID: "event-tap", startedAt: now
            )),
            licenseStore: licenseStore,
            currentDate: { now },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )
        let initialReads = licenseStore.silentLoadCount
        let refreshed = expectation(description: "Idle entitlement revalidation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.1) {
            XCTAssertEqual(licenseStore.silentLoadCount, initialReads + 1)
            XCTAssertTrue(controller.shouldHandleEventTapShortcut())
            refreshed.fulfill()
        }
        wait(for: [refreshed], timeout: 6)
    }

    func testEventTapShortcutRefreshesAfterMonotonicClockResets() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var uptime: TimeInterval = 100
        let controller = makeController(
            trialClaimStore: MemoryTrialClaimStore(claim: makeTrialClaim(
                email: "trial@example.com", installID: "event-tap", startedAt: now
            )),
            currentDate: { now }, currentUptime: { uptime },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )
        uptime = 0
        XCTAssertFalse(controller.shouldHandleEventTapShortcut())
        let refreshed = expectation(description: "Refresh after uptime reset")
        DispatchQueue.main.async {
            XCTAssertTrue(controller.shouldHandleEventTapShortcut())
            refreshed.fulfill()
        }
        wait(for: [refreshed], timeout: 1)
    }

    func testEventTapShortcutRejectsPendingSecurityRead() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let controller = makeController(
            trialClaimStore: MemoryTrialClaimStore(claim: makeTrialClaim(
                email: "trial@example.com", installID: "event-tap", startedAt: now
            )),
            currentDate: { now },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )
        XCTAssertTrue(controller.shouldHandleEventTapShortcut())
        BoundedKeychainReadRegistry.began()
        XCTAssertFalse(controller.shouldHandleEventTapShortcut())
        BoundedKeychainReadRegistry.finished()
        BoundedKeychainReadRegistry.validationCompletedIfIdle()
    }

    func testEventTapShortcutChecksTrialDeadlineAndClockRollbackImmediately() {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        var now = startedAt
        let controller = makeController(
            trialClaimStore: MemoryTrialClaimStore(claim: makeTrialClaim(
                email: "trial@example.com", installID: "event-tap", startedAt: startedAt
            )),
            currentDate: { now }, currentUptime: { 100 },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )
        XCTAssertTrue(controller.shouldHandleEventTapShortcut())
        now = startedAt.addingTimeInterval(14 * 24 * 60 * 60)
        XCTAssertFalse(controller.shouldHandleEventTapShortcut())
        now = startedAt.addingTimeInterval(-24 * 60 * 60)
        XCTAssertFalse(controller.shouldHandleEventTapShortcut())
    }

    func testTimedOutSilentKeychainReadStaysSingleFlightAndFailsClosed() {
        let gate = BoundedSilentKeychainRead<String>()
        let release = DispatchSemaphore(value: 0)
        let began = expectation(description: "Lookup started")
        let completed = expectation(description: "Lookup completed")
        let observer = NotificationCenter.default.addObserver(
            forName: BoundedKeychainReadRegistry.didCompleteNotification,
            object: nil,
            queue: .main
        ) { _ in completed.fulfill() }
        defer { NotificationCenter.default.removeObserver(observer); release.signal() }
        let start = Date()
        XCTAssertNil(gate.load(timeout: 0.02) {
            began.fulfill()
            release.wait()
            return "signed-token"
        })
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.25)
        wait(for: [began], timeout: 1)
        XCTAssertTrue(BoundedKeychainReadRegistry.hasPendingReads)
        XCTAssertNil(gate.load(timeout: 0.02) {
            XCTFail("A blocked Keychain read must not start a second worker")
            return nil
        })
        release.signal()
        wait(for: [completed], timeout: 1)
        XCTAssertFalse(BoundedKeychainReadRegistry.hasPendingReads)
        XCTAssertEqual(gate.load(timeout: 0.02) { nil }, "signed-token")
    }

    func testUnknownPaidEntitlementIsNotDeleted() {
        let store = MemoryDeviceLicenseEntitlementStore()
        _ = makeController(
            deviceEntitlementStore: store,
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )
        XCTAssertEqual(store.clearCount, 0)
    }

    func testCompletedMissingKeychainItemDoesNotRetriggerOnRefresh() {
        let gate = BoundedSilentKeychainRead<String>()
        let completed = expectation(description: "Missing lookup completed")
        let observer = NotificationCenter.default.addObserver(
            forName: BoundedKeychainReadRegistry.didCompleteNotification,
            object: nil,
            queue: .main
        ) { _ in completed.fulfill() }
        defer { NotificationCenter.default.removeObserver(observer) }
        var attempts = 0
        XCTAssertNil(gate.load(timeout: 0.2, cacheDuration: 10) {
            attempts += 1
            return nil
        })
        wait(for: [completed], timeout: 1)
        XCTAssertNil(gate.load(timeout: 0.2, cacheDuration: 10) {
            attempts += 1
            return nil
        })
        XCTAssertEqual(attempts, 1, "A completion recheck must consume the cached miss")
    }

    func testSlowSequentialKeychainReadsRetainEarlierResultUntilValidationCompletes() {
        BoundedKeychainReadRegistry.validationCompletedIfIdle()
        let first = BoundedSilentKeychainRead<String>()
        let second = BoundedSilentKeychainRead<String>()
        let secondRelease = DispatchSemaphore(value: 0)
        defer {
            secondRelease.signal()
            BoundedKeychainReadRegistry.validationCompletedIfIdle()
        }
        let firstCompleted = expectation(description: "First read completed")
        let firstObserver = NotificationCenter.default.addObserver(
            forName: BoundedKeychainReadRegistry.didCompleteNotification,
            object: nil,
            queue: .main
        ) { _ in firstCompleted.fulfill() }
        XCTAssertEqual(first.load(timeout: 0.2, cacheDuration: 0.01) { "paid-token" }, "paid-token")
        wait(for: [firstCompleted], timeout: 1)
        NotificationCenter.default.removeObserver(firstObserver)

        let secondCompleted = expectation(description: "Later read completed")
        let secondObserver = NotificationCenter.default.addObserver(
            forName: BoundedKeychainReadRegistry.didCompleteNotification,
            object: nil,
            queue: .main
        ) { _ in secondCompleted.fulfill() }
        defer { NotificationCenter.default.removeObserver(secondObserver) }
        XCTAssertNil(second.load(timeout: 0.01, cacheDuration: 0.01) {
            secondRelease.wait()
            return "trial-claim"
        })
        Thread.sleep(forTimeInterval: 0.04) // Longer than either result's normal cache lifetime.
        XCTAssertEqual(first.load(timeout: 0.01, cacheDuration: 0.01) {
            XCTFail("Validation must reuse the completed first read")
            return nil
        }, "paid-token")
        secondRelease.signal()
        wait(for: [secondCompleted], timeout: 1)
        XCTAssertEqual(second.load(timeout: 0.01, cacheDuration: 0.01) { nil }, "trial-claim")
        XCTAssertEqual(first.load(timeout: 0.01, cacheDuration: 0.01) {
            XCTFail("The first read must remain valid until the full pass finishes")
            return nil
        }, "paid-token")
        BoundedKeychainReadRegistry.validationCompletedIfIdle()
        XCTAssertFalse(BoundedKeychainReadRegistry.hasPendingReads)
    }

    func testCommerceCapabilityDefaultsClosedAndAcceptsOnlyBooleanBundleMetadata() {
        XCTAssertFalse(LicensingConfiguration.commerceEnabled(infoValue: nil))
        XCTAssertFalse(LicensingConfiguration.commerceEnabled(infoValue: "true"))
        XCTAssertTrue(LicensingConfiguration.commerceEnabled(infoValue: true))
    }

    func testTrialClaimParsesFractionalAndWholeSecondISO8601WithoutChangingWireStrings() {
        let fractionalStart = "2026-07-27T12:34:56.123Z"
        let fractionalEnd = "2026-08-10T12:34:56.123Z"
        let wholeSecondStart = "2026-07-27T12:34:56Z"
        let wholeSecondEnd = "2026-08-10T12:34:56Z"
        let fractionalClaim = makeTrialClaim(
            startedAt: fractionalStart,
            endsAt: fractionalEnd
        )
        let wholeSecondClaim = makeTrialClaim(
            startedAt: wholeSecondStart,
            endsAt: wholeSecondEnd
        )

        guard let parsedFractionalStart = fractionalClaim.startedDate,
              let parsedFractionalEnd = fractionalClaim.endsDate,
              let parsedWholeSecondStart = wholeSecondClaim.startedDate,
              let parsedWholeSecondEnd = wholeSecondClaim.endsDate else {
            return XCTFail("Expected both JavaScript and legacy ISO-8601 shapes to parse")
        }

        XCTAssertEqual(
            parsedFractionalStart.timeIntervalSince(parsedWholeSecondStart),
            0.123,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            parsedFractionalEnd.timeIntervalSince(parsedWholeSecondEnd),
            0.123,
            accuracy: 0.000_001
        )
        XCTAssertEqual(fractionalClaim.startedAt, fractionalStart)
        XCTAssertEqual(fractionalClaim.endsAt, fractionalEnd)
        XCTAssertEqual(wholeSecondClaim.startedAt, wholeSecondStart)
        XCTAssertEqual(wholeSecondClaim.endsAt, wholeSecondEnd)
    }

    func testUnregisteredWithoutServerTrialClaim() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let trialStore = MemoryTrialStartDateStore(date: Calendar.current.date(byAdding: .day, value: -2, to: now))
        let controller = makeController(
            trialStore: trialStore,
            currentDate: { now },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )

        guard case .unregistered = controller.status else {
            return XCTFail("Expected unregistered state")
        }
        XCTAssertFalse(controller.hasUnlockedAccess)
    }

    func testExpiredTrialBlocksAccess() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let trialStore = MemoryTrialStartDateStore(date: Calendar.current.date(byAdding: .day, value: -20, to: now))
        let controller = makeController(
            trialStore: trialStore,
            currentDate: { now },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )

        XCTAssertFalse(controller.hasUnlockedAccess)
        guard case .unregistered = controller.status else {
            return XCTFail("Expected unregistered state")
        }
        XCTAssertFalse(controller.shouldHandleCustomSwitcherShortcut())
    }

    func testSignedLicenseActivatesApp() throws {
        let materials = makeSigningMaterials()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let trialStore = MemoryTrialStartDateStore(date: now)
        let licenseStore = MemoryLicenseKeyStore()
        let activationStore = MemoryLicenseActivationMetadataStore()
        let payloadCacheStore = MemoryLicensedPayloadCacheStore()
        let controller = makeController(
            trialStore: trialStore,
            licenseStore: licenseStore,
            activationMetadataStore: activationStore,
            payloadCacheStore: payloadCacheStore,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64
        )

        let token = try signedToken(
            email: "user@example.com",
            name: "Test User",
            licenseID: "LIC-123",
            privateKey: materials.privateKey,
            issuedAt: now
        )

        XCTAssertTrue(controller.activateLicense(token))

        guard case let .licensed(payload, activatedAt) = controller.status else {
            return XCTFail("Expected licensed state")
        }

        XCTAssertEqual(payload.email, "user@example.com")
        XCTAssertEqual(payload.licenseID, "LIC-123")
        XCTAssertEqual(licenseStore.value, token)
        XCTAssertEqual(activatedAt, now)
        XCTAssertEqual(payloadCacheStore.payload?.licenseID, "LIC-123")
    }

    func testInvalidLicenseIsRejected() {
        let materials = makeSigningMaterials()
        let controller = makeController(publicKeyBase64: materials.publicKeyBase64)

        XCTAssertFalse(controller.activateLicense("CMDTAB1.invalid.payload"))
        XCTAssertFalse(controller.hasUnlockedAccess)
    }

    func testNewPurchaseActivationCredentialCannotUnlockLocally() {
        let materials = makeSigningMaterials()
        let controller = makeController(
            publicKeyBase64: materials.publicKeyBase64
        )

        XCTAssertFalse(
            controller.activateLicense(
                "CMDTAB-ACT-\(String(repeating: "a", count: 43))"
            )
        )
        XCTAssertFalse(controller.hasUnlockedAccess)
    }

    func testAuthoritativeRevocationCreatesPersistentTombstoneButTransientFailuresDoNot() async throws {
        let materials = makeSigningMaterials()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let token = try signedToken(
            email: "revoked@example.com",
            name: nil,
            licenseID: "LIC-REV",
            privateKey: materials.privateKey,
            issuedAt: now
        )
        let licenseStore = MemoryLicenseKeyStore()
        licenseStore.value = token
        let revocationStore = MemoryLicenseRevocationStore()
        let serverClient = MockCmdTabServerClient()
        serverClient.listResult = .failure(CmdTabServerClientError.invalidResponse)
        let controller = makeController(
            licenseStore: licenseStore,
            revocationStore: revocationStore,
            serverClient: serverClient,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64
        )

        await controller.refreshLicensedDevices()
        XCTAssertTrue(controller.hasUnlockedAccess)
        XCTAssertTrue(revocationStore.revokedIdentifiers.isEmpty)

        serverClient.listResult = .failure(CmdTabServerClientError.licenseRevoked)
        await controller.refreshLicensedDevices()
        XCTAssertFalse(controller.hasUnlockedAccess)
        XCTAssertTrue(
            revocationStore.revokedIdentifiers.contains("license:LIC-REV")
        )
        XCTAssertNil(licenseStore.value)
    }

    func testRemoteDeactivationWithEmptyDeviceListRevokesRetainedToken() async throws {
        let legacy = makeSigningMaterials()
        let v2 = P256.Signing.PrivateKey()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let secret = Data(repeating: 5, count: 32)
        let deviceID = SHA256.hash(data: secret)
            .map { String(format: "%02x", $0) }
            .joined()
        let entitlement = try signedV2Entitlement(
            privateKey: v2,
            kid: "license-empty-list",
            type: .license,
            subject: "owner@example.com",
            order: "LIC-EMPTY",
            bindingType: .activation,
            bindingValue: deviceID,
            issuedAt: now
        )
        let entitlementStore = MemoryDeviceLicenseEntitlementStore()
        entitlementStore.value = entitlement
        let credentialStore = MemoryLicenseKeyStore()
        credentialStore.value =
            "CMDTAB-ACT-\(String(repeating: "q", count: 43))"
        let revocations = MemoryLicenseRevocationStore()
        let server = MockCmdTabServerClient()
        server.listResult = .success([])
        server.currentActivationActive = false
        let controller = makeController(
            licenseStore: credentialStore,
            deviceEntitlementStore: entitlementStore,
            deviceIdentityStore: MemoryLicenseDeviceIdentityStore(
                secret: secret
            ),
            revocationStore: revocations,
            licenseV2PublicKeysDERBase64: [
                "license-empty-list":
                    v2.publicKey.derRepresentation.base64EncodedString(),
            ],
            serverClient: server,
            currentDate: { now },
            publicKeyBase64: legacy.publicKeyBase64
        )

        XCTAssertTrue(controller.hasUnlockedAccess)
        await controller.refreshLicensedDevices()
        XCTAssertFalse(controller.hasUnlockedAccess)
        XCTAssertNil(entitlementStore.value)
        XCTAssertNil(credentialStore.value)
        XCTAssertTrue(
            revocations.revokedIdentifiers.contains {
                $0.hasPrefix("token:")
            }
        )
    }

    func testRevocationFallbackSurvivesKeychainFailureAndStoreRecreation() throws {
        let suiteName = "CmdTabTests.revocation.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = "revocation-fallback"
        let failingStore = ThrowingLicenseKeyStore()
        let first = KeychainLicenseRevocationStore(
            store: failingStore,
            defaults: defaults,
            fallbackKey: key
        )

        XCTAssertThrowsError(try first.saveRevocation(licenseID: "license-hash"))
        XCTAssertTrue(first.isRevoked(licenseID: "license-hash"))

        let recreated = KeychainLicenseRevocationStore(
            store: failingStore,
            defaults: defaults,
            fallbackKey: key
        )
        XCTAssertTrue(recreated.isRevoked(licenseID: "license-hash"))
    }

    func testActiveTrialStillHandlesCustomSwitcherShortcut() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let claimStore = MemoryTrialClaimStore(claim: makeTrialClaim(email: "trial@example.com", installID: "install-1", startedAt: now))
        let controller = makeController(
            trialClaimStore: claimStore,
            currentDate: { now },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )

        XCTAssertTrue(controller.shouldHandleCustomSwitcherShortcut())
    }

    func testExactFourteenDayServerClaimUsesUTCMilestonesAndStopsClaimingShortcutAtExpiry() {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let secondsPerDay: TimeInterval = 24 * 60 * 60
        let exactEnd = startedAt.addingTimeInterval(
            TimeInterval(LicensingConfiguration.trialLengthDays) * secondsPerDay
        )
        var now = startedAt
        let controller = makeController(
            trialClaimStore: MemoryTrialClaimStore(
                claim: makeTrialClaim(
                    email: "trial@example.com",
                    installID: "install-boundary",
                    startedAt: startedAt
                )
            ),
            currentDate: { now },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )

        assertActiveTrial(
            controller,
            expectedStart: startedAt,
            expectedEnd: exactEnd,
            expectedDaysRemaining: 14,
            expectedTitle: "14 days left in trial"
        )

        now = startedAt.addingTimeInterval(11 * secondsPerDay)
        controller.refreshStatus()
        assertActiveTrial(
            controller,
            expectedStart: startedAt,
            expectedEnd: exactEnd,
            expectedDaysRemaining: 3,
            expectedTitle: "3 days left in trial"
        )

        now = startedAt.addingTimeInterval(13 * secondsPerDay)
        controller.refreshStatus()
        assertActiveTrial(
            controller,
            expectedStart: startedAt,
            expectedEnd: exactEnd,
            expectedDaysRemaining: 1,
            expectedTitle: "1 day left in trial"
        )

        now = exactEnd.addingTimeInterval(-1)
        controller.refreshStatus()
        assertActiveTrial(
            controller,
            expectedStart: startedAt,
            expectedEnd: exactEnd,
            expectedDaysRemaining: 1,
            expectedTitle: "1 day left in trial"
        )

        now = exactEnd
        controller.refreshStatus()
        guard case let .expired(expiredStart, endedAt, daysOverdue) = controller.status else {
            return XCTFail("Expected trial to expire at the exact 14-day boundary")
        }
        XCTAssertEqual(expiredStart, startedAt)
        XCTAssertEqual(endedAt, exactEnd)
        XCTAssertEqual(daysOverdue, 0)
        XCTAssertTrue(controller.licenseSummaryDetail.hasPrefix("The trial just expired."))
        XCTAssertFalse(controller.shouldHandleCustomSwitcherShortcut())

        now = exactEnd.addingTimeInterval(secondsPerDay)
        controller.refreshStatus()
        guard case let .expired(_, endedAt, daysOverdue) = controller.status else {
            return XCTFail("Expected trial to remain expired after its boundary")
        }
        XCTAssertEqual(endedAt, exactEnd)
        XCTAssertEqual(daysOverdue, 1)
        XCTAssertTrue(controller.licenseSummaryDetail.hasPrefix("The trial expired 1 day ago."))
        XCTAssertFalse(controller.shouldHandleCustomSwitcherShortcut())
    }

    func testTrialWarningAppearsOnlyDuringFinalThreeDaysAndAtExpiry() {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let day: TimeInterval = 24 * 60 * 60
        var now = startedAt.addingTimeInterval(10 * day)
        let controller = makeController(
            trialClaimStore: MemoryTrialClaimStore(
                claim: makeTrialClaim(
                    email: "trial@example.com",
                    installID: "install-warning",
                    startedAt: startedAt
                )
            ),
            currentDate: { now },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )

        XCTAssertNil(controller.trialWarningMessage)
        XCTAssertNil(controller.menuBarTrialStatusTitle)

        now = startedAt.addingTimeInterval(11 * day)
        controller.refreshStatus()
        XCTAssertTrue(
            controller.trialWarningMessage?.text.hasPrefix("3 days remain") == true
        )
        XCTAssertEqual(controller.menuBarTrialStatusTitle, "Trial: 3 Days Remaining")

        now = startedAt.addingTimeInterval(14 * day)
        controller.refreshStatus()
        XCTAssertEqual(controller.trialWarningMessage?.tone, .error)
        XCTAssertTrue(
            controller.trialWarningMessage?.text.contains("native macOS switcher") == true
        )
        XCTAssertEqual(controller.menuBarTrialStatusTitle, "Trial Expired")
    }

    func testClockRollbackCannotLowerSecureTimeDuringOnlineRevalidation() async {
        let materials = makeSigningMaterials()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let claim = makeTrialClaim(
            email: "rollback@example.com",
            installID: "server-binding",
            startedAt: now.addingTimeInterval(-24 * 60 * 60)
        )
        let clockStore = MemorySecureTrialClockStore(
            date: now.addingTimeInterval(60 * 60)
        )
        let serverClient = MockCmdTabServerClient()
        serverClient.trialResult = .success(claim)
        let controller = makeController(
            trialClaimStore: MemoryTrialClaimStore(claim: claim),
            secureTrialClockStore: clockStore,
            serverClient: serverClient,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64
        )

        guard case .unregistered = controller.status else {
            return XCTFail("Expected suspicious rollback to fail closed")
        }
        XCTAssertEqual(
            controller.trialMessage?.text,
            "The system clock moved backwards. Connect to the internet and revalidate the trial."
        )

        let revalidated = await controller.startTrialRegistration()
        XCTAssertFalse(revalidated)
        guard case .unregistered = controller.status else {
            return XCTFail("Expected the still-rolled-back clock to remain blocked")
        }
        XCTAssertEqual(clockStore.date, now.addingTimeInterval(60 * 60))
    }

    func testSignedInstallBoundTrialAuthenticatesAndTamperingFailsClosed() throws {
        let v1 = makeSigningMaterials()
        let trialPrivateKey = P256.Signing.PrivateKey()
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let now = startedAt.addingTimeInterval(60)
        let secret = Data(repeating: 9, count: 32)
        let binding = SHA256.hash(data: secret)
            .map { String(format: "%02x", $0) }
            .joined()
        let claimID = "trial-signed-1"
        let email = "signed@example.com"
        let token = try signedV2Entitlement(
            privateKey: trialPrivateKey,
            kid: "trial-test-1",
            type: .trial,
            subject: email,
            order: claimID,
            bindingType: .install,
            bindingValue: binding,
            issuedAt: startedAt
        )
        let claim = TrialClaimRecord(
            id: claimID,
            email: email,
            installID: binding,
            startedAt: ISO8601DateFormatter().string(from: startedAt),
            endsAt: ISO8601DateFormatter().string(
                from: startedAt.addingTimeInterval(14 * 24 * 60 * 60)
            ),
            appVersion: "1.0",
            osVersion: "14.0",
            entitlementToken: token
        )
        let authenticator = SignedTrialClaimAuthenticator(
            legacyPublicKeyDERBase64: v1.publicKeyBase64,
            v2PublicKeysDERBase64: [
                "trial-test-1":
                    trialPrivateKey.publicKey.derRepresentation.base64EncodedString(),
            ]
        )
        let valid = makeController(
            trialClaimStore: MemoryTrialClaimStore(claim: claim),
            deviceIdentityStore: MemoryLicenseDeviceIdentityStore(secret: secret),
            trialClaimAuthenticator: authenticator,
            currentDate: { now },
            publicKeyBase64: v1.publicKeyBase64
        )
        guard case .activeTrial = valid.status else {
            return XCTFail("Expected signed, install-bound claim to activate")
        }

        let tamperedClaim = TrialClaimRecord(
            id: claim.id,
            email: "attacker@example.com",
            installID: claim.installID,
            startedAt: claim.startedAt,
            endsAt: claim.endsAt,
            appVersion: claim.appVersion,
            osVersion: claim.osVersion,
            entitlementToken: token
        )
        let tampered = makeController(
            trialClaimStore: MemoryTrialClaimStore(claim: tamperedClaim),
            deviceIdentityStore: MemoryLicenseDeviceIdentityStore(secret: secret),
            trialClaimAuthenticator: authenticator,
            currentDate: { now },
            publicKeyBase64: v1.publicKeyBase64
        )
        guard case .unregistered = tampered.status else {
            return XCTFail("Expected tampered claim fields to fail closed")
        }
    }

    func testOverlongServerClaimIsRejectedAndCleared() {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let secondsPerDay: TimeInterval = 24 * 60 * 60
        let claimedEnd = startedAt.addingTimeInterval(15 * secondsPerDay)
        let claimStore = MemoryTrialClaimStore(
            claim: makeTrialClaim(
                email: "trial@example.com",
                installID: "install-overlong-claim",
                startedAt: startedAt,
                endsAt: claimedEnd
            )
        )
        let controller = makeController(
            trialClaimStore: claimStore,
            currentDate: { startedAt },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )

        guard case .unregistered = controller.status else {
            return XCTFail("Expected inconsistent overlong claim to fail closed")
        }
        XCTAssertNil(claimStore.claim)
        XCTAssertFalse(controller.shouldHandleCustomSwitcherShortcut())
    }

    func testEarlyServerClaimIsRejectedAndCleared() {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let secondsPerDay: TimeInterval = 24 * 60 * 60
        let claimedEnd = startedAt.addingTimeInterval(13 * secondsPerDay)
        let claimStore = MemoryTrialClaimStore(
            claim: makeTrialClaim(
                email: "trial@example.com",
                installID: "install-early-claim",
                startedAt: startedAt,
                endsAt: claimedEnd
            )
        )
        let controller = makeController(
            trialClaimStore: claimStore,
            currentDate: { startedAt },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )

        guard case .unregistered = controller.status else {
            return XCTFail("Expected inconsistent early claim to fail closed")
        }
        XCTAssertNil(claimStore.claim)
        XCTAssertFalse(controller.shouldHandleCustomSwitcherShortcut())
    }

    func testDeveloperExpiredTrialOverrideInTestChannel() {
        let materials = makeSigningMaterials()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let developerSettings = DeveloperSettings(defaults: defaults, keyPrefix: "CmdTab.test")
        developerSettings.releaseChannel = .test
        developerSettings.licensingScenario = .expiredTrial

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let controller = makeController(
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64,
            developerSettings: developerSettings
        )

        XCTAssertTrue(controller.status.isExpired)
        XCTAssertFalse(controller.hasUnlockedAccess)
    }

    func testDeveloperSimulatedLicenseOverrideInTestChannel() {
        let materials = makeSigningMaterials()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let developerSettings = DeveloperSettings(defaults: defaults, keyPrefix: "CmdTab.test")
        developerSettings.releaseChannel = .test
        developerSettings.licensingScenario = .simulatedLicensed

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let controller = makeController(
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64,
            developerSettings: developerSettings
        )

        guard case let .licensed(payload, activatedAt) = controller.status else {
            return XCTFail("Expected simulated licensed state")
        }

        XCTAssertEqual(payload.email, "developer@cmdtab.local")
        XCTAssertEqual(payload.licenseID, "DEV-SIMULATED")
        XCTAssertEqual(activatedAt, now)
    }

    func testVerifiedKeychainLicenseWinsOverDeveloperOverride() throws {
        let materials = makeSigningMaterials()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let developerSettings = DeveloperSettings(defaults: defaults, keyPrefix: "CmdTab.test")
        developerSettings.releaseChannel = .test
        developerSettings.licensingScenario = .expiredTrial

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload = SignedLicensePayload(
            version: 1,
            product: "cmdtab",
            email: "real@example.com",
            licenseID: "LIC-REAL",
            issuedAt: ISO8601DateFormatter().string(from: now),
            purchaserName: "Real License"
        )

        let licenseStore = MemoryLicenseKeyStore()
        licenseStore.value = try signedToken(
            email: payload.email,
            name: payload.purchaserName,
            licenseID: payload.licenseID,
            privateKey: materials.privateKey,
            issuedAt: now
        )
        let controller = makeController(
            licenseStore: licenseStore,
            payloadCacheStore: MemoryLicensedPayloadCacheStore(payload: payload),
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64,
            developerSettings: developerSettings
        )

        guard case let .licensed(licensedPayload, _) = controller.status else {
            return XCTFail("Expected verified real license to win over developer override")
        }

        XCTAssertEqual(licensedPayload.licenseID, "LIC-REAL")
    }

    func testStableChannelIgnoresDeveloperScenarioOverride() {
        let materials = makeSigningMaterials()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let developerSettings = DeveloperSettings(defaults: defaults, keyPrefix: "CmdTab.test")
        developerSettings.releaseChannel = .stable
        developerSettings.licensingScenario = .expiredTrial

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let claimStore = MemoryTrialClaimStore(
            claim: makeTrialClaim(
                email: "stable@example.com",
                installID: "install-stable",
                startedAt: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
            )
        )
        let controller = makeController(
            trialClaimStore: claimStore,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64,
            developerSettings: developerSettings
        )

        guard case let .activeTrial(_, _, daysRemaining) = controller.status else {
            return XCTFail("Expected live active trial state")
        }

        XCTAssertEqual(daysRemaining, 12)
    }

    func testCachedPayloadCannotGrantPaidAccessWithoutSignedKeychainToken() throws {
        let materials = makeSigningMaterials()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload = SignedLicensePayload(
            version: 1,
            product: "cmdtab",
            email: "cached@example.com",
            licenseID: "LIC-CACHED",
            issuedAt: ISO8601DateFormatter().string(from: now),
            purchaserName: "Cached User"
        )
        let payloadCacheStore = MemoryLicensedPayloadCacheStore(payload: payload)
        let licenseStore = MemoryLicenseKeyStore()
        let activationStore = MemoryLicenseActivationMetadataStore(date: now)

        let controller = makeController(
            licenseStore: licenseStore,
            activationMetadataStore: activationStore,
            payloadCacheStore: payloadCacheStore,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64
        )

        guard case .unregistered = controller.status else {
            return XCTFail("Expected unsigned cache metadata to fail closed")
        }
        XCTAssertNil(payloadCacheStore.payload)
        XCTAssertEqual(licenseStore.silentLoadCount, 1)
    }

    func testPassiveRefreshChecksKeychainForSignedPaidEntitlement() {
        let materials = makeSigningMaterials()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let trialStore = MemoryTrialStartDateStore(date: now)
        let licenseStore = MemoryLicenseKeyStore()

        let controller = makeController(
            trialStore: trialStore,
            licenseStore: licenseStore,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64
        )

        guard case .unregistered = controller.status else {
            return XCTFail("Expected unregistered state")
        }

        XCTAssertEqual(licenseStore.silentLoadCount, 1)
    }

    func testStartTrialRegistrationActivatesTrialState() async {
        let materials = makeSigningMaterials()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let claimStore = MemoryTrialClaimStore()
        let installIDStore = MemoryAppInstallIDStore(value: "install-registration-1")
        let serverClient = MockCmdTabServerClient()
        serverClient.trialResult = .success(
            makeTrialClaim(email: "trial@example.com", installID: "install-registration-1", startedAt: now)
        )

        let controller = makeController(
            trialClaimStore: claimStore,
            installIDStore: installIDStore,
            serverClient: serverClient,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64
        )

        controller.enteredTrialEmail = "trial@example.com"
        let started = await controller.startTrialRegistration()

        XCTAssertTrue(started)
        XCTAssertEqual(serverClient.startTrialCalls.count, 1)
        XCTAssertEqual(serverClient.startTrialCalls.first?.email, "trial@example.com")
        XCTAssertEqual(claimStore.claim?.email, "trial@example.com")

        guard case let .activeTrial(_, _, daysRemaining) = controller.status else {
            return XCTFail("Expected active trial state")
        }

        XCTAssertEqual(daysRemaining, 14)
    }

    func testStartTrialRegistrationAcceptsJavaScriptFractionalTimestampClaim() async {
        let claim = makeTrialClaim(
            startedAt: "2026-07-27T12:34:56.123Z",
            endsAt: "2026-08-10T12:34:56.123Z"
        )
        guard let startedAt = claim.startedDate,
              let endsAt = claim.endsDate else {
            return XCTFail("Expected API-shaped fractional timestamps to parse")
        }
        let claimStore = MemoryTrialClaimStore()
        let serverClient = MockCmdTabServerClient()
        serverClient.trialResult = .success(claim)
        let controller = makeController(
            trialClaimStore: claimStore,
            serverClient: serverClient,
            currentDate: { startedAt },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )

        controller.enteredTrialEmail = claim.email
        let activated = await controller.startTrialRegistration()

        XCTAssertTrue(activated)
        XCTAssertEqual(claimStore.claim, claim)
        assertActiveTrial(
            controller,
            expectedStart: startedAt,
            expectedEnd: endsAt,
            expectedDaysRemaining: 14,
            expectedTitle: "14 days left in trial"
        )
        XCTAssertEqual(endsAt.timeIntervalSince(startedAt), 14 * 24 * 60 * 60)
    }

    func testStartTrialRegistrationRejectsEarlyServerClaim() async {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let claimStore = MemoryTrialClaimStore()
        let serverClient = MockCmdTabServerClient()
        serverClient.trialResult = .success(
            makeTrialClaim(
                email: "trial@example.com",
                installID: "install-early-response",
                startedAt: startedAt,
                endsAt: startedAt.addingTimeInterval(13 * 24 * 60 * 60)
            )
        )
        let controller = makeController(
            trialClaimStore: claimStore,
            serverClient: serverClient,
            currentDate: { startedAt },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )

        controller.enteredTrialEmail = "trial@example.com"
        let started = await controller.startTrialRegistration()
        XCTAssertFalse(started)
        XCTAssertNil(claimStore.claim)
        XCTAssertEqual(
            controller.trialMessage?.text,
            "The trial response could not be verified. Please try again."
        )
        guard case .unregistered = controller.status else {
            return XCTFail("Expected early registration response to fail closed")
        }
        XCTAssertFalse(controller.shouldHandleCustomSwitcherShortcut())
    }

    func testStartTrialRegistrationRejectsOverlongServerClaim() async {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let claimStore = MemoryTrialClaimStore()
        let serverClient = MockCmdTabServerClient()
        serverClient.trialResult = .success(
            makeTrialClaim(
                email: "trial@example.com",
                installID: "install-overlong-response",
                startedAt: startedAt,
                endsAt: startedAt.addingTimeInterval(15 * 24 * 60 * 60)
            )
        )
        let controller = makeController(
            trialClaimStore: claimStore,
            serverClient: serverClient,
            currentDate: { startedAt },
            publicKeyBase64: makeSigningMaterials().publicKeyBase64
        )

        controller.enteredTrialEmail = "trial@example.com"
        let started = await controller.startTrialRegistration()
        XCTAssertFalse(started)
        XCTAssertNil(claimStore.claim)
        XCTAssertEqual(
            controller.trialMessage?.text,
            "The trial response could not be verified. Please try again."
        )
        guard case .unregistered = controller.status else {
            return XCTFail("Expected overlong registration response to fail closed")
        }
        XCTAssertFalse(controller.shouldHandleCustomSwitcherShortcut())
    }

    func testStartTrialRegistrationShowsBlockedMessage() async {
        let materials = makeSigningMaterials()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let serverClient = MockCmdTabServerClient()
        serverClient.trialResult = .failure(CmdTabServerClientError.blocked("This email has already started a CmdTab trial."))

        let controller = makeController(
            serverClient: serverClient,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64
        )

        controller.enteredTrialEmail = "used@example.com"
        let started = await controller.startTrialRegistration()

        XCTAssertFalse(started)
        XCTAssertEqual(controller.trialMessage?.text, "This email has already started a CmdTab trial.")
        guard case .unregistered = controller.status else {
            return XCTFail("Expected unregistered state after blocked trial registration")
        }
    }

    func testActivatingRealLicenseInTestModeSwitchesScenarioToLive() throws {
        let materials = makeSigningMaterials()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let developerSettings = DeveloperSettings(defaults: defaults, keyPrefix: "CmdTab.test")
        developerSettings.releaseChannel = .test
        developerSettings.licensingScenario = .expiredTrial

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let licenseStore = MemoryLicenseKeyStore()
        let payloadCacheStore = MemoryLicensedPayloadCacheStore()
        let controller = makeController(
            licenseStore: licenseStore,
            payloadCacheStore: payloadCacheStore,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64,
            developerSettings: developerSettings
        )

        let token = try signedToken(
            email: "user@example.com",
            name: "Test User",
            licenseID: "LIC-123",
            privateKey: materials.privateKey,
            issuedAt: now
        )

        XCTAssertTrue(controller.activateLicense(token))
        XCTAssertEqual(developerSettings.licensingScenario, .live)

        guard case let .licensed(payload, _) = controller.status else {
            return XCTFail("Expected licensed state")
        }

        XCTAssertEqual(payload.licenseID, "LIC-123")
    }

    func testOnlineActivationRegistersHashedKeychainDeviceBeforeSavingLicense() async throws {
        let materials = makeSigningMaterials()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let token = "CMDTAB-ACT-\(String(repeating: "z", count: 43))"
        let licenseStore = MemoryLicenseKeyStore()
        let deviceEntitlementStore = MemoryDeviceLicenseEntitlementStore()
        let revocationStore = MemoryLicenseRevocationStore()
        let v2PrivateKey = P256.Signing.PrivateKey()
        let deviceSecret = Data(repeating: 7, count: 32)
        let deviceID = SHA256.hash(data: deviceSecret)
            .map { String(format: "%02x", $0) }
            .joined()
        let paidEntitlement = try signedV2Entitlement(
            privateKey: v2PrivateKey,
            kid: "license-test-1",
            type: .license,
            subject: "user@example.com",
            order: "LIC-ONLINE",
            bindingType: .activation,
            bindingValue: deviceID,
            issuedAt: now
        )
        let serverClient = MockCmdTabServerClient()
        serverClient.activationResult = .success(
            LicenseActivationResult(
                devices: [
                    LicensedDeviceDTO(
                        deviceId: String(repeating: "d", count: 64),
                        deviceName: "Test Mac",
                        activatedAt: "2026-07-27T12:00:00Z"
                    ),
                ],
                entitlementToken: paidEntitlement
            )
        )
        let controller = makeController(
            licenseStore: licenseStore,
            deviceEntitlementStore: deviceEntitlementStore,
            deviceIdentityStore: MemoryLicenseDeviceIdentityStore(
                secret: deviceSecret
            ),
            revocationStore: revocationStore,
            licenseV2PublicKeysDERBase64: [
                "license-test-1":
                    v2PrivateKey.publicKey.derRepresentation.base64EncodedString(),
            ],
            serverClient: serverClient,
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64
        )
        controller.enteredLicenseKey = token

        let activated = await controller.activateEnteredLicenseKeyOnline()
        XCTAssertTrue(activated)
        XCTAssertEqual(licenseStore.value, token)
        XCTAssertEqual(deviceEntitlementStore.value, paidEntitlement)
        XCTAssertEqual(serverClient.activationCalls.count, 1)
        XCTAssertEqual(serverClient.activationCalls[0].licenseKey, token)
        XCTAssertEqual(serverClient.activationCalls[0].deviceID.count, 64)
        XCTAssertNotEqual(
            serverClient.activationCalls[0].deviceID,
            Data(repeating: 7, count: 32).base64EncodedString()
        )
        XCTAssertEqual(controller.licensedDevices.first?.deviceName, "Test Mac")

        serverClient.deactivationResult = .success([])
        let deactivated = await controller.deactivateCurrentDevice()
        XCTAssertTrue(deactivated)
        XCTAssertEqual(serverClient.deactivationCalls.first?.licenseKey, token)
        XCTAssertNil(licenseStore.value)
        XCTAssertNil(deviceEntitlementStore.value)
        XCTAssertEqual(revocationStore.revokedIdentifiers.count, 1)
        XCTAssertTrue(
            revocationStore.revokedIdentifiers.first?.hasPrefix("token:") == true
        )

        // Restoring a saved perpetual token after freeing its slot must not
        // regain access on this Mac.
        deviceEntitlementStore.value = paidEntitlement
        let restored = makeController(
            licenseStore: licenseStore,
            deviceEntitlementStore: deviceEntitlementStore,
            deviceIdentityStore: MemoryLicenseDeviceIdentityStore(
                secret: deviceSecret
            ),
            revocationStore: revocationStore,
            licenseV2PublicKeysDERBase64: [
                "license-test-1":
                    v2PrivateKey.publicKey.derRepresentation.base64EncodedString(),
            ],
            currentDate: { now },
            publicKeyBase64: materials.publicKeyBase64
        )
        XCTAssertFalse(restored.hasUnlockedAccess)
        XCTAssertNil(deviceEntitlementStore.value)
    }

    private func makeController(
        trialStore: TrialStartDateStore = MemoryTrialStartDateStore(),
        trialClaimStore: TrialClaimStore = MemoryTrialClaimStore(),
        licenseStore: LicenseKeyStore = MemoryLicenseKeyStore(),
        deviceEntitlementStore: DeviceLicenseEntitlementStore =
            MemoryDeviceLicenseEntitlementStore(),
        activationMetadataStore: LicenseActivationMetadataStore = MemoryLicenseActivationMetadataStore(),
        payloadCacheStore: LicensedPayloadCacheStore = MemoryLicensedPayloadCacheStore(),
        installIDStore: AppInstallIDStore = MemoryAppInstallIDStore(),
        deviceIdentityStore: LicenseDeviceIdentityStore = MemoryLicenseDeviceIdentityStore(),
        trialClaimAuthenticator: TrialClaimAuthenticating = TrustingTrialClaimAuthenticator(),
        secureTrialClockStore: SecureTrialClockStore = MemorySecureTrialClockStore(),
        revocationStore: LicenseRevocationStore = MemoryLicenseRevocationStore(),
        licenseV2PublicKeysDERBase64: [String: String] = [:],
        serverClient: CmdTabServerClient = MockCmdTabServerClient(),
        currentDate: @escaping () -> Date = Date.init,
        currentUptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        publicKeyBase64: String,
        developerSettings: DeveloperSettings? = nil
    ) -> LicensingController {
        LicensingController(
            trialStore: trialStore,
            trialClaimStore: trialClaimStore,
            licenseStore: licenseStore,
            deviceEntitlementStore: deviceEntitlementStore,
            activationMetadataStore: activationMetadataStore,
            payloadCacheStore: payloadCacheStore,
            installIDStore: installIDStore,
            deviceIdentityStore: deviceIdentityStore,
            trialClaimAuthenticator: trialClaimAuthenticator,
            secureTrialClockStore: secureTrialClockStore,
            revocationStore: revocationStore,
            licenseV2PublicKeysDERBase64: licenseV2PublicKeysDERBase64,
            serverClient: serverClient,
            currentDate: currentDate,
            currentUptime: currentUptime,
            publicKeyDERBase64: publicKeyBase64,
            debugCompatibility: developerSettings ?? DeveloperSettings(
                defaults: UserDefaults(suiteName: UUID().uuidString)!,
                keyPrefix: UUID().uuidString
            )
        )
    }

    private func makeSigningMaterials() -> (privateKey: P256.Signing.PrivateKey, publicKeyBase64: String) {
        let privateKey = P256.Signing.PrivateKey()
        let publicKeyBase64 = privateKey.publicKey.derRepresentation.base64EncodedString()
        return (privateKey, publicKeyBase64)
    }

    private func signedToken(
        email: String,
        name: String?,
        licenseID: String,
        privateKey: P256.Signing.PrivateKey,
        issuedAt: Date
    ) throws -> String {
        let payload = SignedLicensePayload(
            version: 1,
            product: "cmdtab",
            email: email,
            licenseID: licenseID,
            issuedAt: ISO8601DateFormatter().string(from: issuedAt),
            purchaserName: name
        )
        let payloadData = try JSONEncoder().encode(payload)
        let signature = try privateKey.signature(for: payloadData)
        return [
            "CMDTAB1",
            payloadData.base64URLEncodedString(),
            signature.derRepresentation.base64URLEncodedString(),
        ].joined(separator: ".")
    }

    private func signedV2Entitlement(
        privateKey: P256.Signing.PrivateKey,
        kid: String,
        type: CmdTabEntitlementType,
        subject: String,
        order: String,
        bindingType: CmdTabEntitlementBindingType,
        bindingValue: String,
        issuedAt: Date
    ) throws -> String {
        let issued = Int64(issuedAt.timeIntervalSince1970.rounded(.down))
        let payload = CmdTabTokenV2Payload(
            v: 2,
            kid: kid,
            typ: type,
            aud: "cmdtab",
            sub: LicenseTokenVerifier.hashIdentifier(subject),
            order: LicenseTokenVerifier.hashIdentifier(order),
            binding: CmdTabTokenV2Binding(
                typ: bindingType,
                hash: LicenseTokenVerifier.hashIdentifier(bindingValue)
            ),
            iat: issued,
            exp: type == .trial ? issued + 14 * 24 * 60 * 60 : nil,
            updates: "1.x"
        )
        let data = try JSONEncoder().encode(payload)
        let signature = try privateKey.signature(for: data).derRepresentation
        return [
            "CMDTAB2",
            data.base64URLEncodedString(),
            signature.base64URLEncodedString(),
        ].joined(separator: ".")
    }

    private func makeTrialClaim(
        email: String,
        installID: String,
        startedAt: Date,
        endsAt: Date? = nil
    ) -> TrialClaimRecord {
        let defaultEnd = startedAt.addingTimeInterval(
            TimeInterval(LicensingConfiguration.trialLengthDays) * 24 * 60 * 60
        )
        return TrialClaimRecord(
            id: UUID().uuidString,
            email: email,
            installID: installID,
            startedAt: ISO8601DateFormatter().string(from: startedAt),
            endsAt: ISO8601DateFormatter().string(from: endsAt ?? defaultEnd),
            appVersion: "1.0.0",
            osVersion: "14.0.0"
        )
    }

    private func makeTrialClaim(
        startedAt: String,
        endsAt: String
    ) -> TrialClaimRecord {
        TrialClaimRecord(
            id: UUID().uuidString,
            email: "trial@example.com",
            installID: "install-api-shaped",
            startedAt: startedAt,
            endsAt: endsAt,
            appVersion: "1.0.0",
            osVersion: "14.0.0"
        )
    }

    private func assertActiveTrial(
        _ controller: LicensingController,
        expectedStart: Date,
        expectedEnd: Date,
        expectedDaysRemaining: Int,
        expectedTitle: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .activeTrial(startedAt, endsAt, daysRemaining) = controller.status else {
            return XCTFail("Expected active trial state", file: file, line: line)
        }
        XCTAssertEqual(startedAt, expectedStart, file: file, line: line)
        XCTAssertEqual(endsAt, expectedEnd, file: file, line: line)
        XCTAssertEqual(daysRemaining, expectedDaysRemaining, file: file, line: line)
        XCTAssertEqual(controller.licenseSummaryTitle, expectedTitle, file: file, line: line)
        XCTAssertTrue(controller.shouldHandleCustomSwitcherShortcut(), file: file, line: line)
    }
}

private final class MemoryTrialStartDateStore: TrialStartDateStore {
    var date: Date?

    init(date: Date? = nil) {
        self.date = date
    }

    func loadTrialStartDate() -> Date? {
        date
    }

    func saveTrialStartDate(_ date: Date) {
        self.date = date
    }
}

private final class MemoryLicenseKeyStore: LicenseKeyStore {
    var value: String?
    var silentLoadCount = 0

    func loadLicenseKey() -> String? {
        value
    }

    func loadLicenseKeySilently() -> String? {
        silentLoadCount += 1
        return value
    }

    func saveLicenseKey(_ value: String) throws {
        self.value = value
    }

    func clearLicenseKey() throws {
        value = nil
    }
}

private final class MemoryDeviceLicenseEntitlementStore:
    DeviceLicenseEntitlementStore {
    var value: String?
    var clearCount = 0

    func loadEntitlement() -> String? {
        value
    }

    func saveEntitlement(_ value: String) throws {
        self.value = value
    }

    func clearEntitlement() throws {
        clearCount += 1
        value = nil
    }
}

private final class MemoryTrialClaimStore: TrialClaimStore {
    var claim: TrialClaimRecord?

    init(claim: TrialClaimRecord? = nil) {
        self.claim = claim
    }

    func loadClaim() -> TrialClaimRecord? {
        claim
    }

    func saveClaim(_ claim: TrialClaimRecord) {
        self.claim = claim
    }

    func clearClaim() {
        claim = nil
    }
}

private final class MemoryAppInstallIDStore: AppInstallIDStore {
    var value: String?

    init(value: String? = nil) {
        self.value = value
    }

    func loadInstallID() -> String? {
        value
    }

    func saveInstallID(_ value: String) {
        self.value = value
    }
}

private final class MemoryLicenseDeviceIdentityStore: LicenseDeviceIdentityStore {
    let secret: Data

    init(secret: Data = Data(repeating: 1, count: 32)) {
        self.secret = secret
    }

    func loadOrCreateSecret() throws -> Data {
        secret
    }
}

private struct TrustingTrialClaimAuthenticator: TrialClaimAuthenticating {
    func validates(_ claim: TrialClaimRecord, installID: String) -> Bool {
        true
    }
}

private final class MemorySecureTrialClockStore: SecureTrialClockStore {
    var date: Date?

    init(date: Date? = nil) {
        self.date = date
    }

    func loadLastSeenDate() -> Date? {
        date
    }

    func saveLastSeenDate(_ value: Date) {
        date = value
    }

    func clearLastSeenDate() {
        date = nil
    }
}

private final class MemoryLicenseRevocationStore: LicenseRevocationStore {
    var revokedIdentifiers = Set<String>()

    func isRevoked(licenseID: String) -> Bool {
        revokedIdentifiers.contains(licenseID)
    }

    func saveRevocation(licenseID: String) throws {
        revokedIdentifiers.insert(licenseID)
    }
}

private final class ThrowingLicenseKeyStore: LicenseKeyStore {
    func loadLicenseKey() -> String? { nil }
    func loadLicenseKeySilently() -> String? { nil }
    func saveLicenseKey(_ value: String) throws {
        throw LicenseKeyStoreError.unexpectedStatus(errSecNotAvailable)
    }
    func clearLicenseKey() throws {}
}

private final class MemoryLicenseActivationMetadataStore: LicenseActivationMetadataStore {
    var date: Date?

    init(date: Date? = nil) {
        self.date = date
    }

    func loadActivationDate() -> Date? {
        date
    }

    func saveActivationDate(_ date: Date) {
        self.date = date
    }

    func clearActivationDate() {
        date = nil
    }
}

private final class MemoryLicensedPayloadCacheStore: LicensedPayloadCacheStore {
    var payload: SignedLicensePayload?

    init(payload: SignedLicensePayload? = nil) {
        self.payload = payload
    }

    func loadPayload() -> SignedLicensePayload? {
        payload
    }

    func savePayload(_ payload: SignedLicensePayload) {
        self.payload = payload
    }

    func clearPayload() {
        payload = nil
    }
}

private final class MockCmdTabServerClient: CmdTabServerClient {
    struct StartTrialCall: Equatable {
        let email: String
        let installID: String
        let appVersion: String
        let osVersion: String
    }

    var trialResult: Result<TrialClaimRecord, Error>?
    var startTrialCalls: [StartTrialCall] = []
    var activationResult: Result<LicenseActivationResult, Error>?
    var activationCalls: [(licenseKey: String, deviceID: String, deviceName: String)] = []
    var deactivationResult: Result<[LicensedDeviceDTO], Error>?
    var deactivationCalls: [(licenseKey: String, deviceID: String)] = []
    var listResult: Result<[LicensedDeviceDTO], Error>?
    var currentActivationActive: Bool?

    func startTrial(email: String, installID: String, appVersion: String, osVersion: String) async throws -> TrialClaimRecord {
        startTrialCalls.append(
            StartTrialCall(
                email: email,
                installID: installID,
                appVersion: appVersion,
                osVersion: osVersion
            )
        )
        guard let trialResult else {
            throw CmdTabServerClientError.invalidResponse
        }
        return try trialResult.get()
    }

    func activateLicense(
        licenseKey: String,
        deviceID: String,
        deviceName: String
    ) async throws -> LicenseActivationResult {
        activationCalls.append((licenseKey, deviceID, deviceName))
        guard let activationResult else {
            throw CmdTabServerClientError.invalidResponse
        }
        return try activationResult.get()
    }

    func deactivateLicense(
        licenseKey: String,
        deviceID: String
    ) async throws -> [LicensedDeviceDTO] {
        deactivationCalls.append((licenseKey, deviceID))
        guard let deactivationResult else {
            throw CmdTabServerClientError.invalidResponse
        }
        return try deactivationResult.get()
    }

    func listDevices(licenseKey: String) async throws -> [LicensedDeviceDTO] {
        guard let listResult else {
            throw CmdTabServerClientError.invalidResponse
        }
        return try listResult.get()
    }

    func listDeviceStatus(
        licenseKey: String,
        deviceID: String
    ) async throws -> LicenseDeviceListResult {
        LicenseDeviceListResult(
            devices: try await listDevices(licenseKey: licenseKey),
            currentActivationActive: currentActivationActive
        )
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
