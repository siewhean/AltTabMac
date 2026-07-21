import XCTest
import AppKit
@testable import CmdTab

/// Acceptance tests for strict, global window MRU and representation that is
/// independent of screenshot availability.
final class StrictMRUAndCompletenessRegressionTests: XCTestCase {
    func testForwardSelectionUsesPreviousWindowEvenWhenItBelongsToCurrentApplication() throws {
        let previousA = makeItem(
            title: "A — previous",
            appID: "example.app.a",
            identity: .appWindow(pid: 101, windowID: 11)
        )
        let otherB = makeItem(
            title: "B",
            appID: "example.app.b",
            identity: .appWindow(pid: 202, windowID: 21)
        )
        let currentA = makeItem(
            title: "A — current",
            appID: "example.app.a",
            identity: .appWindow(pid: 101, windowID: 12)
        )

        // Strict global MRU after moving the current tile to the end:
        // [A previous, B, A current].
        let session = try XCTUnwrap(
            SwitcherCycleSession(
                mode: .app,
                items: [previousA, otherB, currentA],
                currentFrontmost: currentA.historyIdentity,
                reverse: false,
                pinsSnapshot: true
            )
        )

        XCTAssertEqual(
            session.commitSelection().historyIdentity,
            previousA.historyIdentity,
            "Forward switching must not skip a more-recent window merely because it shares the current PID."
        )
    }

    func testReverseSelectionUsesAdjacentMRUWindowEvenWhenItBelongsToCurrentApplication() throws {
        let otherB = makeItem(
            title: "B",
            appID: "example.app.b",
            identity: .appWindow(pid: 202, windowID: 21)
        )
        let previousA = makeItem(
            title: "A — previous",
            appID: "example.app.a",
            identity: .appWindow(pid: 101, windowID: 11)
        )
        let currentA = makeItem(
            title: "A — current",
            appID: "example.app.a",
            identity: .appWindow(pid: 101, windowID: 12)
        )

        let session = try XCTUnwrap(
            SwitcherCycleSession(
                mode: .app,
                items: [otherB, previousA, currentA],
                currentFrontmost: currentA.historyIdentity,
                reverse: true,
                pinsSnapshot: true
            )
        )

        XCTAssertEqual(
            session.commitSelection().historyIdentity,
            previousA.historyIdentity,
            "Reverse switching must follow the adjacent MRU tile, not scan for a different PID."
        )
    }

    func testAmbiguousFrontmostPIDUsesMostRecentVisibleWindowFromHistory() {
        let currentA = makeItem(
            title: "A — current",
            appID: "example.app.a",
            identity: .appWindow(pid: 101, windowID: 12)
        )
        let olderA = makeItem(
            title: "A — older",
            appID: "example.app.a",
            identity: .appWindow(pid: 101, windowID: 11)
        )
        let otherB = makeItem(
            title: "B",
            appID: "example.app.b",
            identity: .appWindow(pid: 202, windowID: 21)
        )

        let resolved = FrontmostResolution.effectiveIdentity(
            availableItems: [olderA, otherB, currentA],
            historyEntries: [
                currentA.historyIdentity,
                olderA.historyIdentity,
                otherB.historyIdentity,
            ],
            systemFrontmostIdentity: nil,
            systemFrontmostPID: 101,
            observedFrontmostPID: 101,
            overrideState: nil,
            now: 100
        )

        XCTAssertEqual(
            resolved,
            currentA.historyIdentity,
            "When AX cannot resolve the exact focused window, the most recent visible identity for the effective PID is the safest deterministic fallback."
        )
    }

    func testFinalThumbnailFailureKeepsWindowAsPlaceholderTile() {
        XCTAssertTrue(
            AppSwitcher.shouldDisplayWindowItem(
                previewImage: nil,
                capturePreviews: true,
                allowPreviewlessItems: false
            ),
            "Screenshot failure must degrade visual quality, never remove an eligible app/window."
        )
    }

    private func makeItem(
        title: String,
        appID: String,
        identity: SwitcherHistoryIdentity
    ) -> SwitcherItem {
        SwitcherItem(
            title: title,
            subtitle: appID,
            icon: nil,
            previewImage: nil,
            historyIdentity: identity,
            sourceAppIdentifier: appID,
            kind: .appWindow
        ) {}
    }
}
