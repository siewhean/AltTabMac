# Phase 0 Failures and Blockers

## Open blockers

### 1. GitHub Actions hosted-runner execution

Earlier PR #26 attempts assigned failed conclusions before any first step. Workflow Health, Website Security, and SEO/GEO reported `steps: None` and no logs.

The current exact head must be tested by reopening PR #26 after the Git tree cleanup, because GitHub API-authored commits do not reliably emit a pull-request synchronize workflow run.

**Required disposition:** the reopened PR must assign Ubuntu and macOS hosted runners, print runner metadata, complete checkout, and execute every required test step.

### 2. Owner credentials are not available for signing and notarization

No Developer ID Application identity, App Store Connect API credential, or notarization keychain profile has been supplied to the implementation environment.

**Required disposition:** this is expected until Phase 2. Credentials must be provisioned through protected secrets, never committed.

## Resolved blockers

### Vercel build-rate limit

The account build-rate window cleared. Vercel accepted the exact Phase 0 candidate head and began a fresh preview build.

### Recursive generated-output cleanup

The entire tracked `.build/` tree was removed through one Git tree deletion commit. The PR comparison now contains only removals for historical `.build/` paths and no added `.build/` entry.

### Stale manifest after video normalization

The first one-shot normalizer changed the Overview MP4 but did not update the manifest byte count and SHA-256.

**Resolution:** the normalizer recalculates and writes exact byte count and SHA-256 values, and the verifier compares every poster/video file against the manifest.

### Source metadata drift

Root social metadata referenced a PNG and 1280×800 dimensions while the maintained poster was a 1920×1200 WebP.

**Resolution:** root metadata and `siteConfig.socialImagePath` use the current WebP and dimensions.

### Infinite autoplay without visible controls

The production component looped autoplay video indefinitely without a pause, stop, or hide mechanism.

**Resolution:** maintained clips are one-shot, no longer loop, are capped at five seconds, freeze after completion, and remain static for Reduce Motion.
