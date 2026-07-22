#!/usr/bin/env python3
"""Verify the credential, signing, notarization, and distribution source contract.

This verifier intentionally performs no macOS signing operation. It is safe to run on
Linux/Vercel and prevents insecure or incomplete Phase 2 script changes from silently
entering the repository.
"""

from __future__ import annotations

import plistlib
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

SCRIPTS = {
    "preflight": ROOT / "scripts" / "release" / "phase2-preflight.sh",
    "sign": ROOT / "scripts" / "release" / "sign-app.sh",
    "zip": ROOT / "scripts" / "release" / "create-zip.sh",
    "notarize": ROOT / "scripts" / "release" / "notarize-app.sh",
    "staple": ROOT / "scripts" / "release" / "staple-app.sh",
    "verify": ROOT / "scripts" / "release" / "verify-distribution.sh",
    "runner": ROOT / "scripts" / "release" / "run-phase2-qa.sh",
}
DISTRIBUTION_RECORD_TOOL = ROOT / "scripts" / "release" / "write-distribution-record.py"


def fail(message: str) -> None:
    raise SystemExit(message)


def require(text: str, literal: str, label: str) -> None:
    if literal not in text:
        fail(f"{label} is missing required source contract: {literal!r}")


def reject(text: str, literal: str, label: str) -> None:
    if literal in text:
        fail(f"{label} contains forbidden source contract: {literal!r}")


def read_script(label: str, path: Path) -> str:
    if not path.is_file():
        fail(f"Missing Phase 2 script: {path.relative_to(ROOT)}")
    text = path.read_text(encoding="utf-8")
    if not text.startswith("#!/usr/bin/env bash\n"):
        fail(f"{label} must use the repository Bash shebang")
    require(text, "set -euo pipefail", label)
    # macOS still ships Bash 3.2. Keep scripts compatible with that baseline.
    reject(text, "readarray", label)
    reject(text, "mapfile", label)
    return text


