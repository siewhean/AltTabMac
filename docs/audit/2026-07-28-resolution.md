# CmdTab 2026-07-28 Audit Resolution

This document reconciles the third audit against the repository state actually
present on `agent/five-feature-production-suite`. The audit compared an older
Swift snapshot with a newer website snapshot, so several Critical and High
findings were already obsolete before remediation began.

Status meanings:

- **Resolved before audit** — current source already contained the required
  behaviour; the audit inspected stale or incomplete source.
- **Remediated** — this branch adds or tightens the behaviour.
- **Reclassified** — the finding is real technical debt but not a release or
  user-blocking defect at the reported severity.
- **External gate** — evidence requires real hardware, credentials, production
  services, or authentic screen recording and must remain `NOT TESTED` until
  performed.

## Critical findings

| ID | Resolution | Evidence and decision |
|---|---|---|
| C1 | Resolved before audit | Versioned, resumable onboarding already existed, including contextual Accessibility and Screen Recording steps, first-switch practice, and automatic first-run presentation. |
| C2 | Resolved before audit | The production hotkey path checks licensing before consuming the shortcut. Expired or unregistered users retain native macOS Command-Tab; CmdTab does not open its switcher. |
| C3 | Resolved before audit | Sparkle 2.9.2 is pinned through SwiftPM, packaged as an embedded framework, validated before updater startup, checked daily, and exposed through “Check for Updates…”. |
| C4 | Resolved before audit | Native telemetry and website analytics are default-off, consent-gated, withdrawable, bounded, and exclude window titles and captured content. |

## High findings

| ID | Resolution | Evidence and decision |
|---|---|---|
| H1 | Remediated | Existing in-app final-three-day banners and menu-bar status are supplemented by scheduled three-day, one-day, and fresh-expiry macOS notifications with deterministic tests. |
| H2 | Remediated | Each switcher mode now has a bounded first-use hint: Quick Actions for Classic Grid, type-to-search for Command Palette, and directional navigation for Radial Menu. |
| H3 | Remediated | `cmdtab://activate?code=…` is registered, validated with strict credential shapes and length bounds, handled by the native app, and included in purchase email with manual paste fallback. |
| H4 | Reclassified | A locally self-issued offline trial was deliberately rejected because it would weaken the signed, install-bound anti-abuse contract and become resettable. Trial registration remains a one-time fail-closed network operation; native Command-Tab is never intercepted before registration. This is a product trade-off, not a release blocker. |
| H5 | Remediated | Trial email is optional in the app and API. Anonymous trials use an install-bound pseudonymous subject; no reminder email is sent unless the user supplies one. |
| H6 | Resolved before audit | Permission prompts are sequential and preceded by plain-language explanations of why each permission is needed. |
| H7 | Reclassified | Large files are maintainability debt, not a production-severity defect. The active implementation already separates onboarding, licensing, profiles, updater, views, hotkey state, telemetry, and exact-window policy. A broad file move during release finalisation would increase regression risk and invalidate evidence without improving runtime behaviour. |
| H8 | External gate | Authentic Classic Grid and Command Palette recordings require the packaged app on a real Mac. `docs/qa/real-showcase-recording.md` defines the exact-build and evidence contract; simulated or AI footage is explicitly prohibited. |
| H9 | Remediated | A noindex `/thank-you` route now explains secure email delivery, one-click activation, manual fallback, download, and recovery without exposing the activation credential in a web URL. |

## Medium findings

