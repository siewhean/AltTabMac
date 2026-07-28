# CmdTab

Last updated: 2026-07-28
Active task: completed Round 3 audit implementation plan: gated Developer preferences pane behind `#if DEBUG` (preventing licensing bypass), integrated trial email registration into OnboardingView, enforced `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` on Keychain items, skipped sending trial emails to `anonymous@local`, added cross-device purchasing banner on thank-you page, returned 400 Bad Request on Zod errors in telemetry API, added notarization/stapling script logic, added Swift format/lint CI step, replaced unsafe force casts with safe CFTypeRef handling, added VoiceOver accessibility labels across SwiftUI views, replaced silent `try?` with logged `do/catch` in memory/telemetry stores, and verified 129/129 Swift tests + 38/38 Next.js routes.

## Product

CmdTab is a native macOS window switcher built with Swift, AppKit, and SwiftUI. Eligible top-level windows are separate exact `(PID, CGWindowID)` targets in one global recent-use sequence. Multiple windows from one app remain separate, preview failure changes presentation rather than membership, and permanent history updates only after activation is confirmed.

The repository also contains the Next.js product, documentation, commerce, analytics, evidence, and discovery website under `website/`.

## Protected behavior

Changes to hotkey routing, exact-window MRU, frontmost resolution, activation confirmation, focused-window observation, preview-independent membership, quick actions, and suppression animation require focused regressions plus the complete Swift package suite. The event-tap callback must remain non-blocking.

## Automated app evidence

Permanent macOS 14 and macOS 15 CI reproduces the pre-fix state-space model, runs strict-MRU/completeness regressions, runs the complete Swift package suite, and checks patch hygiene. Model counts are synthetic state-space evidence, not observed field failure rates.

## Showcase media

The canonical website showcase is `/showcase`.

- Radial Menu: authentic production SwiftUI/AppKit poster and MP4.
- Overview and Quick Actions: deterministic product-composite posters and MP4s.
- Classic Grid and Command Palette: deterministic product-composite posters.
- All media uses controlled fixture windows, is not AI-generated, and is not a private desktop capture.
- Poster-only entries render an image fallback; no missing MP4 may produce a black panel.
- VideoObject data is emitted only for actual MP4 assets.

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

The permanent SEO workflow also starts the compiled server and runs rendered, webmaster, evidence, retrieval, showcase-response, and desktop/mobile browser checks.

A Vercel deployment is accepted only when its metadata identifies the reviewed `main` commit and the public domain serves `/showcase`, every referenced media file, the 22-route sitemap, and no unsupported claims.

## Remaining signed-app acceptance boundary

Interactive macOS testing is still required for permission grant/denial/revocation, exact focused-window proof, mouse and keyboard commits, minimized/fullscreen windows, Spaces, displays, Stage Manager, rapid input, Secure Input, sleep/wake, signing, notarization, and clean-account installation.
