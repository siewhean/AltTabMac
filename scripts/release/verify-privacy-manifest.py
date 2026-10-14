#!/usr/bin/env python3
"""Validate CmdTab's macOS privacy manifest (PrivacyInfo.xcprivacy).

The expected contract mirrors what Sources/CmdTab actually does:
- no tracking and no tracking domains;
- data sent to cmdtab.net for trial/licensing and opt-in telemetry;
- required-reason APIs: UserDefaults (CA92.1) and system boot time (35F9.1).
Update this contract together with the manifest when the app's behaviour changes.
"""

from __future__ import annotations

import plistlib
import sys
from pathlib import Path

AF = "NSPrivacyCollectedDataTypePurposeAppFunctionality"
AN = "NSPrivacyCollectedDataTypePurposeAnalytics"

EXPECTED_ROOT_KEYS = {
    "NSPrivacyTracking",
    "NSPrivacyTrackingDomains",
    "NSPrivacyCollectedDataTypes",
    "NSPrivacyAccessedAPITypes",
}
EXPECTED_DATA_TYPES = {
    "NSPrivacyCollectedDataTypeEmailAddress": {AF},
    "NSPrivacyCollectedDataTypeDeviceID": {AF, AN},
    "NSPrivacyCollectedDataTypePurchaseHistory": {AF},
    "NSPrivacyCollectedDataTypeProductInteraction": {AN},
    "NSPrivacyCollectedDataTypeOtherDiagnosticData": {AF, AN},
    "NSPrivacyCollectedDataTypeOtherDataTypes": {AF},
}
EXPECTED_API_REASONS = {
    "NSPrivacyAccessedAPICategoryUserDefaults": {"CA92.1"},
    "NSPrivacyAccessedAPICategorySystemBootTime": {"35F9.1"},
}
ENTRY_KEYS = {
    "NSPrivacyCollectedDataType",
    "NSPrivacyCollectedDataTypeLinked",
    "NSPrivacyCollectedDataTypeTracking",
    "NSPrivacyCollectedDataTypePurposes",
}


def fail(message: str) -> None:
    print(f"Privacy manifest verification failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: verify-privacy-manifest.py /path/to/PrivacyInfo.xcprivacy", file=sys.stderr)
        raise SystemExit(2)

    manifest_path = Path(sys.argv[1])
    if not manifest_path.is_file():
        fail(f"missing {manifest_path}")

    try:
        with manifest_path.open("rb") as manifest_file:
            manifest = plistlib.load(manifest_file)
    except (OSError, plistlib.InvalidFileException) as error:
        fail(f"invalid plist: {error}")

    if not isinstance(manifest, dict) or set(manifest) != EXPECTED_ROOT_KEYS:
        fail("root keys do not match the expected contract")
    if manifest["NSPrivacyTracking"] is not False:
        fail("NSPrivacyTracking must be false")
    if manifest["NSPrivacyTrackingDomains"] != []:
        fail("NSPrivacyTrackingDomains must be empty")

    collected = manifest["NSPrivacyCollectedDataTypes"]
    if not isinstance(collected, list):
        fail("NSPrivacyCollectedDataTypes must be an array")
    actual_types: dict[str, set[str]] = {}
    for entry in collected:
        if not isinstance(entry, dict) or set(entry) != ENTRY_KEYS:
            fail("collected-data entry has unexpected shape")
        if entry["NSPrivacyCollectedDataTypeTracking"] is not False:
            fail(f"{entry['NSPrivacyCollectedDataType']} must not be used for tracking")
        if not isinstance(entry["NSPrivacyCollectedDataTypeLinked"], bool):
            fail(f"{entry['NSPrivacyCollectedDataType']} linked flag must be a boolean")
        data_type = entry["NSPrivacyCollectedDataType"]
        if data_type in actual_types:
            fail(f"duplicate collected-data entry {data_type}")
        actual_types[data_type] = set(entry["NSPrivacyCollectedDataTypePurposes"])
    if actual_types != EXPECTED_DATA_TYPES:
        fail(f"collected data types/purposes differ from contract: {actual_types}")

    accessed = manifest["NSPrivacyAccessedAPITypes"]
    if not isinstance(accessed, list):
        fail("NSPrivacyAccessedAPITypes must be an array")
    actual_apis: dict[str, set[str]] = {}
    for entry in accessed:
        if not isinstance(entry, dict) or set(entry) != {
            "NSPrivacyAccessedAPIType",
            "NSPrivacyAccessedAPITypeReasons",
        }:
            fail("accessed-API entry has unexpected shape")
        actual_apis[entry["NSPrivacyAccessedAPIType"]] = set(entry["NSPrivacyAccessedAPITypeReasons"])
    if actual_apis != EXPECTED_API_REASONS:
        fail(f"required-reason API declarations differ from contract: {actual_apis}")

    print(f"Privacy manifest verification passed: {manifest_path}")


if __name__ == "__main__":
    main()
