# CmdTab

Last updated: 2026-07-23  
Active task: begin Phase 2 Developer ID distribution work after the accepted and merged Phase 1 deterministic packaging gate.

## Product

CmdTab is a native macOS window switcher built with Swift, AppKit, and SwiftUI. Eligible top-level windows are separate exact `(PID, CGWindowID)` targets in one global recent-use sequence. Multiple windows from one app remain separate, preview failure changes presentation rather than membership, and permanent history updates only after activation is confirmed.

The repository also contains the Next.js product, documentation, commerce, analytics, evidence, and discovery website under `website/`.

## Production-readiness plan

The canonical phased plan is [`docs/release/native-production-readiness-plan.md`](docs/release/native-production-readiness-plan.md). The active execution sequence and current phase status are recorded in [`docs/release/current-implementation-status.md`](docs/release/current-implementation-status.md).

Phase 1 is complete. PR #31 merged the deterministic local application bundle, permanent bundle identifier, rollback-safe beta migration, local ad-hoc QA package, strict bundle verification, checksums, and byte-for-byte unsigned reproducibility.

The public native release remains blocked until CmdTab has:

- Developer ID signing with Hardened Runtime and a secure timestamp;
- accepted notarization and a stapled ticket;
- Gatekeeper and clean-account installation evidence;
- real macOS proof of exact focused-window activation across the supported desktop matrix;
- private API capability boundaries with explicit degraded behavior;
- tested update, rollback, diagnostics, security, licensing, and support operations.

No public release claim may treat the accepted local ad-hoc artifact as a distributable build.

## Phase 1 accepted evidence

Accepted source commit:

```text
516a9476c01f4d59981f35dc44b6eb09dcd6d790
```

Merged through PR #31 with merge commit:

```text
f37e47029344e191682bd02ade8d7daf4ea241bd
```

The accepted local macOS gate recorded:

- repository identity verification passed;
- bundle migration tests: 6/6 passed;
- capture fallback regression tests: 3/3 passed;
- complete Swift package suite: 132/132 passed;
- release compilation and app assembly passed;
- bundle layout, metadata, architecture, signature, and checksum verification passed;
- two clean unsigned bundles from the canonical build path were byte-for-byte reproducible;
- packaged menu-bar launch, Dock/native-switcher exclusion, permissions, Command-Tab interception, deliberate quit/reopen, Arc preview capture, and Arc activation were manually confirmed.

The complete record is [`docs/release/evidence/phase-1/README.md`](docs/release/evidence/phase-1/README.md).

## Protected behavior

Changes to hotkey routing, exact-window MRU, frontmost resolution, activation confirmation, focused-window observation, preview-independent membership, quick actions, and suppression animation require focused regressions plus the complete Swift package suite. The event-tap callback must remain non-blocking.

## Automated app evidence

Phase 1 local evidence proves the current deterministic host-architecture package on the tested Mac. GitHub-hosted macOS 14 and macOS 15 execution remains deferred under issue #30 and must pass before Phase 2 can be accepted.

Automated SwiftPM evidence does not replace packaged-app testing for permissions, focused `CGWindowID`, Spaces, displays, fullscreen, Stage Manager, Secure Input, signing, notarization, installation, updates, or rollback.

## Showcase media

The canonical website showcase is `/showcase`.

- Overview, Radial Menu, and Quick Actions use deterministic HD product-composite posters and MP4s.
- Classic Grid and Command Palette use deterministic HD product-composite posters.
- All media uses controlled fixture windows, is not AI-generated, and is not a private desktop capture.
- Poster-only entries render an image fallback; no missing MP4 may produce a black panel.
- VideoObject data is emitted only for actual MP4 assets.
- Autoplay clips run once for no more than five seconds, do not loop, and remain static when Reduce Motion is enabled.

The showcase demonstrates presentation. It does not prove signed-app permissions, exact focused `CGWindowID`, Spaces, displays, fullscreen, Stage Manager, signing, notarization, performance, memory use, processor support, or architecture coverage.

## Website and discovery

The website uses one canonical route registry for metadata, sitemap, IndexNow, and verification. The 22 public routes cover product behavior, four feature modes/actions, evidence, guides, comparisons, compatibility, permissions, privacy, commerce, support, and the showcase.

Public claims must be visible in canonical HTML and supported by source, code, tests, or clearly labelled media. Do not publish ScreenCaptureKit, latency, RAM, Universal Binary, Apple Silicon, Intel, processor, fake rating, testimonial, or directory-status claims without evidence.

`/llms.txt` is a descriptive directory. `/llms-full.txt` is a non-standard noindex convenience export; canonical HTML remains authoritative.

## Verification

From `website/`:

```bash
npm ci
npm run prebuild
npm run build
```

The permanent SEO workflow also starts the compiled server and runs rendered, webmaster, evidence, retrieval, showcase-response, and desktop/mobile browser checks when hosted Actions capacity is available.

A Vercel deployment is accepted only when its metadata identifies the reviewed `main` commit and the public domain serves `/showcase`, every referenced media file, the 22-route sitemap, and no unsupported claims.

## Remaining signed-app acceptance boundary

Interactive macOS testing is still required for permission denial and revocation, exact focused-window proof, mouse and keyboard commits, minimized/fullscreen windows, Spaces, displays, Stage Manager, rapid input, Secure Input, sleep/wake, stable signing identity, notarization, updates, rollback, and clean-account installation.