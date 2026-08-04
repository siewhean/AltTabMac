# G1 Unsigned Artifact Results — 2026-08-04

## Provenance

| Field | Value |
| --- | --- |
| Source SHA | `f258eb6c4cdce3fa6c0a87211d78b37bd0145d0d` |
| Baseline | `dcd02faafbe4cd944fa9899d4e5ddcd6d5f70407` |
| Candidate changed files | 153, as enumerated by `git diff --name-only <baseline> <source SHA>` |
| Operator | Codex local release verification |
| UTC completion | `2026-08-04T07:11:01Z` |
| Host | Apple silicon (`arm64`), macOS 26.6 (25G5043d) |
| Permission state | build-only; no permission-state claim |
| Artifact disposition | local unsigned inspection artifact; not committed, uploaded, signed, or published |

## Command record

| Command | Exit | Result |
| --- | --- | --- |
| `python3 scripts/release/release_config.py verify-repository` | 0 | release identity, arm64 policy, and repository checks passed |
| `CMDTAB_REPRO_BUILD_JOBS=1 ./scripts/release/reproducibility-check.sh` | 0 | two clean isolated scratch builds were byte-for-byte reproducible |
| isolated `package-app.sh` with `CMDTAB_SKIP_ADHOC_SIGN=1`, then `verify-bundle.sh <app> unsigned` | 0 | unsigned bundle verification passed |
| `python3 scripts/release/scan_tracked_secrets.py` | 0 | 457 tracked UTF-8 files scanned; 23 binary files skipped; no finding |

The reproducibility command verified each app before comparing sorted file
inventories, `Info.plist`, and `Contents/MacOS/CmdTab`. Its final result was:
`Two clean unsigned CmdTab.app builds from distinct scratch directories are
byte-for-byte reproducible.`

## Inspection record

| Item | Value |
| --- | --- |
| App size | 9,380 KiB |
| File inventory | 93 regular files; deterministic inventory digest `464599f43765909f1b37ea46ef5f79770a96e4cc23e242e1c0e44cc4b21bda2f` |
| Whole-app archive | 4,448,156 bytes; SHA-256 `b16621a362e784899511c3da47e2a807b3fbd0e81bdc2f70946cff06b34861e2` |
| Executable SHA-256 | `5ad0f08fb4567891e9f904a4cab942aa2be5456b0164f846256fcd91b6f6d8a5` |
| `Info.plist` SHA-256 | `274b0870d9a36c94125bd609d1214b3c0c137277c86ccf43f50cb0678e2b445b` |
| Embedded Sparkle SHA-256 | `8f0633d92028a521e8ff9715a7b14b0b4e19a26c2980679a8dbe5b2bd38243c7` |
| Bundle contract | `net.cmdtab.CmdTab`, version `1.0.0 (1)`, minimum macOS 13.0 |
| Architecture | all executable app and Sparkle slices `arm64` |
| Resources | app icon and privacy manifest present; Sparkle 2.9.2 nested verification passed |
| Entitlements / symbols | empty unsigned app entitlements; no dSYM in the app |
| Content review | no local-user path or credential marker found |

## Manual evidence, risk, and QA

No interactive app behavior was asserted. The operator inspected only the
unsigned bundle layout and verifier output. Independent Codex QA/QC reviewed
the source record, canonical index, hashes, scope, and diff hygiene on
2026-08-04 and approved the unsigned-only result. Signing, notarization, DMG,
Gatekeeper, permission transitions, and clean-machine acceptance remain outside
this result.

**Next action:** use the exact clean candidate for credential-backed Gate 3
only after the owner supplies the secure Developer ID/notarization/Sparkle
inputs; keep this result separate from signed-artifact acceptance.
