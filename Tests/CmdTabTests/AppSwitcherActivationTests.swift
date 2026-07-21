import XCTest
import AppKit
@testable import CmdTab

/// Tests for SwitcherHistoryStore and the activation/ordering logic that
/// ensures subsequent app switches work correctly and windows are ordered in
/// true MRU order rather than grouped by application.
final class AppSwitcherActivationTests: XCTestCase {
    func testBoundedCaptureGateReturnsSuccessfulResult() {
        let gate = BoundedCaptureGate<Int>(label: "CmdTabTests.BoundedCapture.Success")

        XCTAssertEqual(gate.run(timeout: 0.1) { 42 }, 42)
    }

    func testBoundedCaptureGateSkipsConcurrentAttemptAfterTimeout() {
        let gate = BoundedCaptureGate<Int>(label: "CmdTabTests.BoundedCapture.Timeout")
        let release = DispatchSemaphore(value: 0)
        let startedAt = CFAbsoluteTimeGetCurrent()

        XCTAssertNil(gate.run(timeout: 0.02) {
            _ = release.wait(timeout: .now() + 0.5)
            return 1
        })
        XCTAssertLessThan(CFAbsoluteTimeGetCurrent() - startedAt, 0.15)

        let secondInvocationRan = LockedCaptureResult<Bool>()
        XCTAssertNil(gate.run(timeout: 0.02) {
            secondInvocationRan.store(true)
            return 2
        })
        XCTAssertNil(secondInvocationRan.load())

        release.signal()
        let completionDeadline = Date().addingTimeInterval(0.2)
        while Date() < completionDeadline {
            if gate.run(timeout: 0.02, operation: { 3 }) == 3 { return }
            Thread.sleep(forTimeInterval: 0.005)
        }
        XCTFail("Gate did not close after the timed-out operation completed")
    }

    func testSwitcherItemUsesApplicationNameForDisplay() {
        let item = SwitcherItem(
            title: "Document 1",
            subtitle: "Preview",
            icon: nil,
            previewImage: nil,
            historyIdentity: .appFallback(bundleID: "com.apple.Preview", pid: nil),
            activate: {}
        )

        XCTAssertEqual(item.displayAppName, "Preview")
    }

    func testSwitcherItemFallsBackToWindowTitleWhenApplicationNameIsMissing() {
        let item = SwitcherItem(
            title: "Document 1",
            subtitle: "  ",
            icon: nil,
            previewImage: nil,
            historyIdentity: .appFallback(bundleID: "com.example.app", pid: nil),
            activate: {}
        )

        XCTAssertEqual(item.displayAppName, "Document 1")
    }

    // MARK: - SwitcherHistoryStore deduplication

    func testNoteActivationSameIdentityTwiceKeepsItAtRankZero() {
        let store = SwitcherHistoryStore()
        let identity = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        store.noteActivation(identity)
        store.noteActivation(identity)

        XCTAssertEqual(store.rank(of: identity), 0)
        XCTAssertEqual(store.snapshot().count, 1, "Duplicate entries must be deduplicated")
    }

    func testNoteActivationMovesPreviousEntryToFront() {
        let store = SwitcherHistoryStore()
        let finder = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let arc    = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)

        store.noteActivation(finder)
        store.noteActivation(arc)
        XCTAssertEqual(store.rank(of: arc),    0)
        XCTAssertEqual(store.rank(of: finder), 1)

