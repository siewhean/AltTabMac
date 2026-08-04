#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import os
import plistlib
import re
import shutil
import subprocess
import tempfile
import unittest
from argparse import Namespace
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
MODULE_SPEC = importlib.util.spec_from_file_location(
    "release_manifest",
    ROOT / "scripts" / "release" / "release_manifest.py",
)
assert MODULE_SPEC and MODULE_SPEC.loader
release_manifest = importlib.util.module_from_spec(MODULE_SPEC)
MODULE_SPEC.loader.exec_module(release_manifest)
PIN_SPEC = importlib.util.spec_from_file_location(
    "verify_workflow_actions",
    ROOT / "scripts" / "release" / "verify-workflow-actions.py",
)
assert PIN_SPEC and PIN_SPEC.loader
verify_workflow_actions = importlib.util.module_from_spec(PIN_SPEC)
PIN_SPEC.loader.exec_module(verify_workflow_actions)


def manifest(build: int = 2) -> dict[str, object]:
    source_sha = "a" * 40
    return {
        "schemaVersion": 1,
        "channel": "stable",
        "version": "1.0.0",
        "build": build,
        "minimumMacOS": "13.0",
        "dmgURL": f"https://releases.cmdtab.net/{source_sha}/CmdTab-1.0.0-{build}.dmg",
        "bytes": 4,
        "sha256": "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
        "releaseDate": "2026-07-27",
        "sourceSHA": source_sha,
        "appcastURL": "https://cmdtab.net/releases/appcast.xml",
    }


def beta_manifest(build: int = 2) -> dict[str, object]:
    source_sha = "b" * 40
    return {
        "schemaVersion": 1,
        "channel": "beta",
        "version": "1.0.0-beta.1",
        "build": build,
        "minimumMacOS": "13.0",
        "dmgURL": f"https://releases.cmdtab.net/{source_sha}/CmdTab-1.0.0-beta.1-{build}.dmg",
        "bytes": 4,
        "sha256": "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
        "releaseDate": "2026-07-27",
        "sourceSHA": source_sha,
        "appcastURL": "https://cmdtab.net/releases/beta/appcast.xml",
    }


