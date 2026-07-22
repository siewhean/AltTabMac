# Phase 0 Failures, Waivers, and Deferred Work

## Approved temporary waiver

### GitHub Actions hosted-runner execution

GitHub Actions usage for the private repository is exhausted. Release Readiness run `29932202852` created all required Ubuntu and macOS jobs, but GitHub rejected every job before step one with `steps: None` and no logs.

The user explicitly approved continuing without GitHub Actions until the usage allowance resets.

This waiver does **not** claim that the following checks passed on the Phase 0 head:

- hosted Ubuntu runner health;
- rendered/browser QA through GitHub Actions;
- Swift on `macos-14`;
- Swift on `macos-15`.

The waiver is accepted for Phase 0 because this phase did not change `Sources/CmdTab/**`, `Tests/CmdTabTests/**`, or `Package.swift`; it changed website behavior, release documentation, workflow definitions, and removal of generated `.build` output. Vercel independently executed the website dependency, source, type, and production-build gates.

**Residual risk:** native Swift tests must be rerun on macOS 14 and 15 before Phase 2 can pass and before any signed public release candidate is distributed.

**Deferred issue:** #30 remains the tracking item for restoring hosted-runner execution when quota becomes available.

## Expected Phase 2 dependency

### Signing and notarization credentials

No Developer ID Application identity, App Store Connect API credential, or notarization keychain profile has been supplied to the implementation environment.

This is expected until Phase 2. Credentials must be provisioned through protected secrets and must never be committed.

## Resolved blockers

### Vercel build-rate limit

The account build-rate window cleared. Vercel accepted the Phase 0 branch and completed fresh READY preview deployments. The website gate reported zero moderate-or-higher dependency vulnerabilities, passed source SEO/media verification, passed TypeScript, and completed the Next.js production build.

### Recursive generated-output cleanup

The entire tracked `.build/` tree was removed through one Git tree deletion commit. The PR comparison contains removals for historical `.build/` paths and no added `.build/` entry.

### Stale manifest after video normalization

The initial one-shot normalizer changed the Overview MP4 without updating manifest bytes and SHA-256.

**Resolution:** the normalizer recalculates exact byte count and SHA-256 values, and the verifier compares every poster and video file with the manifest.

### Source metadata drift

Root social metadata referenced a PNG and 1280 × 800 dimensions while the maintained poster was a 1920 × 1200 WebP.

**Resolution:** root metadata and `siteConfig.socialImagePath` use the maintained WebP and dimensions.

### Infinite autoplay without controls

The production component looped autoplay video indefinitely without a pause, stop, or hide mechanism.

**Resolution:** maintained clips are one-shot, do not loop, remain at or below five seconds, freeze after completion, and remain static for Reduce Motion.