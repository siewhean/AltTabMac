# Phase 1 QA/QC Record

**Phase:** Deterministic application bundle and unsigned/local-QA artifact  
**Branch:** `agent/phase-1-deterministic-packaging`  
**Pull request:** #31  
**Status:** IMPLEMENTATION IN PROGRESS  
**Started:** 2026-07-22

## Implemented in source

- Added `release/ReleaseConfig.json` as the canonical local bundle metadata source.
- Selected `net.cmdtab.CmdTab` as the permanent direct-distribution bundle identifier, pending Apple Developer team confirmation before Phase 2.
- Added deterministic Info.plist rendering and source verification.
- Added a repository identity gate covering Info.plist, website product facts, native migration constants, startup ordering, empty Phase 1 entitlements, and absence of tracked app bundles.
- Added a one-time migration from the legacy `com.user.CmdTab` UserDefaults domain.
- Migrates only maintained CmdTab preference, search-memory, trial, install-ID, activation, cache, and developer-test keys.
- Preserves values already present in the new domain and leaves the legacy domain intact for rollback.
- Copies a legacy stored license into the new Keychain account only when the new item is absent.
- Leaves the migration marker unset when Keychain access is temporarily unavailable so migration can retry.
- Added unit tests for migration filtering, preservation, idempotence, retry behavior, and bundle-identity constants.
- Added clean release-mode Swift build tooling with isolated scratch directories.
- Added deterministic `.app` assembly with explicit file permissions and no symbolic links.
- Added optional ad-hoc local signing with Hardened Runtime enabled.
- Replaced misleading network-deny entitlements with an empty reviewed entitlement baseline.
- Added bundle layout, metadata, architecture, quarantine, executable, and signature verification.
- Added bundle manifest and SHA-256 generation.
- Added a two-clean-build byte-for-byte reproducibility check.
- Kept `build.sh` as a compatibility wrapper around the new packaging pipeline.
- Removed the tracked legacy root `CmdTab.app` bundle from source control.

## QA/QC checklist

| Check | Status | Required evidence |
|---|---|---|
| ReleaseConfig and repository identity validation | Pending exact-head Vercel execution | `release_config.py verify-repository` |
| Checked-in Info.plist matches ReleaseConfig | Pending exact-head Vercel execution | repository identity gate |
| Public product facts match native bundle identity | Pending exact-head Vercel execution | repository identity gate |
| Bundle migration unit tests | Pending local macOS execution | `swift test --filter BundleIdentityMigrationTests` |
| Full Swift test suite | Pending local macOS execution | `swift test --scratch-path ...` |
| Clean Swift release build | Pending execution on macOS | `build-app.sh` output |
| Valid app bundle layout | Pending execution on macOS | `verify-bundle.sh` |
| Main executable present and executable | Pending execution | bundle verifier |
| No unexpected executable or symlink | Pending execution | bundle verifier |
| App icon present | Pending execution | bundle verifier |
| Actual architecture recorded | Pending execution | bundle manifest |
| Ad-hoc signature verifies | Pending execution | `codesign --verify --strict` |
| Info.plist and resources checksummed | Pending execution | `.sha256` and manifest |
| Two clean unsigned builds are byte-for-byte reproducible | Pending execution | `reproducibility-check.sh` |
| Existing beta preferences and license remain available | Pending manual migration QA | launch old bundle, seed state, launch new bundle |
| Accessibility and Screen Recording re-grant guidance works | Pending manual macOS QA | TCC transition record |
| App launches as a menu-bar agent | Pending manual macOS QA | launch record |
| App remains absent from Dock/native switcher | Pending manual macOS QA | launch record |

## Current release decision

**NO-GO.** Phase 1 source scaffolding and identity migration are implemented, but the scripts and native tests have not executed on a macOS build machine in this environment. Phase 1 remains incomplete until clean build, full Swift tests, bundle verification, reproducibility, migration, and menu-bar launch checks pass and their outputs are recorded here.

## Known boundaries

- GitHub Actions execution remains deferred under issue #30.
- The current pipeline builds the host Mac architecture only.
- No Universal Binary claim is permitted.
- Changing the bundle identifier may require users to grant Accessibility and Screen Recording again; TCC permissions cannot be copied by CmdTab.
- No Developer ID, notarization, stapling, or Gatekeeper distribution claim is permitted.
- The existing signed/notarized DMG script is not accepted as Phase 2 evidence until it is reconciled with this Phase 1 pipeline and run with protected credentials.
