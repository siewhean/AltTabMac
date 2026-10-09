import AppKit
import ApplicationServices
import XCTest
@testable import CmdTab

final class MinimizedPreviewRetentionTests: XCTestCase {
    func testOlderCompleteSnapshotCannotEraseOrReplaceNewerIdentity() {
        let generation = Date(timeIntervalSince1970: 1)
        func observe(_ elementPID: pid_t?, at time: TimeInterval, minimized: Bool = true) {
            SwitcherPreviewContinuityStore.observeIdentitySnapshot(
                generations: [101: generation],
                elements: elementPID.map { [101: [7: AXUIElementCreateApplication($0)]] } ?? [:],
                completePIDs: [101], minimizedIDs: minimized ? [101: [7]] : [:],
                observedAtByPID: [101: Date(timeIntervalSince1970: time)])
        }
        observe(101, at: 200)
        _ = resolve(image: NSImage(size: NSSize(width: 120, height: 90)))
        let token = SwitcherPreviewContinuityStore.captureToken(identityKey: "one")
        observe(nil, at: 199)
        observe(102, at: 198, minimized: false)
        XCTAssertTrue(SwitcherPreviewContinuityStore.isCurrentCapture(identityKey: "one", token: token))
        XCTAssertNotNil(resolve(at: start.addingTimeInterval(3600)).preview)
        observe(nil, at: 201)
        XCTAssertFalse(SwitcherPreviewContinuityStore.isCurrentCapture(identityKey: "one", token: token))
        XCTAssertNil(resolve(at: start.addingTimeInterval(3601)).preview)
    }

    func testEnrichedLiveClonePreservesCaptureTimeAndCannotReplaceNewerRecovery() {
        let identity = SwitcherHistoryIdentity.appWindow(pid: ProcessInfo.processInfo.processIdentifier, windowID: 0)
        let capturedAt = Date().addingTimeInterval(-60)
        let original = SwitcherItem(title: "Window", subtitle: "App", icon: nil,
            previewImage: NSImage(size: NSSize(width: 120, height: 90)),
            previewCapturedAt: capturedAt, allowsPreviewRecovery: true,
            previewCacheKey: "original", historyIdentity: identity, activate: {})
        let metadata = snapshot(minimized: false).metadata(ownerPID: 101, windowID: 7)!
        let descriptor = LiveWindowHistoryDescriptor(identity: identity, bundleIdentifier: "fixture", title: "Window")
        let clone = ProductionAppSwitcher.clone(original, metadata: metadata, descriptor: descriptor, activation: {})
        XCTAssertEqual(clone.previewCapturedAt, capturedAt)
        XCTAssertFalse(clone.allowsPreviewRecovery, "The base item already owns any deferred recovery")
        let recovered = NSImage(size: NSSize(width: 150, height: 100))
        let newer = SwitcherItem(title: "Window", subtitle: "App", icon: nil,
            previewImage: recovered, allowsPreviewRecovery: false,
            previewCacheKey: "original", historyIdentity: identity, activate: {})
        let staleClone = ProductionAppSwitcher.clone(original, metadata: metadata, descriptor: descriptor, activation: {})
        XCTAssertEqual(staleClone.previewCapturedAt, newer.previewCapturedAt)
        XCTAssertTrue(staleClone.previewImage === recovered)
        SwitcherPreviewContinuityStore.purge(ownerPID: identity.ownerPID!)
        let closedClone = ProductionAppSwitcher.clone(original, metadata: metadata, descriptor: descriptor, activation: {})
        XCTAssertNil(closedClone.previewImage, "A clone must not restore a purged frame")
        XCTAssertFalse(closedClone.previewCaptureIsFresh)
    }

    private let start = Date(timeIntervalSince1970: 100)
    override func tearDown() {
        SwitcherPreviewContinuityStore.resetForTesting()
        super.tearDown()
    }

    private func snapshot(minimized: Bool = true, elementPID: pid_t = 101,
                          generation: Date = Date(timeIntervalSince1970: 1),
                          present: Bool = true, complete: Bool = true) -> AXWindowCatalogSnapshot {
        let metadata = AXWindowMetadata(ownerPID: 101, windowID: 7, title: "Window",
            role: kAXWindowRole as String, subrole: kAXStandardWindowSubrole as String,
            parentRole: nil, documentURL: nil, frame: nil, isMinimized: minimized,
            isFullscreen: false, isOnScreen: !minimized,
            workspace: .fallback(isOnScreen: !minimized, reason: "fixture"))
        return AXWindowCatalogSnapshot(byPID: present ? [101: [7: metadata]] : [:],
            enumeratedPIDs: complete ? [101] : [], unresolvedIdentityPIDs: [], capability: .available,
            processGenerations: [101: generation],
            elementsByPID: present ? [101: [7: AXUIElementCreateApplication(elementPID)]] : [:])
    }

    private func resolve(_ identity: String = "one", image: NSImage? = nil,
                         at: Date? = nil, allowed: Bool = true) -> SwitcherPreviewContinuityStore.ResolvedImages {
        SwitcherPreviewContinuityStore.resolve(key: "metadata", identityKey: identity, preview: image,
            backdrop: image, captureAccessAllowed: allowed, ownerPID: 101, windowID: 7, now: at ?? start)
    }

