# Phase 0 QA/QC Record

**Phase:** Governance, repository hygiene, and trustworthy gates  
**Branch:** `agent/native-release-readiness`  
**Status:** IN PROGRESS  
**Started:** 2026-07-22

## Scope completed in source

- The phased production-readiness plan was committed before implementation.
- Looping autoplay was replaced by one-shot playback.
- Every autoplay clip is capped at five seconds; the Overview is normalized to 4.8 seconds.
- Reduce Motion pauses the media and returns it to the poster state.
- Completed playback is remembered and does not restart after leaving and re-entering the viewport.
- The generated manifest now records exact duration, byte count, SHA-256, and the one-shot motion policy.
- Source, rendered-response, and browser verification were updated for the new contract.
- Stale root social metadata now uses the maintained 1920×1200 WebP poster.
- README and task tracking now identify native production readiness as the active phase.
- A hosted-runner health workflow was added.
- Root `.DS_Store` and `.build/.lock` were removed from tracking.

## QA/QC status

| Check | Status | Evidence / next action |
|---|---|---|
| Dependency audit at moderate threshold | Pending exact final head | Vercel preview build |
| Source SEO and media verification | Pending exact final head | Vercel preview build |
| TypeScript | Pending exact final head | Vercel preview build |
| Next.js production build | Pending exact final head | Vercel preview build |
| Rendered-site checks | Pending | GitHub SEO/GEO workflow |
| Desktop/mobile browser checks | Pending | GitHub SEO/GEO workflow |
| One-shot completion/replay test | Implemented, pending execution | `verify-browser.mjs` |
| Reduce Motion test | Implemented, pending execution | `verify-browser.mjs` |
| Hosted runner reaches first shell step | Pending | Workflow Health job |
| Swift macOS 14 | Pending runner recovery | permanent Swift workflow |
| Swift macOS 15 | Pending runner recovery | permanent Swift workflow |
| Recursive tracked `.build/` removal | Incomplete | requires full index cleanup, not only root lock removal |
| Branch deletion inventory | Prepared, not executed | execute after merge |

## Release decision

**NO-GO.** Phase 0 is not passed until the final branch head has a READY Vercel preview, all required GitHub workflows execute real steps, every tracked `.build/` file is removed, and the completed evidence record identifies one exact accepted commit.

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
