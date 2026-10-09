import XCTest
@testable import CmdTab

final class SwitcherQuickActionShortcutTests: XCTestCase {
    func testMappedCommandShortcutResolvesAction() {
        XCTAssertEqual(
            SwitcherQuickAction.action(
                forKeyCode: 4,
                commandHeld: true,
                acceptsBareShortcut: false
            ),
            .hideApp
        )
        XCTAssertEqual(
            SwitcherQuickAction.action(
                forKeyCode: 46,
                commandHeld: true,
                acceptsBareShortcut: false
            ),
            .minimizeWindow
        )
    }

    func testKeyEquivalentResolvesActionWithoutRelyingOnHardwareKeyCode() {
        XCTAssertEqual(
            SwitcherQuickAction.action(
                forKeyCode: 999,
                keyEquivalent: "q",
                commandHeld: true,
                acceptsBareShortcut: false
            ),
            .quitApp
        )
        XCTAssertEqual(
            SwitcherQuickAction.action(
                forKeyCode: 999,
                keyEquivalent: "M",
                commandHeld: true,
                acceptsBareShortcut: false
            ),
            .minimizeWindow
        )
    }

    func testBareShortcutResolvesWhenAllowed() {
        XCTAssertEqual(
            SwitcherQuickAction.action(
                forKeyCode: 13,
                commandHeld: false,
                acceptsBareShortcut: true
            ),
            .closeWindow
        )
    }

    func testBareQuitNeverResolvesButCommandQuitDoes() {
        XCTAssertNil(
            SwitcherQuickAction.action(
                forKeyCode: 12,
                commandHeld: false,
                acceptsBareShortcut: true
            )
        )
        XCTAssertNil(
            SwitcherQuickAction.action(
                forKeyCode: 999,
                keyEquivalent: "q",
                commandHeld: false,
                acceptsBareShortcut: true
            )
        )
        XCTAssertEqual(
            SwitcherQuickAction.action(
                forKeyCode: 12,
                commandHeld: true,
                acceptsBareShortcut: true
            ),
            .quitApp
        )
    }

    func testBareShortcutDoesNotResolveWhenDisallowed() {
        XCTAssertNil(
            SwitcherQuickAction.action(
                forKeyCode: 12,
                commandHeld: false,
                acceptsBareShortcut: false
            )
        )
    }

    func testUnmappedKeyDoesNotResolve() {
        XCTAssertNil(
            SwitcherQuickAction.action(
                forKeyCode: 0,
                commandHeld: true,
                acceptsBareShortcut: false
            )
        )
    }

    func testQuitShortcutAlwaysTerminatesTheOwningApplication() {
        XCTAssertEqual(
            SwitcherQuickAction.quitApp.execution(for: .appWindow),
            .terminateApplication
        )
    }

    func testQuitShortcutStillTerminatesAppFallbackTiles() {
        XCTAssertEqual(
            SwitcherQuickAction.quitApp.execution(for: .appFallback),
            .terminateApplication
        )
    }

    func testTerminateApplicationSuppressionTargetsAllTilesForThatApp() {
        let item = SwitcherItem(
            title: "Finder",
            subtitle: "com.apple.finder",
            icon: nil,
            previewImage: nil,
            historyIdentity: .appFallback(bundleID: "com.apple.finder", pid: 101),
            sourceAppIdentifier: "com.apple.finder",
            kind: .appFallback
        ) {}

        XCTAssertEqual(
            SwitcherQuickActionExecution.terminateApplication.suppressionTarget(for: item),
            .application(pid: 101, sourceAppIdentifier: "com.apple.finder")
        )
    }
}
