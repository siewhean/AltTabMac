import AppKit
import XCTest
@testable import CmdTab

final class PreviewContinuitySafetyTests: XCTestCase {
    private final class AttemptRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var recordedAttempts: [Int] = []

        func record(_ attempt: Int) {
            lock.lock()
            recordedAttempts.append(attempt)
            lock.unlock()
        }

        var attempts: [Int] {
            lock.lock()
            defer { lock.unlock() }
            return recordedAttempts
        }
    }

    override func tearDown() {
        SwitcherPreviewContinuityStore.resetForTesting()
        SwitcherItem.resetPreviewContinuityIdentityForTesting()
        super.tearDown()
    }

    func testPreviewRecoveryExecutesBothImmediateRetriesBeforeTerminalFailure() {
        let recorder = AttemptRecorder()
        ReliableWindowPreviewRecovery.configureForTesting(preflightGranted: true) { attempt in
            recorder.record(attempt)
            return nil
        }
        let completed = expectation(description: "all immediate retries executed")

        ReliableWindowPreviewRecovery.schedule(
            windowID: 700,
            exactKey: "exact-window",
            identityKey: "process-window"
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            completed.fulfill()
        }

        wait(for: [completed], timeout: 1.5)
        XCTAssertEqual(recorder.attempts, [0, 1, 2])
    }

    func testProcessGenerationTokenDoesNotFlipWhenLaunchDateAppearsLater() {
        let identity = SwitcherHistoryIdentity.appWindow(pid: 777, windowID: 700)

        let beforeLaunchServicesIsReady = SwitcherItem.previewContinuityIdentityKey(
            historyIdentity: identity,
            sourceAppIdentifier: "com.example.gpu",
            processLaunchDate: nil
        )
        let afterLaunchServicesIsReady = SwitcherItem.previewContinuityIdentityKey(
            historyIdentity: identity,
            sourceAppIdentifier: "com.example.gpu",
            processLaunchDate: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertEqual(afterLaunchServicesIsReady, beforeLaunchServicesIsReady)
        XCTAssertTrue(afterLaunchServicesIsReady.hasSuffix("|unknown-launch"))
    }

    func testProcessGenerationTokenChangesWhenPIDIsReusedAfterKnownLaunch() {
        let identity = SwitcherHistoryIdentity.appWindow(pid: 777, windowID: 700)
        let firstGeneration = SwitcherItem.previewContinuityIdentityKey(
            historyIdentity: identity,
            sourceAppIdentifier: "com.example.gpu",
            processLaunchDate: Date(timeIntervalSince1970: 2_000)
        )
        let reusedPID = SwitcherItem.previewContinuityIdentityKey(
            historyIdentity: identity,
            sourceAppIdentifier: "com.example.gpu",
            processLaunchDate: Date(timeIntervalSince1970: 3_000)
        )

        XCTAssertNotEqual(reusedPID, firstGeneration)
        XCTAssertTrue(reusedPID.hasSuffix("|3000000"))
    }

    func testPreviewRecoveryUsesTwoBoundedImmediateRetriesBeforeBackoff() {
        XCTAssertEqual(
            ReliableWindowPreviewRecovery.immediateRetryDelay(afterFailedAttempt: 0),
            0.12
        )
        XCTAssertEqual(
            ReliableWindowPreviewRecovery.immediateRetryDelay(afterFailedAttempt: 1),
            0.45
        )
        XCTAssertNil(ReliableWindowPreviewRecovery.immediateRetryDelay(afterFailedAttempt: 2))
    }

    func testIdentityContinuityIsLongLivedButNeverCrossesWindowOrProcessGeneration() {
        let image = NSImage(size: NSSize(width: 120, height: 90))
        let capturedAt = Date(timeIntervalSince1970: 100)
        let identity = "app-window:77:700|com.example.gpu|launch-1"

        _ = SwitcherPreviewContinuityStore.resolve(
            key: "title-and-frame-v1",
            identityKey: identity,
            preview: image,
            backdrop: image,
            captureAccessAllowed: true,
            now: capturedAt
        )

        let anotherWindow = SwitcherPreviewContinuityStore.resolve(
            key: "title-and-frame-v2",
            identityKey: "app-window:77:701|com.example.gpu|launch-1",
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 105)
        )
        XCTAssertNil(anotherWindow.preview)

        let restartedProcess = SwitcherPreviewContinuityStore.resolve(
            key: "title-and-frame-v2",
            identityKey: "app-window:77:700|com.example.gpu|launch-2",
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 105)
        )
        XCTAssertNil(restartedProcess.preview)

        let stillCurrent = SwitcherPreviewContinuityStore.resolve(
            key: "title-and-frame-v3",
            identityKey: identity,
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 699)
        )
        XCTAssertTrue(stillCurrent.preview === image)

        let expired = SwitcherPreviewContinuityStore.resolve(
            key: "title-and-frame-v4",
            identityKey: identity,
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 701)
        )
        XCTAssertNil(expired.preview)
    }

    func testExactMetadataKeyCannotCrossProcessGeneration() {
        let image = NSImage(size: NSSize(width: 120, height: 90))
        let capturedAt = Date(timeIntervalSince1970: 200)
        let exactKey = "same-pid-window-title-frame"

        _ = SwitcherPreviewContinuityStore.resolve(
            key: exactKey,
            identityKey: "app-window:77:700|com.example.gpu|launch-1",
            preview: image,
            backdrop: image,
            captureAccessAllowed: true,
            now: capturedAt
        )

        let restartedProcess = SwitcherPreviewContinuityStore.resolve(
            key: exactKey,
            identityKey: "app-window:77:700|com.example.gpu|launch-2",
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 205)
        )

        XCTAssertNil(restartedProcess.preview)
        XCTAssertNil(restartedProcess.backdrop)
    }

    func testPermissionDenialRequiresStableFalseSignalAndSuccessfulAccessResetsIt() {
        let start = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: false,
                preflightGranted: false,
                now: start
            )
        )
        XCTAssertTrue(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: false,
                preflightGranted: false,
                now: Date(timeIntervalSince1970: 1_000.5)
            )
        )
        XCTAssertFalse(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: false,
                preflightGranted: false,
                now: Date(timeIntervalSince1970: 1_001.1)
            )
        )
        XCTAssertTrue(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: false,
                preflightGranted: true,
                now: Date(timeIntervalSince1970: 1_001.2)
            )
        )
        XCTAssertTrue(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: false,
                preflightGranted: false,
                now: Date(timeIntervalSince1970: 1_001.3)
            ),
            "A newly granted or successful capture must begin a fresh denial confirmation window."
        )
    }

    func testConfirmedRevocationClearsAllContinuityAndBlocksReuseUntilRegrant() {
        let grantedAt = Date(timeIntervalSince1970: 2_000)
        let firstImage = NSImage(size: NSSize(width: 120, height: 90))
        let secondImage = NSImage(size: NSSize(width: 140, height: 100))
        let firstIdentity = "app-window:77:700|com.example.first|launch-1"
        let secondIdentity = "app-window:88:800|com.example.second|launch-1"

        XCTAssertTrue(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: false,
                preflightGranted: true,
                now: grantedAt
            )
        )
        _ = SwitcherPreviewContinuityStore.resolve(
            key: "first",
            identityKey: firstIdentity,
            preview: firstImage,
            backdrop: firstImage,
            captureAccessAllowed: true,
            now: grantedAt
        )
        _ = SwitcherPreviewContinuityStore.resolve(
            key: "second",
            identityKey: secondIdentity,
            preview: secondImage,
            backdrop: secondImage,
            captureAccessAllowed: true,
            now: grantedAt
        )

        XCTAssertTrue(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: true,
                preflightGranted: false,
                now: Date(timeIntervalSince1970: 2_000.5)
            ),
            "A single false preflight may retain continuity, even if the caller has a cached image."
        )
        XCTAssertFalse(
            SwitcherPreviewPermissionState.allowsNewCapture(preflightGranted: false),
            "Cached content must never authorise new capture work."
        )
        XCTAssertFalse(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: true,
                preflightGranted: false,
                now: Date(timeIntervalSince1970: 2_001.6)
            )
        )

        SwitcherPreviewContinuityStore.clearProtectedContent()
        for (key, identity) in [("first", firstIdentity), ("second", secondIdentity)] {
            let resolved = SwitcherPreviewContinuityStore.resolve(
                key: key,
                identityKey: identity,
                preview: nil,
                backdrop: nil,
                captureAccessAllowed: false,
                now: Date(timeIntervalSince1970: 2_001.7)
            )
            XCTAssertNil(resolved.preview)
            XCTAssertNil(resolved.backdrop)
        }

        XCTAssertTrue(
            SwitcherPreviewPermissionState.effectiveAccess(
                hasCurrentCapture: false,
                preflightGranted: true,
                now: Date(timeIntervalSince1970: 2_001.8)
            )
        )
        XCTAssertTrue(SwitcherPreviewPermissionState.allowsNewCapture(preflightGranted: true))
        let beforeNewCapture = SwitcherPreviewContinuityStore.resolve(
            key: "first",
            identityKey: firstIdentity,
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 2_001.9)
        )
        XCTAssertNil(beforeNewCapture.preview, "Regrant must not resurrect protected content.")

        let freshImage = NSImage(size: NSSize(width: 160, height: 120))
        _ = SwitcherPreviewContinuityStore.resolve(
            key: "first",
            identityKey: firstIdentity,
            preview: freshImage,
            backdrop: freshImage,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 2_002.0)
        )
        let afterNewCapture = SwitcherPreviewContinuityStore.resolve(
            key: "first-updated-title",
            identityKey: firstIdentity,
            preview: nil,
            backdrop: nil,
            captureAccessAllowed: true,
            now: Date(timeIntervalSince1970: 2_002.1)
        )
        XCTAssertTrue(afterNewCapture.preview === freshImage)
    }
}
