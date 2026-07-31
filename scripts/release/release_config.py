#!/usr/bin/env python3
"""Validate CmdTab release metadata and render a deterministic Info.plist."""

from __future__ import annotations

import argparse
import base64
import json
import os
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
    "updateChannel",
    "sparkleVersion",
    "updateFeedURL",
    "updateCheckIntervalSeconds",
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
    if data["architecturePolicy"] != "arm64-only":
        raise SystemExit("Only the arm64-only architecture policy is supported for this beta")
    if data["updateChannel"] != "stable":
        raise SystemExit("Only the stable update channel is supported for v1")
    if data["sparkleVersion"] != "2.9.2":
        raise SystemExit("Sparkle must remain pinned to reviewed version 2.9.2")
    if not re.fullmatch(r"https://[^\s]+", data["updateFeedURL"]):
        raise SystemExit("updateFeedURL must be an HTTPS URL")
    if data["updateCheckIntervalSeconds"] != 86400:
        raise SystemExit("updateCheckIntervalSeconds must remain one day")
    return data


def plist_for(
    config: dict[str, Any],
    *,
    include_environment_key: bool = True,
) -> dict[str, Any]:
    plist = {
        "CFBundleName": config["appName"],
        "CFBundleDisplayName": config["appName"],
        "CFBundleIdentifier": config["bundleIdentifier"],
        "CFBundleVersion": str(config["buildNumber"]),
        "CFBundleShortVersionString": config["marketingVersion"],
        "CFBundleExecutable": config["executableName"],
        "CFBundleIconFile": config["iconFile"],
        "CFBundlePackageType": config["packageType"],
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleURLTypes": [
            {
                "CFBundleTypeRole": "Viewer",
                "CFBundleURLName": "net.cmdtab.activation",
                "CFBundleURLSchemes": ["cmdtab"],
            }
        ],
        "LSMinimumSystemVersion": config["minimumSystemVersion"],
        "LSUIElement": bool(config["agentApplication"]),
        "NSHighResolutionCapable": bool(config["highResolutionCapable"]),
        "NSSupportsAutomaticTermination": False,
        "NSSupportsSuddenTermination": False,
        "SUFeedURL": config["updateFeedURL"],
        "SUScheduledCheckInterval": config["updateCheckIntervalSeconds"],
        "SUEnableSystemProfiling": False,
        "SURequireSignedFeed": True,
        "SUVerifyUpdateBeforeExtraction": True,
        "NSAccessibilityUsageDescription": (
            "CmdTab needs Accessibility permission to intercept Command-Tab and "
            "Option-Tab and activate the selected window."
        ),
        "NSScreenCaptureUsageDescription": (
            "CmdTab needs Screen Recording permission to display previews of your open windows. "
            "Captured window images stay on your Mac."
        ),
    }
    public_key = (
        os.environ.get("CMDTAB_SPARKLE_PUBLIC_ED_KEY", "").strip()
        if include_environment_key
        else ""
    )
    if public_key:
        try:
            decoded_key = base64.b64decode(public_key, validate=True)
        except ValueError as error:
            raise SystemExit("CMDTAB_SPARKLE_PUBLIC_ED_KEY must be valid base64") from error
        if len(decoded_key) != 32:
            raise SystemExit("CMDTAB_SPARKLE_PUBLIC_ED_KEY must decode to exactly 32 bytes")
        plist["SUPublicEDKey"] = public_key
    return plist


