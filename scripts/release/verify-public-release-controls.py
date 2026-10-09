#!/usr/bin/env python3
"""Fail closed when DEBUG-only licensing controls can leak into a release."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def fail(message: str) -> None:
    raise SystemExit(message)


def read(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file():
        fail(f"Missing public-release control source: {relative}")
    return path.read_text(encoding="utf-8")


def debug_only_file(relative: str, declaration: str) -> None:
    source = read(relative)
    start = source.find("#if DEBUG")
    end = source.rfind("#endif")
    if start < 0 or end <= start or declaration not in source[start:end]:
        fail(f"{relative} must compile {declaration} only under #if DEBUG")


def debug_only_occurrences(relative: str, needle: str) -> None:
    source = read(relative)
    active_debug_depth = 0
    for number, line in enumerate(source.splitlines(), start=1):
        stripped = line.strip()
        if stripped == "#if DEBUG":
            active_debug_depth += 1
            continue
        if stripped == "#endif" and active_debug_depth:
            active_debug_depth -= 1
            continue
        if needle in line and active_debug_depth == 0:
            fail(f"{relative}:{number} exposes {needle} outside #if DEBUG")


def main() -> None:
    debug_only_file("Sources/CmdTab/DeveloperSettings.swift", "DeveloperSettings")
    debug_only_file(
        "Sources/CmdTab/DeveloperPreferencesPane.swift", "DeveloperPreferencesPane"
    )
    debug_only_file(
        "Sources/CmdTab/DeveloperLicenseGenerator.swift", "DeveloperLicenseGenerator"
    )

    for needle in ("DeveloperSettings", "developerOverrideStatus", "developerSettings"):
        debug_only_occurrences("Sources/CmdTab/LicensingController.swift", needle)
    debug_only_occurrences("Sources/CmdTab/PreferencesView.swift", "DeveloperSettings")
    debug_only_occurrences(
        "Sources/CmdTab/PreferencesView.swift", "DeveloperPreferencesPane"
    )

    licensing_config = read("Sources/CmdTab/LicensingConfiguration.swift")
    if 'forInfoDictionaryKey: "CmdTabCommerceEnabled"' not in licensing_config:
        fail("LicensingConfiguration must read the typed CmdTabCommerceEnabled capability")
    licensing_pane = read("Sources/CmdTab/LicensingPreferencesPane.swift")
    if "else if LicensingConfiguration.commerceEnabled" not in licensing_pane:
        fail("Buy presentation must remain gated by the commerce capability")
    if "if LicensingConfiguration.commerceEnabled {\n                    purchaseActivationControls" not in licensing_pane:
        fail("Paid activation presentation must remain gated by the commerce capability")
    onboarding = read("Sources/CmdTab/OnboardingWindowController.swift")
    if "if LicensingConfiguration.commerceEnabled {\n                HStack(spacing: 12)" not in onboarding:
        fail("Onboarding paid activation presentation must be capability-gated")

    quick_actions = read("Sources/CmdTab/SwitcherPreferenceModels.swift")
    if "case .quitApp:\n            return .terminateApplication" not in quick_actions:
        fail("Cmd-Q must terminate the application for every selected tile kind")
    if "Close the selected window when a window tile is highlighted" in quick_actions:
        fail("Cmd-Q retains stale window-close copy")

    print("Public-release control verification passed")


if __name__ == "__main__":
    main()
