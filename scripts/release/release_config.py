#!/usr/bin/env python3
"""Validate CmdTab release metadata and render a deterministic Info.plist."""

from __future__ import annotations

import argparse
import json
import plistlib
import re
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CONFIG = ROOT / "release" / "ReleaseConfig.json"

REQUIRED_KEYS = {
    "schemaVersion",
    "appName",
    "executableName",
    "bundleIdentifier",
    "marketingVersion",
    "buildNumber",
    "minimumSystemVersion",
    "iconFile",
    "packageType",
    "agentApplication",
    "highResolutionCapable",
    "architecturePolicy",
    "distributionChannel",
}


def load_config(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    missing = sorted(REQUIRED_KEYS - data.keys())
    if missing:
        raise SystemExit(f"Missing release configuration keys: {', '.join(missing)}")
    if data["schemaVersion"] != 1:
        raise SystemExit("Unsupported ReleaseConfig schemaVersion")
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", data["bundleIdentifier"]):
        raise SystemExit("bundleIdentifier is not a valid reverse-DNS identifier")
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?", data["marketingVersion"]):
        raise SystemExit("marketingVersion must be semantic-version shaped")
    if not re.fullmatch(r"[1-9]\d*", str(data["buildNumber"])):
        raise SystemExit("buildNumber must be a positive integer string")
    if not re.fullmatch(r"\d+\.\d+(?:\.\d+)?", data["minimumSystemVersion"]):
        raise SystemExit("minimumSystemVersion is invalid")
    if data["packageType"] != "APPL":
        raise SystemExit("packageType must remain APPL")
    return data


def plist_for(config: dict[str, Any]) -> dict[str, Any]:
    return {
        "CFBundleName": config["appName"],
        "CFBundleDisplayName": config["appName"],
        "CFBundleIdentifier": config["bundleIdentifier"],
        "CFBundleVersion": str(config["buildNumber"]),
        "CFBundleShortVersionString": config["marketingVersion"],
        "CFBundleExecutable": config["executableName"],
        "CFBundleIconFile": config["iconFile"],
        "CFBundlePackageType": config["packageType"],
        "CFBundleInfoDictionaryVersion": "6.0",
        "LSMinimumSystemVersion": config["minimumSystemVersion"],
        "LSUIElement": bool(config["agentApplication"]),
        "NSHighResolutionCapable": bool(config["highResolutionCapable"]),
        "NSSupportsAutomaticTermination": False,
        "NSSupportsSuddenTermination": False,
        "NSAccessibilityUsageDescription": (
            "CmdTab needs Accessibility permission to intercept Command-Tab and "
            "Option-Tab and activate the selected window."
        ),
    }


def render(config: dict[str, Any], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as handle:
        plistlib.dump(plist_for(config), handle, fmt=plistlib.FMT_XML, sort_keys=True)


def verify_info(config: dict[str, Any], path: Path) -> None:
    with path.open("rb") as handle:
        actual = plistlib.load(handle)
    expected = plist_for(config)
    if actual != expected:
        missing = sorted(expected.keys() - actual.keys())
        extra = sorted(actual.keys() - expected.keys())
        changed = sorted(key for key in expected.keys() & actual.keys() if expected[key] != actual[key])
        details = []
        if missing:
            details.append(f"missing={missing}")
        if extra:
            details.append(f"extra={extra}")
        if changed:
            details.append(f"changed={changed}")
        raise SystemExit(f"Info.plist diverges from ReleaseConfig: {'; '.join(details)}")


def require_literal(path: Path, literal: str, description: str) -> None:
    text = path.read_text(encoding="utf-8")
    if literal not in text:
        raise SystemExit(f"{description} is missing from {path.relative_to(ROOT)}: {literal!r}")


def tracked_paths(pathspec: str) -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files", "--", pathspec],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise SystemExit(f"git ls-files failed: {result.stderr.strip()}")
    return [line for line in result.stdout.splitlines() if line]


def verify_repository(config: dict[str, Any]) -> None:
    verify_info(config, ROOT / "Resources" / "Info.plist")

    with (ROOT / "Resources" / "CmdTab.entitlements").open("rb") as handle:
        entitlements = plistlib.load(handle)
    if entitlements != {}:
        raise SystemExit(
            "Phase 1 entitlements must remain empty until a verified runtime requirement justifies an entry"
        )

    bundle_id = config["bundleIdentifier"]
    version = config["marketingVersion"]
    build = str(config["buildNumber"])
    minimum = config["minimumSystemVersion"]

    product_facts = ROOT / "website" / "src" / "content" / "product-facts.ts"
    require_literal(product_facts, f'bundleIdentifier: "{bundle_id}"', "public bundle identifier")
    require_literal(product_facts, f'currentVersion: "{version}"', "public marketing version")
    require_literal(product_facts, f'buildNumber: "{build}"', "public build number")
    require_literal(product_facts, f'minimumMacOS: "macOS {minimum}', "public minimum macOS")

    identity_source = ROOT / "Sources" / "CmdTab" / "BundleIdentityMigration.swift"
    require_literal(
        identity_source,
        f'static let currentIdentifier = "{bundle_id}"',
        "native current bundle identifier",
    )
    require_literal(
        identity_source,
        'static let legacyIdentifier = "com.user.CmdTab"',
        "legacy beta bundle identifier",
    )
    require_literal(
        identity_source,
        "kSecAttrAccount as String: currentAccount",
        "Keychain migration target account",
    )

    main_source = ROOT / "Sources" / "CmdTab" / "main.swift"
    require_literal(
        main_source,
        "BundleIdentityMigration.migrateIfNeeded()",
        "startup bundle-identity migration",
    )

    tracked_app = tracked_paths("CmdTab.app")
    if tracked_app:
        raise SystemExit(
            "Generated CmdTab.app remains tracked:\n  " + "\n  ".join(tracked_app[:20])
        )

    print("Repository release identity verification passed")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    sub = parser.add_subparsers(dest="command", required=True)

    get_parser = sub.add_parser("get")
    get_parser.add_argument("key")

    render_parser = sub.add_parser("render-info-plist")
    render_parser.add_argument("output", type=Path)

    verify_parser = sub.add_parser("verify-info-plist")
    verify_parser.add_argument("path", type=Path)

    sub.add_parser("verify-repository")
    sub.add_parser("validate")

    args = parser.parse_args()
    config = load_config(args.config)

    if args.command == "get":
        if args.key not in config:
            raise SystemExit(f"Unknown ReleaseConfig key: {args.key}")
        value = config[args.key]
        print(json.dumps(value) if isinstance(value, (dict, list, bool)) else value)
    elif args.command == "render-info-plist":
        render(config, args.output)
    elif args.command == "verify-info-plist":
        verify_info(config, args.path)
    elif args.command == "verify-repository":
        verify_repository(config)
    elif args.command == "validate":
        print("ReleaseConfig validation passed")


if __name__ == "__main__":
    main()
