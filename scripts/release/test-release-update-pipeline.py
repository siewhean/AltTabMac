#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_SPEC = importlib.util.spec_from_file_location(
    "release_manifest",
    ROOT / "scripts" / "release" / "release_manifest.py",
)
assert MODULE_SPEC and MODULE_SPEC.loader
release_manifest = importlib.util.module_from_spec(MODULE_SPEC)
MODULE_SPEC.loader.exec_module(release_manifest)
CONFIG_SPEC = importlib.util.spec_from_file_location(
    "release_config", ROOT / "scripts" / "release" / "release_config.py"
)
assert CONFIG_SPEC and CONFIG_SPEC.loader
release_config = importlib.util.module_from_spec(CONFIG_SPEC)
CONFIG_SPEC.loader.exec_module(release_config)
PIN_SPEC = importlib.util.spec_from_file_location(
    "verify_workflow_actions",
    ROOT / "scripts" / "release" / "verify-workflow-actions.py",
)
assert PIN_SPEC and PIN_SPEC.loader
verify_workflow_actions = importlib.util.module_from_spec(PIN_SPEC)
PIN_SPEC.loader.exec_module(verify_workflow_actions)


def manifest(build: int = 2, channel: str = "stable") -> dict[str, object]:
    source_sha = "a" * 40
    return {
        "schemaVersion": 1,
        "channel": channel,
        "version": "1.0.0",
        "build": build,
        "minimumMacOS": "13.0",
        "dmgURL": f"https://releases.cmdtab.net/{source_sha}/CmdTab-1.0.0-{build}.dmg",
        "bytes": 4,
        "sha256": "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
        "releaseDate": "2026-07-27",
        "sourceSHA": source_sha,
        "appcastURL": (
            "https://cmdtab.net/releases/beta/appcast.xml"
            if channel == "beta"
            else "https://cmdtab.net/releases/appcast.xml"
        ),
    }


