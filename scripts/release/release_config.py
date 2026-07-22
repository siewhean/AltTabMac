#!/usr/bin/env python3
"""Validate CmdTab release metadata and render a deterministic Info.plist."""

from __future__ import annotations

import argparse
import json
import plistlib
import re
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
    elif args.command == "validate":
        print("ReleaseConfig validation passed")


if __name__ == "__main__":
    main()