def render(config: dict[str, Any], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as handle:
        plistlib.dump(plist_for(config), handle, fmt=plistlib.FMT_XML, sort_keys=True)


def verify_info(
    config: dict[str, Any],
    path: Path,
    *,
    include_environment_key: bool = True,
) -> None:
    with path.open("rb") as handle:
        actual = plistlib.load(handle)
    expected = plist_for(config, include_environment_key=include_environment_key)
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


def reject_literal(path: Path, literal: str, description: str) -> None:
    text = path.read_text(encoding="utf-8")
    if literal in text:
        raise SystemExit(f"{description} remains in {path.relative_to(ROOT)}: {literal!r}")


def tracked_paths(pathspec: str) -> list[str]:
    try:
        result = subprocess.run(
            ["git", "-C", str(ROOT), "ls-files", "--", pathspec],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            return []
        return [line for line in result.stdout.splitlines() if line]
    except Exception:
        return []


def verify_repository(config: dict[str, Any]) -> None:
    verify_info(
        config,
        ROOT / "Resources" / "Info.plist",
        include_environment_key=False,
    )

    sensitive_paths = set(tracked_paths(".secrets"))
    for extension in ("pem", "key", "p12", "pfx", "cer", "crt", "der", "csr"):
        sensitive_paths.update(tracked_paths(f"*.{extension}"))
    if sensitive_paths:
        raise SystemExit(
            "Sensitive key or certificate material remains tracked:\n  "
            + "\n  ".join(sorted(sensitive_paths)[:20])
        )

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
    require_literal(
        identity_source,
        "import LocalAuthentication",
        "LocalAuthentication import for noninteractive Keychain access",
    )
    require_literal(
        identity_source,
        "kSecUseAuthenticationContext as String",
        "noninteractive Keychain authentication context",
    )
    require_literal(
        identity_source,
        "context.interactionNotAllowed = true",
        "noninteractive Keychain UI policy",
    )
    reject_literal(
        identity_source,
        "kSecUseAuthenticationUIFail",
        "deprecated Keychain authentication UI policy",
    )

    main_source = ROOT / "Sources" / "CmdTab" / "main.swift"
    require_literal(
        main_source,
        "BundleIdentityMigration.migrateIfNeeded()",
        "startup bundle-identity migration",
    )

    activation_source = ROOT / "Sources" / "CmdTab" / "ActivationDeepLink.swift"
    require_literal(
        activation_source,
        'static let scheme = "cmdtab"',
        "one-click activation URL scheme",
    )
    require_literal(
        activation_source,
        "maximumCodeLength = 4_096",
        "activation-link input bound",
    )

    build_tool = ROOT / "scripts" / "release" / "build-app.sh"
    require_literal(
        build_tool,
        "build_arguments+=( -Xlinker -reproducible )",
        "deterministic linker mode",
    )
    require_literal(
        build_tool,
        "-Xswiftc -gnone",
        "release debug-data exclusion",
    )
    reject_literal(
        build_tool,
        "-no_uuid",
        "release linker mode that removes the Mach-O UUID",
    )
    require_literal(
        build_tool,
        'BUILD_ARCHITECTURES="${CMDTAB_BUILD_ARCHITECTURES:-}"',
        "architecture build control",
    )
    require_literal(
        build_tool,
        '"arm64-apple-macosx13.0"',
        "Apple Silicon deployment target",
    )
    require_literal(
        build_tool,
        '-Xlinker "@executable_path/../Frameworks"',
        "embedded framework runtime search path",
    )

    package_tool = ROOT / "scripts" / "release" / "package-app.sh"
    require_literal(
        package_tool,
        "codesign --remove-signature",
        "unsigned reproducibility signature normalization",
    )

    package_manifest = ROOT / "Package.swift"
    require_literal(
        package_manifest,
        'exact: "2.9.2"',
        "exact Sparkle SwiftPM dependency",
    )
    resolved = json.loads((ROOT / "Package.resolved").read_text(encoding="utf-8"))
    sparkle_pins = [
        pin for pin in resolved.get("pins", [])
        if pin.get("identity") == "sparkle"
    ]
    if len(sparkle_pins) != 1 or sparkle_pins[0].get("state", {}).get("version") != "2.9.2":
        raise SystemExit("Package.resolved does not pin Sparkle 2.9.2 exactly")

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
