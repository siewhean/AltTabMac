# Phase 0 Failures and Blockers

## Open blockers

### 1. GitHub Actions cannot assign hosted runners

On PR #26, Workflow Health, Website Security, and SEO/GEO all failed before their first step. Each job reports `steps: None` and no job log.

This rules out a source assertion as the immediate cause. The repository cannot treat these statuses as proof that the source failed or passed.

**Required disposition:** confirm account quota/billing, Actions policy, hosted-runner availability, repository permissions, and any spending limit. The Workflow Health job must print runner metadata and complete checkout before the gate is trusted.

### 2. Vercel rejected the exact PR head before build

The exact PR head received a Vercel failure status that links to the account build-rate limit. An earlier intermediate preview is READY, but it predates the final manifest checksum enforcement and Phase 0 evidence updates.

**Required disposition:** wait for the build-rate window to clear or adjust the account limit, then require a READY preview whose deployment metadata names the exact accepted head.

### 3. Recursive generated-output cleanup is incomplete

The root `.build/.lock` and `.DS_Store` were removed, but the repository historically tracked a large `.build/` tree. The connector has not yet provided a recursive index-deletion operation for the directory.

**Required disposition:** run `git rm -r --cached .build` from an authenticated checkout or create an equivalent Git tree deletion commit, then verify `git ls-files .build` returns no entries.

### 4. Owner credentials are not available for signing and notarization

No Developer ID Application identity, App Store Connect API credential, or notarization keychain profile has been supplied to the implementation environment.

**Required disposition:** this is expected until Phase 2. Credentials must be provisioned through protected secrets, never committed.

## Resolved failures during implementation

### Stale manifest after video normalization

The first one-shot normalizer changed the Overview MP4 but did not update the manifest byte count and SHA-256.

**Resolution:** the normalizer now recalculates and writes exact byte count and SHA-256 values, and the verifier compares every poster/video file against the manifest.

### Source metadata drift

Root social metadata still referenced a PNG and 1280×800 dimensions while the maintained poster was a 1920×1200 WebP.

**Resolution:** root metadata and `siteConfig.socialImagePath` now use the current WebP and dimensions.

### Infinite autoplay without visible controls

The production component looped autoplay video indefinitely without a pause, stop, or hide mechanism.

**Resolution:** maintained clips are one-shot, no longer loop, are capped at five seconds, freeze after completion, and remain static for Reduce Motion.