class ReleaseManifestTests(unittest.TestCase):
    def test_release_config_derives_each_supported_channel(self) -> None:
        base = json.loads((ROOT / "release" / "ReleaseConfig.json").read_text(encoding="utf-8"))
        expected = {
            "development": ("local-qa", None),
            "beta": ("public-beta", "https://cmdtab.net/releases/beta/appcast.xml"),
            "stable": ("developer-id-direct", "https://cmdtab.net/releases/appcast.xml"),
        }
        for channel, (distribution, feed) in expected.items():
            candidate = dict(base, updateChannel=channel, distributionChannel=distribution)
            with tempfile.NamedTemporaryFile(mode="w", suffix=".json") as handle:
                json.dump(candidate, handle)
                handle.flush()
                loaded = release_config.load_config(Path(handle.name))
                self.assertEqual(loaded["updateFeedURL"], feed)
                plist = release_config.plist_for(loaded, include_environment_key=False)
                self.assertEqual(plist.get("SUFeedURL"), feed)
                if channel == "development":
                    self.assertNotIn("SUScheduledCheckInterval", plist)

    def test_release_config_rejects_mismatched_channel_metadata(self) -> None:
        base = json.loads((ROOT / "release" / "ReleaseConfig.json").read_text(encoding="utf-8"))
        candidate = dict(base, updateChannel="beta", distributionChannel="developer-id-direct")
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json") as handle:
            json.dump(candidate, handle)
            handle.flush()
            with self.assertRaisesRegex(SystemExit, "does not match"):
                release_config.load_config(Path(handle.name))

    def test_release_config_rejects_commerce_enabled_public_beta(self) -> None:
        base = json.loads((ROOT / "release" / "ReleaseConfig.json").read_text(encoding="utf-8"))
        candidate = dict(base, commerceEnabled=True)
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json") as handle:
            json.dump(candidate, handle)
            handle.flush()
            with self.assertRaisesRegex(SystemExit, "commerceEnabled false"):
                release_config.load_config(Path(handle.name))

    def test_release_info_plist_injects_only_valid_public_trial_keyring(self) -> None:
        config = release_config.load_config(ROOT / "release" / "ReleaseConfig.json")
        public_key = (
            "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEZ9FZZyw0trHoeLiL/uri6aLwr8R"
            "hw9vNEGuI6afJqY9foeogoVNhQRZ4Hexv/fLhASKa4FKqaEflq3Uh6PIfDw=="
        )
        with patch.dict(
            "os.environ",
            {
                "CMDTAB_TRIAL_SIGNING_KID": "trial-2026-01",
                "CMDTAB_TRIAL_PUBLIC_KEYRING_JSON": json.dumps(
                    {"trial-2026-01": public_key}
                ),
            },
            clear=True,
        ):
            plist = release_config.plist_for(config)
        self.assertEqual(
            plist["CmdTabTrialPublicKeyring"], {"trial-2026-01": public_key}
        )

    def test_release_info_plist_rejects_invalid_or_unbound_trial_keyring(self) -> None:
        public_key = (
            "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEZ9FZZyw0trHoeLiL/uri6aLwr8R"
            "hw9vNEGuI6afJqY9foeogoVNhQRZ4Hexv/fLhASKa4FKqaEflq3Uh6PIfDw=="
        )
        with self.assertRaisesRegex(SystemExit, "must contain CMDTAB_TRIAL_SIGNING_KID"):
            release_config.validate_trial_public_keyring(
                json.dumps({"trial-old": public_key}), "trial-2026-01"
            )
        with self.assertRaisesRegex(SystemExit, "canonical P-256 SPKI"):
            release_config.validate_trial_public_keyring(
                json.dumps({"trial-2026-01": "AA=="}), "trial-2026-01"
            )
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
        self.assertIn("verify-notarized-dmg.sh", appcast)
        for required in [
            "codesign --verify",
            "stapler validate",
            "spctl --assess --type open",
            "verify-bundle.sh",
            "spctl --assess --type execute",
        ]:
            self.assertIn(required, verifier)

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

    def test_release_package_fails_closed_on_universal_architecture_policy(self) -> None:
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
            "universal-arm64-x86_64",
        )
        for required in [
            "universal-arm64-x86_64",
            'BUILD_ARCHITECTURES="arm64,x86_64"',
            'EXPECTED_ARCHITECTURES="arm64,x86_64"',
            'CMDTAB_BUILD_ARCHITECTURES="${BUILD_ARCHITECTURES}"',
            'CMDTAB_EXPECTED_ARCHITECTURES="${EXPECTED_ARCHITECTURES}"',
            "Release architecture policy requires arm64,x86_64",
        ]:
            self.assertIn(required, packager)
        self.assertIn("Expected architectures", verifier)

    def test_valid_manifest_and_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            artifact = Path(directory) / "CmdTab.dmg"
            artifact.write_bytes(b"test")
            release_manifest.validate_manifest(manifest(), artifact=artifact)

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

    def test_beta_manifest_requires_beta_feed_and_channel_matched_history(self) -> None:
        release_manifest.validate_manifest(manifest(channel="beta"))
        bad_feed = manifest(channel="beta")
        bad_feed["appcastURL"] = "https://cmdtab.net/releases/appcast.xml"
        with self.assertRaisesRegex(ValueError, "does not match"):
            release_manifest.validate_manifest(bad_feed)
        with self.assertRaisesRegex(ValueError, "channel does not match"):
            release_manifest.validate_manifest(manifest(channel="beta"), previous=manifest())

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
    <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
    <enclosure url="{manifest()['dmgURL']}" length="4"
      sparkle:edSignature="{'A' * 88}" type="application/octet-stream"/>
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
            manifest_path = root / "beta.json"
            beta_manifest = manifest(channel="beta")
            manifest_path.write_text(json.dumps(beta_manifest), encoding="utf-8")
            appcast_path = root / "appcast.xml"
            appcast_path.write_text(
                f'''<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>
<sparkle:version>2</sparkle:version><sparkle:channel>beta</sparkle:channel>
<sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
<enclosure url="{beta_manifest["dmgURL"]}" length="4" sparkle:edSignature="{'A' * 88}" />
</item></channel></rss>''', encoding="utf-8")
            result = subprocess.run(
                ["python3", str(ROOT / "scripts" / "release" / "validate-appcast.py"), str(appcast_path), str(manifest_path)],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
