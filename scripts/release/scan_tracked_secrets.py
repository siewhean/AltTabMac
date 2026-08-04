#!/usr/bin/env python3
"""Fail closed when a git-tracked text file contains credential material.

The scanner intentionally obtains its input from ``git ls-files`` instead of
walking the worktree. That makes the checked set deterministic and prevents an
untracked local credential from becoming a release blocker while still
detecting a credential once it is staged/committed. The only suppression
mechanism is a content-hash-bound allowlist entry for one rule in one tracked
file; comments, directories, and glob patterns cannot suppress findings.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ALLOWLIST = ROOT / "scripts" / "release" / "tracked-secret-allowlist.json"


@dataclass(frozen=True)
class SecretRule:
    name: str
    pattern: re.Pattern[str]


# These are high-confidence credential formats. Do not add generic words such
# as "token", "secret", or environment-variable names: source code and
# documentation legitimately contain those terms and a broad pattern creates
# an unsafe habit of suppressing real findings.
RULES = (
    SecretRule("private-key-pem", re.compile(r"-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----")),
    SecretRule("aws-access-key-id", re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b")),
    SecretRule("github-classic-token", re.compile(r"\bghp_[A-Za-z0-9]{36}\b")),
    SecretRule("github-fine-grained-token", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b")),
    SecretRule("gitlab-personal-token", re.compile(r"\bglpat-[A-Za-z0-9_-]{20,}\b")),
    SecretRule("npm-access-token", re.compile(r"\bnpm_[A-Za-z0-9]{36}\b")),
    SecretRule("slack-token", re.compile(r"\bxox(?:b|p|a|r)-[A-Za-z0-9-]{20,}\b")),
    SecretRule("stripe-live-secret", re.compile(r"\b(?:sk|rk)_live_[A-Za-z0-9]{16,}\b")),
    SecretRule("sendgrid-api-key", re.compile(r"\bSG\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\b")),
    SecretRule("google-api-key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
)


@dataclass(frozen=True)
class Finding:
    path: str
    line: int
    rule: str
    digest: str


def tracked_paths(root: Path) -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-z"], check=True, capture_output=True
    )
    return sorted(path for path in result.stdout.decode("utf-8").split("\0") if path)


def parse_allowlist(data: bytes, description: str) -> set[tuple[str, str, str]]:
    """Load exact (path, rule, sha256) suppressions from a small JSON file."""

    data = json.loads(data.decode("utf-8"))
    if not isinstance(data, dict) or set(data) != {"version", "entries"}:
        raise ValueError(f"{description}: allowlist must contain only version and entries")
    if data["version"] != 1 or not isinstance(data["entries"], list):
        raise ValueError(f"{description}: unsupported allowlist schema")

    allowed: set[tuple[str, str, str]] = set()
    rule_names = {candidate.name for candidate in RULES}
    for index, entry in enumerate(data["entries"]):
        if not isinstance(entry, dict) or set(entry) != {"path", "rule", "sha256", "reason"}:
            raise ValueError(f"{description}: entry {index} must contain path, rule, sha256, and reason")
        file_path, rule, digest, reason = (
            entry["path"], entry["rule"], entry["sha256"], entry["reason"]
        )
        if not all(isinstance(value, str) and value for value in (file_path, rule, digest, reason)):
            raise ValueError(f"{description}: entry {index} has an empty required field")
        if Path(file_path).is_absolute() or ".." in Path(file_path).parts:
            raise ValueError(f"{description}: entry {index} path must be repository-relative")
        if rule not in rule_names:
            raise ValueError(f"{description}: entry {index} has an unknown rule {rule!r}")
        if not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError(f"{description}: entry {index} sha256 must be lowercase hexadecimal")
        allowed.add((file_path, rule, digest))
    return allowed


def load_allowlist(path: Path) -> set[tuple[str, str, str]]:
    """Load a caller-provided test allowlist from disk."""

    if not path.exists():
        return set()
    return parse_allowlist(path.read_bytes(), str(path))


def read_index_blobs(root: Path, paths: Iterable[str]) -> dict[str, bytes]:
    """Read index blobs in one Git process, never mutable worktree bytes."""

    requested = list(paths)
    if any("\n" in path for path in requested):
        raise ValueError("tracked paths containing newlines are not supported")
    query = b"".join(f":{path}\n".encode("utf-8") for path in requested)
    result = subprocess.run(
        ["git", "-C", str(root), "cat-file", "--batch"],
        input=query,
        check=True,
        capture_output=True,
    )
    output = result.stdout
    offset = 0
    blobs: dict[str, bytes] = {}
    for path in requested:
        line_end = output.find(b"\n", offset)
        if line_end == -1:
            raise ValueError(f"Git omitted an index object header for {path}")
        header = output[offset:line_end].decode("ascii", errors="strict")
        offset = line_end + 1
        if header.endswith(" missing"):
            raise ValueError(f"Git index object is missing for {path}")
        fields = header.split()
        if len(fields) != 3 or fields[1] != "blob" or not fields[2].isdigit():
            raise ValueError(f"Git index object for {path} is not a readable blob")
        size = int(fields[2])
        data_end = offset + size
        if data_end >= len(output) or output[data_end:data_end + 1] != b"\n":
            raise ValueError(f"Git returned a truncated index blob for {path}")
        blobs[path] = output[offset:data_end]
        offset = data_end + 1
    if offset != len(output):
        raise ValueError("Git returned unexpected trailing index data")
    return blobs


def scan_text(data: bytes) -> str | None:
    if b"\0" in data:
        return None
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return None


def finding_digest(path: str, rule: str, line_text: str) -> str:
    material = f"{path}\0{rule}\0{line_text}".encode("utf-8")
    return hashlib.sha256(material).hexdigest()


def scan_repository(
    root: Path,
    *,
    allowlist_path: Path | None = None,
    path_provider: Callable[[Path], Iterable[str]] = tracked_paths,
) -> tuple[list[Finding], int, int]:
    """Return unsuppressed findings, text-file count, and skipped binary count."""

    findings: list[Finding] = []
    text_files = 0
    binary_files = 0
    paths = list(path_provider(root))
    blobs = read_index_blobs(root, paths)
    if allowlist_path:
        # Unit tests may inject a temporary file. Production calls use the
        # index-backed branch below so an unstaged allowlist edit cannot hide a
        # staged candidate secret.
        allowlist = load_allowlist(allowlist_path)
    else:
        allowlist_relative = str(DEFAULT_ALLOWLIST.relative_to(ROOT))
        if allowlist_relative not in blobs:
            raise ValueError(
                f"default allowlist {allowlist_relative} must be tracked in the Git index"
            )
        allowlist = parse_allowlist(blobs[allowlist_relative], allowlist_relative)
    for relative_path in paths:
        text = scan_text(blobs[relative_path])
        if text is None:
            binary_files += 1
            continue
        text_files += 1
        for line_number, line_text in enumerate(text.splitlines(), 1):
            for rule in RULES:
                if rule.pattern.search(line_text):
                    digest = finding_digest(relative_path, rule.name, line_text)
                    if (relative_path, rule.name, digest) not in allowlist:
                        findings.append(Finding(relative_path, line_number, rule.name, digest))
    return findings, text_files, binary_files


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root (tests only)")
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        findings, text_files, binary_files = scan_repository(root)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"Tracked-secret scan failed to initialize: {error}") from error
    if findings:
        details = "\n".join(
            f"{finding.path}:{finding.line}: {finding.rule} (sha256={finding.digest})"
            for finding in findings
        )
        raise SystemExit(
            "Tracked-secret content detected. Remove it or add a narrowly scoped, "
            f"hash-bound fixture allowlist entry:\n{details}"
        )
    print(
        "Tracked-secret content scan passed "
        f"({text_files} tracked UTF-8 text files; {binary_files} binary files skipped)"
    )


if __name__ == "__main__":
    main()
