#!/usr/bin/env python3
"""Validate raw CmdTab performance measurements without inventing evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import platform
import re
from pathlib import Path
from typing import Any

THRESHOLDS = {
    "reveal_p95_ms_max": 500.0,
    "selection_p95_ms_max": 600.0,
    "observation_capture_p95_ms_max": 500.0,
    "session_cpu_p95_ms_max": 100.0,
    "idle_cpu_percent_max": 1.0,
    "rss_growth_bytes_max": 32 * 1024 * 1024,
    "rss_slope_bytes_per_session_max": 64 * 1024,
}

EXPECTED = {
    "readiness": {"matrix_sessions": 3, "soak_sessions": 10},
    "acceptance": {"matrix_sessions": 100, "soak_sessions": 1000},
}


def percentile(values: list[float], fraction: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    index = max(0, math.ceil(fraction * len(ordered)) - 1)
    return ordered[index]


def linear_slope(values: list[int]) -> float:
    if len(values) < 2:
        return 0.0
    x_mean = (len(values) - 1) / 2
    y_mean = sum(values) / len(values)
    numerator = sum(
        (index - x_mean) * (value - y_mean)
        for index, value in enumerate(values)
    )
    denominator = sum((index - x_mean) ** 2 for index in range(len(values)))
    return numerator / denominator if denominator else 0.0


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def summarize_run(document: dict[str, Any], path: Path) -> dict[str, Any]:
    measurements = document.get("measurements", [])
    warmup = min(len(measurements), max(1, math.ceil(len(measurements) * 0.1)))
    rss = [
        int(row["residentBytes"])
        for row in measurements[warmup:]
        if row.get("residentBytes") is not None
    ]

    def numbers(field: str) -> list[float]:
        return [
            float(row[field])
            for row in measurements
            if row.get(field) is not None
        ]

    failures = [
        {"index": row.get("index"), "failure": row.get("failure")}
        for row in measurements
        if row.get("failure")
    ]
    unresponsive = sum(
        row.get("eventTapState") != "responsive" for row in measurements
    )
    enough_rss_samples = len(rss) >= 8
    return {
        "path": str(path),
        "sha256": sha256(path),
        "window_count": document.get("preconditions", {}).get(
            "fixtureWindowCountExpected"
        ),
        "observed_window_count": document.get("preconditions", {}).get(
            "fixtureWindowCountObserved"
        ),
        "sessions": len(measurements),
        "source_sha": document.get("metadata", {}).get("sourceSHA"),
        "run_kind": document.get("metadata", {}).get("runKind"),
        "host_os": document.get("metadata", {}).get("hostOS"),
        "host_architecture": document.get("metadata", {}).get("hostArchitecture"),
        "cmdtab_executable_sha256": document.get("metadata", {}).get(
            "cmdTabExecutableSHA256"
        ),
        "windowlab_executable_sha256": document.get("metadata", {}).get(
            "windowLabExecutableSHA256"
        ),
        "raw_evidence_state": document.get("evidenceState"),
        "reveal_p95_ms": percentile(numbers("revealMilliseconds"), 0.95),
        "selection_p95_ms": percentile(numbers("selectionMilliseconds"), 0.95),
        "observation_capture_p95_ms": percentile(
            numbers("observationCaptureMilliseconds"),
            0.95,
        ),
        "session_cpu_p95_ms": percentile(numbers("cpuMilliseconds"), 0.95),
        "idle_cpu_percent": document.get("idleCPUPercent"),
        "rss_growth_bytes": (
            rss[-1] - rss[0] if enough_rss_samples else None
        ),
        "rss_slope_bytes_per_session": (
            linear_slope(rss) if enough_rss_samples else None
        ),
        "rss_strictly_monotonic_increase": (
            enough_rss_samples
            and all(after > before for before, after in zip(rss, rss[1:]))
        ),
        "rss_samples_after_warmup": len(rss),
        "event_tap_unresponsive_sessions": unresponsive,
        "failures": failures,
    }


def validate_document(document: dict[str, Any], path: Path) -> list[str]:
    reasons: list[str] = []
    metadata = document.get("metadata", {})
    preconditions = document.get("preconditions", {})
    measurements = document.get("measurements")
    if metadata.get("schemaVersion") != 1:
        reasons.append(f"{path}: unsupported or missing raw schema version.")
    if not isinstance(metadata.get("hostOS"), str) or not metadata.get("hostOS"):
        reasons.append(f"{path}: hostOS is missing.")
    if metadata.get("hostArchitecture") not in {"arm64", "x86_64"}:
        reasons.append(f"{path}: hostArchitecture is missing or unsupported.")
    if not isinstance(measurements, list):
        return reasons + [f"{path}: measurements must be an array."]
    if preconditions.get("fixtureWindowCountObserved") != preconditions.get(
        "fixtureWindowCountExpected"
    ):
        reasons.append(f"{path}: observed fixture-window count does not match expected.")
    if document.get("evidenceState") == "measured" and (
        preconditions.get("accessibilityTrusted") is not True
        or preconditions.get("screenCaptureAuthorized") is not True
    ):
        reasons.append(
            f"{path}: measured evidence requires Accessibility and Screen Recording."
        )
    for field in ("cmdTabExecutableSHA256", "windowLabExecutableSHA256"):
        value = metadata.get(field)
        if not isinstance(value, str) or re.fullmatch(r"[0-9a-f]{64}", value) is None:
            reasons.append(f"{path}: {field} is not a SHA-256 value.")
    if [row.get("index") for row in measurements] != list(
        range(1, len(measurements) + 1)
    ):
        reasons.append(f"{path}: session indexes are not exact and contiguous.")

    numeric_fields = (
        "revealMilliseconds",
        "selectionMilliseconds",
        "observationCaptureMilliseconds",
        "cpuMilliseconds",
        "residentBytes",
    )
    for row in measurements:
        for field in numeric_fields:
            value = row.get(field)
            if value is None:
                if not row.get("failure"):
                    reasons.append(
                        f"{path}: successful session {row.get('index')} is missing {field}."
                    )
                continue
            if (
                not isinstance(value, (int, float))
                or isinstance(value, bool)
                or not math.isfinite(float(value))
                or float(value) < 0
            ):
                reasons.append(
                    f"{path}: session {row.get('index')} has invalid {field}."
                )
    idle_cpu = document.get("idleCPUPercent")
    if (
        not isinstance(idle_cpu, (int, float))
        or isinstance(idle_cpu, bool)
        or not math.isfinite(float(idle_cpu))
        or float(idle_cpu) < 0
    ):
        reasons.append(f"{path}: idleCPUPercent is missing or invalid.")
    return reasons


def evaluate(
    documents: list[tuple[Path, dict[str, Any]]],
    *,
    mode: str,
    source_sha: str,
    source_clean: bool,
) -> tuple[dict[str, Any], bool]:
    summaries = [summarize_run(document, path) for path, document in documents]
    reasons: list[str] = []
    expected = EXPECTED[mode]

    if len(documents) != 4:
        reasons.append("Exactly four raw runs are required.")
    for path, document in documents:
        reasons.extend(validate_document(document, path))
    if mode == "acceptance" and not source_clean:
        reasons.append("Acceptance requires a clean Git worktree.")
    if any(run["source_sha"] != source_sha for run in summaries):
        reasons.append("One or more raw runs are bound to a different source SHA.")
    if any(run["run_kind"] != mode for run in summaries):
        reasons.append("One or more raw runs use a different run kind.")
    if any(run["raw_evidence_state"] != "measured" for run in summaries):
        reasons.append("One or more raw runs were blocked and contain no measurements.")

    matrix = [
        run for run in summaries
        if run["sessions"] == expected["matrix_sessions"]
    ]
    soak = [
        run for run in summaries
        if run["sessions"] == expected["soak_sessions"]
        and run["window_count"] == 50
    ]
    if sorted(run["window_count"] for run in matrix) != [10, 25, 50]:
        reasons.append(
            "The exact 10/25/50-window matrix is incomplete or has the wrong session count."
        )
    if len(soak) != 1:
        reasons.append("The exact 50-window soak run is missing or duplicated.")

    executable_hashes = {
        run["cmdtab_executable_sha256"] for run in summaries
        if run["cmdtab_executable_sha256"]
    }
    fixture_hashes = {
        run["windowlab_executable_sha256"] for run in summaries
        if run["windowlab_executable_sha256"]
    }
    if len(executable_hashes) != 1:
        reasons.append("Raw runs do not bind to one CmdTab executable.")
    if len(fixture_hashes) != 1:
        reasons.append("Raw runs do not bind to one WindowLab executable.")
    host_operating_systems = {run["host_os"] for run in summaries if run["host_os"]}
    host_architectures = {
        run["host_architecture"] for run in summaries if run["host_architecture"]
    }
    if len(host_operating_systems) != 1 or len(host_architectures) != 1:
        reasons.append("Raw runs do not come from one consistent measurement host.")
    if host_architectures != {platform.machine()}:
        reasons.append(
            "Raw measurement architecture does not match the evaluator host."
        )

    always_required_checks = [
        ("reveal_p95_ms", "reveal_p95_ms_max"),
        ("selection_p95_ms", "selection_p95_ms_max"),
        (
            "observation_capture_p95_ms",
            "observation_capture_p95_ms_max",
        ),
        ("session_cpu_p95_ms", "session_cpu_p95_ms_max"),
        ("idle_cpu_percent", "idle_cpu_percent_max"),
    ]
    for run in summaries:
        if run["failures"]:
            reasons.append(f"{run['path']}: {len(run['failures'])} failed sessions.")
        if run["event_tap_unresponsive_sessions"]:
            reasons.append(
                f"{run['path']}: event-tap responsiveness proxy failed in "
                f"{run['event_tap_unresponsive_sessions']} sessions."
            )
        if run["rss_strictly_monotonic_increase"]:
            reasons.append(f"{run['path']}: warmed RSS increased on every sample.")
        for measured, threshold in always_required_checks:
            value = run[measured]
            if value is None:
                reasons.append(f"{run['path']}: missing {measured}.")
            elif float(value) > THRESHOLDS[threshold]:
                reasons.append(
                    f"{run['path']}: {measured}={value:.3f} exceeds "
                    f"{THRESHOLDS[threshold]:.3f}."
                )
        if run["rss_samples_after_warmup"] >= 8:
            for measured, threshold in [
                ("rss_growth_bytes", "rss_growth_bytes_max"),
                (
                    "rss_slope_bytes_per_session",
                    "rss_slope_bytes_per_session_max",
                ),
            ]:
                value = run[measured]
                if value is None:
                    reasons.append(f"{run['path']}: missing {measured}.")
                elif float(value) > THRESHOLDS[threshold]:
                    reasons.append(
                        f"{run['path']}: {measured}={value:.3f} exceeds "
                        f"{THRESHOLDS[threshold]:.3f}."
                    )

    passed = not reasons
    state = (
        "accepted"
        if passed and mode == "acceptance"
        else "ready"
        if passed
        else "blocked"
    )
    manifest = {
        "schema_version": 1,
        "source_sha": source_sha,
        "source_clean": source_clean,
        "mode": mode,
        "state": state,
        "acceptance_claim_allowed": state == "accepted",
        "measurement_host": {
            "operating_system": next(iter(host_operating_systems), None),
            "architecture": next(iter(host_architectures), None),
        },
        "evaluator_host": {
            "system": platform.system(),
            "architecture": platform.machine(),
        },
        "thresholds": THRESHOLDS,
        "runs": summaries,
        "reasons": reasons,
        "interpretation": (
            "A readiness result validates harness operation only. Acceptance requires "
            "a clean source tree, the full real-machine matrix, and all thresholds."
        ),
    }
    return manifest, passed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=EXPECTED, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--source-clean", choices=["true", "false"], required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("raw_results", nargs="+", type=Path)
    arguments = parser.parse_args()

    documents = [
        (path, json.loads(path.read_text(encoding="utf-8")))
        for path in arguments.raw_results
    ]
    manifest, passed = evaluate(
        documents,
        mode=arguments.mode,
        source_sha=arguments.source_sha,
        source_clean=arguments.source_clean == "true",
    )
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"Performance evidence: {manifest['state']}")
    for reason in manifest["reasons"]:
        print(f"- {reason}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
