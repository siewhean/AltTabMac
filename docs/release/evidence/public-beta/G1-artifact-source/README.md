# G1 Artifact-Source Record — 2026-08-04

## Candidate and scope

- **Exact SHA:** `f258eb6c4cdce3fa6c0a87211d78b37bd0145d0d`
- **Artifact:** unsigned, isolated arm64 macOS 13 build only; no Developer ID
  identity, timestamp, notarization, or distribution claim.
- **Artifact retention:** the local inspection artifact is not committed or
  published; its hashes and inspection result are recorded below.

Historical Phase 1 and prior source checks establish the policy and prove the
repository verifier exists. They do **not** prove the next frozen candidate.
This record is the exact unsigned-artifact evidence for `f258eb6`; it must be
repeated after a source change.

## Commands and automated result

| Command | Result |
| --- | --- |
| `python3 scripts/release/release_config.py verify-repository` | PASS |
| `CMDTAB_REPRO_BUILD_JOBS=1 ./scripts/release/reproducibility-check.sh` | PASS — two clean scratch builds byte-for-byte reproducible |
| isolated `package-app.sh` with `CMDTAB_SKIP_ADHOC_SIGN=1`, then `verify-bundle.sh … unsigned` | PASS |
| `python3 scripts/release/scan_tracked_secrets.py` | PASS — 457 tracked UTF-8 files; 23 binary files skipped |

The reproducibility script independently verified each bundle before comparing
its file inventory, `Info.plist`, and `CmdTab` executable bytes.

## Artifact inspection

| Item | Result |
| --- | --- |
| Bundle/version | `net.cmdtab.CmdTab`, `1.0.0 (1)` |
| Minimum OS / architecture | macOS 13.0 / all app and Sparkle executables `arm64` |
| Resources | app icon and `PrivacyInfo.xcprivacy` present |
| Entitlements | empty unsigned app entitlements |
| Sparkle | 2.9.2 embedded; strict nested verification passed |
| dSYMs | none in the artifact (0) |
| Sensitive/local content | no developer-home path or credential marker |
| `CmdTab` SHA-256 | `5ad0f08fb4567891e9f904a4cab942aa2be5456b0164f846256fcd91b6f6d8a5` |
| `Info.plist` SHA-256 | `274b0870d9a36c94125bd609d1214b3c0c137277c86ccf43f50cb0678e2b445b` |
| Sparkle SHA-256 | `8f0633d92028a521e8ff9715a7b14b0b4e19a26c2980679a8dbe5b2bd38243c7` |

## Disposition

See the command, hash, size, host, and scope record in
[`results.md`](results.md). **PASS — independent QA/QC approved the exact
unsigned artifact integrity/reproducibility result.** It does not establish
Developer ID signing, notarization, stapling, Gatekeeper, DMG integrity, or
clean-machine behavior.

**Next action:** obtain independent QA/QC of this record, then use the exact
clean candidate for credential-backed Gate 3 only after the owner supplies the
secure Developer ID/notarization/Sparkle inputs. Do not commit artifacts,
private dSYMs, credentials, or the local inspection path.
