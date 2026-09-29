#!/usr/bin/env python3
"""Fail-closed validator for physical CmdTab private-capability canaries.

The receipt is intentionally an observation, not a release PASS. It binds a
single signed artifact and clean source candidate to one authorized macOS 14 or
15 Mac while preserving the capability's declared degraded behaviour.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import plistlib
import re
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_VERSION = 1
RECEIPT_KIND = "cmdtab.private-capability-canary"
CAPABILITY_STATES = frozenset({"available", "degraded", "unavailable", "failed"})
REQUIRED_CAPABILITIES = frozenset({
    "axWindowIDBridge", "skyLightExactFocus", "skyLightCapture",
})
SHA40 = re.compile(r"[a-f0-9]{40}")
SHA256 = re.compile(r"[a-f0-9]{64}")
VERSION = re.compile(r"\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def is_int(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def require_exact_keys(value: object, keys: set[str], label: str, errors: list[str]) -> dict[str, Any] | None:
    if not isinstance(value, dict):
        fail(errors, f"{label} must be an object.")
        return None
    if set(value) != keys:
        fail(errors, f"{label} must contain exactly: {', '.join(sorted(keys))}.")
    return value


def validate_capability_base(name: str, value: object, required: set[str], errors: list[str]) -> dict[str, Any] | None:
    item = require_exact_keys(value, required, f"capabilities.{name}", errors)
    if item is None:
        return None
    state = item.get("state")
    reason = item.get("failureReason")
    if state not in CAPABILITY_STATES:
        fail(errors, f"capabilities.{name}.state is invalid.")
    if state == "available" and reason is not None:
        fail(errors, f"capabilities.{name}.available must have a null failureReason.")
    if state != "available" and (not isinstance(reason, str) or not reason.strip()):
        fail(errors, f"capabilities.{name}.{state} requires a non-empty failureReason.")
    return item


def validate_document(receipt: object) -> list[str]:
    errors: list[str] = []
    document = require_exact_keys(
        receipt,
        {"schemaVersion", "receiptKind", "receiptState", "source", "artifact", "host", "recordedAt", "operatorAcknowledgement", "capabilities"},
        "receipt",
        errors,
    )
    if document is None:
        return errors
    if document.get("schemaVersion") != SCHEMA_VERSION:
        fail(errors, "receipt schemaVersion is unsupported.")
    if document.get("receiptKind") != RECEIPT_KIND:
        fail(errors, "receiptKind is invalid.")
    if document.get("receiptState") not in {"observed", "blocked"}:
        fail(errors, "receiptState must be observed or blocked.")

    source = require_exact_keys(document.get("source"), {"sha", "branch", "clean", "releaseConfigSHA256"}, "source", errors)
    if source:
        if not isinstance(source.get("sha"), str) or not SHA40.fullmatch(source["sha"]):
            fail(errors, "source.sha must be a lowercase 40-character SHA.")
        if not isinstance(source.get("branch"), str) or not source["branch"].strip():
            fail(errors, "source.branch is required.")
        if source.get("clean") is not True:
            fail(errors, "source.clean must be true.")
        if not isinstance(source.get("releaseConfigSHA256"), str) or not SHA256.fullmatch(source["releaseConfigSHA256"]):
            fail(errors, "source.releaseConfigSHA256 must be a lowercase SHA-256.")

    artifact = require_exact_keys(document.get("artifact"), {"path", "sha256", "bytes", "bundleIdentifier", "marketingVersion", "buildNumber"}, "artifact", errors)
    if artifact:
        if not isinstance(artifact.get("path"), str) or not artifact["path"].strip():
            fail(errors, "artifact.path is required.")
        if not isinstance(artifact.get("sha256"), str) or not SHA256.fullmatch(artifact["sha256"]):
            fail(errors, "artifact.sha256 must be a lowercase SHA-256.")
        if not is_int(artifact.get("bytes")) or artifact["bytes"] < 1:
            fail(errors, "artifact.bytes must be a positive integer.")
        if artifact.get("bundleIdentifier") != "net.cmdtab.CmdTab":
            fail(errors, "artifact.bundleIdentifier must be net.cmdtab.CmdTab.")
        if not isinstance(artifact.get("marketingVersion"), str) or not VERSION.fullmatch(artifact["marketingVersion"]):
            fail(errors, "artifact.marketingVersion is invalid.")
        if not isinstance(artifact.get("buildNumber"), str) or not re.fullmatch(r"[1-9]\d*", artifact["buildNumber"]):
            fail(errors, "artifact.buildNumber is invalid.")

    host = require_exact_keys(document.get("host"), {"productVersion", "majorVersion", "architecture"}, "host", errors)
    if host:
        major = host.get("majorVersion")
        product = host.get("productVersion")
        if major not in {14, 15}:
            fail(errors, "host.majorVersion must be 14 or 15.")
        if not isinstance(product, str) or not re.fullmatch(r"(14|15)(?:\.\d+){0,2}", product):
            fail(errors, "host.productVersion must be a macOS 14 or 15 version.")
        elif is_int(major) and int(product.split(".")[0]) != major:
            fail(errors, "host.productVersion does not match host.majorVersion.")
        if host.get("architecture") not in {"arm64", "x86_64"}:
            fail(errors, "host.architecture must be arm64 or x86_64.")

    timestamp = document.get("recordedAt")
    if not isinstance(timestamp, str):
        fail(errors, "recordedAt must be an RFC 3339 timestamp.")
    else:
        try:
            dt.datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
        except ValueError:
            fail(errors, "recordedAt must be an RFC 3339 timestamp.")

    acknowledgement = require_exact_keys(document.get("operatorAcknowledgement"), {"authorizedMac", "noSecretsIncluded"}, "operatorAcknowledgement", errors)
    if acknowledgement:
        if acknowledgement.get("authorizedMac") is not True:
            fail(errors, "operatorAcknowledgement.authorizedMac must be true.")
        if acknowledgement.get("noSecretsIncluded") is not True:
            fail(errors, "operatorAcknowledgement.noSecretsIncluded must be true.")

    capabilities = document.get("capabilities")
    if not isinstance(capabilities, dict) or set(capabilities) != REQUIRED_CAPABILITIES:
        fail(errors, "capabilities must contain exactly the three required canaries.")
        return errors

    bridge = validate_capability_base("axWindowIDBridge", capabilities["axWindowIDBridge"], {"state", "failureReason", "fixtureWindowCount", "roundTripResult"}, errors)
    focus = validate_capability_base("skyLightExactFocus", capabilities["skyLightExactFocus"], {"state", "failureReason", "iterations", "exactVerifiedCount", "nonExactOutcomeCount", "wrongSiblingCount"}, errors)
    capture = validate_capability_base("skyLightCapture", capabilities["skyLightCapture"], {"state", "failureReason", "fixtureWindowCount", "correctPreviewCount", "truthfullyUnavailableCount", "staleOrCrossWindowPreviewCount"}, errors)

    if bridge:
        if not is_int(bridge.get("fixtureWindowCount")) or bridge["fixtureWindowCount"] < 2:
            fail(errors, "axWindowIDBridge.fixtureWindowCount must be at least 2.")
        if bridge.get("roundTripResult") not in {"exact_id_round_trip", "identity_unavailable"}:
            fail(errors, "axWindowIDBridge.roundTripResult is invalid.")
        elif bridge.get("state") == "available" and bridge.get("roundTripResult") != "exact_id_round_trip":
            fail(errors, "available axWindowIDBridge requires an exact ID round trip.")
        elif bridge.get("state") != "available" and bridge.get("roundTripResult") != "identity_unavailable":
            fail(errors, "degraded axWindowIDBridge must report identity_unavailable.")

    receipt_state = document.get("receiptState")
    if focus:
        numeric = ["iterations", "exactVerifiedCount", "nonExactOutcomeCount", "wrongSiblingCount"]
        if any(not is_int(focus.get(name)) or focus[name] < 0 for name in numeric):
            fail(errors, "skyLightExactFocus counters must be non-negative integers.")
        elif focus["iterations"] < 2:
            fail(errors, "skyLightExactFocus requires at least two sibling selections.")
        elif focus["exactVerifiedCount"] + focus["nonExactOutcomeCount"] != focus["iterations"]:
            fail(errors, "skyLightExactFocus outcome counters must equal iterations.")
        if focus.get("wrongSiblingCount", 0) > 0 and receipt_state != "blocked":
            fail(errors, "a wrong sibling activation requires receiptState=blocked.")
        if focus.get("state") == "available" and focus.get("exactVerifiedCount") != focus.get("iterations"):
            fail(errors, "available skyLightExactFocus requires every iteration to be exact verified.")

    if capture:
        numeric = ["fixtureWindowCount", "correctPreviewCount", "truthfullyUnavailableCount", "staleOrCrossWindowPreviewCount"]
        if any(not is_int(capture.get(name)) or capture[name] < 0 for name in numeric):
            fail(errors, "skyLightCapture counters must be non-negative integers.")
        elif capture["fixtureWindowCount"] < 2:
            fail(errors, "skyLightCapture.fixtureWindowCount must be at least 2.")
        elif capture["correctPreviewCount"] + capture["truthfullyUnavailableCount"] != capture["fixtureWindowCount"]:
            fail(errors, "skyLightCapture preview results must cover every fixture window.")
        if capture.get("staleOrCrossWindowPreviewCount", 0) > 0 and receipt_state != "blocked":
            fail(errors, "a stale or cross-window preview requires receiptState=blocked.")
        if capture.get("state") == "available" and capture.get("truthfullyUnavailableCount") != 0:
            fail(errors, "available skyLightCapture cannot report unavailable previews.")
    return errors


def validate_current_binding(receipt: dict[str, Any], args: argparse.Namespace) -> list[str]:
    errors: list[str] = []
    expected_sha = args.candidate.lower()
    if not SHA40.fullmatch(expected_sha):
        return ["--candidate must be a lowercase 40-character SHA."]
    if receipt["source"]["sha"] != expected_sha:
        fail(errors, "receipt source SHA does not match --candidate.")
    if receipt["source"]["branch"] != args.branch:
        fail(errors, "receipt branch does not match --branch.")
    config = args.config.resolve()
    artifact = args.artifact.resolve()
    bundle = args.bundle.resolve()
    if not config.is_file() or not artifact.is_file() or not bundle.is_dir():
        return errors + ["--config, archive --artifact, and installed --bundle must exist."]
    if receipt["source"]["releaseConfigSHA256"] != sha256(config):
        fail(errors, "receipt release-config hash does not match --config.")
    if receipt["artifact"]["sha256"] != sha256(artifact) or receipt["artifact"]["bytes"] != artifact.stat().st_size:
        fail(errors, "receipt artifact bytes or hash do not match --artifact.")
    info = bundle / "Contents" / "Info.plist"
    if not info.is_file():
        fail(errors, "--bundle must be a CmdTab.app bundle with Contents/Info.plist.")
    else:
        with info.open("rb") as handle:
            plist = plistlib.load(handle)
        expected_metadata = {
            "bundleIdentifier": plist.get("CFBundleIdentifier"),
            "marketingVersion": plist.get("CFBundleShortVersionString"),
            "buildNumber": str(plist.get("CFBundleVersion", "")),
        }
        for key, value in expected_metadata.items():
            if receipt["artifact"][key] != value:
                fail(errors, f"receipt artifact {key} does not match the bundle.")
    if args.require_current_checkout:
        try:
            head = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
            branch = subprocess.check_output(["git", "-C", str(ROOT), "branch", "--show-current"], text=True).strip()
            dirty = subprocess.check_output(["git", "-C", str(ROOT), "status", "--porcelain=v1", "--untracked-files=all"], text=True).strip()
        except subprocess.CalledProcessError as error:
            return errors + [f"could not inspect current checkout: {error}"]
        if head != expected_sha or branch != args.branch or dirty:
            fail(errors, "current checkout is not the requested clean candidate.")
    return errors


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipt", type=Path)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--branch", required=True)
    parser.add_argument("--config", type=Path, default=ROOT / "release" / "ReleaseConfig.json")
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--require-current-checkout", action="store_true")
    args = parser.parse_args()
    try:
        receipt = json.loads(args.receipt.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Cannot read canary receipt: {error}") from error
    errors = validate_document(receipt)
    if not errors:
        errors.extend(validate_current_binding(receipt, args))
    if errors:
        raise SystemExit("Private-capability canary is invalid:\n- " + "\n- ".join(errors))
    print("Private-capability canary receipt is structurally valid and candidate-bound; physical acceptance remains unproven.")


if __name__ == "__main__":
    main()