def validate_shell_syntax() -> None:
    bash = shutil.which("bash")
    if bash is None:
        fail("bash is required to validate Phase 2 shell syntax")
    for label, path in SCRIPTS.items():
        result = subprocess.run(
            [bash, "-n", str(path)],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip() or "unknown syntax error"
            fail(f"{label} failed bash -n: {detail}")


def read_python_tool(path: Path) -> str:
    if not path.is_file():
        fail(f"Missing Phase 2 Python tool: {path.relative_to(ROOT)}")
    text = path.read_text(encoding="utf-8")
    try:
        compile(text, str(path), "exec")
    except SyntaxError as error:
        fail(f"{path.name} has invalid Python syntax: {error}")
    return text


def main() -> None:
    texts = {label: read_script(label, path) for label, path in SCRIPTS.items()}
    validate_shell_syntax()

    preflight = texts["preflight"]
    for required in (
        "CMDTAB_DEVELOPER_IDENTITY",
        "CMDTAB_TEAM_ID",
        "security find-identity",
        "CMDTAB_NOTARY_PROFILE",
        "CMDTAB_NOTARY_KEY_ID",
        "CMDTAB_NOTARY_ISSUER",
        "CMDTAB_NOTARY_KEY_PATH",
        "notarytool history",
        "chmod 600",
        "No artifact was built or submitted",
    ):
        require(preflight, required, "phase2-preflight.sh")
    reject(preflight, "notarytool submit", "phase2-preflight.sh")
    reject(preflight, "--password", "phase2-preflight.sh")

    sign = texts["sign"]
    require(sign, "CMDTAB_DEVELOPER_IDENTITY", "sign-app.sh")
    require(sign, "CMDTAB_TEAM_ID", "sign-app.sh")
    require(sign, "security find-identity", "sign-app.sh")
    require(sign, "--options runtime", "sign-app.sh")
    require(sign, "--timestamp", "sign-app.sh")
    require(sign, "--generate-entitlement-der", "sign-app.sh")
    require(sign, "--entitlements", "sign-app.sh")
    require(sign, "TeamIdentifier=", "sign-app.sh")
    require(sign, "deepest-first", "sign-app.sh")
    reject(sign, "--timestamp=none", "sign-app.sh")
    reject(sign, "--sign -", "sign-app.sh")
    reject(sign, "\n    --deep", "sign-app.sh")

    zip_source = texts["zip"]
    require(zip_source, "ditto -c -k --sequesterRsrc --keepParent", "create-zip.sh")
    require(zip_source, "unzip -tq", "create-zip.sh")
    require(zip_source, "shasum -a 256", "create-zip.sh")

    notarize = texts["notarize"]
    require(notarize, "CMDTAB_NOTARY_PROFILE", "notarize-app.sh")
    require(notarize, "CMDTAB_NOTARY_KEY_ID", "notarize-app.sh")
    require(notarize, "CMDTAB_NOTARY_ISSUER", "notarize-app.sh")
    require(notarize, "CMDTAB_NOTARY_KEY_PATH", "notarize-app.sh")
    require(notarize, "notarytool submit", "notarize-app.sh")
    require(notarize, "--wait", "notarize-app.sh")
    require(notarize, "--output-format json", "notarize-app.sh")
    require(notarize, "notarytool log", "notarize-app.sh")
    require(notarize, '"Accepted"', "notarize-app.sh")
    require(notarize, 'data.get("issues")', "notarize-app.sh")
    reject(notarize, "--password", "notarize-app.sh")
    reject(notarize, "CMDTAB_APPLE_ID_PASSWORD", "notarize-app.sh")

    staple = texts["staple"]
    require(staple, "stapler staple", "staple-app.sh")
    require(staple, "stapler validate", "staple-app.sh")

    verify = texts["verify"]
    require(verify, "codesign --verify --deep --strict", "verify-distribution.sh")
    require(verify, "spctl --assess --type execute", "verify-distribution.sh")
    require(verify, "stapler validate", "verify-distribution.sh")
    require(verify, "Timestamp=", "verify-distribution.sh")
    require(verify, "TeamIdentifier=", "verify-distribution.sh")
    require(verify, "embedded entitlements differ", "verify-distribution.sh")

    distribution_record = read_python_tool(DISTRIBUTION_RECORD_TOOL)
    for required in (
        "sourceCommit",
        "unsignedInput",
        "signedBundle",
        "finalArtifact",
        "submissionId",
        "hardenedRuntimeVerified",
        "secureTimestampVerified",
        "entitlementsVerified",
        "gatekeeperVerified",
        "stapleVerified",
        "issueCount",
    ):
        require(distribution_record, required, DISTRIBUTION_RECORD_TOOL.name)
    reject(distribution_record, "password", DISTRIBUTION_RECORD_TOOL.name)
    reject(distribution_record, "privateKey", DISTRIBUTION_RECORD_TOOL.name)

    runner = texts["runner"]
    for required in (
        "phase2-preflight.sh",
        "run-phase1-qa.sh",
        "CMDTAB_SKIP_ADHOC_SIGN=1",
        "sign-app.sh",
        "create-zip.sh",
        "notarize-app.sh",
        "staple-app.sh",
        "verify-distribution.sh",
        "write-distribution-record.py",
        "distribution-record.json",
        "AUTOMATED_PASS",
        "manual-checks.md",
    ):
        require(runner, required, "run-phase2-qa.sh")

    resource_entitlements = ROOT / "Resources" / "CmdTab.entitlements"
    release_entitlements = ROOT / "release" / "CmdTab.entitlements"
    for path in (resource_entitlements, release_entitlements):
        if not path.is_file():
            fail(f"Missing entitlement baseline: {path.relative_to(ROOT)}")

    with resource_entitlements.open("rb") as handle:
        resource_value = plistlib.load(handle)
    with release_entitlements.open("rb") as handle:
        release_value = plistlib.load(handle)

    if resource_value != release_value:
        fail("Resources and release entitlement baselines diverge")
    if release_value != {}:
        fail("Phase 2 starts from an empty entitlement baseline; add only runtime-proven entries")

    print("Phase 2 signing/notarization source verification passed")


if __name__ == "__main__":
    main()
