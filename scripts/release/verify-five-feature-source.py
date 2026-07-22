#!/usr/bin/env python3
"""Verify the five-feature production source contract without macOS credentials."""

from __future__ import annotations

import plistlib
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED_FILES = [
    ROOT / "docs" / "features" / "five-feature-production-plan.md",
    ROOT / "Sources" / "CmdTab" / "AXWindowCatalog.swift",
    ROOT / "Sources" / "CmdTab" / "WindowWorkspaceProvider.swift",
    ROOT / "Sources" / "CmdTab" / "SwitcherProfiles.swift",
    ROOT / "Sources" / "CmdTab" / "DurableSwitcherHistory.swift",
    ROOT / "Sources" / "CmdTab" / "WindowManagementActions.swift",
    ROOT / "Sources" / "CmdTab" / "ProductionAppSwitcher.swift",
    ROOT / "Sources" / "CmdTab" / "ProductionSwitcherWindowController.swift",
    ROOT / "Sources" / "CmdTab" / "ProfileHotkeyManager.swift",
    ROOT / "Sources" / "CmdTab" / "SwitcherProfilePreferences.swift",
    ROOT / "Tests" / "CmdTabTests" / "MinimizedWindowPolicyTests.swift",
    ROOT / "Tests" / "CmdTabTests" / "WorkspaceProviderModelTests.swift",
    ROOT / "Tests" / "CmdTabTests" / "SwitcherProfileTests.swift",
    ROOT / "Tests" / "CmdTabTests" / "DurableSwitcherHistoryTests.swift",
    ROOT / "Tests" / "CmdTabTests" / "WindowManagementActionTests.swift",
    ROOT / "Tests" / "CmdTabTests" / "FiveFeatureIntegrationTests.swift",
]


def fail(message: str) -> None:
    raise SystemExit(message)


