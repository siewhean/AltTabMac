#!/usr/bin/env python3
"""Verify the five-feature production source contract without macOS credentials.

This is deliberately a structural and syntax gate. Real AppKit, Accessibility,
WindowServer, Space, Stage Manager, and exact-focus behaviour remains the job of
`run-five-feature-qa.sh` plus its packaged-app matrix on macOS.
"""

from __future__ import annotations

import plistlib
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

SOURCE_FILES = [
    "AXWindowCatalog.swift",
    "WindowWorkspaceProvider.swift",
    "SwitcherProfiles.swift",
    "SwitcherSessionConfigurationFreeze.swift",
    "DurableSwitcherHistory.swift",
    "WindowManagementActions.swift",
    "ProductionAppSwitcher.swift",
    "ProductionSwitcherWindowController.swift",
    "ProductionSwitcherVisuals.swift",
    "ProductionDiagnosticsWindow.swift",
    "ProductionProfilePreferences.swift",
    "ProfileHotkeyManager.swift",
    "ProfileSwitcherView.swift",
    "ScreenTopologyObserver.swift",
    "SecureInputMonitor.swift",
    "ShortcutRecorder.swift",
    "HotkeyModifier+Sendable.swift",
]

TEST_FILES = [
    "MinimizedWindowPolicyTests.swift",
    "WorkspaceProviderModelTests.swift",
    "SwitcherProfileTests.swift",
    "SwitcherProfileSafetyTests.swift",
    "SwitcherSessionConfigurationFreezeTests.swift",
    "DurableSwitcherHistoryTests.swift",
    "WindowManagementActionTests.swift",
    "FiveFeatureIntegrationTests.swift",
    "ProductionMembershipPolicyTests.swift",
    "ProductionVisualStateTests.swift",
]

