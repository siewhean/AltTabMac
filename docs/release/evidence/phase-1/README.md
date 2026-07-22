# Phase 1 QA/QC Record

**Phase:** Deterministic application bundle and unsigned/local-QA artifact  
**Branch:** `agent/phase-1-deterministic-packaging`  
**Pull request:** #31  
**Status:** PASS  
**Started:** 2026-07-22  
**Accepted:** 2026-07-23  
**Accepted source commit:** `516a9476c01f4d59981f35dc44b6eb09dcd6d790`  
**Merge commit:** `f37e47029344e191682bd02ade8d7daf4ea241bd`

## Decision boundary

Phase 1 proves that CmdTab can be built from source into one deterministic host-architecture application bundle, verified locally, ad-hoc signed for local QA, and exercised on a real Mac.

This pass does **not** approve public distribution. Developer ID signing, secure timestamping, notarization, stapling, Gatekeeper assessment, clean-account installation, updates, rollback, and the complete interactive desktop matrix remain later-phase gates.

## Implemented in source

- Added `release/ReleaseConfig.json` as the canonical local bundle metadata source.
- Selected `net.cmdtab.CmdTab` as the permanent direct-distribution bundle identifier, pending confirmation against the intended Apple Developer team before Phase 2 acceptance.
- Added deterministic Info.plist rendering and repository-wide identity verification.
- Added a repository identity gate covering Info.plist, website product facts, migration constants, startup ordering, the empty Phase 1 entitlement baseline, and absence of tracked app bundles.
- Added a one-time migration from the legacy `com.user.CmdTab` UserDefaults domain and Keychain account.
- Migrates only maintained preference, search-memory, trial, install-ID, activation, cache, license, and developer-test state when the new identity does not already contain the value.
- Preserves the legacy UserDefaults domain and Keychain item for rollback.
- Leaves migration retryable when silent Keychain access is temporarily unavailable.
- Added unit tests for migration filtering, preservation, idempotence, retry behavior, and bundle-identity constants.
- Added clean release-mode Swift build tooling with isolated scratch directories.
- Added deterministic `.app` assembly with explicit file permissions and no symbolic links.
- Added optional ad-hoc local signing for local QA only.
- Replaced misleading network-deny entitlements with an empty reviewed entitlement baseline.
- Added bundle layout, metadata, architecture, quarantine, executable, resource, checksum, and signature verification.
- Added bundle manifest and SHA-256 generation.
- Added a two-clean-build byte-for-byte reproducibility check using one canonical scratch path.
- Added `scripts/release/run-phase1-qa.sh` to execute native tests, packaging, reproducibility, inspection, and evidence collection in one command.
- Kept `build.sh` as a compatibility wrapper around the new packaging pipeline.
- Removed the tracked legacy root `CmdTab.app` bundle from source control.
- Fixed Arc preview capture so an unusable SkyLight hardware frame falls through to the public Core Graphics strategies instead of returning `nil`.
- Added regression tests for accepted, rejected, and missing preferred capture paths.

## Cross-platform and hosted verification

Vercel reached `READY` for the Phase 1 branch and exercised the repository identity gate, dependency audit, source SEO/media/copy checks, TypeScript, and the Next.js production build.

GitHub-hosted Actions remained unavailable because the private-repository usage allowance was exhausted. That waiver allowed Phase 1 local packaging work to proceed, but issue #30 remains a mandatory prerequisite before Phase 2 can be accepted.

## Final automated local macOS QA

The authoritative command was run from the accepted source commit:

```bash
./scripts/release/run-phase1-qa.sh
```

The generated evidence identified the same source commit as `git rev-parse HEAD`:

```text
516a9476c01f4d59981f35dc44b6eb09dcd6d790
```

The final result file contained:

```text
PASS
```

### Automated results

