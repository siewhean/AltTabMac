# Phase 0 QA/QC Record

**Phase:** Governance, repository hygiene, and trustworthy gates  
**Branch:** `agent/native-release-readiness`  
**Pull request:** #26  
**Status:** PASS WITH USER-APPROVED GITHUB ACTIONS QUOTA WAIVER  
**Started:** 2026-07-22  
**Accepted:** 2026-07-22

## Decision boundary

The user explicitly instructed the implementation to continue without GitHub Actions because the private-repository Actions usage limit has been reached.

This Phase 0 pass therefore means:

- repository and website Phase 0 work is accepted;
- Vercel and source-level website gates passed;
- generated build output was removed;
- the project may proceed to deterministic local application packaging;
- GitHub-hosted macOS 14 and macOS 15 execution is deferred, not treated as passed.

It does **not** mean the native app is signed, notarized, accepted on real Macs, or ready for public distribution.

## Scope completed

- The phased production-readiness plan was committed before implementation.
- Infinite autoplay loops were replaced by one-shot playback.
- Every autoplay clip is five seconds or less; Overview is normalized to 4.8 seconds.
- Reduce Motion returns media to a static poster state.
- Completed playback is remembered and does not restart after viewport re-entry.
- The generated manifest records duration, byte count, SHA-256, and one-shot motion policy.
- Source, rendered-response, and browser verification contracts were updated.
- Stale social metadata now references the maintained 1920 × 1200 WebP poster.
- README and task tracking identify native release readiness as the active phase.
- Root `.DS_Store` and the complete tracked `.build/` tree were removed.
- The Vercel build-rate window cleared.
- A no-path-filter `Release Readiness` workflow was added for use when Actions quota returns.
- GitHub Actions runner rejection is preserved as deferred issue #30.

## QA/QC result

| Check | Result | Evidence / limitation |
|---|---|---|
| Dependency audit at moderate threshold | **PASS** | Vercel build: `found 0 vulnerabilities` |
| Source SEO and media verification | **PASS** | Vercel source verification passed for 22 public routes and maintained showcase media |
| TypeScript | **PASS** | Vercel `tsc --noEmit` completed |
| Next.js production build | **PASS** | Vercel generated all 37 application pages |
| Vercel preview | **PASS** | Fresh branch deployments reached `READY` after the rate window cleared |
| One-shot media source contract | **PASS** | no `loop`; completion and replay guards are present |
| Reduce Motion source contract | **PASS** | static poster behavior is implemented and verified by source assertions |
| Recursive tracked `.build/` removal | **PASS** | Git tree deletion and PR comparison contain no added `.build` entries |
| Root `.DS_Store` removal | **PASS** | PR comparison |
| README, metadata, and provenance reconciliation | **PASS** | current source contract |
| Hosted Ubuntu runner execution | **WAIVED / DEFERRED** | usage limit exhausted; issue #30 |
| Swift macOS 14 | **WAIVED / DEFERRED** | no Swift production source changed in Phase 0; must pass before Phase 2 |
| Swift macOS 15 | **WAIVED / DEFERRED** | no Swift production source changed in Phase 0; must pass before Phase 2 |
| GitHub rendered/browser workflow | **WAIVED / DEFERRED** | source contracts and Vercel production build used as the temporary substitute |

## Residual risks carried into later phases

1. The full Swift suite has not executed on the Phase 0 head because Actions quota is exhausted.
2. Runtime browser completion, viewport replay, and Reduce Motion checks have not executed in the GitHub browser harness on the final head.
3. Developer ID signing, Hardened Runtime, notarization, stapling, Gatekeeper assessment, and clean-machine installation are unimplemented.
4. Real-macOS exact focused-window acceptance remains unexecuted.

These risks block Phase 2 completion and any public native release, but they do not block starting Phase 1 deterministic packaging.

## Phase 0 release decision

**PASS WITH WAIVER.** PR #26 may be merged and Phase 1 may begin.

Conditions attached to this pass:

- issue #30 remains open until Actions quota returns;
- the no-path-filter Release Readiness workflow must be rerun before Phase 2 passes;
- Swift macOS 14 and macOS 15 must pass before signing/notarization is accepted;
- no public release claim may cite the waived checks as successful evidence.

## Branch cleanup inventory

Merged, superseded, or operational branches should be deleted after PR #26 merges. Branch deletion is repository housekeeping and does not alter the accepted source state.

Do not delete `main`. Do not create `release/native-rc1` before Phase 2 passes.