        // Re-activate finder → it moves to rank 0
        store.noteActivation(finder)
        XCTAssertEqual(store.rank(of: finder), 0)
        XCTAssertEqual(store.rank(of: arc),    1)
    }

    // MARK: - Finder → Arc → Finder scenario

    /// Using Finder, then Arc, then Finder again (same window) should result in
    /// history [Finder (rank 0), Arc (rank 1)] — no duplicate entries.
    func testFinderArcFinderHistoryHasNoDuplicates() {
        let store = SwitcherHistoryStore()
        let finder = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let arc    = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)

        store.noteActivation(finder)  // Finder
        store.noteActivation(arc)     // Arc
        store.noteActivation(finder)  // Finder again

        XCTAssertEqual(store.snapshot().count, 2)
        XCTAssertEqual(store.rank(of: finder), 0)
        XCTAssertEqual(store.rank(of: arc),    1)
    }

    /// When the switcher presents items after the Finder→Arc→Finder pattern,
    /// the first item in the ordered list should be Arc (the app to switch TO),
    /// not Finder again.
    func testFinderArcFinderOrderingSelectsArcFirst() {
        let store  = SwitcherHistoryStore()
        let finder = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let arc    = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)

        store.noteActivation(finder)
        store.noteActivation(arc)
        store.noteActivation(finder)  // Back to Finder

        let items = [
            makeItem(title: "Finder", identity: finder),
            makeItem(title: "Arc",    identity: arc),
        ]

        let ordered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: finder)
        // Finder (frontmost) moved to end; first item = Arc
        XCTAssertEqual(ordered.map(\.title), ["Arc", "Finder"])
    }

    // MARK: - Eager history note (quick re-press scenario)

    /// Simulates the user pressing Cmd+Tab twice quickly.
    /// After the first commit (which eagerly notes Arc in history),
    /// the second session should see Arc as the frontmost and offer Finder first.
    func testQuickRePressAfterEagerHistoryNoteOffersCorrectApp() {
        let store  = SwitcherHistoryStore()
        let finder = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let arc    = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)
        let safari = SwitcherHistoryIdentity.appWindow(pid: 303, windowID: 3)

        // Initial state: Finder is frontmost, history = [Finder, Arc, Safari]
        store.noteActivation(safari)
        store.noteActivation(arc)
        store.noteActivation(finder)

        // First Cmd+Tab: items ordered with Finder at end → Arc selected
        let firstItems = [
            makeItem(title: "Finder", identity: finder),
            makeItem(title: "Arc",    identity: arc),
            makeItem(title: "Safari", identity: safari),
        ]
        let firstOrdered = SwitcherOrdering.orderedItems(firstItems, history: store, currentFrontmost: finder)
        XCTAssertEqual(firstOrdered.first?.title, "Arc")

        // Eager history note: record Arc BEFORE the async activation fires
        store.noteActivation(arc)
        // History is now: [Arc, Finder, Safari]

        // Second Cmd+Tab arrives before Arc fully activates.
        // frontmostApplication might still report Finder, but after eager note
        // the ordering sees Arc at rank 0 → moved to end → Finder offered first.
        let secondItems = firstItems  // same item list, fresh ordering
        let secondOrdered = SwitcherOrdering.orderedItems(secondItems, history: store, currentFrontmost: arc)
        XCTAssertEqual(secondOrdered.first?.title, "Finder")
    }

    // MARK: - Double-noting suppression logic

    /// Simulates what happens WITHOUT suppression: appActivated fires and notes
    /// Finder W2 (wrong window), overriding Finder W1 that activateWindow noted.
    /// This test documents the BUGGY behaviour so the pendingActivationPID fix
    /// can be verified by the absence of this sequence.
    func testWithoutSuppressionWrongWindowGetsGrouped() {
        let store    = SwitcherHistoryStore()
        let finderW1 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let finderW2 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 2)
        let arc      = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 3)

        // Simulate activateWindow noting Finder W1
        store.noteActivation(finderW1)
        // Simulate appActivated (without suppression) noting Finder W2
        store.noteActivation(finderW2)
        // Arc was previously at rank 2
        store.noteActivation(arc)

        // Without suppression, both Finder windows have recent ranks
        // (finderW2=1, finderW1=2) while arc was noted before them
        store.noteActivation(finderW1)  // redo the sequence properly
        store.noteActivation(finderW2)  // appActivated overrides

        // Both Finder windows end up with ranks 0 and 1, Arc at rank 2
        XCTAssertNotNil(store.rank(of: finderW1))
        XCTAssertNotNil(store.rank(of: finderW2))
        let arcRank = store.rank(of: arc) ?? Int.max
        let finderW1Rank = store.rank(of: finderW1) ?? Int.max
        let finderW2Rank = store.rank(of: finderW2) ?? Int.max
        // Arc has a higher (worse) rank than both Finder windows → they'd appear grouped before Arc
        XCTAssertTrue(arcRank > finderW1Rank || arcRank > finderW2Rank,
                      "Without suppression, both Finder windows rank higher than Arc — the grouping bug")
    }

    /// Simulates correct behaviour WITH suppression: appActivated does NOT
    /// override the history. Only activateWindow's specific window note survives.
    func testWithSuppressionOnlyCorrectWindowNoted() {
        let store    = SwitcherHistoryStore()
        let arc      = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 3)
        let finderW1 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let finderW2 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 2)

        // Setup: Arc was used most recently, then Finder W2 less recently
        store.noteActivation(finderW2)
        store.noteActivation(arc)

        // activateWindow selects Finder W1 and notes it
        store.noteActivation(finderW1)
        // appActivated is SUPPRESSED (pendingActivationPID match) → no extra note

        // History should be [Finder W1, Arc, Finder W2] — W1 at rank 0, W2 at rank 2
        XCTAssertEqual(store.rank(of: finderW1), 0)
        XCTAssertEqual(store.rank(of: arc),      1)
        XCTAssertEqual(store.rank(of: finderW2), 2)

        // Now when showing the switcher with Finder W1 as frontmost,
        // the order should interleave: Arc, Finder W2, Finder W1(at end)
        let items = [
            makeItem(title: "Finder W1", identity: finderW1),
            makeItem(title: "Arc",       identity: arc),
            makeItem(title: "Finder W2", identity: finderW2),
        ]
        let ordered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: finderW1)
        XCTAssertEqual(ordered.map(\.title), ["Arc", "Finder W2", "Finder W1"])
    }

    // MARK: - Multiple scenarios

    /// Three distinct apps used in sequence: A, B, C.
    /// From C, switcher should offer B first, then A.
    func testThreeDistinctAppsInSequenceOffersCorrectOrder() {
        let store = SwitcherHistoryStore()
        let appA  = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let appB  = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)
        let appC  = SwitcherHistoryIdentity.appWindow(pid: 303, windowID: 3)

        store.noteActivation(appA)
        store.noteActivation(appB)
        store.noteActivation(appC)

        let items = [
            makeItem(title: "A", identity: appA),
            makeItem(title: "B", identity: appB),
            makeItem(title: "C", identity: appC),
        ]
        let ordered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: appC)
        XCTAssertEqual(ordered.map(\.title), ["B", "A", "C"])
    }

    /// Single app only — switcher should have no other options.
    func testSingleAppResultsInOneItem() {
        let store   = SwitcherHistoryStore()
        let finder  = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        store.noteActivation(finder)

        let items   = [makeItem(title: "Finder", identity: finder)]
        let ordered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: finder)
        XCTAssertEqual(ordered.count, 1)
        // Finder is both frontmost AND only item — still present (moved to end = stays)
        XCTAssertEqual(ordered.first?.title, "Finder")
    }

    func testTrimmedWindowCaptureRemovesTransparentBorder() {
        let cgImage = makeCGImage(width: 6, height: 6) { x, y in
            let isBorder = x == 0 || y == 0 || x == 5 || y == 5
            return isBorder ? (255, 255, 255, 0) : (12, 12, 12, 255)
        }

        let trimmed = AppSwitcher.trimmedWindowCapture(cgImage, alphaThreshold: 20, maxInset: 4)
        XCTAssertEqual(trimmed.width, 4)
        XCTAssertEqual(trimmed.height, 4)
    }

    func testPresentationSafeWindowCaptureCropsTopAndSideFringe() {
        let cgImage = makeCGImage(width: 1000, height: 700) { _, _ in
            (32, 32, 32, 255)
        }

        let prepared = AppSwitcher.presentationSafeWindowCapture(cgImage)
        XCTAssertLessThan(prepared.width, cgImage.width)
        XCTAssertLessThan(prepared.height, cgImage.height)
        XCTAssertEqual(prepared.width, 996)
        XCTAssertEqual(prepared.height, 697)
    }

    func testFallbackAppsAreDroppedWhenWindowsAlreadyRepresentThatApp() {
        var seen = Set<String>()

        XCTAssertFalse(
            AppSwitcher.shouldIncludeFallbackApp(
                processIdentifier: 101,
                sourceAppIdentifier: "com.apple.finder",
                representedWindowPIDs: [101],
                representedWindowAppIdentifiers: ["com.apple.finder"],
                seenFallbackAppIdentifiers: &seen
            )
        )
    }

    func testFallbackAppsAreDisabledEvenWithoutRepresentedWindows() {
        var seen = Set<String>()

        XCTAssertFalse(
            AppSwitcher.shouldIncludeFallbackApp(
                processIdentifier: 101,
                sourceAppIdentifier: "com.apple.finder",
                representedWindowPIDs: [],
                representedWindowAppIdentifiers: [],
                seenFallbackAppIdentifiers: &seen
            )
        )
    }

    func testPreviewlessWindowTilesRemainWhenFallbackPresentationIsAllowed() {
        XCTAssertFalse(AppSwitcher.shouldDisplayWindowItem(previewImage: nil, capturePreviews: true))
        XCTAssertTrue(AppSwitcher.shouldDisplayWindowItem(previewImage: NSImage(size: NSSize(width: 10, height: 10)), capturePreviews: true))
        XCTAssertFalse(AppSwitcher.shouldDisplayWindowItem(previewImage: nil, capturePreviews: false))
        XCTAssertTrue(AppSwitcher.shouldDisplayWindowItem(previewImage: nil, capturePreviews: false, allowPreviewlessItems: true))
        XCTAssertTrue(AppSwitcher.shouldDisplayWindowItem(previewImage: nil, capturePreviews: true, allowPreviewlessItems: true))
    }

    func testPresentationUsefulWindowCaptureRejectsSolidBlackImage() {
        let image = makeCGImage(width: 120, height: 80) { _, _ in
            (0, 0, 0, 255)
        }

        XCTAssertFalse(AppSwitcher.isPresentationUsefulWindowCapture(image))
        XCTAssertNotNil(
            AppSwitcher.preparedSupportedWindowCapture(image),
            "A successful supported capture may legitimately contain a black window"
        )
    }

    func testSupportedWindowCaptureRejectsTransparentOutput() {
        let image = makeCGImage(width: 120, height: 80) { _, _ in
            (0, 0, 0, 0)
        }

        XCTAssertNil(AppSwitcher.preparedSupportedWindowCapture(image))
    }

    func testPresentationUsefulWindowCaptureKeepsDarkImageWithVisibleContent() {
        let image = makeCGImage(width: 120, height: 80) { x, y in
            if x > 20 && x < 100 && y > 20 && y < 60 {
                return (80, 80, 80, 255)
            }
            return (8, 8, 8, 255)
        }

        XCTAssertTrue(AppSwitcher.isPresentationUsefulWindowCapture(image))
    }

    func testPresentationUsefulWindowCaptureHandlesWindowServerByteOrder() {
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        let context = CGContext(
            data: nil,
            width: 120,
            height: 80,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        )!
        context.setFillColor(CGColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
        context.setFillColor(CGColor(red: 0.18, green: 0.72, blue: 0.46, alpha: 1))
        context.fill(CGRect(x: 60, y: 0, width: 60, height: 80))

        let image = context.makeImage()!
        XCTAssertTrue(AppSwitcher.isPresentationUsefulWindowCapture(image))

        let trimmed = AppSwitcher.trimmedWindowCapture(image)
        XCTAssertEqual(trimmed.width, image.width)
        XCTAssertEqual(trimmed.height, image.height)
    }

    func testDeduplicateCandidateProbesCollapsesDuplicateEntriesForSameWindowID() {
        let duplicateOffscreen = WindowCandidateDeduplicationProbe(
            ownerPID: 101,
            windowID: 77,
            title: "ChatGPT",
            hasExplicitTitle: true,
            bounds: CGRect(x: 10, y: 10, width: 900, height: 600),
            orderIndex: 8,
            sortScore: 120,
            isOnScreen: false
        )
        let preferredOnscreen = WindowCandidateDeduplicationProbe(
            ownerPID: 101,
            windowID: 77,
            title: "ChatGPT",
            hasExplicitTitle: true,
            bounds: CGRect(x: 10, y: 10, width: 1280, height: 820),
            orderIndex: 2,
            sortScore: 420,
            isOnScreen: true
        )

        let deduplicated = AppSwitcher.deduplicateCandidateProbes([duplicateOffscreen, preferredOnscreen])

        XCTAssertEqual(deduplicated.count, 1)
        XCTAssertEqual(deduplicated.first, preferredOnscreen)
    }

    func testDeduplicateCandidateProbesPreservesDistinctWindowIDs() {
        let first = WindowCandidateDeduplicationProbe(
            ownerPID: 101,
            windowID: 77,
            title: "ChatGPT",
            hasExplicitTitle: true,
            bounds: CGRect(x: 10, y: 10, width: 1280, height: 820),
            orderIndex: 2,
            sortScore: 420,
            isOnScreen: true
        )
        let second = WindowCandidateDeduplicationProbe(
            ownerPID: 101,
            windowID: 78,
            title: "ChatGPT",
            hasExplicitTitle: true,
            bounds: CGRect(x: 60, y: 40, width: 1280, height: 820),
            orderIndex: 3,
            sortScore: 415,
            isOnScreen: true
        )

        let deduplicated = AppSwitcher.deduplicateCandidateProbes([first, second])

        XCTAssertEqual(deduplicated, [first, second])
    }

    func testDistinctWindowIDsSurviveIdenticalSameAppTitleAndFrame() {
        let firstWindow = WindowCandidateDeduplicationProbe(
            ownerPID: 101,
            windowID: 77,
            title: "Arc",
            hasExplicitTitle: false,
            bounds: CGRect(x: 1496, y: 300, width: 749, height: 938),
            orderIndex: 2,
            sortScore: 410,
            isOnScreen: true
        )
        let largerWindow = WindowCandidateDeduplicationProbe(
            ownerPID: 101,
            windowID: 78,
            title: "Arc",
            hasExplicitTitle: false,
            bounds: CGRect(x: 1496, y: 300, width: 749, height: 938),
            orderIndex: 4,
            sortScore: 405,
            isOnScreen: true
        )

        let deduplicated = AppSwitcher.deduplicateCandidateProbes([firstWindow, largerWindow])

        XCTAssertEqual(deduplicated, [firstWindow, largerWindow])
    }

    func testDistinctWindowIDsSurviveOverlappingSameAppSurfaces() {
        let first = WindowCandidateDeduplicationProbe(
            ownerPID: 101,
            windowID: 77,
            title: "ChatGPT",
            hasExplicitTitle: true,
            bounds: CGRect(x: 10, y: 10, width: 1280, height: 820),
            orderIndex: 2,
            sortScore: 420,
            isOnScreen: true
        )
        let second = WindowCandidateDeduplicationProbe(
            ownerPID: 101,
            windowID: 78,
            title: "ChatGPT",
            hasExplicitTitle: true,
            bounds: CGRect(x: 420, y: 140, width: 1280, height: 820),
            orderIndex: 3,
            sortScore: 415,
            isOnScreen: true
        )

        let deduplicated = AppSwitcher.deduplicateCandidateProbes([first, second])

        XCTAssertEqual(deduplicated, [first, second])
    }

    /// Empty items list returns empty.
    func testEmptyItemsReturnsEmpty() {
        let store   = SwitcherHistoryStore()
        let ordered = SwitcherOrdering.orderedItems([], history: store, currentFrontmost: nil)
        XCTAssertTrue(ordered.isEmpty)
    }

    // MARK: - Repeated Cmd+Tab simulation (the core bug)

    /// Simulates 3 consecutive Cmd+Tab presses: each time, the previously
    /// activated app must be treated as the frontmost (even before the OS
    /// reports it). Without lastCommittedIdentity, the second and third
    /// presses would land on the same app again.
    func testThreeConsecutiveSwitchesAlternateCorrectly() {
        let store  = SwitcherHistoryStore()
        let finder = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let arc    = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)
        let safari = SwitcherHistoryIdentity.appWindow(pid: 303, windowID: 3)

        // Setup: user was in Safari → Arc → Finder
        store.noteActivation(safari)
        store.noteActivation(arc)
        store.noteActivation(finder)

        let items = [
            makeItem(title: "Finder", identity: finder),
            makeItem(title: "Arc",    identity: arc),
            makeItem(title: "Safari", identity: safari),
        ]

        // 1st Cmd+Tab: frontmost=Finder → moved to end → [Arc, Safari, Finder]
        let firstOrdered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: finder)
        XCTAssertEqual(firstOrdered.first?.title, "Arc", "First switch should offer Arc")

        // Simulate eager history note from commitCurrentSelection:
        store.noteActivation(arc)
        // lastCommittedIdentity would be `arc`

        // 2nd Cmd+Tab: frontmost=Arc (from lastCommittedIdentity) → moved to end
        let secondOrdered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: arc)
        XCTAssertEqual(secondOrdered.first?.title, "Finder", "Second switch should offer Finder")

        // Simulate eager history note:
        store.noteActivation(finder)

        // 3rd Cmd+Tab: frontmost=Finder → moved to end
        let thirdOrdered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: finder)
        XCTAssertEqual(thirdOrdered.first?.title, "Arc", "Third switch should offer Arc again")
    }

    /// Simulates the exact scenario from the bug report: after one successful
    /// switch, the second switch should NOT land on the same app.
    func testSecondSwitchNeverLandsOnSameApp() {
        let store = SwitcherHistoryStore()
        let currentApp = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let otherApp   = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)

        store.noteActivation(otherApp)
        store.noteActivation(currentApp)

        let items = [
            makeItem(title: "Current", identity: currentApp),
            makeItem(title: "Other",   identity: otherApp),
        ]

        // First switch: from Current → should land on Other
        let first = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: currentApp)
        XCTAssertEqual(first.first?.title, "Other")

        // Simulate: eager history note for Other, then use Other as lastCommittedIdentity
        store.noteActivation(otherApp)

        // Second switch: from Other (lastCommittedIdentity) → should land on Current, NOT Other
        let second = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: otherApp)
        XCTAssertEqual(second.first?.title, "Current", "Second switch must NOT land on the same app")
    }

    /// The current window (frontmost) should NEVER appear at index 0.
    /// It must always be moved to the end of the list.
    func testFrontmostIsNeverAtIndexZero() {
        let store = SwitcherHistoryStore()
        let a = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let b = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 2)
        let c = SwitcherHistoryIdentity.appWindow(pid: 303, windowID: 3)

        store.noteActivation(a)
        store.noteActivation(b)
        store.noteActivation(c)

        let items = [
            makeItem(title: "A", identity: a),
            makeItem(title: "B", identity: b),
            makeItem(title: "C", identity: c),
        ]

        // For each possible frontmost, it should never be at index 0
        for frontmost in [a, b, c] {
            let ordered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: frontmost)
            XCTAssertNotEqual(ordered.first?.historyIdentity, frontmost,
                              "Frontmost app must never be at index 0")
            XCTAssertEqual(ordered.last?.historyIdentity, frontmost,
                           "Frontmost app must be at the end of the list")
        }
    }

    // MARK: - ownerPID property tests

    func testOwnerPIDReturnsCorrectValueForAppWindow() {
        let identity = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        XCTAssertEqual(identity.ownerPID, 101)
    }

    func testOwnerPIDReturnsCorrectValueForAppFallback() {
        let identity = SwitcherHistoryIdentity.appFallback(bundleID: "com.apple.finder", pid: 101)
        XCTAssertEqual(identity.ownerPID, 101)
    }

    // MARK: - PID-based frontmost detection tests

    /// When the committed identity's window ID changes across cache rebuilds,
    /// PID-based matching still correctly identifies the frontmost app.
    func testPIDBasedMatchingWorksAcrossWindowIDChanges() {
        let store = SwitcherHistoryStore()
        // Simulate: user activated Arc window 22, then Finder window 11
        let arcOldWindow  = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 22)
        let finderWindow  = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 11)
        store.noteActivation(arcOldWindow)
        store.noteActivation(finderWindow)

        // Cache rebuilds: Arc's window ID changed from 22 to 99
        let arcNewWindow = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 99)
        let items = [
            makeItem(title: "Finder", identity: finderWindow),
            makeItem(title: "Arc",    identity: arcNewWindow),
        ]

        // Even though finderWindow (pid 101) is the frontmost PID,
        // orderedItems should move Finder to end → Arc at index 0
        let ordered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: finderWindow)
        XCTAssertEqual(ordered.first?.title, "Arc",
                       "PID-based matching should work even when window IDs change")
        XCTAssertEqual(ordered.last?.title, "Finder",
                       "Frontmost should be at the end")
    }

    func testPreviewCacheKeyStaysStableForSameWindowIdentity() {
        let firstKey = AppSwitcher.previewCacheKey(
            ownerPID: 404,
            windowID: 77
        )
        let secondKey = AppSwitcher.previewCacheKey(
            ownerPID: 404,
            windowID: 77
        )

        XCTAssertEqual(firstKey, secondKey)
    }

    func testPreviewCacheKeyDiffersForDifferentWindowIdentities() {
        let firstKey = AppSwitcher.previewCacheKey(
            ownerPID: 404,
            windowID: 77
        )
        let secondKey = AppSwitcher.previewCacheKey(
            ownerPID: 404,
            windowID: 78
        )

        XCTAssertNotEqual(firstKey, secondKey)
    }

    func testPhaseTwoReusesStaleCachedPreviewAfterCaptureFailure() {
        let image = NSImage(size: NSSize(width: 320, height: 180))
        let capturedAt = Date(timeIntervalSince1970: 1_000)
        let entry = AppSwitcher.PreviewCacheEntry(
            image: image,
            backdropImage: nil,
            capturedAt: capturedAt,
            lastAccessAt: capturedAt,
            byteCost: 320 * 180 * 4
        )

        let fallback = AppSwitcher.reusablePhaseTwoFallback(from: entry)

        XCTAssertTrue(fallback === image, "A stale preview remains usable until normal cache eviction")
    }

    func testReusedStalePreviewDoesNotResetCaptureTimestamp() {
        let image = NSImage(size: NSSize(width: 320, height: 180))
        let capturedAt = Date(timeIntervalSince1970: 1_000)
        let existing = AppSwitcher.PreviewCacheEntry(
            image: image,
            backdropImage: nil,
            capturedAt: capturedAt,
            lastAccessAt: capturedAt,
            byteCost: 320 * 180 * 4
        )
        let accessedAt = Date(timeIntervalSince1970: 10_000)

        let updated = AppSwitcher.updatedPreviewCacheEntry(
            existing: existing,
            image: image,
            backdropImage: nil,
            now: accessedAt,
            byteCost: existing.byteCost
        )

        XCTAssertEqual(updated.capturedAt, capturedAt)
        XCTAssertEqual(updated.lastAccessAt, accessedAt)
    }

    func testPreviewCacheTrimEvictsHardExpiredThenLeastRecentlyUsedEntries() {
        let now = Date(timeIntervalSince1970: 10_000)
        let image = NSImage(size: NSSize(width: 10, height: 10))
        let entries = [
            "hard-expired": AppSwitcher.PreviewCacheEntry(
                image: image,
                backdropImage: nil,
                capturedAt: now.addingTimeInterval(-181),
                lastAccessAt: now.addingTimeInterval(-1),
                byteCost: 40
            ),
            "least-recent": AppSwitcher.PreviewCacheEntry(
                image: image,
                backdropImage: nil,
                capturedAt: now.addingTimeInterval(-10),
                lastAccessAt: now.addingTimeInterval(-9),
                byteCost: 40
            ),
            "most-recent": AppSwitcher.PreviewCacheEntry(
                image: image,
                backdropImage: nil,
                capturedAt: now.addingTimeInterval(-10),
                lastAccessAt: now.addingTimeInterval(-0.5),
                byteCost: 40
            ),
        ]

        let evictionKeys = AppSwitcher.previewCacheEvictionKeys(
            entries: entries,
            totalBytes: 120,
            maxBytes: 40,
            now: now,
            hardTTL: 180
        )

        XCTAssertEqual(evictionKeys, ["hard-expired", "least-recent"])
    }

    func testAllowedWindowIDDefaultsToTrueWhenNoPolicyExists() {
        XCTAssertTrue(AppSwitcher.isAllowedWindowID(77, policy: nil))
    }

    func testAllowedWindowIDRejectsNonDisplayWindowIDs() {
        XCTAssertTrue(AppSwitcher.isAllowedWindowID(77, policy: .restricted([77, 88])))
        XCTAssertFalse(AppSwitcher.isAllowedWindowID(99, policy: .restricted([77, 88])))
    }

    func testAllowedWindowPolicyPreservesDisplayWindowsAndIncludesPreferredWindow() {
        let resolved = AppSwitcher.allowedWindowPolicy(
            displayWindowIDs: [11, 22],
            preferredWindowIDs: [33]
        )

        XCTAssertEqual(resolved, .restricted([11, 22, 33]))
    }

    func testAllowedWindowPolicyFallsBackToPreferredWindowWhenDisplayFilterIsEmpty() {
        let resolved = AppSwitcher.allowedWindowPolicy(
            displayWindowIDs: [],
            preferredWindowIDs: [77]
        )

        XCTAssertEqual(resolved, .restricted([77]))
    }

    func testAllowedWindowPolicyRejectsAllWindowsWhenNoTrustedIDsExist() {
        XCTAssertEqual(
            AppSwitcher.allowedWindowPolicy(
                displayWindowIDs: [],
                preferredWindowIDs: []
            ),
            .noneTrusted
        )
    }

    func testAllowedWindowPolicyFallsBackWhenEligibleAXWindowsCannotResolveIDs() {
        XCTAssertEqual(
            AppSwitcher.allowedWindowPolicy(
                displayWindowIDs: [],
                preferredWindowIDs: [],
                hasEligibleAXWindows: true
            ),
            .fallbackHeuristics
        )
        XCTAssertTrue(AppSwitcher.isAllowedWindowID(77, policy: .fallbackHeuristics))
    }

    func testAllowedWindowPolicyFallsBackWhenAXWindowQueryFails() {
        XCTAssertEqual(
            AppSwitcher.allowedWindowPolicy(
                displayWindowIDs: [],
                preferredWindowIDs: [],
                axWindowQuerySucceeded: false
            ),
            .fallbackHeuristics
        )
    }

    func testAllUntrustedPoliciesUsePerApplicationHeuristicFallback() {
        let resolved = AppSwitcher.policiesWithPerApplicationFallback([
            101: .noneTrusted,
            202: .noneTrusted,
        ])

        XCTAssertEqual(resolved[101], .fallbackHeuristics)
        XCTAssertEqual(resolved[202], .fallbackHeuristics)
    }

    func testPerApplicationFallbackPreservesExactPolicyAndRecoversUntrustedApp() {
        let original: [pid_t: AppSwitcher.AllowedWindowPolicy] = [
            101: .restricted([77]),
            202: .noneTrusted,
        ]

        let resolved = AppSwitcher.policiesWithPerApplicationFallback(original)

        XCTAssertEqual(resolved[101], .restricted([77]))
        XCTAssertEqual(resolved[202], .fallbackHeuristics)
    }

    func testTransientEmptyEnumerationPreservesWarmItemsForBoundedRetries() {
        XCTAssertTrue(AppSwitcher.shouldPreserveCachedItems(
            cachedItemCount: 4,
            enumeratedCandidateCount: 0,
            consecutiveEmptyEnumerations: 0,
            maximumRetries: 2
        ))
        XCTAssertTrue(AppSwitcher.shouldPreserveCachedItems(
            cachedItemCount: 4,
            enumeratedCandidateCount: 0,
            consecutiveEmptyEnumerations: 1,
            maximumRetries: 2
        ))
        XCTAssertFalse(AppSwitcher.shouldPreserveCachedItems(
            cachedItemCount: 4,
            enumeratedCandidateCount: 0,
            consecutiveEmptyEnumerations: 2,
            maximumRetries: 2
        ))
    }

    func testEmptyEnumerationDoesNotPreserveWithoutWarmItemsOrWhenCandidatesExist() {
        XCTAssertFalse(AppSwitcher.shouldPreserveCachedItems(
            cachedItemCount: 0,
            enumeratedCandidateCount: 0,
            consecutiveEmptyEnumerations: 0,
            maximumRetries: 2
        ))
        XCTAssertFalse(AppSwitcher.shouldPreserveCachedItems(
            cachedItemCount: 4,
            enumeratedCandidateCount: 1,
            consecutiveEmptyEnumerations: 0,
            maximumRetries: 2
        ))
    }

    func testUnsharedWindowsAreOnlyAllowedForPermissionDeniedSkeletons() {
        XCTAssertFalse(AppSwitcher.shouldAllowWindowSharingState(
            0,
            allowUnsharedWindows: false
        ))
        XCTAssertTrue(AppSwitcher.shouldAllowWindowSharingState(
            0,
            allowUnsharedWindows: true
        ))
        XCTAssertTrue(AppSwitcher.shouldAllowWindowSharingState(
            1,
            allowUnsharedWindows: false
        ))
    }

    func testAllowedWindowIDRejectsAllWindowsWhenPolicyIsNoneTrusted() {
        XCTAssertFalse(AppSwitcher.isAllowedWindowID(77, policy: .noneTrusted))
    }

    func testSwitcherDisplaySubroleRejectsFloatingPanels() {
        XCTAssertTrue(AppSwitcher.isSwitcherDisplaySubrole(kAXStandardWindowSubrole as String))
        XCTAssertTrue(AppSwitcher.isSwitcherDisplaySubrole("AXFullScreenWindow"))
        XCTAssertFalse(AppSwitcher.isSwitcherDisplaySubrole(kAXFloatingWindowSubrole as String))
    }

    func testShouldAllowAXWindowRejectsMissingSubroleForSwitcherDisplay() {
        XCTAssertFalse(
            AppSwitcher.shouldAllowAXWindow(
                role: kAXWindowRole as String,
                subrole: nil,
                parentRole: nil,
                isMinimized: false
            )
        )
    }

    func testShouldAllowAXWindowRejectsChildWindows() {
        XCTAssertFalse(
            AppSwitcher.shouldAllowAXWindow(
                role: kAXWindowRole as String,
                subrole: kAXStandardWindowSubrole as String,
                parentRole: kAXWindowRole as String,
                isMinimized: false
            )
        )
    }

    func testShouldAllowAXWindowRejectsMinimizedWindowsInVisibleSpacesScope() {
        XCTAssertFalse(
            AppSwitcher.shouldAllowAXWindow(
                role: kAXWindowRole as String,
                subrole: kAXStandardWindowSubrole as String,
                parentRole: nil,
                isMinimized: true
            )
        )
    }

    func testShouldAllowAXWindowIncludesMinimizedStandardWindowsInAllSpacesScope() {
        XCTAssertTrue(
            AppSwitcher.shouldAllowAXWindow(
                role: kAXWindowRole as String,
                subrole: kAXStandardWindowSubrole as String,
                parentRole: nil,
                isMinimized: true,
                allowMinimizedStandardWindow: true
            )
        )
        XCTAssertFalse(
            AppSwitcher.shouldAllowAXWindow(
                role: kAXWindowRole as String,
                subrole: kAXFloatingWindowSubrole as String,
                parentRole: nil,
                isMinimized: true,
                allowMinimizedStandardWindow: true
            )
        )
    }

    /// With multiple windows for the same app, the most recently used window
    /// of the frontmost app should be used as the currentFrontmost identity.
    func testMultipleWindowsSameAppUsesCorrectFrontmostWindow() {
        let store = SwitcherHistoryStore()
        let finderW1 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 1)
        let finderW2 = SwitcherHistoryIdentity.appWindow(pid: 101, windowID: 2)
        let arc      = SwitcherHistoryIdentity.appWindow(pid: 202, windowID: 3)

        // History: finderW1 most recent, then arc, then finderW2
        store.noteActivation(finderW2)
        store.noteActivation(arc)
        store.noteActivation(finderW1)

        let items = [
            makeItem(title: "Finder W1", identity: finderW1),
            makeItem(title: "Arc",       identity: arc),
            makeItem(title: "Finder W2", identity: finderW2),
        ]

        // Frontmost PID = 101 (Finder). The most recently used Finder window
        // is W1 (rank 0). orderedItems should move W1 to end.
        let ordered = SwitcherOrdering.orderedItems(items, history: store, currentFrontmost: finderW1)
        XCTAssertEqual(ordered.map(\.title), ["Arc", "Finder W2", "Finder W1"])
    }

    // MARK: - Helpers

    private func makeItem(title: String, identity: SwitcherHistoryIdentity) -> SwitcherItem {
        SwitcherItem(
            title: title,
            subtitle: "",
            icon: nil,
            previewImage: nil,
            backdropImage: nil,
            historyIdentity: identity,
            sourceAppIdentifier: nil,
            kind: .appWindow
        ) {}
    }

    private func makeCGImage(
        width: Int,
        height: Int,
        pixel: (Int, Int) -> (UInt8, UInt8, UInt8, UInt8)
    ) -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let (r, g, b, a) = pixel(x, y)
                let offset = (y * width + x) * 4
                bytes[offset + 0] = r
                bytes[offset + 1] = g
                bytes[offset + 2] = b
                bytes[offset + 3] = a
            }
        }

        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }
}
