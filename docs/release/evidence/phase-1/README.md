# Phase 1 QA/QC Record

**Phase:** Deterministic application bundle and unsigned/local-QA artifact  
**Branch:** `agent/phase-1-deterministic-packaging`  
**Pull request:** #31  
**Status:** CROSS-PLATFORM GATE PASSED / NATIVE MACOS GATE PENDING  
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
- Added `scripts/release/run-phase1-qa.sh` to execute native tests, packaging, reproducibility, and evidence collection locally in one command.
- Kept `build.sh` as a compatibility wrapper around the new packaging pipeline.
- Removed the tracked legacy root `CmdTab.app` bundle from source control.

## Cross-platform verification

Vercel deployment `dpl_FUF6dt3ghEDLsrPG3cZzFZmrJuFU` reached `READY` for commit `8989139ec05083bce738561a7b399094373f0f74`.

The Vercel build recorded:

- `Repository release identity verification passed`;
- dependency audit found `0 vulnerabilities` at the moderate threshold;
- SEO, media, and copy verification passed;
- TypeScript passed;
- the Next.js production build completed.

The subsequent branch commit adds the local macOS QA evidence runner and does not change the release identity contract verified by that deployment.

## QA/QC checklist

| Check | Status | Evidence / next action |
|---|---|---|
| ReleaseConfig and repository identity validation | **PASS** | Vercel `dpl_FUF6dt3ghEDLsrPG3cZzFZmrJuFU` |
| Checked-in Info.plist matches ReleaseConfig | **PASS** | repository identity gate |
| Public product facts match native bundle identity | **PASS** | repository identity gate |
| Empty Phase 1 entitlement baseline | **PASS** | repository identity gate |
| Generated root `CmdTab.app` absent from tracking | **PASS** | repository identity gate and branch diff |
| Dependency audit at moderate threshold | **PASS** | Vercel reported zero vulnerabilities |
| Website SEO/media/copy verification | **PASS** | Vercel prebuild |
| Website TypeScript and production build | **PASS** | Vercel READY deployment |
| Bundle migration unit tests | **PENDING LOCAL MACOS** | `run-phase1-qa.sh` |
| Full Swift test suite | **PENDING LOCAL MACOS** | `run-phase1-qa.sh` |
| Clean Swift release build | **PENDING LOCAL MACOS** | `run-phase1-qa.sh` |
| Valid app bundle layout | **PENDING LOCAL MACOS** | bundle verifier |
| Main executable present and executable | **PENDING LOCAL MACOS** | bundle verifier |
| No unexpected executable or symlink | **PENDING LOCAL MACOS** | bundle verifier |
| App icon present | **PENDING LOCAL MACOS** | bundle verifier |
| Actual architecture recorded | **PENDING LOCAL MACOS** | bundle manifest |
| Ad-hoc signature verifies | **PENDING LOCAL MACOS** | `codesign --verify --strict` |
| Info.plist and resources checksummed | **PENDING LOCAL MACOS** | `.sha256` and manifest |
| Two clean unsigned builds are byte-for-byte reproducible | **PENDING LOCAL MACOS** | reproducibility check |
| Existing beta preferences and license remain available | **PENDING MANUAL MACOS** | legacy/new bundle migration exercise |
| Accessibility and Screen Recording re-grant guidance works | **PENDING MANUAL MACOS** | TCC transition record |
| App launches as a menu-bar agent | **PENDING MANUAL MACOS** | launch record |
| App remains absent from Dock/native switcher | **PENDING MANUAL MACOS** | launch record |

## Required local command

From a checkout of the branch on a Mac:

```bash
./scripts/release/run-phase1-qa.sh
```

The command writes automated evidence to:

```text
dist/phase1-evidence/
```

After it passes, complete `dist/phase1-evidence/manual-checks.md` and copy the accepted evidence into this phase record before merging PR #31.

## Current release decision

**NO-GO.** The cross-platform source and website gate passed, but Phase 1 cannot pass until the Swift sources compile and test on macOS, the app is packaged and verified, two clean builds reproduce, migration is observed, and menu-bar-only launch behavior is confirmed.

## Known boundaries

- GitHub Actions execution remains deferred under issue #30.
- The current pipeline builds the host Mac architecture only.
- No Universal Binary claim is permitted.
- Changing the bundle identifier may require users to grant Accessibility and Screen Recording again; TCC permissions cannot be copied by CmdTab.
- No Developer ID, notarization, stapling, or Gatekeeper distribution claim is permitted.
- The existing signed/notarized DMG script is not accepted as Phase 2 evidence until it is reconciled with this Phase 1 pipeline and run with protected credentials.