REQUIRED_FILES = [
    ROOT / "docs" / "features" / "five-feature-production-plan.md",
    ROOT / "docs" / "release" / "evidence" / "five-feature-suite" / "README.md",
    *[ROOT / "Sources" / "CmdTab" / name for name in SOURCE_FILES],
    *[ROOT / "Tests" / "CmdTabTests" / name for name in TEST_FILES],
    ROOT / "Tests" / "Fixtures" / "WindowLab" / "main.swift",
    ROOT / "Tests" / "Fixtures" / "WindowProbe" / "main.swift",
    ROOT / "scripts" / "release" / "build-windowlab-fixture.sh",
    ROOT / "scripts" / "release" / "build-windowprobe-fixture.sh",
    ROOT / "scripts" / "release" / "run-five-feature-qa.sh",
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


def require_all(path: Path, literals: tuple[str, ...]) -> str:
    text = read(path)
    for literal in literals:
        require(text, literal, path.name)
    return text


def verify_shell_syntax() -> None:
    bash = shutil.which("bash")
    if not bash:
        fail("bash is required for shell syntax verification")
    for name in (
        "build-windowlab-fixture.sh",
        "build-windowprobe-fixture.sh",
        "run-five-feature-qa.sh",
    ):
        path = ROOT / "scripts" / "release" / name
        result = subprocess.run(
            [bash, "-n", str(path)],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip()
            fail(f"Shell syntax failed for {path.relative_to(ROOT)}:\n{detail}")


def verify_swift_parse_when_available() -> None:
    swiftc = shutil.which("swiftc")
    if not swiftc:
        return

    paths = [path for path in REQUIRED_FILES if path.suffix == ".swift"]
    paths.extend(
        ROOT / "Sources" / "CmdTab" / name
        for name in (
            "AppDelegate.swift",
            "FocusedWindowHistoryObserver.swift",
            "MenuBarController.swift",
            "SwitcherHistory.swift",
            "SwitcherItem.swift",
            "SwitcherPreferences.swift",
            "SwitcherPreferenceModels.swift",
            "SwitcherStyle.swift",
        )
    )

    seen: set[Path] = set()
    for path in paths:
        if path in seen:
            continue
        seen.add(path)
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


def verify_entitlements() -> None:
    values = []
    for path in (
        ROOT / "Resources" / "CmdTab.entitlements",
        ROOT / "release" / "CmdTab.entitlements",
    ):
        with path.open("rb") as handle:
            values.append(plistlib.load(handle))
    if values[0] != values[1]:
        fail("Resource and release entitlement baselines diverge")


def main() -> None:
    for path in REQUIRED_FILES:
        read(path)
    verify_shell_syntax()

    app_delegate = require_all(
        ROOT / "Sources" / "CmdTab" / "AppDelegate.swift",
        (
            "switcher = ProductionSwitcherWindowController()",
            "hotkeyManager = ProfileHotkeyManager(switcher: switcher)",
            "ScreenTopologyObserver",
            "requestRequiredPermissionsIfNeeded",
            "beginDefaultConfigurationFreeze",
            "waitForPendingWrites",
        ),
    )
    reject(app_delegate, "switcher = SwitcherWindowController()", "AppDelegate")
    reject(app_delegate, "hotkeyManager = HotkeyManager(switcher: switcher)", "AppDelegate")

    require_all(
        ROOT / "Sources" / "CmdTab" / "SwitcherPreferences.swift",
        ("includeMinimizedWindows", "resetDurableWindowHistory"),
    )
    require_all(
        ROOT / "Sources" / "CmdTab" / "AXWindowCatalog.swift",
        (
            "_AXUIElementGetWindow",
            "isMinimized",
            "isFullscreen",
            "documentURL",
            "isOnScreen",
            "WindowWorkspaceSnapshot",
            "includeMinimized",
        ),
    )
    require_all(
        ROOT / "Sources" / "CmdTab" / "WindowWorkspaceProvider.swift",
        (
            "SLSCopyManagedDisplaySpaces",
            "SLSCopySpacesForWindows",
            "CapabilityStatus",
            "StageManagerWindowState",
            "isOnCurrentManagedSpace",
            "prepareActivation",
        ),
    )

    profiles = require_all(
        ROOT / "Sources" / "CmdTab" / "SwitcherProfiles.swift",
        (
            "SwitcherShortcutProfile",
            "SwitcherSessionConfiguration",
            "SwitcherProfileValidator",
            "duplicateShortcut",
            "invalidFilter",
            "noEnabledProfiles",
            "SwitcherProfileDocument",
            "currentSchemaVersion",
            "exportDocument",
            "importDocument",
            "SwitcherSessionConfigurationFreeze.shared.resolve",
            "looksLikeBundleIdentifier",
        ),
    )
    reject(profiles, "document.schemaVersion <=", "SwitcherProfiles.swift")

    require_all(
        ROOT / "Sources" / "CmdTab" / "SwitcherSessionConfigurationFreeze.swift",
        ("preserveExisting", "frozenConfiguration", "resolve(", "func end()", "NSLock"),
    )

    hotkeys = require_all(
        ROOT / "Sources" / "CmdTab" / "ProfileHotkeyManager.swift",
        (
            "profileStore.match",
            "ShortcutRecordingState.shared.isRecording",
            "SecureInputMonitor.isEnabled",
            "LicensingController.shared.shouldHandleCustomSwitcherShortcut",
            "configurationFreeze.begin",
            "configurationFreeze.end",
            "tapDisabledByTimeout",
            "scheduleInstallRetry",
            "swallowedKeyCodes.remove(keyCode) != nil",
            "dispatchToMain",
        ),
    )
    reject(
        hotkeys,
        "if profileStore.match(keyCode: keyCode, flags: event.flags) != nil {\n                return nil",
        "ProfileHotkeyManager.swift",
    )

    require_all(
        ROOT / "Sources" / "CmdTab" / "SecureInputMonitor.swift",
        ("IsSecureEventInputEnabled", "dlsym"),
    )
    require_all(
        ROOT / "Sources" / "CmdTab" / "ShortcutRecorder.swift",
        (
            "ShortcutRecordingState",
            "ShortcutRecorder",
            "accessibilityPerformPress",
            "isAccessibilityElement",
            "Delete clears",
        ),
    )

    durable = require_all(
        ROOT / "Sources" / "CmdTab" / "DurableSwitcherHistory.swift",
        (
            "titleHash",
            "documentURLHash",
            "SHA256.hash",
            ".atomic",
            ".posixPermissions: 0o600",
            "Ambiguous candidates must not inherit durable rank",
            "expirationInterval",
        ),
    )
    record_block = durable.split("struct DurableWindowHistoryRecord", 1)[1].split(
        "struct DurableWindowHistoryFile", 1
    )[0]
    reject(record_block, "let title: String", "DurableWindowHistoryRecord")
    reject(record_block, "let documentURL: URL", "DurableWindowHistoryRecord")

    require_all(
        ROOT / "Sources" / "CmdTab" / "SwitcherHistory.swift",
        (
            "SwitcherMembershipPolicy",
            "deduplicatedWithoutRepresentedFallbacks",
            "applyingPerApplicationLimit",
            "currentFrontmost",
        ),
    )

    require_all(
        ROOT / "Sources" / "CmdTab" / "WindowManagementActions.swift",
        (
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
            "approximatelyEqual",
        ),
    )

    require_all(
        ROOT / "Sources" / "CmdTab" / "ProductionAppSwitcher.swift",
        (
            "ProductionAppSwitcher.Enrichment",
            "scheduleEnrichment",
            "enrichmentGeneration",
            "cachedEnrichedItems",
            "provisionalItems",
            "activateExactSyntheticWindow",
            "history.reconcileLiveWindows",
            "includeMinimizedWindows",
            "managementActionAvailability",
        ),
    )
    require_all(
        ROOT / "Sources" / "CmdTab" / "ProductionSwitcherWindowController.swift",
        (
            "activeConfiguration",
            "profileID",
            "ProfileSwitcherView",
            "showManagementMenu",
            "requiresConfirmation",
            "WindowManagementAction.allCases",
        ),
    )
    require_all(
        ROOT / "Sources" / "CmdTab" / "ProductionSwitcherVisuals.swift",
        (
            "SwitcherItemStateBadges",
            "ProductionClassicGridView",
            "ProductionCommandPaletteView",
            "ProductionRadialMenuView",
            "Workspace precision is degraded",
            "Other Space",
            "Hidden Set",
        ),
    )
    require_all(
        ROOT / "Sources" / "CmdTab" / "ProfileSwitcherView.swift",
        (
            "ProductionClassicGridView",
            "ProductionCommandPaletteView",
            "ProductionRadialMenuView",
            "Right-click for window actions",
        ),
    )

    require_all(
        ROOT / "Sources" / "CmdTab" / "ProductionDiagnosticsWindow.swift",
        (
            "Copy Sanitized Report",
            "Reset Durable MRU",
            "Secure Input",
            "Workspace Provider",
            "account-specific home paths",
            "durableHistoryLocation",
        ),
    )
    require_all(
        ROOT / "Sources" / "CmdTab" / "ProductionProfilePreferences.swift",
        (
            "Save changes to this shortcut profile?",
            "Unsaved changes",
            "Choose Installed Apps…",
            "Import…",
            "Export…",
            "Reset Durable MRU…",
            "Edits made while a switcher is visible apply to the next session",
            "Keeps the raw draft intact",
        ),
    )
    require_all(
        ROOT / "Sources" / "CmdTab" / "MenuBarController.swift",
        (
            "ProductionProfilePreferencesWindowController",
            "Diagnostics…",
            "ProductionDiagnosticsWindowController",
        ),
    )
    require_all(
        ROOT / "Sources" / "CmdTab" / "ScreenTopologyObserver.swift",
        (
            "didChangeScreenParametersNotification",
            "didWakeNotification",
            "Observation(center:",
        ),
    )
    require_all(
        ROOT / "Sources" / "CmdTab" / "FocusedWindowHistoryObserver.swift",
        (
            "history.noteActivation(identity, descriptor: descriptor)",
            "startPermissionRetryIfNeeded",
        ),
    )

    require_all(
        ROOT / "Tests" / "Fixtures" / "WindowProbe" / "main.swift",
        (
            "focusedWindowID",
            "mainWindowID",
            "_AXUIElementGetWindow",
            "accessibilityTrusted",
            "isFrontmostProcess",
        ),
    )

    qa = require_all(
        ROOT / "scripts" / "release" / "run-five-feature-qa.sh",
        (
            "build-windowlab-fixture.sh",
            "build-windowprobe-fixture.sh",
            "ProductionMembershipPolicyTests",
            "ProductionVisualStateTests",
            "SwitcherSessionConfigurationFreezeTests",
            "AUTOMATED_PASS",
        ),
    )
    reject(qa, "MANUAL_PASS", "run-five-feature-qa.sh")

    verify_entitlements()
    verify_swift_parse_when_available()
    print("Five-feature production source verification passed")


if __name__ == "__main__":
    main()
