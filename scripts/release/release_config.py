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
    "commerceEnabled",
    "sparkleVersion",
    "updateCheckIntervalSeconds",
}

KEY_ID_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._/-]{0,127}")
# Canonical DER SubjectPublicKeyInfo encoding for id-ecPublicKey / prime256v1.
# A public verification key is intentionally allowed in the signed bundle; a
# private key cannot satisfy this exact SPKI representation.
P256_SPKI_PREFIX = bytes.fromhex("3059301306072A8648CE3D020106082A8648CE3D03010703420004")
P256_SPKI_LENGTH = 91

CHANNELS = {
    "development": {"distributionChannel": "local-qa", "feedURL": None},
    "beta": {"distributionChannel": "public-beta", "feedURL": "https://cmdtab.net/releases/beta/appcast.xml"},
    "stable": {"distributionChannel": "developer-id-direct", "feedURL": "https://cmdtab.net/releases/appcast.xml"},
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
    channel = data["updateChannel"]
    if channel not in CHANNELS:
        raise SystemExit("updateChannel must be development, beta, or stable")
    if data["distributionChannel"] != CHANNELS[channel]["distributionChannel"]:
        raise SystemExit("distributionChannel does not match updateChannel")
    if not isinstance(data["commerceEnabled"], bool):
        raise SystemExit("commerceEnabled must be a boolean")
    if channel == "beta" and data["commerceEnabled"]:
        raise SystemExit("Public beta must keep commerceEnabled false")
    if data["sparkleVersion"] != "2.9.2":
        raise SystemExit("Sparkle must remain pinned to reviewed version 2.9.2")
    if data["updateCheckIntervalSeconds"] != 86400:
        raise SystemExit("updateCheckIntervalSeconds must remain one day")
    # Feed selection is derived from the typed channel, never trusted as a
    # separately editable URL in release metadata.
    data["updateFeedURL"] = CHANNELS[channel]["feedURL"]
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
        "NSAccessibilityUsageDescription": (
            "CmdTab needs Accessibility permission to intercept Command-Tab and "
            "Option-Tab and activate the selected window."
        ),
        "NSScreenCaptureUsageDescription": (
            "CmdTab needs Screen Recording permission to display previews of your open windows. "
            "Captured window images stay on your Mac."
        ),
        "CmdTabCommerceEnabled": config["commerceEnabled"],
    }
    if config["updateFeedURL"] is not None:
        plist.update({
            "SUFeedURL": config["updateFeedURL"],
            "SUScheduledCheckInterval": config["updateCheckIntervalSeconds"],
            "SUEnableSystemProfiling": False,
            "SURequireSignedFeed": True,
            "SUVerifyUpdateBeforeExtraction": True,
        })
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
    trial_keyring = trial_public_keyring_from_environment() if include_environment_key else None
    if trial_keyring is not None:
        plist["CmdTabTrialPublicKeyring"] = trial_keyring
    # Paid activations return CMDTAB2 entitlements the app can only verify
    # with the embedded license keyring; without it every activation would
    # consume a server device slot and then fail locally with unknownKey.
    license_keyring = license_public_keyring_from_environment() if include_environment_key else None
    if license_keyring is not None:
        plist["CmdTabLicensePublicKeyring"] = license_keyring
    elif include_environment_key and config["commerceEnabled"]:
        raise SystemExit(
            "commerceEnabled requires CMDTAB_LICENSE_PUBLIC_KEYRING_JSON and "
            "CMDTAB_LICENSE_SIGNING_KID so paid entitlements can be verified"
        )
    return plist


def validate_public_keyring(raw: str, signing_kid: str, kind: str) -> dict[str, str]:
    """Accept only a non-empty public P-256 keyring containing the active kid.

    `kind` is "TRIAL" or "LICENSE" and names the environment variables.
    """
    keyring_var = f"CMDTAB_{kind}_PUBLIC_KEYRING_JSON"
    kid_var = f"CMDTAB_{kind}_SIGNING_KID"
    if not KEY_ID_PATTERN.fullmatch(signing_kid):
        raise SystemExit(f"{kid_var} must be a valid key identifier")
    try:
        decoded = json.loads(raw)
    except json.JSONDecodeError as error:
        raise SystemExit(f"{keyring_var} must be a JSON object") from error
    if not isinstance(decoded, dict) or not decoded:
        raise SystemExit(f"{keyring_var} must be a non-empty JSON object")

    keyring: dict[str, str] = {}
    for kid, encoded_key in decoded.items():
        if not isinstance(kid, str) or not KEY_ID_PATTERN.fullmatch(kid):
            raise SystemExit(f"{keyring_var} contains an invalid key identifier")
        if not isinstance(encoded_key, str):
            raise SystemExit(f"{keyring_var} contains a non-string key")
        try:
            key = base64.b64decode(encoded_key, validate=True)
        except ValueError as error:
            raise SystemExit(f"{keyring_var} contains invalid base64") from error
        if (
            base64.b64encode(key).decode("ascii") != encoded_key
            or len(key) != P256_SPKI_LENGTH
            or not key.startswith(P256_SPKI_PREFIX)
        ):
            raise SystemExit(f"{keyring_var} must contain canonical P-256 SPKI public keys")
        keyring[kid] = encoded_key
    if signing_kid not in keyring:
        raise SystemExit(f"{keyring_var} must contain {kid_var}")
    return keyring


def validate_trial_public_keyring(raw: str, signing_kid: str) -> dict[str, str]:
    return validate_public_keyring(raw, signing_kid, "TRIAL")


def public_keyring_from_environment(kind: str) -> dict[str, str] | None:
    raw = os.environ.get(f"CMDTAB_{kind}_PUBLIC_KEYRING_JSON", "").strip()
    if not raw:
        return None
    return validate_public_keyring(
        raw,
        os.environ.get(f"CMDTAB_{kind}_SIGNING_KID", "").strip(),
        kind,
    )


def trial_public_keyring_from_environment() -> dict[str, str] | None:
    return public_keyring_from_environment("TRIAL")


def license_public_keyring_from_environment() -> dict[str, str] | None:
    return public_keyring_from_environment("LICENSE")


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

    expected_channel_copy = {
        "development": "development update channel",
        "beta": "beta update channel",
        "stable": "stable update channel",
    }[config["updateChannel"]]
    require_literal(
        ROOT / "Sources" / "CmdTab" / "PreferencesView.swift",
        expected_channel_copy,
        "update-preferences channel copy",
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
    reject_literal(
        build_tool,
        "-no_uuid",
        "release linker mode that removes the Mach-O UUID",
    )
    require_literal(
        build_tool,
        'BUILD_ARCHITECTURES="${CMDTAB_BUILD_ARCHITECTURES:-}"',
        "credential-gated Universal Binary build control",
    )
    require_literal(
        build_tool,
        "lipo -create",
        "Universal Binary merge",
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