| Check | Result | Evidence |
|---|---|---|
| ReleaseConfig and repository identity validation | **PASS** | `run-phase1-qa.sh` |
| Checked-in Info.plist matches ReleaseConfig | **PASS** | repository identity gate |
| Public product facts match native bundle identity | **PASS** | repository identity gate |
| Empty Phase 1 entitlement baseline | **PASS** | repository identity gate |
| Generated root `CmdTab.app` absent from tracking | **PASS** | repository identity gate |
| Bundle migration tests | **PASS — 6/6** | focused Swift test run |
| Capture fallback regression tests | **PASS — 3/3** | `CaptureFallbackTests` |
| Complete Swift package suite | **PASS — 132/132** | clean isolated scratch path |
| Clean Swift release build | **PASS** | production build |
| Valid app bundle layout | **PASS** | `verify-bundle.sh` |
| Main executable present and executable | **PASS** | bundle verifier |
| No unexpected executable or symlink | **PASS** | bundle verifier |
| App icon and required resources present | **PASS** | bundle verifier |
| Bundle identifier and version | **PASS** | `net.cmdtab.CmdTab`, `1.0.0 (1)` |
| Actual architecture recorded | **PASS** | `arm64` |
| Ad-hoc signature verifies | **PASS** | strict local bundle verification |
| Info.plist and resources checksummed | **PASS** | manifest and SHA-256 output |
| Two clean unsigned builds are byte-for-byte reproducible | **PASS** | canonical reproducibility check |
| Evidence source commit matches tested HEAD | **PASS** | both recorded `516a947…` |

The only emitted packaging warning was the deprecated `codesign` `--entitlements :-` inspection syntax. It did not affect signature validation or the Phase 1 result and should be corrected during later release-script maintenance.

## Final manual macOS QA

The packaged application at `dist/CmdTab.app` was tested on the build Mac.

| Check | Result | Notes |
|---|---|---|
| Packaged app launches | **PASS** | exact `dist/CmdTab.app` bundle |
| Menu-bar application behavior | **PASS** | status item visible |
| App absent from Dock | **PASS** | accessory/menu-bar agent behavior |
| App absent from native macOS Command-Tab switcher | **PASS** | native switcher exclusion confirmed |
| Settings opens | **PASS** | menu-bar path confirmed |
| Accessibility permission path | **PASS** | stale ad-hoc TCC records required a controlled reset and exact-bundle re-add |
| Screen Recording permission path | **PASS** | exact tested bundle re-added and relaunched |
| Custom Command-Tab interception | **PASS** | CmdTab overlay appeared and native switcher was suppressed |
| Deliberate quit and reopen | **PASS** | confirmed using CmdTab's quit pathway |
| Arc window membership | **PASS** | Arc tile appeared |
| Arc live thumbnail | **PASS** | real preview replaced the placeholder |
| Arc activation | **PASS** | selected Arc tile activated the intended Arc window |

### Migration observation limitation

A real legacy beta profile containing old preferences, search memory, trial/license state, and Keychain data was not separately exercised during the final manual acceptance session. Migration behavior is covered by six passing focused tests, including preservation, idempotence, non-overwrite, and retry behavior.

This limitation is carried forward as an upgrade-path test for the signed release candidate. It must not be rewritten as a completed manual observation.

## Failure history and disposition

Phase 1 did not pass on the first attempt. The following failures were found and resolved before acceptance:

1. Build-path-sensitive and linker-generated differences prevented reproducibility.
   - Resolved by using one canonical scratch path and deterministic linker mode.
2. Accessibility and Screen Recording appeared enabled in System Settings while the rebuilt ad-hoc bundle reported them as required.
   - Resolved for local QA by stopping every stale process, resetting TCC records, re-adding the exact packaged bundle, and relaunching it.
   - Stable Developer ID signing remains the production solution for consistent code identity.
3. Arc appeared as a switcher item but its preview remained a placeholder.
   - Root cause: an unusable preferred SkyLight frame returned `nil` before public capture fallbacks ran.
   - Resolved by falling through when preferred capture preparation fails and adding three regression tests.

## Phase 1 release decision

**PASS.** The deterministic local bundle, migration logic, local ad-hoc package, automated suite, reproducibility check, and required manual packaged-app behavior passed at source commit `516a9476c01f4d59981f35dc44b6eb09dcd6d790`. PR #31 merged that accepted commit into `main` through merge commit `f37e47029344e191682bd02ade8d7daf4ea241bd`.

Phase 2 may begin. No public artifact may be distributed from this evidence alone.

## Known boundaries carried into Phase 2

- GitHub Actions execution remains deferred under issue #30 and must pass before Phase 2 acceptance.
- The current pipeline builds the host Mac architecture only.
- No Universal Binary, Intel, or cross-architecture claim is permitted.
- Ad-hoc signing is for local QA only and can cause rebuilt bundles to require fresh macOS privacy grants.
- `net.cmdtab.CmdTab` must be confirmed against the intended Apple Developer team before Developer ID signing is accepted.
- No Developer ID, secure timestamp, notarization, stapling, Gatekeeper, clean-account distribution, update, or rollback claim is permitted yet.
- Real legacy-profile upgrade testing must be included in the signed release-candidate matrix.