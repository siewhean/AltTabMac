#!/usr/bin/env python3
"""Create and verify fail-closed, candidate-bound release evidence receipts."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import platform
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMA_VERSION = 1


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(ROOT), *args], text=True
    ).strip()


def assert_candidate(candidate: str, branch: str) -> None:
    if len(candidate) != 40 or any(char not in "0123456789abcdef" for char in candidate):
        raise ValueError("candidate SHA must be 40 lowercase hexadecimal characters")
    if git("rev-parse", "HEAD") != candidate:
        raise ValueError("requested candidate SHA does not match HEAD")
    if git("branch", "--show-current") != branch:
        raise ValueError("requested branch does not match the checked-out branch")
    if git("status", "--porcelain=v1", "--untracked-files=all"):
        raise ValueError("candidate evidence requires a completely clean worktree")


def command_result(command: str) -> dict[str, object]:
    completed = subprocess.run(
        command,
        shell=True,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    output_hash = hashlib.sha256(completed.stdout.encode("utf-8")).hexdigest()
    return {
        "command": command,
        "exitCode": completed.returncode,
        "outputSHA256": output_hash,
    }


def record(args: argparse.Namespace) -> None:
    candidate = args.candidate.lower()
    assert_candidate(candidate, args.branch)
    config = args.config.resolve()
    if not config.is_file():
        raise ValueError("release configuration is missing")

    build_result = command_result(args.build_command)
    test_results = [command_result(command) for command in args.test_command]
    artifact = args.artifact.resolve()
    if not artifact.is_file() or artifact.stat().st_size == 0:
        raise ValueError("build command did not produce the required artifact")

    receipt: dict[str, object] = {
        "schemaVersion": SCHEMA_VERSION,
        "status": "PASS" if build_result["exitCode"] == 0 and all(result["exitCode"] == 0 for result in test_results) else "FAIL",
        "sourceSHA": candidate,
        "branch": args.branch,
        "sourceClean": True,
        "releaseConfig": {
            "path": str(config.relative_to(ROOT)),
            "sha256": sha256(config),
        },
        "artifact": {
            "path": str(artifact),
            "bytes": artifact.stat().st_size,
            "sha256": sha256(artifact),
        },
        "build": build_result,
        "tests": test_results,
        "host": {
            "os": platform.platform(),
            "architecture": platform.machine(),
        },
        "recordedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if receipt["status"] != "PASS":
        raise SystemExit("candidate evidence recorded a failed build or test command")
    print(args.output)


def verify(args: argparse.Namespace) -> None:
    receipt = json.loads(args.receipt.read_text(encoding="utf-8"))
    required = {
        "schemaVersion", "status", "sourceSHA", "branch", "sourceClean", "releaseConfig",
        "artifact", "build", "tests", "host", "recordedAt",
    }
    if set(receipt) != required or receipt["schemaVersion"] != SCHEMA_VERSION:
        raise ValueError("candidate evidence receipt schema is invalid")
    if receipt["status"] != "PASS" or receipt["sourceClean"] is not True:
        raise ValueError("candidate evidence receipt is not a PASS from a clean source")
    candidate = args.candidate.lower()
    if receipt["sourceSHA"] != candidate or receipt["branch"] != args.branch:
        raise ValueError("receipt candidate identity does not match the requested release")
    assert_candidate(candidate, args.branch)
    config = args.config.resolve()
    artifact = args.artifact.resolve()
    if not config.is_file() or not artifact.is_file():
        raise ValueError("receipt configuration or artifact is missing")
    if receipt["releaseConfig"] != {"path": str(config.relative_to(ROOT)), "sha256": sha256(config)}:
        raise ValueError("receipt release configuration does not match")
    expected_artifact = receipt["artifact"]
    if not isinstance(expected_artifact, dict) or expected_artifact.get("sha256") != sha256(artifact) or expected_artifact.get("bytes") != artifact.stat().st_size:
        raise ValueError("receipt artifact does not match")
    records = [receipt["build"], *receipt["tests"]]
    if any(not isinstance(record, dict) or record.get("exitCode") != 0 for record in records):
        raise ValueError("receipt contains a failed build or test command")
    print("Candidate evidence verification passed")


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--candidate", required=True)
    common.add_argument("--branch", required=True)
    common.add_argument("--config", type=Path, default=ROOT / "release" / "ReleaseConfig.json")
    common.add_argument("--artifact", type=Path, required=True)
    create = subparsers.add_parser("record", parents=[common])
    create.add_argument("--build-command", required=True)
    create.add_argument("--test-command", action="append", default=[])
    create.add_argument("--output", required=True, type=Path)
    validate = subparsers.add_parser("verify", parents=[common])
    validate.add_argument("receipt", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "record":
            record(args)
        else:
            verify(args)
    except (OSError, ValueError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        raise SystemExit(str(error)) from error


if __name__ == "__main__":
    main()