def read(path: Path) -> str:
    if not path.is_file():
        fail(f"Missing five-feature source: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def require(text: str, literal: str, label: str) -> None:
    if literal not in text:
        fail(f"{label} is missing required source contract: {literal!r}")


def reject(text: str, literal: str, label: str) -> None:
    if literal in text:
        fail(f"{label} contains forbidden source contract: {literal!r}")


def verify_swift_parse_when_available() -> None:
    swiftc = subprocess.run(
        ["bash", "-lc", "command -v swiftc || true"],
        text=True,
        capture_output=True,
        check=False,
    ).stdout.strip()
    if not swiftc:
        return

    changed_sources = [
        path for path in REQUIRED_FILES if path.suffix == ".swift"
    ] + [
        ROOT / "Sources" / "CmdTab" / "AppDelegate.swift",
        ROOT / "Sources" / "CmdTab" / "FocusedWindowHistoryObserver.swift",
        ROOT / "Sources" / "CmdTab" / "MenuBarController.swift",
        ROOT / "Sources" / "CmdTab" / "SwitcherHistory.swift",
        ROOT / "Sources" / "CmdTab" / "SwitcherItem.swift",
        ROOT / "Sources" / "CmdTab" / "SwitcherPreferences.swift",
        ROOT / "Sources" / "CmdTab" / "SwitcherPreferenceModels.swift",
        ROOT / "Sources" / "CmdTab" / "SwitcherStyle.swift",
    ]
    for path in changed_sources:
        result = subprocess.run(
            [swiftc, "-frontend", "-parse", str(path)],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip()
            fail(f"Swift parse failed for {path.relative_to(ROOT)}:\n{detail}")


def main() -> None:
    for path in REQUIRED_FILES:
        read(path)

    app_delegate = read(ROOT / "Sources" / "CmdTab" / "AppDelegate.swift")
    require(app_delegate, "ProductionSwitcherWindowController()", "AppDelegate")
    require(app_delegate, "ProfileHotkeyManager(switcher: switcher)", "AppDelegate")
    reject(app_delegate, "SwitcherWindowController()", "AppDelegate")
    reject(app_delegate, "HotkeyManager(switcher: switcher)", "AppDelegate")

    preferences = read(ROOT / "Sources" / "CmdTab" / "SwitcherPreferences.swift")
    require(preferences, "includeMinimizedWindows", "SwitcherPreferences")
    require(preferences, "resetDurableWindowHistory", "SwitcherPreferences")

    catalogue = read(ROOT / "Sources" / "CmdTab" / "AXWindowCatalog.swift")
    for literal in (
        "_AXUIElementGetWindow",
        "isMinimized",
        "documentURL",
        "isOnScreen",
        "WindowWorkspaceSnapshot",
        "includeMinimized",
    ):
        require(catalogue, literal, "AXWindowCatalog")

    workspace = read(ROOT / "Sources" / "CmdTab" / "WindowWorkspaceProvider.swift")
    for literal in (
        "SLSCopyManagedDisplaySpaces",
        "SLSCopySpacesForWindows",
        "CapabilityStatus",
        "degraded(",
        "StageManagerWindowState",
        "isOnCurrentManagedSpace",
    ):
        require(workspace, literal, "WindowWorkspaceProvider")

    profiles = read(ROOT / "Sources" / "CmdTab" / "SwitcherProfiles.swift")
    for literal in (
        "SwitcherShortcutProfile",
        "SwitcherSessionConfiguration",
        "SwitcherProfileValidator",
        "duplicateShortcut",
        "SwitcherProfileDocument",
        "currentSchemaVersion",
        "exportDocument",
        "importDocument",
        "profilesSnapshot",
        "pressToToggle",
        "holdPrimaryModifier",
    ):
        require(profiles, literal, "SwitcherProfiles")

    hotkeys = read(ROOT / "Sources" / "CmdTab" / "ProfileHotkeyManager.swift")
    for literal in (
        "profileStore.match",
        "ShortcutRecordingState.shared.isRecording",
        "tapDisabledByTimeout",
        "scheduleInstallRetry",
        "dispatchToMain",
    ):
        require(hotkeys, literal, "ProfileHotkeyManager")

    durable = read(ROOT / "Sources" / "CmdTab" / "DurableSwitcherHistory.swift")
    for literal in (
        "titleHash",
        "documentURLHash",
        "SHA256.hash",
        ".atomic",
        ".posixPermissions: 0o600",
        "Ambiguous candidates must not inherit durable rank",
        "expirationInterval",
    ):
        require(durable, literal, "DurableSwitcherHistory")
    record_block = durable.split(
        "struct DurableWindowHistoryRecord", 1
    )[1].split("struct DurableWindowHistoryFile", 1)[0]
    reject(record_block, "let title: String", "DurableWindowHistoryRecord")
    reject(record_block, "let documentURL: URL", "DurableWindowHistoryRecord")

    actions = read(ROOT / "Sources" / "CmdTab" / "WindowManagementActions.swift")
    for literal in (
        "restoreWindow",
        "zoomWindow",
        "toggleFullscreen",
        "moveToNextDisplay",
        "centerWindow",
        "tileLeft",
        "tileRight",
        "tileFirstThird",
        "tileCenterThird",
        "tileLastThird",
        "forceQuitApplication",
        "WindowActionAvailability",
        "AXWindowIdentityLookup.windowElement",
    ):
        require(actions, literal, "WindowManagementActions")

    facade = read(ROOT / "Sources" / "CmdTab" / "ProductionAppSwitcher.swift")
    for literal in (
        "synthesizes eligible minimized and off-space windows",
        "activateExactSyntheticWindow",
        "history.reconcileLiveWindows",
        "includeMinimizedWindows",
        "visibilityScope",
        "managementActionAvailability",
    ):
        require(facade, literal, "ProductionAppSwitcher")

    controller = read(
        ROOT / "Sources" / "CmdTab" / "ProductionSwitcherWindowController.swift"
    )
    for literal in (
        "activeConfiguration",
        "profileID",
        "ProfileSwitcherView",
        "showManagementMenu",
        "requiresConfirmation",
        "WindowManagementAction.allCases",
    ):
        require(controller, literal, "ProductionSwitcherWindowController")

    profile_ui = read(
        ROOT / "Sources" / "CmdTab" / "SwitcherProfilePreferences.swift"
    )
    for literal in (
        "ShortcutRecorder",
        "ShortcutRecordingState",
        "Import…",
        "Export…",
        "Reset Durable MRU",
        "Include minimized windows",
        "Application Filter",
    ):
        require(profile_ui, literal, "SwitcherProfilePreferences")

    observer = read(
        ROOT / "Sources" / "CmdTab" / "FocusedWindowHistoryObserver.swift"
    )
    require(
        observer,
        "history.noteActivation(identity, descriptor: descriptor)",
        "FocusedWindowHistoryObserver",
    )
    require(observer, "startPermissionRetryIfNeeded", "FocusedWindowHistoryObserver")

    entitlements_paths = [
        ROOT / "Resources" / "CmdTab.entitlements",
        ROOT / "release" / "CmdTab.entitlements",
    ]
    entitlements = []
    for path in entitlements_paths:
        with path.open("rb") as handle:
            entitlements.append(plistlib.load(handle))
    if entitlements[0] != entitlements[1]:
        fail("Resource and release entitlement baselines diverge")

    verify_swift_parse_when_available()
    print("Five-feature production source verification passed")


if __name__ == "__main__":
    main()