    func testVerifiedMinimizedFrameSurvivesLongAbsenceWithOriginalCaptureDateAndNoBackdrop() {
        SwitcherPreviewContinuityStore.observe(snapshot: snapshot(minimized: false))
        _ = resolve(image: NSImage(size: NSSize(width: 120, height: 90)))
        SwitcherPreviewContinuityStore.observe(snapshot: snapshot())
        let retained = resolve(at: start.addingTimeInterval(3600))
        XCTAssertNotNil(retained.preview)
        XCTAssertEqual(retained.capturedAt, start)
        XCTAssertNil(retained.backdrop)
    }

    func testIncompleteEnumerationPreservesButCompleteClosurePurges() {
        SwitcherPreviewContinuityStore.observe(snapshot: snapshot())
        _ = resolve(image: NSImage(size: NSSize(width: 120, height: 90)))
        SwitcherPreviewContinuityStore.observe(snapshot: snapshot(present: false, complete: false))
        XCTAssertNotNil(resolve(at: start.addingTimeInterval(3600)).preview)
        SwitcherPreviewContinuityStore.observe(snapshot: snapshot(present: false))
        XCTAssertNil(resolve(at: start.addingTimeInterval(3601)).preview)
    }

    func testCompleteAXOmissionRetainsExactLiveCandidateUntilWindowDisappears() {
        SwitcherPreviewContinuityStore.observe(snapshot: snapshot(minimized: false))
        _ = resolve(image: NSImage(size: NSSize(width: 120, height: 90)))

        let missingFromAX = snapshot(minimized: false, present: false)
        SwitcherPreviewContinuityStore.observe(
            snapshot: missingFromAX,
            knownLiveWindowIDsByPID: [101: [7]]
        )
        XCTAssertNotNil(resolve(at: start.addingTimeInterval(1)).preview,
                        "A complete AX call can omit a still-live window on another Space")

        SwitcherPreviewContinuityStore.observe(snapshot: missingFromAX)
        XCTAssertNil(resolve(at: start.addingTimeInterval(2)).preview,
                     "Closure must purge the saved frame once neither inventory contains the exact ID")
    }

    func testReplacementAndProcessGenerationPurgeEvenBeforeNormalExpiry() {
        for changed in [snapshot(elementPID: 102), snapshot(generation: Date(timeIntervalSince1970: 2))] {
            SwitcherPreviewContinuityStore.resetForTesting()
            SwitcherPreviewContinuityStore.observe(snapshot: snapshot())
            _ = resolve(image: NSImage(size: NSSize(width: 120, height: 90)))
            SwitcherPreviewContinuityStore.observe(snapshot: changed)
            XCTAssertNil(resolve(at: start.addingTimeInterval(1)).preview)
        }
    }

    func testTerminationAndDenialPurgeRetainedFrames() {
        SwitcherPreviewContinuityStore.observe(snapshot: snapshot())
        _ = resolve(image: NSImage(size: NSSize(width: 120, height: 90)))
        SwitcherPreviewContinuityStore.purge(ownerPID: 101)
        XCTAssertNil(resolve(at: start.addingTimeInterval(1)).preview)
        _ = resolve(image: NSImage(size: NSSize(width: 120, height: 90)))
        _ = resolve("other", allowed: false)
        XCTAssertNil(resolve(at: start.addingTimeInterval(1)).preview)
    }

    func testClosedWindowCannotBeResurrectedByInFlightCapture() {
        SwitcherPreviewContinuityStore.observe(snapshot: snapshot())
        _ = resolve()
        let token = SwitcherPreviewContinuityStore.captureToken(identityKey: "one")
        SwitcherPreviewContinuityStore.observe(snapshot: snapshot(present: false))
        XCTAssertFalse(SwitcherPreviewContinuityStore.isCurrentCapture(identityKey: "one", token: token))
        let late = SwitcherPreviewContinuityStore.resolve(key: "old", identityKey: "one",
            preview: NSImage(size: NSSize(width: 120, height: 90)), backdrop: nil,
            captureAccessAllowed: true, captureToken: token)
        XCTAssertNil(late.preview)
    }

    func testByteBudgetEvictsLeastRecentlyUsedAndDownscalesLargeCapture() throws {
        SwitcherPreviewContinuityStore.resetForTesting(byteBudget: 2 * 100 * 100 * 4)
        let context = try XCTUnwrap(CGContext(data: nil, width: 100, height: 100,
            bitsPerComponent: 8, bytesPerRow: 400, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = NSImage(cgImage: try XCTUnwrap(context.makeImage()), size: NSSize(width: 100, height: 100))
        _ = resolve("one", image: image)
        _ = resolve("two", image: image)
        _ = resolve("one")
        _ = resolve("three", image: image)
        XCTAssertNil(resolve("two").preview)
        XCTAssertNotNil(resolve("one").preview)
        SwitcherPreviewContinuityStore.resetForTesting()
        let large = try XCTUnwrap(CGContext(data: nil, width: 2400, height: 1600,
            bitsPerComponent: 8, bytesPerRow: 9600, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let result = resolve(image: NSImage(cgImage: try XCTUnwrap(large.makeImage()),
                                           size: NSSize(width: 2400, height: 1600)))
        XCTAssertEqual(result.preview?.size, NSSize(width: 900, height: 600))
        XCTAssertNil(result.backdrop)
    }
}
