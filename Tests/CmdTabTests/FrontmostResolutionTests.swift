import XCTest
@testable import CmdTab

final class FrontmostResolutionTests: XCTestCase {
    func testActiveOverrideWinsDuringShortGraceWindow() {
        let notebookLM = makeItem(title: "NotebookLM", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 21))
        let arc = makeItem(title: "Arc", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22))
        let finder = makeItem(title: "Finder", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11))
        let history = [arc.historyIdentity, notebookLM.historyIdentity, finder.historyIdentity]
        let override = FrontmostOverrideState(identity: arc.historyIdentity, pid: 202, startedAtUptime: 10.0)

        let identity = FrontmostResolution.effectiveIdentity(
            availableItems: [arc, finder, notebookLM],
            historyEntries: history,
            systemFrontmostIdentity: nil,
            systemFrontmostPID: 101,
            observedFrontmostPID: 101,
            overrideState: override,
            now: 10.05
        )

        XCTAssertEqual(identity, arc.historyIdentity)
    }

    func testExpiredOverrideDoesNotGuessBetweenSamePIDWindowsWithoutExactIdentity() {
        let notebookLM = makeItem(title: "NotebookLM", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 21))
        let arc = makeItem(title: "Arc", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22))
        let finder = makeItem(title: "Finder", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11))
        let history = [arc.historyIdentity, notebookLM.historyIdentity, finder.historyIdentity]
        let override = FrontmostOverrideState(identity: arc.historyIdentity, pid: 202, startedAtUptime: 10.0)

        let identity = FrontmostResolution.effectiveIdentity(
            availableItems: [arc, finder, notebookLM],
            historyEntries: history,
            systemFrontmostIdentity: nil,
            systemFrontmostPID: 101,
            observedFrontmostPID: 101,
            overrideState: override,
            now: 10.5
        )

        XCTAssertNil(identity)
    }

    func testExactSystemFrontmostIdentityWinsOverSamePIDHistoryFallback() {
        let notebookLM = makeItem(title: "NotebookLM", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 21))
        let arc = makeItem(title: "Arc", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 22))
        let finder = makeItem(title: "Finder", appID: "com.apple.finder", identity: .appWindow(pid: 101, windowID: 11))
        let history = [notebookLM.historyIdentity, arc.historyIdentity, finder.historyIdentity]

        let identity = FrontmostResolution.effectiveIdentity(
            availableItems: [arc, finder, notebookLM],
            historyEntries: history,
            systemFrontmostIdentity: arc.historyIdentity,
            systemFrontmostPID: 202,
            observedFrontmostPID: 202,
            overrideState: nil,
            now: 10.5
        )

        XCTAssertEqual(identity, arc.historyIdentity)
    }

    func testAppFallbackIsUsedWhenOnlyPidLevelIdentityExists() {
        let fallback = makeItem(title: "Arc", appID: "company.thebrowser.Browser", identity: .appFallback(bundleID: "company.thebrowser.Browser", pid: 202), kind: .appFallback)
        let notebookLM = makeItem(title: "NotebookLM", appID: "company.thebrowser.Browser", identity: .appWindow(pid: 202, windowID: 21))
        let history = [notebookLM.historyIdentity, fallback.historyIdentity]

        let identity = FrontmostResolution.effectiveIdentity(
            availableItems: [notebookLM, fallback],
            historyEntries: history,
            systemFrontmostIdentity: nil,
            systemFrontmostPID: 202,
            observedFrontmostPID: 202,
            overrideState: nil,
            now: 12.0
        )

        XCTAssertEqual(identity, fallback.historyIdentity)
    }

    private func makeItem(title: String, appID: String, identity: SwitcherHistoryIdentity, kind: SwitcherItemKind = .appWindow) -> SwitcherItem {
        SwitcherItem(
            title: title,
            subtitle: appID,
            icon: nil,
            previewImage: nil,
            historyIdentity: identity,
            sourceAppIdentifier: appID,
            kind: kind
        ) {}
    }
}
