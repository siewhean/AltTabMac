# Phase 0 QA/QC Record

**Phase:** Governance, repository hygiene, and trustworthy gates  
**Branch:** `agent/native-release-readiness`  
**Pull request:** #26  
**Candidate head:** populated after the reopened-PR workflow run  
**Status:** VALIDATION IN PROGRESS  
**Started:** 2026-07-22

## Scope completed in source

- The phased production-readiness plan was committed before implementation.
- Looping autoplay was replaced by one-shot playback.
- Every autoplay clip is capped at five seconds; the Overview is normalized to 4.8 seconds.
- Reduce Motion pauses the media and returns it to the poster state.
- Completed playback is remembered and does not restart after leaving and re-entering the viewport.
- The generated manifest records exact duration, byte count, SHA-256, and the one-shot motion policy.
- Source, rendered-response, and browser verification were updated for the new contract.
- Stale root social metadata uses the maintained 1920×1200 WebP poster.
- README and task tracking identify native production readiness as the active phase.
- A hosted-runner health workflow is present.
- Root `.DS_Store` and the complete tracked `.build/` tree were removed.
- The Vercel build-rate window cleared and a fresh exact-branch preview can run.

## QA/QC gate

The accepted Phase 0 commit must pass every row below without substituting an earlier commit.

| Check | Status | Evidence / next action |
|---|---|---|
| Dependency audit at moderate threshold | Running | exact-head Vercel preview |
| Source SEO and media verification | Running | exact-head Vercel preview |
| TypeScript | Running | exact-head Vercel preview |
| Next.js production build | Running | exact-head Vercel preview |
| Rendered-site checks | Pending | reopened PR SEO/GEO workflow |
| Desktop/mobile browser checks | Pending | reopened PR SEO/GEO workflow |
| One-shot completion/replay test | Pending | `verify-browser.mjs` |
| Reduce Motion test | Pending | `verify-browser.mjs` |
| Hosted runner reaches first shell step | Pending | reopened Workflow Health run |
| Website Security | Pending | reopened PR run |
| SEO/GEO | Pending | reopened PR run |
| Swift macOS 14 | Pending | reopened PR run |
| Swift macOS 15 | Pending | reopened PR run |
| Vercel preview for exact head | Pending | deployment metadata must equal accepted commit |
| Recursive tracked `.build/` removal | **PASS** | Git tree deletion commit and PR comparison |
| Root `.DS_Store` removal | **PASS** | PR comparison |
| Branch deletion inventory | Prepared | execute immediately after merge |

## Release decision

**NOT YET PASS.** Update this file exactly once more after all checks finish. That final documentation commit must itself receive the exact-head Vercel and hosted-runner gates before PR #26 is marked ready and merged.

## Branch cleanup inventory after merge

Delete merged or superseded refs if they still exist:

```text
agent/fix-switcher-mru-completeness
agent/implement-seo-geo-audit
agent/seo-geo-competitive-hardening
agent/configure-indexnow-production
agent/align-switcher-claims-with-product
agent/seo-geo-evidence-authority-phase
agent/seo-geo-retrieval-and-feature-depth
agent/real-app-showcase-media
agent/fix-showcase-discovery-copy
agent/hd-showcase-upgrade
agent/deploy-hd-showcase-vercel
agent/finalize-hd-dependency-lock
agent/simplify-autoplay-mobile
agent/verify-production-seo-geo
agent/submit-indexnow-production
agent/verify-authority-production
pre-exam-status-(BAD)
```

Do not delete `main`. Do not create `release/native-rc1` before Phase 2 passes.
