# Phase 0 QA/QC Record

**Phase:** Governance, repository hygiene, and trustworthy gates  
**Branch:** `agent/native-release-readiness`  
**Pull request:** #26  
**Audited head:** `cb3ca4d8a671cb615a58c96fe887812bdfc315ac`  
**Status:** BLOCKED / NO-GO  
**Started:** 2026-07-22

## Scope completed in source

- The phased production-readiness plan was committed before implementation.
- Looping autoplay was replaced by one-shot playback.
- Every autoplay clip is capped at five seconds; the Overview is normalized to 4.8 seconds.
- Reduce Motion pauses the media and returns it to the poster state.
- Completed playback is remembered and does not restart after leaving and re-entering the viewport.
- The generated manifest records exact duration, byte count, SHA-256, and the one-shot motion policy.
- Source, rendered-response, and browser verification were updated for the new contract.
- Stale root social metadata now uses the maintained 1920×1200 WebP poster.
- README and task tracking identify native production readiness as the active phase.
- A hosted-runner health workflow was added.
- Root `.DS_Store` and `.build/.lock` were removed from tracking.

## QA/QC status on the audited head

| Check | Status | Evidence / next action |
|---|---|---|
| Dependency audit at moderate threshold | Not executed on audited head | Vercel rejected the head at the account build-rate limit; GitHub Security never received a runner |
| Source SEO and media verification | Not executed on audited head | same blockers |
| TypeScript | Not executed on audited head | same blockers |
| Next.js production build | Not executed on audited head | same blockers |
| Rendered-site checks | Not executed | SEO/GEO job has no steps or log |
| Desktop/mobile browser checks | Not executed | SEO/GEO job has no steps or log |
| One-shot completion/replay test | Implemented, not executed | `verify-browser.mjs` |
| Reduce Motion test | Implemented, not executed | `verify-browser.mjs` |
| Hosted runner reaches first shell step | **Failed infrastructure gate** | Workflow Health failed with `steps: None` and no log |
| Website Security | **Failed infrastructure gate** | job failed with `steps: None` and no log |
| SEO/GEO | **Failed infrastructure gate** | job failed with `steps: None` and no log |
| Swift macOS 14 | Not triggered by this website/docs-only diff | must be rerun after hosted-runner recovery |
| Swift macOS 15 | Not triggered by this website/docs-only diff | must be rerun after hosted-runner recovery |
| Vercel preview for exact head | **Rejected before build** | account build-rate limit |
| Recursive tracked `.build/` removal | Incomplete | requires full index cleanup, not only root lock removal |
| Branch deletion inventory | Prepared, not executed | execute after merge |

## What earlier previews prove—and do not prove

Earlier branch commits reached READY in Vercel and demonstrated that intermediate source states could install dependencies and build. They do **not** prove the audited head because later commits changed manifest-integrity assertions, QA records, and the final implementation contract.

No intermediate preview may be substituted for the exact-head gate.

## Release decision

**NO-GO.** Phase 0 is not passed. The PR must remain draft until:

1. the Vercel rate window permits an exact-head preview;
2. GitHub can assign hosted runners and every required workflow executes real steps;
3. the exact head passes dependency, source, type, build, rendered, browser, one-shot, and Reduce Motion checks;
4. every tracked `.build/` entry is removed;
5. this record is updated with one accepted commit and evidence artifact.

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
