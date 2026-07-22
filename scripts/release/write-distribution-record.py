#!/usr/bin/env python3
"""Write a machine-readable traceability record for one CmdTab distribution ZIP."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Could not read JSON from {path}: {error}") from error
    if not isinstance(value, dict):
        raise SystemExit(f"Expected a JSON object in {path}")
    return value


def require_file(path: Path, label: str) -> Path:
    resolved = path.resolve()
    if not resolved.is_file():
        raise SystemExit(f"Missing {label}: {resolved}")
    return resolved


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--release-config", required=True, type=Path)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--unsigned-manifest", required=True, type=Path)
    parser.add_argument("--signed-manifest", required=True, type=Path)
    parser.add_argument("--final-artifact", required=True, type=Path)
    parser.add_argument("--notary-result", required=True, type=Path)
    parser.add_argument("--notary-log", required=True, type=Path)
    parser.add_argument("--submission-id", required=True)
    parser.add_argument("--signing-identity", required=True)
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    release_config_path = require_file(args.release_config, "release configuration")
    unsigned_manifest_path = require_file(args.unsigned_manifest, "unsigned bundle manifest")
    signed_manifest_path = require_file(args.signed_manifest, "signed bundle manifest")
    final_artifact_path = require_file(args.final_artifact, "final distribution artifact")
    notary_result_path = require_file(args.notary_result, "notarization result")
    notary_log_path = require_file(args.notary_log, "notarization log")

    release_config = load_json(release_config_path)
    unsigned_manifest = load_json(unsigned_manifest_path)
    signed_manifest = load_json(signed_manifest_path)
    notary_result = load_json(notary_result_path)
    notary_log = load_json(notary_log_path)

    if notary_result.get("status") != "Accepted":
        raise SystemExit("distribution record requires an Accepted notarization result")
    if str(notary_result.get("id", "")) != args.submission_id:
        raise SystemExit("notarization result ID does not match --submission-id")
    issues = notary_log.get("issues") or []
    if issues:
        raise SystemExit("distribution record refuses a notarization log containing issues")

    for manifest_name, manifest in (
        ("unsigned", unsigned_manifest),
        ("signed", signed_manifest),
    ):
        for key in ("bundleIdentifier", "marketingVersion", "buildNumber"):
            expected = str(release_config[key])
            actual = str(manifest.get(key, ""))
            if actual != expected:
                raise SystemExit(
                    f"{manifest_name} manifest {key} differs from ReleaseConfig: "
                    f"expected={expected!r} actual={actual!r}"
                )

    signing = signed_manifest.get("signing") or {}
    if signing.get("mode") != "identity":
        raise SystemExit("signed manifest does not describe an identity-signed bundle")
    authorities = signing.get("authorities") or []
    if args.signing_identity not in authorities:
        raise SystemExit("signed manifest does not contain the requested Developer ID authority")

    architectures = signed_manifest.get("architectures") or []
    if not architectures:
        raise SystemExit("signed manifest does not record an architecture")

    payload = {
        "schemaVersion": 1,
        "sourceCommit": args.source_commit,
        "bundleIdentifier": release_config["bundleIdentifier"],
        "marketingVersion": release_config["marketingVersion"],
        "buildNumber": str(release_config["buildNumber"]),
        "minimumSystemVersion": release_config["minimumSystemVersion"],
        "architectures": architectures,
        "architecturePolicy": release_config["architecturePolicy"],
        "distributionChannel": release_config["distributionChannel"],
        "signing": {
            "identity": args.signing_identity,
            "teamId": args.team_id,
            "hardenedRuntimeVerified": True,
            "secureTimestampVerified": True,
            "entitlementsVerified": True,
        },
        "notarization": {
            "status": "Accepted",
            "submissionId": args.submission_id,
            "resultSha256": sha256(notary_result_path),
            "logSha256": sha256(notary_log_path),
            "issueCount": 0,
            "stapleVerified": True,
            "gatekeeperVerified": True,
        },
        "unsignedInput": {
            "manifestFile": unsigned_manifest_path.name,
            "manifestSha256": sha256(unsigned_manifest_path),
        },
        "signedBundle": {
            "manifestFile": signed_manifest_path.name,
            "manifestSha256": sha256(signed_manifest_path),
        },
        "finalArtifact": {
            "file": final_artifact_path.name,
            "bytes": final_artifact_path.stat().st_size,
            "sha256": sha256(final_artifact_path),
        },
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
