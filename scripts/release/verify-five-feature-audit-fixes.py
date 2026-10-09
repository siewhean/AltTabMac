#!/usr/bin/env python3
"""Fail-closed source checks for the independent PR #35 audit remediation."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def fail(message: str) -> None:
    raise SystemExit(message)


def read(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file():
        fail(f"Missing audit-fix source: {relative}")
    return path.read_text(encoding="utf-8")


def require(text: str, literal: str, label: str) -> None:
    if literal not in text:
        fail(f"{label} is missing audit-fix contract: {literal!r}")


def reject(text: str, literal: str, label: str) -> None:
    if literal in text:
        fail(f"{label} contains forbidden audit-fix contract: {literal!r}")


def parse_swift(relative: str) -> None:
    swiftc = shutil.which("swiftc")
    if not swiftc:
        return
    result = subprocess.run(
        [swiftc, "-frontend", "-parse", str(ROOT / relative)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        fail(f"Swift parse failed for {relative}:\n{detail}")


def main() -> None:
    timing = read("Sources/CmdTab/ProfileHotkeyTimingState.swift")
    for literal in (
        "PhysicalModifierChordTimingState",
        "PhysicalModifierDeviceFlags",
        "EventTimestampClock",
        "registerAdditionalAdvance",
        "simultaneousChordKeys",
        "ProfileHotkeyTimingPolicy",
        "revealDelay: 0.20",
        "startedAtUptime",
        "registerHiddenTrigger",
        "handleRevealDeadline",
        "handleModifierRelease",
        "quickSwitch",
        "confirmSelection",
        "ignoresRepeatedTriggerBeforeReveal",
    ):
        require(timing, literal, "ProfileHotkeyTimingState.swift")
    reject(timing, "revealDelay: 0.10", "ProfileHotkeyTimingState.swift")
    # Command-Tab is accepted like the native switcher; the 160 ms chord gate
    # swallowed legitimate presses and must not return.
    reject(timing, "struct ShortcutChordTimingState", "ProfileHotkeyTimingState.swift")

    hotkeys = read("Sources/CmdTab/ProfileHotkeyManager.swift")
    for literal in (
        "ProfileHotkeyTimingState()",
        "PhysicalModifierChordTimingState()",
        "physicalChordTimingState.accepts",
        "registerAdditionalAdvance",
        "EventTapRunLoopThread",
        "tapThread.runLoop",
        "inputMirror.state",
        "stateLock",
        "passUnretained(event)",
        "Ignored delayed Hot Swap modifier chord",
        "isProtectedApplicationCommand",
        "handlePassThroughKeyDown",
        "clearCompletedProfileTriggerState",
        "Cancelled stale switcher trigger",
        "Command-V",
        "currentUptime",
        "eventUptime(event)",
        "scheduleReveal(atUptime:",
        "handleProfileModifierRelease",
        "commitTriggerSession",
        "swallowedKeyCodes.remove(keyCode) != nil",
        "ShortcutRecordingState.shared.isRecording",
        "SecureInputMonitor.isEnabled",
        "licensingGate.allowsShortcut()",
        "tapDisabledByTimeout",
        "scheduleInstallRetry",
    ):
        require(hotkeys, literal, "ProfileHotkeyManager.swift")
    # The tap runs off the main thread: no main-actor licensing call, no
    # retained pass-through (it leaked every event), no chord gate.
    for forbidden in (
        "passRetained(event)",
        "LicensingController.shared.should",
        "shortcutChordTimingState",
        "CFRunLoopGetMain()",
    ):
        reject(hotkeys, forbidden, "ProfileHotkeyManager.swift")
    reject(
        hotkeys,
        "case .holdPrimaryModifier:\n            activeHoldMatch = match",
        "ProfileHotkeyManager.swift",
    )
    reject(
        hotkeys,
        "case .holdPrimaryModifier:\n            dispatchToMain",
        "ProfileHotkeyManager.swift",
    )

    state_models = read("Sources/CmdTab/HotkeyStateModels.swift")
    for literal in (
        "struct AlternateModifierTriggerState",
        "maximumDoubleTapGap: TimeInterval = 0.25",
        "pressedKeys",
        "mode.productionSafeMode",
        "gap <= Self.maximumDoubleTapGap",
        "Option alone",
        "pressedKeys == monitoredKeys",
        "struct HotkeyTriggerState",
    ):
        require(state_models, literal, "HotkeyStateModels.swift")
    reject(
        state_models,
        "maximumDoubleTapGap: TimeInterval = 1.0",
        "HotkeyStateModels.swift",
    )

    # The retired permissive legacy router is deleted, not merely excluded.
    if (ROOT / "Sources/CmdTab/HotkeyManager.swift").exists():
        fail("the retired legacy HotkeyManager.swift must not return")

    hot_swap_policy = read("Sources/CmdTab/AlternateTriggerProductionPolicy.swift")
    for literal in (
        "productionHotSwapModes",
        ".leftCommandDoubleTap",
        ".rightCommandDoubleTap",
        ".leftOptionDoubleTap",
        ".rightOptionDoubleTap",
        "productionSafeMode",
        "case .rightCommandTap",
        "case .rightOptionTap",
        "return .disabled",
        "isProductionImmediateDoubleTap",
        "isProductionSimultaneousChord",
    ):
        require(hot_swap_policy, literal, "AlternateTriggerProductionPolicy.swift")

    preferences = read("Sources/CmdTab/SwitcherPreferences.swift")
    for literal in (
        "storedAlternateTrigger",
        "safeAlternateTrigger",
        "storedAlternateTrigger.productionSafeMode",
        "alternateTrigger = safeMode",
        "defaults.set(safeAlternateTrigger.rawValue",
    ):
        require(preferences, literal, "SwitcherPreferences.swift")

    switcher = read("Sources/CmdTab/ProductionAppSwitcher.swift")
    for literal in (
        "ProductionEnrichmentGate",
        "ProductionEnrichmentInputSignature",
        "ProvisionalSwitcherPolicy",
        "permitsBaseSnapshot",
        "filteredEnrichedItems",
        "enrichmentGate.shouldSchedule",
        "enrichmentGate.invalidate",
    ):
        require(switcher, literal, "ProductionAppSwitcher.swift")
    try:
        getter = switcher.split("func getItems() -> [SwitcherItem]", 1)[1].split(
            "@discardableResult", 1
        )[0]
    except IndexError:
        fail("ProductionAppSwitcher.swift has no reviewable getItems body")
    reject(getter, "scheduleEnrichment", "ProductionAppSwitcher.getItems")

    item = read("Sources/CmdTab/SwitcherItem.swift")
    for literal in (
        "SwitcherPreviewPermissionState",
        "denialConfirmationInterval: TimeInterval = 1.0",
        "SwitcherPreviewContinuityStore",
        "byteLimit = 128 * 1_024 * 1_024",
        "identityMaximumAge: TimeInterval = 600",
        "private static var entries: [String: Entry]",
        "identityWindows",
        "identityKey:",
        "captureAccessAllowed",
        "CGPreflightScreenCaptureAccess",
        "launchDate",
        "ReliableWindowPreviewRecovery.schedule",
        "previewCacheKey != nil, kind == .appWindow",
    ):
        require(item, literal, "SwitcherItem.swift")
    reject(item, "identityMaximumAge: TimeInterval = 15", "SwitcherItem.swift")

    recovery = read("Sources/CmdTab/ReliableWindowPreviewRecovery.swift")
    for literal in (
        "@preconcurrency import ScreenCaptureKit",
        "SCShareableContent.getExcludingDesktopWindows",
        "SCContentFilter(desktopIndependentWindow:",
        "SCScreenshotManager.captureImage",
        "PreviewRecoveryRequestState",
        "entry.inFlight",
        "entry.retryAfter",
        "didRecoverPreviewNotification",
        "SwitcherPreviewContinuityStore.resolve",
    ):
        require(recovery, literal, "ReliableWindowPreviewRecovery.swift")

    app_delegate = read("Sources/CmdTab/AppDelegate.swift")
    for literal in (
        "ReliableWindowPreviewRecovery.didRecoverPreviewNotification",
        "handleRecoveredWindowPreview",
        "switcher?.refreshPreviewCache()",
    ):
        require(app_delegate, literal, "AppDelegate.swift")

    cycle = read("Sources/CmdTab/SwitcherCycleSession.swift")
    for literal in (
        "A quick trigger must never commit",
        "items[proposed].historyIdentity == currentFrontmost",
    ):
        require(cycle, literal, "SwitcherCycleSession.swift")

    menu = read("Sources/CmdTab/MenuBarController.swift")
    for literal in (
        "Settings…",
        "Check for Beta Updates…",
        "Diagnostics…",
        "Setup Guide…",
        "Quit CmdTab",
        "menu.popUp(",
    ):
        require(menu, literal, "MenuBarController.swift")
    for removed_menu_control in (
        "Show Minimized Windows",
        "Reverse Cycle: ⇧⌘Tab or ⇧⌥Tab",
    ):
        reject(menu, removed_menu_control, "MenuBarController.swift")

    feedback = read(
        "docs/release/evidence/five-feature-suite/manual-feedback-regressions.md"
    )
    for literal in (
        "160 ms",
        "200 ms",
        "250 ms",
        "Option alone",
        "two seconds",
        "Show Minimized Windows",
        "Arc and Telegram",
        "focused `CGWindowID`",
        "Command-V",
        "must not switch back",
        "stale release owner",
        "ScreenCaptureKit",
        "600 seconds",
    ):
        require(feedback, literal, "manual-feedback-regressions.md")

    durable = read("Sources/CmdTab/DurableSwitcherHistory.swift")
    for literal in (
        "DurableHistoryWriteMatcher",
        "recordIDByLiveIdentity",
        "liveIdentityByRecordID",
        "unavailableRecordIDs",
        "preferred.bundleIdentifier == bundleIdentifier",
        "privacy fingerprint",
    ):
        require(durable, literal, "DurableSwitcherHistory.swift")

    stage = read("Sources/CmdTab/StageManagerCapabilityPolicy.swift")
    for literal in (
        "StageManagerCapabilityPolicy",
        "truthfulStatus",
        "addingLimitation",
        "Inferred Active Set",
        "Inferred Hidden Set",
    ):
        require(stage, literal, "StageManagerCapabilityPolicy.swift")

    visuals = read("Sources/CmdTab/ProductionSwitcherVisuals.swift")
    require(
        visuals,
        "StageManagerCapabilityPolicy.visibleLabel",
        "ProductionSwitcherVisuals.swift",
    )
    require(
        visuals,
        "StageManagerCapabilityPolicy.truthfulStatus",
        "ProductionSwitcherVisuals.swift",
    )
    reject(
        visuals,
        '("rectangle.stack.badge.minus", "Hidden Set"',
        "ProductionSwitcherVisuals.swift",
    )

    diagnostics = read("Sources/CmdTab/ProductionDiagnosticsWindow.swift")
    require(
        diagnostics,
        "StageManagerCapabilityPolicy.truthfulStatus",
        "ProductionDiagnosticsWindow.swift",
    )

    test_contracts = {
        "Tests/CmdTabTests/ProfileHotkeyTimingTests.swift": (
            "testQuickReleaseCommitsWithoutOverlay",
            "testHeldModifierRevealsMatchingProfile",
            "testRepeatedHiddenKeyDownDoesNotRescheduleDeadline",
            "testLateDeadlineStillUsesOriginalTrigger",
            "testReplacingVisibleProfileTransfersReleaseOwnership",
            "testDeliberateTabsBeforeQuickReleaseAdvanceTheCommit",
            "A delayed Hot Swap modifier chord must not activate",
            "Fast Command-Tab-Tab must land on the second item",
        ),
        "Tests/CmdTabTests/ProductionHotSwapPolicyTests.swift": (
            "testProductionModesExposeImmediateCommandDoubleTapsAndSideMatchedChords",
            "testOnlyLegacySingleTapModesMigrateToStandardOnly",
            "testImmediateDoubleCommandAcceptedButDelayedAndOptionAloneRejected",
            "A two-second delay must never activate Hot Swap",
            "Option alone must not activate",
            "above 250 ms must be rejected",
        ),
        "Tests/CmdTabTests/SwitcherProfileSafetyTests.swift": (
            "ProfileHotkeyTriggerCoordinator",
            ".quickSwitch(forward)",
            ".confirmSelection(reverse)",
        ),
        "Tests/CmdTabTests/ProductionMembershipPolicyTests.swift": (
            "ProductionEnrichmentGate",
            "ProvisionalSwitcherPolicy.permitsBaseSnapshot",
            "must fail closed",
            "SwitcherPreviewContinuityStore.resolve",
            "longLivedMetadataChange",
            "SwitcherPreviewPermissionState.effectiveAccess",
            "One transient false TCC preflight",
            "captureAccessAllowed: false",
        ),
        "Tests/CmdTabTests/SwitcherCycleSessionTests.swift": (
            "staleOrderingSession",
            "must still avoid committing the current",
        ),
        "Tests/CmdTabTests/DurableSwitcherHistoryTests.swift": (
            "DurableHistoryWriteMatcher",
            "Two exact same-title windows",
            "com.example.second",
        ),
        "Tests/CmdTabTests/WorkspaceProviderModelTests.swift": (
            "StageManagerCapabilityPolicy.truthfulStatus",
            "Inferred Hidden Set",
        ),
    }
    for relative, literals in test_contracts.items():
        text = read(relative)
        for literal in literals:
            require(text, literal, relative)

    gates = read("scripts/release/five-feature-qa-gates.sh")
    require(
        gates,
        'FOCUSED_XCTEST_EXPECTED_COUNT="${CMDTAB_FOCUSED_XCTEST_EXPECTED_COUNT:-61}"',
        "five-feature-qa-gates.sh",
    )

    for relative in (
        "Sources/CmdTab/ProfileHotkeyTimingState.swift",
        "Sources/CmdTab/ProfileHotkeyManager.swift",
        "Sources/CmdTab/HotkeyStateModels.swift",
        "Sources/CmdTab/AlternateTriggerProductionPolicy.swift",
        "Sources/CmdTab/SwitcherPreferences.swift",
        "Sources/CmdTab/ProductionAppSwitcher.swift",
        "Sources/CmdTab/SwitcherItem.swift",
        "Sources/CmdTab/ReliableWindowPreviewRecovery.swift",
        "Sources/CmdTab/AppDelegate.swift",
        "Sources/CmdTab/SwitcherCycleSession.swift",
        "Sources/CmdTab/MenuBarController.swift",
        "Sources/CmdTab/DurableSwitcherHistory.swift",
        "Sources/CmdTab/StageManagerCapabilityPolicy.swift",
        "Sources/CmdTab/ProductionSwitcherVisuals.swift",
        "Sources/CmdTab/ProductionDiagnosticsWindow.swift",
        "Tests/CmdTabTests/ProfileHotkeyTimingTests.swift",
        "Tests/CmdTabTests/ProductionHotSwapPolicyTests.swift",
        "Tests/CmdTabTests/ProductionMembershipPolicyTests.swift",
        "Tests/CmdTabTests/SwitcherCycleSessionTests.swift",
    ):
        parse_swift(relative)

    print("PR #35 audit-fix source verification passed")


if __name__ == "__main__":
    main()
