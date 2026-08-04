#!/usr/bin/env python3
"""Focused hermetic tests for the tracked-secret content scanner."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("scan_tracked_secrets.py")
SPEC = importlib.util.spec_from_file_location("scan_tracked_secrets", SCRIPT)
assert SPEC and SPEC.loader
scanner = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = scanner
SPEC.loader.exec_module(scanner)
GITHUB_FIXTURE_TOKEN = "ghp_" + "abcdefghijklmnopqrstuvwxyz0123456789"


class TrackedSecretScanTests(unittest.TestCase):
    def make_repository(self) -> Path:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        subprocess.run(["git", "init", "-q", str(root)], check=True)
        return root

    def tracked_file(self, root: Path, path: str, contents: str) -> None:
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(contents, encoding="utf-8")
        subprocess.run(["git", "-C", str(root), "add", path], check=True)

    def test_detects_credential_in_tracked_source_content(self) -> None:
        root = self.make_repository()
        self.tracked_file(root, "Sources/config.swift", f'let key = "{GITHUB_FIXTURE_TOKEN}"\n')

        findings, text_files, binary_files = scanner.scan_repository(root, allowlist_path=root / "allowlist.json")

        self.assertEqual(text_files, 1)
        self.assertEqual(binary_files, 0)
        self.assertEqual([(item.path, item.line, item.rule) for item in findings], [
            ("Sources/config.swift", 1, "github-classic-token")
        ])

    def test_ignores_untracked_secret_content(self) -> None:
        root = self.make_repository()
        self.tracked_file(root, "README.md", "safe documentation\n")
        (root / "local.env").write_text(f"{GITHUB_FIXTURE_TOKEN}\n", encoding="utf-8")

        findings, _, _ = scanner.scan_repository(root, allowlist_path=root / "allowlist.json")

        self.assertEqual(findings, [])

    def test_scans_staged_content_not_mutable_worktree_bytes(self) -> None:
        root = self.make_repository()
        path = "Sources/config.swift"
        self.tracked_file(root, path, f'let key = "{GITHUB_FIXTURE_TOKEN}"\n')
        # A developer can revert the worktree file after staging. The scanner
        # must still inspect the candidate that would be committed/checked out.
        (root / path).write_text("let key = \"redacted\"\n", encoding="utf-8")

        findings, _, _ = scanner.scan_repository(root, allowlist_path=root / "allowlist.json")

        self.assertEqual([(item.path, item.line, item.rule) for item in findings], [
            (path, 1, "github-classic-token")
        ])

    def test_ignores_unstaged_secret_in_an_otherwise_safe_tracked_file(self) -> None:
        root = self.make_repository()
        path = "README.md"
        self.tracked_file(root, path, "safe documentation\n")
        (root / path).write_text(f"{GITHUB_FIXTURE_TOKEN}\n", encoding="utf-8")

        findings, _, _ = scanner.scan_repository(root, allowlist_path=root / "allowlist.json")

        self.assertEqual(findings, [])

    def test_reads_a_tracked_symlink_blob_without_dereferencing_its_target(self) -> None:
        root = self.make_repository()
        external = root / "external-secret.txt"
        external.write_text(f"{GITHUB_FIXTURE_TOKEN}\n", encoding="utf-8")
        link = root / "docs" / "example-link"
        link.parent.mkdir(parents=True)
        link.symlink_to(external)
        subprocess.run(["git", "-C", str(root), "add", "docs/example-link"], check=True)

        findings, text_files, binary_files = scanner.scan_repository(
            root, allowlist_path=root / "allowlist.json"
        )

        self.assertEqual(findings, [])
        self.assertEqual(text_files, 1)
        self.assertEqual(binary_files, 0)

    def test_hash_bound_allowlist_does_not_hide_changed_or_other_occurrences(self) -> None:
        root = self.make_repository()
        path = "tests/fixture.txt"
        fixture = f"{GITHUB_FIXTURE_TOKEN}\n"
        self.tracked_file(root, path, fixture)
        digest = scanner.finding_digest(path, "github-classic-token", fixture.rstrip("\n"))
        allowlist = root / "allowlist.json"
        allowlist.write_text(json.dumps({"version": 1, "entries": [{
            "path": path,
            "rule": "github-classic-token",
            "sha256": digest,
            "reason": "Synthetic scanner fixture; not a credential.",
        }]}), encoding="utf-8")

        findings, _, _ = scanner.scan_repository(root, allowlist_path=allowlist)
        self.assertEqual(findings, [])

        changed_fixture = "ghp_" + "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        self.tracked_file(root, path, fixture + f"{changed_fixture}\n")
        findings, _, _ = scanner.scan_repository(root, allowlist_path=allowlist)
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].line, 2)

    def test_default_allowlist_uses_its_staged_blob_not_an_unstaged_edit(self) -> None:
        root = self.make_repository()
        path = "Sources/config.swift"
        line = f'let key = "{GITHUB_FIXTURE_TOKEN}"'
        self.tracked_file(root, path, line + "\n")
        allowlist_path = "scripts/release/tracked-secret-allowlist.json"
        self.tracked_file(root, allowlist_path, '{"version": 1, "entries": []}')
        digest = scanner.finding_digest(path, "github-classic-token", line)
        # This matching approval exists only in the mutable worktree and must
        # not suppress the staged source candidate.
        (root / allowlist_path).write_text(json.dumps({"version": 1, "entries": [{
            "path": path,
            "rule": "github-classic-token",
            "sha256": digest,
            "reason": "Unstaged attempt to suppress a candidate secret.",
        }]}), encoding="utf-8")

        findings, _, _ = scanner.scan_repository(root)

        self.assertEqual([(item.path, item.line, item.rule) for item in findings], [
            (path, 1, "github-classic-token")
        ])

    def test_rejects_broad_allowlist_shape(self) -> None:
        root = self.make_repository()
        allowlist = root / "allowlist.json"
        allowlist.write_text('{"version": 1, "entries": [{"path": "*"}]}', encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "must contain path, rule, sha256, and reason"):
            scanner.load_allowlist(allowlist)


if __name__ == "__main__":
    unittest.main()
