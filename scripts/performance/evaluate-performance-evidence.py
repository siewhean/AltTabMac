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
    "reveal_p50_ms_max": 80.0,
    "reveal_p95_ms_max": 150.0,
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

INTERRUPTION_CODES = frozenset({
    "accessibility_unavailable",
    "screen_recording_unavailable",
    "secure_input_active",
    "event_tap_or_hid_rejected",
    "candidate_launch_mismatch",
    "candidate_frontmost_mismatch",
    "fixture_frontmost_mismatch",
    "fixture_window_count_mismatch",
    "cmdtab_terminated_or_unresponsive",
    "reveal_timeout",
    "selection_timeout",
    "observation_capture_unavailable",
})


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

    interruptions = [
        {
            "index": row.get("index"),
            "code": row.get("interruptionCode"),
            "detail": row.get("interruptionDetail"),
        }
        for row in measurements
        if row.get("interruptionCode")
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
        "prerequisite_interruptions": document.get("prerequisiteInterruptions", []),
        "reveal_p50_ms": percentile(numbers("revealMilliseconds"), 0.50),
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
        "missed_overlay_sessions": sum(
            row.get("interruptionCode") in {"event_tap_or_hid_rejected", "reveal_timeout"}
            for row in measurements
        ),
        "preview_integrity_failures": sum(
            row.get("previewIntegrity") != "observed"
            for row in measurements
        ),
        "cmdtab_not_running_sessions": sum(
            row.get("cmdTabRunningAfterSession") is not True
            for row in measurements
        ),
        "activation_outcomes": document.get("activationOutcomeMetrics"),
        "interruptions": interruptions,
    }


