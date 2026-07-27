#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import platform
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
MODULE_PATH = Path(__file__).with_name("evaluate-performance-evidence.py")
SPEC = importlib.util.spec_from_file_location("performance_evidence", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

SOURCE_SHA = "a" * 40


def measurement(index: int, *, rss: int = 100_000_000) -> dict:
    return {
        "index": index,
        "revealMilliseconds": 250.0,
        "selectionMilliseconds": 20.0,
        "observationCaptureMilliseconds": 8.0,
        "cpuMilliseconds": 15.0,
        "residentBytes": rss,
        "eventTapState": "responsive",
        "failure": None,
    }


def document(window_count: int, sessions: int, mode: str) -> dict:
    return {
        "metadata": {
            "schemaVersion": 1,
            "sourceSHA": SOURCE_SHA,
            "runKind": mode,
            "hostOS": "Test macOS",
            "hostArchitecture": platform.machine(),
            "cmdTabExecutableSHA256": "b" * 64,
            "windowLabExecutableSHA256": "c" * 64,
        },
        "preconditions": {
            "accessibilityTrusted": True,
            "screenCaptureAuthorized": True,
            "fixtureWindowCountExpected": window_count,
            "fixtureWindowCountObserved": window_count,
        },
        "measurements": [measurement(index) for index in range(1, sessions + 1)],
        "idleCPUPercent": 0.5,
        "evidenceState": "measured",
        "evidenceStateReason": "test",
        "eventTapObservationMethod": "test proxy",
    }


class PerformanceEvidenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write_documents(self, mode: str) -> list[tuple[Path, dict]]:
        matrix_sessions = MODULE.EXPECTED[mode]["matrix_sessions"]
        soak_sessions = MODULE.EXPECTED[mode]["soak_sessions"]
        values = [
            document(10, matrix_sessions, mode),
            document(25, matrix_sessions, mode),
            document(50, matrix_sessions, mode),
            document(50, soak_sessions, mode),
        ]
        output = []
        for index, value in enumerate(values):
            path = self.root / f"run-{index}.json"
            path.write_text(json.dumps(value), encoding="utf-8")
            output.append((path, value))
        return output

    def test_readiness_pass_never_becomes_acceptance(self) -> None:
        manifest, passed = MODULE.evaluate(
            self.write_documents("readiness"),
            mode="readiness",
            source_sha=SOURCE_SHA,
            source_clean=False,
        )
        self.assertTrue(passed)
        self.assertEqual(manifest["state"], "ready")
        self.assertFalse(manifest["acceptance_claim_allowed"])

    def test_acceptance_requires_clean_source(self) -> None:
        manifest, passed = MODULE.evaluate(
            self.write_documents("acceptance"),
            mode="acceptance",
            source_sha=SOURCE_SHA,
            source_clean=False,
        )
        self.assertFalse(passed)
        self.assertEqual(manifest["state"], "blocked")
        self.assertIn("clean Git worktree", " ".join(manifest["reasons"]))

    def test_blocked_raw_run_cannot_create_measurements(self) -> None:
        documents = self.write_documents("readiness")
        documents[0][1]["evidenceState"] = "blocked"
        documents[0][1]["measurements"] = []
        documents[0][0].write_text(
            json.dumps(documents[0][1]),
            encoding="utf-8",
        )
        manifest, passed = MODULE.evaluate(
            documents,
            mode="readiness",
            source_sha=SOURCE_SHA,
            source_clean=True,
        )
        self.assertFalse(passed)
        self.assertIn(
            "contain no measurements",
            " ".join(manifest["reasons"]),
        )

    def test_monotonic_rss_growth_is_rejected(self) -> None:
        documents = self.write_documents("readiness")
        target = documents[-1][1]
        for index, row in enumerate(target["measurements"]):
            row["residentBytes"] = 100_000_000 + index * 100_000
        documents[-1][0].write_text(json.dumps(target), encoding="utf-8")
        manifest, passed = MODULE.evaluate(
            documents,
            mode="readiness",
            source_sha=SOURCE_SHA,
            source_clean=True,
        )
        self.assertFalse(passed)
        self.assertIn(
            "warmed RSS increased on every sample",
            " ".join(manifest["reasons"]),
        )

    def test_threshold_regression_is_rejected(self) -> None:
        documents = self.write_documents("readiness")
        documents[1][1]["measurements"][-1]["revealMilliseconds"] = 900.0
        documents[1][0].write_text(
            json.dumps(documents[1][1]),
            encoding="utf-8",
        )
        manifest, passed = MODULE.evaluate(
            documents,
            mode="readiness",
            source_sha=SOURCE_SHA,
            source_clean=True,
        )
        self.assertFalse(passed)
        self.assertIn("reveal_p95_ms", " ".join(manifest["reasons"]))

    def test_non_finite_measurement_is_rejected(self) -> None:
        documents = self.write_documents("readiness")
        documents[0][1]["measurements"][0][
            "observationCaptureMilliseconds"
        ] = float("nan")
        documents[0][0].write_text(
            json.dumps(documents[0][1]),
            encoding="utf-8",
        )
        manifest, passed = MODULE.evaluate(
            documents,
            mode="readiness",
            source_sha=SOURCE_SHA,
            source_clean=True,
        )
        self.assertFalse(passed)
        self.assertIn(
            "invalid observationCaptureMilliseconds",
            " ".join(manifest["reasons"]),
        )

    def test_fixture_count_mismatch_is_rejected(self) -> None:
        documents = self.write_documents("readiness")
        documents[2][1]["preconditions"]["fixtureWindowCountObserved"] = 49
        documents[2][0].write_text(
            json.dumps(documents[2][1]),
            encoding="utf-8",
        )
        manifest, passed = MODULE.evaluate(
            documents,
            mode="readiness",
            source_sha=SOURCE_SHA,
            source_clean=True,
        )
        self.assertFalse(passed)
        self.assertIn("does not match expected", " ".join(manifest["reasons"]))

    def test_measured_run_requires_permissions_and_supported_schema(self) -> None:
        documents = self.write_documents("readiness")
        documents[0][1]["metadata"]["schemaVersion"] = 999
        documents[0][1]["preconditions"]["accessibilityTrusted"] = False
        documents[0][0].write_text(
            json.dumps(documents[0][1]),
            encoding="utf-8",
        )
        manifest, passed = MODULE.evaluate(
            documents,
            mode="readiness",
            source_sha=SOURCE_SHA,
            source_clean=True,
        )
        self.assertFalse(passed)
        reasons = " ".join(manifest["reasons"])
        self.assertIn("schema version", reasons)
        self.assertIn("requires Accessibility", reasons)


if __name__ == "__main__":
    unittest.main()