class ReleaseManifestTests(unittest.TestCase):
    def publication_harness(self, root: Path) -> tuple[Path, dict[str, str]]:
        release_dir = root / "scripts" / "release"
        release_dir.mkdir(parents=True)
        publication = release_dir / "prepare-release-publication.sh"
        shutil.copy2(
            ROOT / "scripts" / "release" / "prepare-release-publication.sh",
            publication,
        )

        manifest = release_dir / "release_manifest.py"
        manifest.write_text(
            "\n".join(
                [
                    "#!/usr/bin/env python3",
                    "import json, os, sys",
                    "from pathlib import Path",
                    'Path(os.environ["CMDTAB_TEST_MANIFEST_ARGS"]).write_text(json.dumps(sys.argv[1:]), encoding="utf-8")',
                    'output = Path(sys.argv[sys.argv.index("--output") + 1])',
                    "output.parent.mkdir(parents=True, exist_ok=True)",
                    'output.write_text("{}\\n", encoding="utf-8")',
                ]
            )
            + "\n",
            encoding="utf-8",
        )

        release_config = release_dir / "release_config.py"
        release_config.write_text(
            "\n".join(
                [
                    "#!/usr/bin/env python3",
                    "import os, sys",
                    'values = {"marketingVersion": os.environ["CMDTAB_TEST_CONFIG_VERSION"], "buildNumber": os.environ["CMDTAB_TEST_CONFIG_BUILD"]}',
                    'if sys.argv[1:] and sys.argv[1] == "get" and sys.argv[2] in values:',
                    "    print(values[sys.argv[2]])",
                    "    raise SystemExit(0)",
                    "raise SystemExit(2)",
                ]
            )
            + "\n",
            encoding="utf-8",
        )

        appcast = release_dir / "generate-signed-appcast.sh"
        appcast.write_text(
            "\n".join(
                [
                    "#!/usr/bin/env bash",
                    "set -euo pipefail",
                    "printf '%s\\n' \"$@\" > \"${CMDTAB_TEST_APPCAST_ARGS}\"",
                    'touch "$3"',
                ]
            )
            + "\n",
            encoding="utf-8",
        )
        appcast.chmod(0o755)
        environment = os.environ.copy()
        environment.update(
            {
                "CMDTAB_ALLOW_TEST_SOURCE_SHA": "1",
                "CMDTAB_TEST_CONFIG_VERSION": "1.0.0",
                "CMDTAB_TEST_CONFIG_BUILD": "1",
                "CMDTAB_TEST_PACKAGED_VERSION": "1.0.0",
                "CMDTAB_TEST_PACKAGED_BUILD": "1",
                "CMDTAB_TEST_MANIFEST_ARGS": str(root / "manifest-args.json"),
                "CMDTAB_TEST_APPCAST_ARGS": str(root / "appcast-args.txt"),
            }
        )
        return publication, environment

    def test_workflow_pin_parser_covers_step_shorthand_and_containers(self) -> None:
        pattern = verify_workflow_actions.USE_PATTERN
        self.assertEqual(
            pattern.match("- uses: owner/action@main").group(1),
            "owner/action@main",
        )
        self.assertIsNotNone(
            verify_workflow_actions.validate_reference("owner/action@main")
        )
        self.assertIsNotNone(
            verify_workflow_actions.validate_reference(
                "docker://example/image:latest"
            )
        )
        self.assertIsNone(
            verify_workflow_actions.validate_reference(
                f"docker://example/image@sha256:{'a' * 64}"
            )
        )
        self.assertIsNotNone(
            verify_workflow_actions.USES_KEY_PATTERN.search(
                "- { uses: owner/action@main }"
            )
        )
        self.assertIsNotNone(
            verify_workflow_actions.USES_KEY_PATTERN.search(
                '- "uses": owner/action@main'
            )
        )

    def test_private_secret_path_detection(self) -> None:
        self.assertTrue(
            verify_workflow_actions.is_private_secret_path(".secrets/token")
        )
        self.assertTrue(
            verify_workflow_actions.is_private_secret_path(
                "website/.secrets/signing-key.pem"
            )
        )
        self.assertFalse(
            verify_workflow_actions.is_private_secret_path(
                "website/.env.example"
            )
        )
        self.assertFalse(
            verify_workflow_actions.is_private_secret_path(
                "docs/secrets-management.md"
            )
        )

    def test_candidate_security_and_audit_workflows_cover_every_source_change(self) -> None:
        self.assertEqual(
            verify_workflow_actions.candidate_workflow_coverage_failures(),
            [],
        )
        for filename in verify_workflow_actions.CANDIDATE_WORKFLOWS:
            lines = (
                ROOT / ".github" / "workflows" / filename
            ).read_text(encoding="utf-8").splitlines()
            for event in ("push", "pull_request"):
                block = verify_workflow_actions.workflow_event_block(lines, event)
                self.assertIsNotNone(block)
                self.assertFalse(
                    any(
                        line.strip().startswith(("paths:", "paths-ignore:"))
                        for line in block or []
                    )
                )

    def test_release_signing_requires_clean_untracked_state_and_notarized_dmg(self) -> None:
        notarized_build = (
            ROOT / "scripts" / "release" / "build-notarized-dmg.sh"
        ).read_text(encoding="utf-8")
        publication = (
            ROOT / "scripts" / "release" / "prepare-release-publication.sh"
        ).read_text(encoding="utf-8")
        appcast = (
            ROOT / "scripts" / "release" / "generate-signed-appcast.sh"
        ).read_text(encoding="utf-8")
        verifier = (
            ROOT / "scripts" / "release" / "verify-notarized-dmg.sh"
        ).read_text(encoding="utf-8")

        self.assertIn("--untracked-files=all", notarized_build)
        self.assertIn("--untracked-files=all", publication)
        self.assertIn("--preflight|--dry-run", notarized_build)
        self.assertIn("No signing, notarization, artifact creation, or network request", notarized_build)
        self.assertLess(
            notarized_build.index('if [[ "${PREFLIGHT_ONLY}" == "1" ]]'),
            notarized_build.index('mkdir -p "${OUTPUT_DIR}"'),
        )
        self.assertLess(
            notarized_build.index('if [[ "${PREFLIGHT_ONLY}" == "1" ]]'),
            notarized_build.index('SIGNING_IDENTITY="${CMDTAB_SIGNING_IDENTITY:-}"'),
        )
        self.assertIn('DMG_PATH="${OUTPUT_DIR}/CmdTab-${BETA_VERSION}-${BUILD}.dmg"', notarized_build)
        self.assertIn("Notarized public-beta builds require --beta", notarized_build)
        self.assertIn("Beta publication DMG must be named", publication)
        self.assertIn("verify-notarized-dmg.sh", appcast)
        self.assertIn("resolve-sparkle-tools.sh", appcast)
        self.assertNotIn(".build/artifacts/sparkle", appcast)
        self.assertNotIn("mapfile", appcast)
        for required in [
            "codesign --verify",
            "stapler validate",
            "spctl --assess --type open",
            "verify-bundle.sh",
            "spctl --assess --type execute",
        ]:
            self.assertIn(required, verifier)

    def test_publication_wrapper_preserves_stable_default_and_emits_beta_namespace(self) -> None:
        source_sha = "a" * 40
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            publication, environment = self.publication_harness(root)
            dmg = root / "CmdTab.dmg"
            dmg.write_bytes(b"test")

            stable_output = root / "stable-output"
            stable = subprocess.run(
                [
                    "bash", str(publication), str(dmg),
                    f"https://releases.cmdtab.net/{source_sha}/CmdTab-1.0.0-2.dmg",
                    source_sha, str(stable_output),
                ],
                capture_output=True,
                text=True,
                env=environment,
            )
            self.assertEqual(stable.returncode, 0, stable.stderr)
            self.assertTrue((stable_output / "stable.json").is_file())
            self.assertTrue((stable_output / "appcast.xml").is_file())
            self.assertFalse((stable_output / "beta.json").exists())
            stable_arguments = json.loads(
                Path(environment["CMDTAB_TEST_MANIFEST_ARGS"]).read_text(
                    encoding="utf-8"
                )
            )
            self.assertNotIn("--channel", stable_arguments)
            self.assertNotIn("--version", stable_arguments)
            beta_output = root / "beta-output"
            beta_dmg = root / "CmdTab-1.0.0-beta.7-1.dmg"
            beta_dmg.write_bytes(b"test")
            beta_environment = {
                **environment,
                "CMDTAB_TEST_CONFIG_VERSION": "1.0.0",
                "CMDTAB_TEST_PACKAGED_VERSION": "1.0.0",
            }
            beta = subprocess.run(
                [
                    "bash", str(publication), "--beta", "1.0.0-beta.7", str(beta_dmg),
                    f"https://releases.cmdtab.net/{source_sha}/CmdTab-1.0.0-beta.7-1.dmg",
                    source_sha, str(beta_output),
                ],
                capture_output=True,
                text=True,
                env=beta_environment,
            )
            self.assertEqual(beta.returncode, 0, beta.stderr)
            self.assertTrue((beta_output / "beta.json").is_file())
            self.assertTrue((beta_output / "beta-appcast.xml").is_file())
            self.assertFalse((beta_output / "stable.json").exists())
            beta_arguments = json.loads(
                Path(environment["CMDTAB_TEST_MANIFEST_ARGS"]).read_text(
                    encoding="utf-8"
                )
            )
            self.assertEqual(
                beta_arguments[beta_arguments.index("--channel") + 1], "beta"
            )
            self.assertEqual(
                beta_arguments[beta_arguments.index("--version") + 1],
                "1.0.0-beta.7",
            )
            self.assertEqual(
                Path(beta_environment["CMDTAB_TEST_APPCAST_ARGS"])
                .read_text(encoding="utf-8")
                .splitlines()[1:],
                [
                    str(beta_output / "beta.json"),
                    str(beta_output / "beta-appcast.xml"),
                ],
            )

    def test_beta_publication_rejects_numeric_local_dmg_name_before_metadata(self) -> None:
        source_sha = "a" * 40
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            publication, environment = self.publication_harness(root)
            numeric_dmg = root / "CmdTab-1.0.0-1.dmg"
            numeric_dmg.write_bytes(b"test")
            rejected = subprocess.run(
                [
                    "bash", str(publication), "--beta", "1.0.0-beta.7", str(numeric_dmg),
                    f"https://releases.cmdtab.net/{source_sha}/CmdTab-1.0.0-beta.7-1.dmg",
                    source_sha, str(root / "output"),
                ],
                capture_output=True,
                text=True,
                env=environment,
            )
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("Beta publication DMG must be named CmdTab-1.0.0-beta.7-1.dmg", rejected.stderr)
            self.assertFalse(Path(environment["CMDTAB_TEST_MANIFEST_ARGS"]).exists())
            self.assertFalse(Path(environment["CMDTAB_TEST_APPCAST_ARGS"]).exists())

    def test_sparkle_tool_resolver_preserves_explicit_pair_overrides(self) -> None:
        resolver = ROOT / "scripts" / "release" / "resolve-sparkle-tools.sh"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            generator = root / "generate_appcast"
            signer = root / "sign_update"
            for executable in (generator, signer):
                executable.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
                executable.chmod(0o755)
            scratch = root / "isolated-scratch"
            result = subprocess.run(
                ["bash", str(resolver), "--scratch-path", str(scratch)],
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "CMDTAB_GENERATE_APPCAST": str(generator),
                    "CMDTAB_SIGN_UPDATE": str(signer),
                },
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), [str(generator), str(signer)])
            self.assertFalse(scratch.exists())

    def test_publication_wrapper_rejects_beta_version_before_writing_metadata(self) -> None:
        source_sha = "a" * 40
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            publication, environment = self.publication_harness(root)
            dmg = root / "CmdTab.dmg"
            dmg.write_bytes(b"test")
            beta_environment = {
                **environment,
                "CMDTAB_TEST_CONFIG_VERSION": "1.0.1",
                "CMDTAB_TEST_PACKAGED_VERSION": "1.0.1",
            }
            rejected = subprocess.run(
                [
                    "bash", str(publication), "--beta", "1.0.0-beta.8", str(dmg),
                    f"https://releases.cmdtab.net/{source_sha}/CmdTab-1.0.0-beta.8-1.dmg",
                    source_sha, str(root / "output"),
                ],
                capture_output=True,
                text=True,
                env=beta_environment,
            )
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("must use ReleaseConfig marketingVersion", rejected.stderr)
            self.assertFalse(
                Path(beta_environment["CMDTAB_TEST_MANIFEST_ARGS"]).exists()
            )
            self.assertFalse(
                Path(beta_environment["CMDTAB_TEST_APPCAST_ARGS"]).exists()
            )

    def test_publication_wrapper_rejects_missing_or_invalid_beta_version_before_signing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            publication, environment = self.publication_harness(root)
            missing = subprocess.run(
                ["bash", str(publication), "--beta"],
                capture_output=True,
                text=True,
                env=environment,
            )
            self.assertEqual(missing.returncode, 2)
            self.assertIn("Usage:", missing.stderr)

            invalid = subprocess.run(
                [
                    "bash", str(publication), "--beta", "1.0.0", "CmdTab.dmg",
                    "https://releases.cmdtab.net/example/CmdTab-1.0.0-2.dmg",
                    "a" * 40, str(root / "output"),
                ],
                capture_output=True,
                text=True,
                env=environment,
            )
            self.assertEqual(invalid.returncode, 2)
            self.assertIn("Beta publication requires", invalid.stderr)
            self.assertFalse(
                Path(environment["CMDTAB_TEST_MANIFEST_ARGS"]).exists()
            )

    def test_branded_dmg_contract_has_drag_install_layout(self) -> None:
        notarized_build = (
            ROOT / "scripts" / "release" / "build-notarized-dmg.sh"
        ).read_text(encoding="utf-8")
        background_renderer = (
            ROOT / "scripts" / "release" / "render-dmg-background.swift"
        ).read_text(encoding="utf-8")

        for required in [
            "render-dmg-background.swift",
            ".background/background.png",
            "-format UDRW",
            "set background picture of viewOptions",
            'set position of item "CmdTab.app"',
            'set position of item "Applications"',
            "-format UDZO",
        ]:
            self.assertIn(required, notarized_build)
        self.assertIn("Drag CmdTab into Applications", background_renderer)
        self.assertIn("Window-level switching for macOS", background_renderer)

    def test_packaged_launch_smoke_proves_exact_executable(self) -> None:
        smoke = (
            ROOT / "scripts" / "release" / "smoke-launch-app.sh"
        ).read_text(encoding="utf-8")

        for required in [
            "codesign --verify --deep --strict",
            'lsof -a -p "${PID}" -d txt',
            'grep -Fx "${EXECUTABLE_PATH}"',
            "Packaged launch smoke test passed",
        ]:
            self.assertIn(required, smoke)

    def test_ad_hoc_sparkle_packaging_omits_hardened_runtime(self) -> None:
        signer = (
            ROOT / "scripts" / "release" / "sign-app-bundle.sh"
        ).read_text(encoding="utf-8")
        verifier = (
            ROOT / "scripts" / "release" / "verify-bundle.sh"
        ).read_text(encoding="utf-8")

        self.assertIn('if [[ "${IDENTITY}" != "-" ]]', signer)
        self.assertIn("USE_HARDENED_RUNTIME=1", signer)
        self.assertIn('arguments+=(--options runtime)', signer)
        self.assertIn('APP_SIGNING_ARGUMENTS+=(--options runtime)', signer)
        self.assertNotIn('"${SIGNING_OPTIONS[@]}"', signer)
        self.assertIn(
            "Ad-hoc Sparkle QA bundles must not enable Hardened Runtime",
            verifier,
        )
        self.assertIn("Developer ID bundle is missing Hardened Runtime", verifier)

    def test_release_package_fails_closed_on_arm64_architecture_policy(self) -> None:
        config = json.loads(
            (ROOT / "release" / "ReleaseConfig.json").read_text(
                encoding="utf-8"
            )
        )
        packager = (
            ROOT / "scripts" / "release" / "package-app.sh"
        ).read_text(encoding="utf-8")
        verifier = (
            ROOT / "scripts" / "release" / "verify-bundle.sh"
        ).read_text(encoding="utf-8")

        self.assertEqual(
            config["architecturePolicy"],
            "arm64-only",
        )
        for required in [
            "arm64-only",
            'BUILD_ARCHITECTURES="arm64"',
            'EXPECTED_ARCHITECTURES="arm64"',
            'CMDTAB_BUILD_ARCHITECTURES="${BUILD_ARCHITECTURES}"',
            'CMDTAB_EXPECTED_ARCHITECTURES="${EXPECTED_ARCHITECTURES}"',
            "Release architecture policy requires arm64",
            "thin_executables_to_arm64",
            "lipo -thin arm64",
        ]:
            self.assertIn(required, packager)
        self.assertIn("Expected architectures", verifier)

    def test_beta_candidate_configuration_rejects_the_stable_feed(self) -> None:
        config_path = ROOT / "release" / "ReleaseConfig.json"
        config = json.loads(config_path.read_text(encoding="utf-8"))
        beta_feed = "https://cmdtab.net/releases/beta/appcast.xml"
        self.assertEqual(config["updateChannel"], "beta")
        self.assertEqual(config["updateFeedURL"], beta_feed)

        with (ROOT / "Resources" / "Info.plist").open("rb") as handle:
            self.assertEqual(plistlib.load(handle)["SUFeedURL"], beta_feed)

        valid = subprocess.run(
            ["python3", str(ROOT / "scripts" / "release" / "release_config.py"), "validate"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(valid.returncode, 0, valid.stderr)

        with tempfile.TemporaryDirectory() as directory:
            invalid_path = Path(directory) / "ReleaseConfig.json"
            invalid = {**config, "updateChannel": "stable", "updateFeedURL": "https://cmdtab.net/releases/appcast.xml"}
            invalid_path.write_text(json.dumps(invalid), encoding="utf-8")
            rejected = subprocess.run(
                [
                    "python3", str(ROOT / "scripts" / "release" / "release_config.py"),
                    "--config", str(invalid_path), "validate",
                ],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("isolated beta update channel", rejected.stderr)

    def test_valid_manifest_and_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            artifact = Path(directory) / "CmdTab.dmg"
            artifact.write_bytes(b"test")
            release_manifest.validate_manifest(manifest(), artifact=artifact)

    def test_beta_manifest_creation_rejects_bundle_version_or_build_mismatch(self) -> None:
        source_sha = "a" * 40
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            artifact = root / "CmdTab.dmg"
            artifact.write_bytes(b"test")
            config_path = root / "ReleaseConfig.json"
            config_path.write_text(
                json.dumps(
                    {
                        "marketingVersion": "1.0.0",
                        "buildNumber": "17",
                        "minimumSystemVersion": "13.0",
                    }
                ),
                encoding="utf-8",
            )
            args = Namespace(
                channel="beta",
                version="1.0.0-beta.1",
                dmg=artifact,
                dmg_url=f"https://releases.cmdtab.net/{source_sha}/CmdTab-1.0.0-beta.1-17.dmg",
                source_sha=source_sha,
                release_date="2026-08-04",
                previous=None,
                output=root / "beta.json",
            )
            with mock.patch.object(release_manifest, "CONFIG_PATH", config_path):
                for detail in (
                    "DMG CFBundleShortVersionString (1.0.1) does not match expected release version (1.0.0).",
                    "DMG CFBundleVersion (18) does not match expected release build (17).",
                ):
                    with mock.patch.object(
                        release_manifest.subprocess,
                        "run",
                        return_value=subprocess.CompletedProcess(
                            args=[], returncode=1, stdout="", stderr=detail
                        ),
                    ):
                        with self.assertRaisesRegex(ValueError, re.escape(detail)):
                            release_manifest.create_manifest(args)
            self.assertFalse(args.output.exists())

    def test_beta_manifest_binds_prerelease_to_numeric_bundle_version_and_build(self) -> None:
        source_sha = "a" * 40
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            artifact = root / "CmdTab.dmg"
            artifact.write_bytes(b"test")
            config_path = root / "ReleaseConfig.json"
            config_path.write_text(
                json.dumps(
                    {
                        "marketingVersion": "1.0.0",
                        "buildNumber": "17",
                        "minimumSystemVersion": "13.0",
                    }
                ),
                encoding="utf-8",
            )
            args = Namespace(
                channel="beta",
                version="1.0.0-beta.1",
                dmg=artifact,
                dmg_url=f"https://releases.cmdtab.net/{source_sha}/CmdTab-1.0.0-beta.1-17.dmg",
                source_sha=source_sha,
                release_date="2026-08-04",
                previous=None,
                output=root / "beta.json",
            )
            with mock.patch.object(release_manifest, "CONFIG_PATH", config_path), mock.patch.object(
                release_manifest.subprocess,
                "run",
                return_value=subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr=""),
            ) as verified:
                created = release_manifest.create_manifest(args)
            self.assertEqual(created["version"], "1.0.0-beta.1")
            self.assertEqual(created["build"], 17)
            self.assertEqual(
                verified.call_args.args[0][-4:],
                ["--expected-version", "1.0.0", "--expected-build", "17"],
            )

            args.version = "1.0.1-beta.1"
            with mock.patch.object(release_manifest, "CONFIG_PATH", config_path):
                with self.assertRaisesRegex(ValueError, "as its x.y.z base"):
                    release_manifest.create_manifest(args)

    def test_tampered_artifact_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            artifact = Path(directory) / "CmdTab.dmg"
            artifact.write_bytes(b"evil")
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                release_manifest.validate_manifest(manifest(), artifact=artifact)

    def test_equal_and_lower_builds_are_rejected(self) -> None:
        previous = manifest(build=2)
        with self.assertRaisesRegex(ValueError, "strictly greater"):
            release_manifest.validate_manifest(manifest(build=2), previous=previous)
        with self.assertRaisesRegex(ValueError, "strictly greater"):
            release_manifest.validate_manifest(manifest(build=1), previous=previous)
        release_manifest.validate_manifest(manifest(build=3), previous=previous)

    def test_beta_contract_requires_an_isolated_prerelease_and_feed(self) -> None:
        release_manifest.validate_manifest(beta_manifest())
        invalid_version = beta_manifest()
        invalid_version["version"] = "1.0.0"
        with self.assertRaisesRegex(ValueError, "beta version"):
            release_manifest.validate_manifest(invalid_version)
        invalid_feed = beta_manifest()
        invalid_feed["appcastURL"] = "https://cmdtab.net/releases/appcast.xml"
        with self.assertRaisesRegex(ValueError, "beta appcast"):
            release_manifest.validate_manifest(invalid_feed)
        with self.assertRaisesRegex(ValueError, "same release channel"):
            release_manifest.validate_manifest(beta_manifest(), previous=manifest())

    def test_mutable_or_credentialed_urls_are_rejected(self) -> None:
        mutable = manifest()
        mutable["dmgURL"] = "https://releases.cmdtab.net/latest/CmdTab.dmg"
        with self.assertRaises(ValueError):
            release_manifest.validate_manifest(mutable)

        credentialed = manifest()
        credentialed["appcastURL"] = "https://token@example.com/appcast.xml"
        with self.assertRaisesRegex(ValueError, "without credentials"):
            release_manifest.validate_manifest(credentialed)

    def test_appcast_rejects_equal_build_and_accepts_higher_build(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = root / "stable.json"
            manifest_path.write_text(json.dumps(manifest()), encoding="utf-8")
            appcast_path = root / "appcast.xml"
            appcast_path.write_text(
                f"""<?xml version="1.0"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel><item>
    <sparkle:version>2</sparkle:version>
    <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
    <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
    <enclosure url="{manifest()['dmgURL']}" length="4"
      sparkle:sha256="{manifest()['sha256']}" sparkle:edSignature="{'A' * 88}" type="application/octet-stream"/>
  </item></channel>
</rss>
""",
                encoding="utf-8",
            )
            command = [
                "python3",
                str(ROOT / "scripts" / "release" / "validate-appcast.py"),
                str(appcast_path),
                str(manifest_path),
            ]
            passed = subprocess.run(
                command + ["--current-build", "1"],
                capture_output=True,
                text=True,
            )
            self.assertEqual(passed.returncode, 0, passed.stderr)
            rejected = subprocess.run(
                command + ["--current-build", "2"],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("equal or lower", rejected.stderr)

    def test_beta_appcast_requires_sparkle_beta_channel(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            release = beta_manifest()
            manifest_path = root / "beta.json"
            manifest_path.write_text(json.dumps(release), encoding="utf-8")
            appcast_path = root / "beta.xml"
            appcast_path.write_text(
                f'''<?xml version="1.0"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel><item>
    <sparkle:version>2</sparkle:version>
    <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
    <sparkle:channel>beta</sparkle:channel>
    <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
    <enclosure url="{release['dmgURL']}" length="4"
      sparkle:sha256="{release['sha256']}" sparkle:edSignature="{'A' * 88}" type="application/octet-stream"/>
  </item></channel>
</rss>
''',
                encoding="utf-8",
            )
            result = subprocess.run(
                ["python3", str(ROOT / "scripts" / "release" / "validate-appcast.py"), str(appcast_path), str(manifest_path)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            appcast_path.write_text(appcast_path.read_text(encoding="utf-8").replace("<sparkle:channel>beta</sparkle:channel>", ""), encoding="utf-8")
            rejected = subprocess.run(
                ["python3", str(ROOT / "scripts" / "release" / "validate-appcast.py"), str(appcast_path), str(manifest_path)],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("beta channel", rejected.stderr)
            appcast_path.write_text(
                appcast_path.read_text(encoding="utf-8").replace(
                    "<sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>",
                    "<sparkle:shortVersionString>1.0.1</sparkle:shortVersionString>",
                ),
                encoding="utf-8",
            )
            version_rejected = subprocess.run(
                ["python3", str(ROOT / "scripts" / "release" / "validate-appcast.py"), str(appcast_path), str(manifest_path)],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(version_rejected.returncode, 0)
            self.assertIn("short version", version_rejected.stderr)


if __name__ == "__main__":
    unittest.main()
