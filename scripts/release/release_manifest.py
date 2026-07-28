#!/usr/bin/env python3
"""Create and validate the canonical stable release-manifest contract."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
CONFIG_PATH = ROOT / "release" / "ReleaseConfig.json"
SHA_PATTERN = re.compile(r"^[a-f0-9]{40}$")
HASH_PATTERN = re.compile(r"^[a-f0-9]{64}$")
VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+$")


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def https_url(value: str, name: str) -> str:
    parsed = urlparse(value)
    if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password:
        raise ValueError(f"{name} must be an HTTPS URL without credentials")
    if parsed.query or parsed.fragment:
        raise ValueError(f"{name} must not contain a query or fragment")
    return value


def validate_manifest(
    manifest: dict[str, object],
    *,
    artifact: Path | None = None,
    previous: dict[str, object] | None = None,
) -> None:
    expected_keys = {
        "schemaVersion", "channel", "version", "build", "minimumMacOS",
        "dmgURL", "bytes", "sha256", "releaseDate", "sourceSHA", "appcastURL",
    }
    if set(manifest) != expected_keys:
        raise ValueError("manifest keys do not match the stable v1 contract")
    if manifest["schemaVersion"] != 1 or manifest["channel"] != "stable":
        raise ValueError("only stable manifest schemaVersion 1 is supported")
    if not isinstance(manifest["version"], str) or not VERSION_PATTERN.fullmatch(manifest["version"]):
        raise ValueError("version must be x.y.z")
    if not isinstance(manifest["build"], int) or isinstance(manifest["build"], bool) or manifest["build"] < 1:
        raise ValueError("build must be a positive integer")
    if not isinstance(manifest["minimumMacOS"], str) or not re.fullmatch(r"\d+\.\d+(?:\.\d+)?", manifest["minimumMacOS"]):
        raise ValueError("minimumMacOS is invalid")
    dmg_url = https_url(str(manifest["dmgURL"]), "dmgURL")
    https_url(str(manifest["appcastURL"]), "appcastURL")
    if not isinstance(manifest["bytes"], int) or isinstance(manifest["bytes"], bool) or manifest["bytes"] < 1:
        raise ValueError("bytes must be a positive integer")
    if not isinstance(manifest["sha256"], str) or not HASH_PATTERN.fullmatch(manifest["sha256"]):
        raise ValueError("sha256 is invalid")
    if not isinstance(manifest["sourceSHA"], str) or not SHA_PATTERN.fullmatch(manifest["sourceSHA"]):
        raise ValueError("sourceSHA is invalid")
    try:
        dt.date.fromisoformat(str(manifest["releaseDate"]))
    except ValueError as error:
        raise ValueError("releaseDate must be YYYY-MM-DD") from error

    immutable_path = urlparse(dmg_url).path
    if manifest["sourceSHA"] not in immutable_path:
        raise ValueError("dmgURL path must contain sourceSHA to be immutable")
    expected_name = f"CmdTab-{manifest['version']}-{manifest['build']}.dmg"
    if not immutable_path.endswith(f"/{expected_name}"):
        raise ValueError(f"dmgURL must end in {expected_name}")

    if artifact is not None:
        if artifact.stat().st_size != manifest["bytes"]:
            raise ValueError("artifact byte count does not match manifest")
        if file_sha256(artifact) != manifest["sha256"]:
            raise ValueError("artifact SHA-256 does not match manifest")

    if previous is not None:
        validate_manifest(previous)
        if int(manifest["build"]) <= int(previous["build"]):
            raise ValueError("new stable build must be strictly greater than the published build")


def create_manifest(args: argparse.Namespace) -> dict[str, object]:
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    source_sha = args.source_sha.lower()
    if not SHA_PATTERN.fullmatch(source_sha):
        raise ValueError("source SHA must be exactly 40 lowercase hexadecimal characters")
    artifact = args.dmg.resolve()
    if not artifact.is_file() or artifact.stat().st_size < 1:
        raise ValueError("DMG artifact is missing or empty")
    manifest: dict[str, object] = {
        "schemaVersion": 1,
        "channel": "stable",
        "version": config["marketingVersion"],
        "build": int(config["buildNumber"]),
        "minimumMacOS": config["minimumSystemVersion"],
        "dmgURL": args.dmg_url,
        "bytes": artifact.stat().st_size,
        "sha256": file_sha256(artifact),
        "releaseDate": args.release_date,
        "sourceSHA": source_sha,
        "appcastURL": config["updateFeedURL"],
    }
    previous = load_json(args.previous) if args.previous else None
    validate_manifest(manifest, artifact=artifact, previous=previous)
    return manifest


def load_json(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("manifest root must be an object")
    return value


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    create = subparsers.add_parser("create")
    create.add_argument("--dmg", required=True, type=Path)
    create.add_argument("--dmg-url", required=True)
    create.add_argument("--source-sha", required=True)
    create.add_argument("--release-date", default=dt.date.today().isoformat())
    create.add_argument("--previous", type=Path)
    create.add_argument("--output", required=True, type=Path)
    validate = subparsers.add_parser("validate")
    validate.add_argument("manifest", type=Path)
    validate.add_argument("--artifact", type=Path)
    validate.add_argument("--previous", type=Path)
    args = parser.parse_args()

    try:
        if args.command == "create":
            manifest = create_manifest(args)
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            print(args.output)
        else:
            manifest = load_json(args.manifest)
            previous = load_json(args.previous) if args.previous else None
            validate_manifest(manifest, artifact=args.artifact, previous=previous)
            print("Stable release manifest validation passed")
    except (OSError, ValueError, json.JSONDecodeError) as error:
        raise SystemExit(str(error)) from error


if __name__ == "__main__":
    main()
