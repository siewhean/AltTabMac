# Phase 1 QA/QC Record

**Phase:** Deterministic application bundle and unsigned/local-QA artifact  
**Branch:** `agent/phase-1-deterministic-packaging`  
**Status:** IMPLEMENTATION IN PROGRESS  
**Started:** 2026-07-22

## Implemented in source

- Added `release/ReleaseConfig.json` as the canonical local bundle metadata source.
- Selected `net.cmdtab.CmdTab` as the permanent direct-distribution bundle identifier, pending Apple Developer team confirmation before Phase 2.
- Added deterministic Info.plist rendering and source verification.
- Added clean release-mode Swift build tooling with isolated scratch directories.
- Added deterministic `.app` assembly with explicit file permissions and no symbolic links.
- Added optional ad-hoc local signing with Hardened Runtime enabled.
- Replaced misleading network-deny entitlements with an empty reviewed entitlement baseline.
- Added bundle layout, metadata, architecture, quarantine, executable, and signature verification.
- Added bundle manifest and SHA-256 generation.
- Added a two-clean-build byte-for-byte reproducibility check.
- Kept `build.sh` as a compatibility wrapper around the new packaging pipeline.

## QA/QC checklist

| Check | Status | Required evidence |
|---|---|---|
| ReleaseConfig validation | Pending execution | `release_config.py validate` |
| Checked-in Info.plist matches ReleaseConfig | Pending execution | `verify-info-plist` |
| Clean Swift release build | Pending execution on macOS | `build-app.sh` output |
| Valid app bundle layout | Pending execution on macOS | `verify-bundle.sh` |
| Main executable present and executable | Pending execution | bundle verifier |
| No unexpected executable or symlink | Pending execution | bundle verifier |
| App icon present | Pending execution | bundle verifier |
| Actual architecture recorded | Pending execution | bundle manifest |
| Ad-hoc signature verifies | Pending execution | `codesign --verify --strict` |
| Info.plist and resources checksummed | Pending execution | `.sha256` and manifest |
| Two clean unsigned builds are byte-for-byte reproducible | Pending execution | `reproducibility-check.sh` |
| App launches as a menu-bar agent | Pending manual macOS QA | launch record |
| App remains absent from Dock/native switcher | Pending manual macOS QA | launch record |

## Current release decision

**NO-GO.** Phase 1 source scaffolding is implemented, but the scripts have not yet been executed on a macOS build machine in this environment. Phase 1 remains incomplete until the clean build, bundle verification, reproducibility check, and menu-bar launch checks pass and their outputs are recorded here.

## Known boundaries

- GitHub Actions execution remains deferred under issue #30.
- The current pipeline builds the host Mac architecture only.
- No Universal Binary claim is permitted.
- No Developer ID, notarization, stapling, or Gatekeeper distribution claim is permitted.
- The existing signed/notarized DMG script is not accepted as Phase 2 evidence until it is reconciled with this Phase 1 pipeline and run with protected credentials.