def validate_document(document: dict[str, Any], path: Path) -> list[str]:
    reasons: list[str] = []
    metadata = document.get("metadata", {})
    preconditions = document.get("preconditions", {})
    measurements = document.get("measurements")
    if metadata.get("schemaVersion") != 2:
        reasons.append(f"{path}: unsupported or missing raw schema version.")
    if not isinstance(metadata.get("hostOS"), str) or not metadata.get("hostOS"):
        reasons.append(f"{path}: hostOS is missing.")
    if metadata.get("hostArchitecture") not in {"arm64", "x86_64"}:
        reasons.append(f"{path}: hostArchitecture is missing or unsupported.")
    if not isinstance(measurements, list):
        return reasons + [f"{path}: measurements must be an array."]
    interruptions = document.get("prerequisiteInterruptions")
    if not isinstance(interruptions, list) or any(
        code not in INTERRUPTION_CODES for code in interruptions
    ):
        reasons.append(f"{path}: prerequisiteInterruptions must contain known codes.")
    activation_metrics = document.get("activationOutcomeMetrics")
    expected_activation_metric_keys = {
        "requested", "exactVerified", "applicationFallbackUnverified",
        "targetDisappeared", "accessibilityUnavailable", "verificationFailure",
    }
    if not isinstance(activation_metrics, dict) or set(activation_metrics) != expected_activation_metric_keys or any(
        not isinstance(value, int) or value < 0 for value in activation_metrics.values()
    ):
        reasons.append(f"{path}: activationOutcomeMetrics must contain non-negative outcome counters.")
    if preconditions.get("fixtureWindowCountObserved") != preconditions.get(
        "fixtureWindowCountExpected"
    ):
        reasons.append(f"{path}: observed fixture-window count does not match expected.")
    allowed_preconditions = {
        "secureInputObservation": {"not_observable_by_probe", "active"},
        "eventTapHIDObservation": {"external_behavioral_proxy_only", "rejected"},
        "candidateLaunchStatus": {"exact_bundle_verified", "mismatch"},
        "candidateFrontmostStatus": {"verified", "mismatch"},
        "cmdTabProcessRunning": {True, False},
    }
    for field, allowed in allowed_preconditions.items():
        if preconditions.get(field) not in allowed:
            reasons.append(f"{path}: {field} is missing or invalid.")
    if document.get("evidenceState") == "measured" and (
        preconditions.get("accessibilityTrusted") is not True
        or preconditions.get("screenCaptureAuthorized") is not True
    ):
        reasons.append(
            f"{path}: measured evidence requires Accessibility and Screen Recording."
        )
    if document.get("evidenceState") == "measured" and (
        preconditions.get("candidateLaunchStatus") != "exact_bundle_verified"
        or preconditions.get("candidateFrontmostStatus") != "verified"
        or preconditions.get("cmdTabProcessRunning") is not True
        or preconditions.get("secureInputObservation") != "not_observable_by_probe"
        or preconditions.get("eventTapHIDObservation") != "external_behavioral_proxy_only"
    ):
        reasons.append(f"{path}: measured evidence requires an exact running candidate.")
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
                if not row.get("interruptionCode"):
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
        interruption = row.get("interruptionCode")
        if interruption is not None and interruption not in INTERRUPTION_CODES:
            reasons.append(
                f"{path}: session {row.get('index')} has an unknown interruption code."
            )
        if interruption is None and row.get("interruptionDetail") is not None:
            reasons.append(
                f"{path}: session {row.get('index')} has interruption detail without a code."
            )
        if row.get("previewIntegrity") not in {"observed", "unavailable"}:
            reasons.append(
                f"{path}: session {row.get('index')} has invalid previewIntegrity."
            )
        if row.get("activationOutcome") not in {
            "fixture_application_frontmost_verified",
            "frontmost_mismatch",
            "not_observed",
        }:
            reasons.append(
                f"{path}: session {row.get('index')} has invalid activationOutcome."
            )
        if not isinstance(row.get("cmdTabRunningAfterSession"), bool):
            reasons.append(
                f"{path}: session {row.get('index')} is missing CmdTab liveness."
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
        reasons.append("One or more raw runs were blocked by typed prerequisite interruptions.")
    if any(run["prerequisite_interruptions"] for run in summaries):
        reasons.append("One or more raw runs have prerequisite interruptions.")

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
        ("reveal_p50_ms", "reveal_p50_ms_max"),
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
        if run["interruptions"]:
            reasons.append(
                f"{run['path']}: {len(run['interruptions'])} interrupted sessions."
            )
        if run["event_tap_unresponsive_sessions"]:
            reasons.append(
                f"{run['path']}: event-tap responsiveness proxy failed in "
                f"{run['event_tap_unresponsive_sessions']} sessions."
            )
        if run["missed_overlay_sessions"]:
            reasons.append(
                f"{run['path']}: {run['missed_overlay_sessions']} missed overlay/shortcut sessions."
            )
        if run["preview_integrity_failures"]:
            reasons.append(
                f"{run['path']}: {run['preview_integrity_failures']} preview-integrity failures."
            )
        if run["activation_outcomes"] is None:
            reasons.append(f"{run['path']}: activation outcome counters are missing.")
        else:
            activation_metrics = run["activation_outcomes"]
            terminal_outcomes = sum(
                activation_metrics[key]
                for key in (
                    "exactVerified",
                    "applicationFallbackUnverified",
                    "targetDisappeared",
                    "accessibilityUnavailable",
                    "verificationFailure",
                )
            )
            if activation_metrics["requested"] != run["sessions"]:
                reasons.append(
                    f"{run['path']}: requested activation count does not reconcile to sessions."
                )
            if terminal_outcomes != activation_metrics["requested"]:
                reasons.append(
                    f"{run['path']}: terminal activation outcomes do not reconcile to requests."
                )
            if mode == "acceptance" and activation_metrics["exactVerified"] != run["sessions"]:
                reasons.append(
                    f"{run['path']}: acceptance requires every activation to be exact-window verified."
                )
        if run["cmdtab_not_running_sessions"]:
            reasons.append(
                f"{run['path']}: CmdTab was not running after "
                f"{run['cmdtab_not_running_sessions']} sessions."
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
        "schema_version": 2,
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
