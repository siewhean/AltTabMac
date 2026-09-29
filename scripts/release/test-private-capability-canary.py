#!/usr/bin/env python3
"""Deterministic contract tests for the physical private-capability receipt."""

from __future__ import annotations

import importlib.util
import unittest
from copy import deepcopy
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("validate-private-capability-canary.py")
SPEC = importlib.util.spec_from_file_location("private_capability_canary", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def valid_receipt() -> dict:
    return {
        "schemaVersion": 1,
        "receiptKind": "cmdtab.private-capability-canary",
        "receiptState": "observed",
        "source": {
            "sha": "a" * 40,
            "branch": "main",
            "clean": True,
            "releaseConfigSHA256": "b" * 64,
        },
        "artifact": {
            "path": "/Applications/CmdTab.app",
            "sha256": "c" * 64,
            "bytes": 1234,
            "bundleIdentifier": "net.cmdtab.CmdTab",
            "marketingVersion": "1.0.0",
            "buildNumber": "1",
        },
        "host": {
            "productVersion": "14.7.1",
            "majorVersion": 14,
            "architecture": "arm64",
        },
        "recordedAt": "2026-09-09T00:00:00Z",
        "operatorAcknowledgement": {"authorizedMac": True, "noSecretsIncluded": True},
        "capabilities": {
            "axWindowIDBridge": {
                "state": "available",
                "failureReason": None,
                "fixtureWindowCount": 2,
                "roundTripResult": "exact_id_round_trip",
            },
            "skyLightExactFocus": {
                "state": "available",
                "failureReason": None,
                "iterations": 2,
                "exactVerifiedCount": 2,
                "nonExactOutcomeCount": 0,
                "wrongSiblingCount": 0,
            },
            "skyLightCapture": {
                "state": "available",
                "failureReason": None,
                "fixtureWindowCount": 2,
                "correctPreviewCount": 2,
                "truthfullyUnavailableCount": 0,
                "staleOrCrossWindowPreviewCount": 0,
            },
        },
    }


class PrivateCapabilityCanaryTests(unittest.TestCase):
    def test_valid_available_observation_is_schema_valid(self) -> None:
        self.assertEqual(MODULE.validate_document(valid_receipt()), [])

    def test_supported_major_versions_include_macos_15(self) -> None:
        receipt = valid_receipt()
        receipt["host"].update(productVersion="15.1", majorVersion=15, architecture="x86_64")
        self.assertEqual(MODULE.validate_document(receipt), [])

    def test_unavailable_state_requires_truthful_degradation(self) -> None:
        receipt = valid_receipt()
        receipt["receiptState"] = "blocked"
        receipt["capabilities"]["axWindowIDBridge"].update(
            state="unavailable",
            failureReason="Exact AX identity symbol unavailable on this OS build.",
            roundTripResult="identity_unavailable",
        )
        receipt["capabilities"]["skyLightExactFocus"].update(
            state="degraded",
            failureReason="Exact identity cannot be confirmed.",
            exactVerifiedCount=0,
            nonExactOutcomeCount=2,
        )
        receipt["capabilities"]["skyLightCapture"].update(
            state="unavailable",
            failureReason="Capture symbol unavailable.",
            correctPreviewCount=0,
            truthfullyUnavailableCount=2,
        )
        self.assertEqual(MODULE.validate_document(receipt), [])

    def test_wrong_sibling_requires_a_blocked_receipt(self) -> None:
        receipt = valid_receipt()
        receipt["capabilities"]["skyLightExactFocus"]["wrongSiblingCount"] = 1
        self.assertIn("receiptState=blocked", " ".join(MODULE.validate_document(receipt)))

        receipt["receiptState"] = "blocked"
        receipt["capabilities"]["skyLightExactFocus"].update(
            state="failed",
            failureReason="A sibling window received focus.",
            exactVerifiedCount=1,
            nonExactOutcomeCount=1,
        )
        self.assertEqual(MODULE.validate_document(receipt), [])

    def test_stale_preview_requires_a_blocked_receipt(self) -> None:
        receipt = valid_receipt()
        receipt["capabilities"]["skyLightCapture"].update(
            state="degraded",
            failureReason="One fixture used the public fallback.",
            correctPreviewCount=1,
            truthfullyUnavailableCount=1,
            staleOrCrossWindowPreviewCount=1,
        )
        self.assertIn("receiptState=blocked", " ".join(MODULE.validate_document(receipt)))
        receipt["receiptState"] = "blocked"
        self.assertEqual(MODULE.validate_document(receipt), [])

    def test_dirty_or_unsupported_host_is_rejected(self) -> None:
        receipt = valid_receipt()
        receipt["source"]["clean"] = False
        receipt["host"].update(productVersion="16.0", majorVersion=16)
        errors = " ".join(MODULE.validate_document(receipt))
        self.assertIn("source.clean", errors)
        self.assertIn("majorVersion", errors)

    def test_schema_rejects_unrecognized_receipt_data(self) -> None:
        receipt = deepcopy(valid_receipt())
        receipt["secret"] = "never include credentials"
        self.assertIn("exactly", " ".join(MODULE.validate_document(receipt)))


if __name__ == "__main__":
    unittest.main()