| ID | Resolution | Evidence and decision |
|---|---|---|
| M1 | Reclassified | Directory shape alone is not a correctness or release defect. Moving files is deferred until after accepted runtime evidence. |
| M2 | Resolved before audit | Current AX extraction uses guarded `AXValueGetType` and `AXValueGetValue` checks rather than forced AX casts. |
| M3 | Remediated / bounded | Search-memory decode and persistence failures now produce privacy-safe diagnostics. Remaining `try?` uses in licensing are limited to best-effort cleanup, cache invalidation, or offline-preserving paths where failure must not crash or revoke paid access. |
| M4 | Reclassified | The three presentations intentionally share a model but differ in navigation and rendering. Shared primitives already live outside the mode views; forced consolidation would obscure mode-specific behaviour. |
| M5 | Reclassified | Release-critical state is already encapsulated behind private stores, immutable snapshots, and narrow controllers. A blanket access-control churn is deferred because it creates source noise without changing runtime security. |
| M6 | Remediated | The notarized release flow now generates a deterministic branded background, builds a writable Finder layout, positions CmdTab and Applications, converts to compressed UDZO, then signs, notarizes, staples, and Gatekeeper-checks the DMG. |
| M7 | Remediated | The AltTab comparison now answers “why pay?” directly and also states when AltTab or Apple’s built-in switcher is the rational choice. |
| M8 | Resolved before audit | The homepage already includes a deterministic overview video/animation and reduced-motion fallback. |
| M9 | Resolved before audit | Production dashboard access uses Auth0-compatible owner-subject sessions, generation invalidation, CSRF checks, idle/absolute limits, and an MFA-required production configuration. |
| M10 | Remediated | Per-request CSP nonces replace `unsafe-inline` for scripts and style elements. Development-only `unsafe-eval` is isolated. Inline style attributes remain narrowly allowed because React uses them for dynamic visual geometry; script execution is not covered by that exception. |
| M11 | Resolved before audit | Website environment files are ignored. |
| M12 | Corrected | `website/src/proxy.ts` is active security middleware and must not be deleted. Archived code is not part of the production build. |
| M13 | Reclassified | Static server-rendered sections do not need loading skeletons. Skeletons would add visual instability without masking meaningful I/O. |
| M14 | Resolved before audit | Browser gates cover desktop, mobile, zoom, keyboard, reflow, and reduced-motion layouts. Real-device checks remain an external acceptance gate. |
| M15 | Remediated | Switcher view-model and history tests now cover empty/clamped state, wraparound, uneven grids, fallback replacement, sibling preservation, matching, ranking, and the 256-entry bound. |
| M16 | Remediated / external boundary | Deterministic state tests are supplemented by an exact-bundle packaged launch smoke script. Accessibility event-tap and real-window interaction still require manual macOS acceptance. |
| M17 | Resolved before audit | Workflow actions are pinned to immutable commit SHAs; the verifier also rejects mutable container references. |
| M18 | Corrected | Feedback and style-change HUD components are referenced by production source; they are not dead code. |
| M19 | Remediated | Public-form and ingest limits now use PostgreSQL-backed fixed windows and persistent duplicate protection across serverless instances. Production fails closed when shared abuse controls are unavailable; local memory is development-only. Migration-owned tables and expiry indexes are included. |
| M20 | Remediated | Arbitrary-length admin secrets are compared through equal-length SHA-256 digests before `timingSafeEqual`, with unequal-length regression coverage. |
| M21 | Remediated | The stale waitlist-first FAQ was replaced with release-preparation, trial, and signed-download language. |
| M22 | Resolved before audit | Walkthrough copy names alternative modes rather than implying a mandatory linear product journey. |

## Additional blockers found during remediation

1. The earlier ad-hoc universal app enabled Hardened Runtime, causing macOS
   Library Validation to reject the embedded Sparkle framework before launch.
   Ad-hoc QA packages now omit Hardened Runtime; Developer ID packages retain it.
2. The first signing correction expanded an empty Bash array under the macOS
   system Bash with `set -u`. Conditional argument construction replaced the
   incompatible expansion and is covered by release-tooling tests.
3. Package verification previously proved signature structure but not that the
   exact bundle stayed alive. `smoke-launch-app.sh` now verifies the exact loaded
   executable after launch.
4. The prior rate limiter was process-local. Shared database windows and
   deduplication now survive cold starts and fail closed in production.

## Remaining acceptance boundary

No source document may claim public-release readiness until the current exact
head passes all of the following:

- Swift build and complete test suite;
- website unit, privacy, API, SEO, dependency, typecheck, and production build;
- release and performance tool tests;
- universal ad-hoc package verification and exact-bundle launch smoke;
- manual Hot Swap, native shortcut pass-through, exact-window, thumbnail,
  onboarding, licensing, telemetry, and updater rows;
- a new exact-head security diff scan and final report;
- Developer ID signing, notarization, stapling, Gatekeeper, clean Apple Silicon
  and Intel installation, signed update, rollback, production infrastructure,
  backup/restore, and sandbox commerce evidence;
- authentic real-app showcase recordings for the modes still represented by
  posters.

Unsupported hardware, credentials, services, and real recordings remain
`NOT TESTED`. They are not inferred from source inspection or unit tests.
