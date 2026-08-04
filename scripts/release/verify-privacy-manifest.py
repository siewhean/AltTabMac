#!/usr/bin/env python3
"""Validate CmdTab's fixed, aggregate-only macOS privacy manifest."""

from __future__ import annotations

import plistlib
import sys
from pathlib import Path


EXPECTED_DATA_TYPES = {
    "NSPrivacyCollectedDataTypeProductInteraction",
    "NSPrivacyCollectedDataTypePurchaseHistory",
    "NSPrivacyCollectedDataTypeOtherDataTypes",
}
EXPECTED_PURPOSES = {"NSPrivacyCollectedDataTypePurposeAnalytics"}
EXPECTED_ROOT_KEYS = {
    "NSPrivacyTracking",
    "NSPrivacyCollectedDataTypes",
    "NSPrivacyAccessedAPITypes",
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
        fail("root keys do not match the fixed aggregate-only contract")
    if manifest["NSPrivacyTracking"] is not False:
        fail("tracking must be false")
    if manifest["NSPrivacyAccessedAPITypes"] != []:
        fail("macOS bundle must not declare unreviewed required-reason APIs")

    collected = manifest["NSPrivacyCollectedDataTypes"]
    if not isinstance(collected, list) or len(collected) != len(EXPECTED_DATA_TYPES):
        fail("collected-data entries do not match the fixed contract")

    actual_types: set[str] = set()
    for entry in collected:
        if not isinstance(entry, dict):
            fail("collected-data entry is not a dictionary")
        expected_entry_keys = {
            "NSPrivacyCollectedDataType",
            "NSPrivacyCollectedDataTypeLinked",
            "NSPrivacyCollectedDataTypeTracking",
            "NSPrivacyCollectedDataTypePurposes",
        }
        if set(entry) != expected_entry_keys:
            fail("collected-data entry contains an unexpected key")
        if entry["NSPrivacyCollectedDataTypeLinked"] is not False:
            fail("collected data must not be linked to a user")
        if entry["NSPrivacyCollectedDataTypeTracking"] is not False:
            fail("collected data must not be used for tracking")
        if set(entry["NSPrivacyCollectedDataTypePurposes"]) != EXPECTED_PURPOSES:
            fail("collected-data purposes must be analytics only")
        actual_types.add(entry["NSPrivacyCollectedDataType"])

    if actual_types != EXPECTED_DATA_TYPES:
        fail("collected data types do not match the fixed contract")

    print(f"Privacy manifest verification passed: {manifest_path}")


if __name__ == "__main__":
    main()
