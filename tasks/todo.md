# Todo

## 2026-07-23 — PR #35 Five-Feature Production QA

- [x] Audit the phased runner, focused-test inventory, deterministic fixtures, and objective probe contract.
- [x] Require an exact 61-test focused XCTest aggregate with zero failures and zero unexpected results.
- [x] Bind phase evidence to one clean immutable HEAD and hash-seal phase logs and artifacts.
- [x] Reject tracked changes everywhere, including tracked files under generated-output directories.
- [x] Invalidate downstream evidence when an earlier phase is rerun.
- [x] Make the duplicate-title fixture genuinely ambiguous by removing document identity and keeping candidates within the production matcher margin.
- [x] Prevent AppKit restoration and content fitting from leaking prior minimized state or collapsed geometry into later fixture scenarios.
- [x] Add objective minimized/fullscreen/subrole evidence to WindowProbe without representing unknown state as false.
- [x] Commit and push the hardened branch without merging PR #35.
- [x] Patch the independent audit blockers: profile quick-switch semantics, enrichment recursion, fail-closed provisional scope, durable-write collisions, and truthful Stage Manager inference.
- [x] Add targeted regressions and raise the required focused XCTest count from 50 to 61.
- [ ] Rerun source, tests, package, reproducibility, and finalization from the new exact clean audit-fix HEAD.
- [ ] Execute only physically observable packaged-app rows and label all unsupported rows `NOT TESTED`.
- [ ] Complete independent final QA/QC and record PASS/FAIL/NOT TESTED evidence for the audit-fix artifact.

### Review

- The initial feature implementation passed preliminary source verification, 50 focused tests, and 182 full Swift tests, but its evidence runner and fixtures had fail-closed gaps.
- Independent review of `97fc00eda0a5a8cac40d3910f59c5c7fc82e2456` found four production-path defects and one Stage Manager truthfulness issue. Source fixes and regressions were added afterward, invalidating all earlier phase markers.
- The next accepted result must come from one exact clean post-audit head. No earlier automated marker, manual checkbox, or WindowProbe output is transferable.

## 2026-07-23 — Native Production Readiness

Canonical plan: `docs/release/native-production-readiness-plan.md`

### Phase 0 — Governance, hygiene, and trustworthy gates

- [x] Commit the phased implementation and QA/QC plan before implementation.
- [x] Create a dedicated `agent/native-release-readiness` branch from current `main`.
- [x] Replace looping showcase autoplay with one-shot playback of no more than five seconds.
- [x] Add Reduce Motion behavior and browser-level replay checks.
- [x] Keep generated media byte counts and SHA-256 values exact after normalization.
- [x] Correct stale PNG/1280×800 social metadata and stale media provenance in README.
- [x] Add a hosted-runner workflow-health diagnostic.
- [x] Remove the tracked root `.DS_Store` and complete `.build/` tree from the repository index.
- [x] Record the Phase 0 evidence and branch-deletion inventory.
- [x] Pass the accepted Vercel source, dependency, TypeScript, and production-build gate.
- [ ] Confirm all GitHub Actions jobs reach checkout and at least one shell step when quota returns (issue #30).
- [ ] Pass Swift macOS 14 and macOS 15 workflows on one exact head when quota returns (issue #30).
- [ ] Pass Website Security, SEO/GEO, rendered, and browser workflows on one exact head when quota returns (issue #30).
- [ ] Complete the live production deployment reconciliation tracked by PR #32 after Vercel build allowance is available.

### Phase 1 — Deterministic local app bundle — ACCEPTED

Accepted source commit: `516a9476c01f4d59981f35dc44b6eb09dcd6d790`  
Merged through PR #31: `f37e47029344e191682bd02ade8d7daf4ea241bd`

- [x] Select and document the permanent bundle identifier `net.cmdtab.CmdTab`.
- [x] Add one-command release build and deterministic `.app` assembly scripts.
- [x] Add the empty reviewed entitlement baseline with source-backed boundaries.
- [x] Add bundle-layout, metadata, architecture, quarantine, checksum, and ad-hoc signature verification.
- [x] Build twice from the canonical clean scratch path and prove byte-for-byte unsigned reproducibility.
- [x] Add rollback-safe migration from the legacy `com.user.CmdTab` defaults and Keychain identity.
- [x] Pass bundle migration tests: 6/6.
- [x] Add and pass Arc capture fallback regression tests: 3/3.
- [x] Pass the complete Swift package suite: 132/132.
- [x] Pass `scripts/release/run-phase1-qa.sh` with matching tested and evidence commits.
- [x] Confirm menu-bar launch, Dock/native-switcher exclusion, Command-Tab interception, settings, deliberate quit/reopen, and permission re-grant behavior.
- [x] Confirm Arc renders a real thumbnail and activates the selected Arc window.
- [ ] Preserve the limitation that a real legacy beta profile migration was not separately observed during final manual QA; automated migration coverage passed.

### Phase 2 — Developer ID distribution — ACTIVE NEXT PHASE

Owner prerequisites:

- [ ] Confirm Apple Developer Program membership and the intended Apple Developer Team ID.
- [ ] Confirm `net.cmdtab.CmdTab` is registered to the intended Apple Developer team.
- [ ] Confirm a valid `Developer ID Application` certificate is available in the signing environment.
- [ ] Configure App Store Connect API credentials or a protected `notarytool` keychain profile.
- [ ] Decide and document the first RC architecture policy; default recommendation is arm64-only until Universal Binary is independently built and verified.

Implementation:

- [ ] Add secure Developer ID signing with Hardened Runtime and secure timestamp.
- [ ] Add deterministic unsigned-input manifesting before signing.
- [ ] Add ZIP creation for notarization and direct distribution.
- [ ] Add `notarytool` submission with persisted submission ID and notarization log.
- [ ] Staple and validate the ticket.
- [ ] Pass strict codesign and Gatekeeper assessment.
- [ ] Verify stable Accessibility, Screen Recording, and Launch at Login identity across consecutive signed builds.
- [ ] Pass clean-account download, installation, launch, quit, and relaunch.
- [ ] Restore and pass the deferred GitHub Actions gates before Phase 2 acceptance (issue #30).
- [ ] Record `docs/release/evidence/phase-2/` and make an explicit GO/NO-GO decision.

### Phase 3 — Private API capability boundaries and real macOS acceptance

- [ ] Capture a signed-baseline smoke record before provider refactoring.
- [ ] Isolate private APIs behind explicit identity, capture, focus, and workspace capability providers.
- [ ] Build deterministic multi-window fixture applications.
- [ ] Record requested, selected, committed, and actual focused identities.
- [ ] Execute permissions, input, Space, display, fullscreen, Stage Manager, Secure Input, sleep/wake, and rapid-input rows.
- [ ] Require actual focused `CGWindowID` evidence for every P0 row.

### Release safety before optional features

- [ ] Add signed updates, stable/beta channels, rollback, tamper rejection, and interrupted-update recovery.
- [ ] Add privacy-safe crash diagnostics and user-exportable support bundles.
- [ ] Verify production trial, license activation, cached-license, and failure recovery paths.
- [ ] Complete owner-operated security, mail, WAF, sender-domain, and incident-response controls.
- [ ] Create `release/native-rc1` only after signing, provider isolation, the full desktop matrix, and release-safety infrastructure pass.

### Optional feature expansion after the first safe RC

- [ ] Implement minimized-window restoration.
- [ ] Implement true workspace/Space/Stage Manager identity where not already required for the supported contract.
- [ ] Implement configurable scoped shortcut profiles.
- [ ] Implement durable MRU restoration across app restarts.
- [ ] Implement expanded exact-window actions.

## 2026-07-20 — Independent SEO And GEO Competitive Hardening

- [x] Review PR #11 as a separate specialist branch rather than silently modifying the first pass.
- [x] Compare CmdTab with AltTab, Scopo, BetterCmdTab, Contexts, Apple documentation, and current Google, Bing, and OpenAI guidance.
- [x] Add authoritative pages for the core window-switcher category, Mac window-switching guide, native comparison, and canonical FAQ.
- [x] Make product version, requirements, breadcrumbs, review dates, source links, telemetry, exclusions, and limitations visible in canonical HTML.
- [x] Expand Organization, Person, WebSite, SoftwareApplication, WebPage, FAQPage, TechArticle, Offer, and Breadcrumb structured data.
- [x] Publish the actual native-app telemetry contract and the local window-content fields excluded from the current payload.
- [x] Add broad AI/search discovery classification without collecting prompts or search queries.
- [x] Add a private discovery dashboard, canonical route registry, IndexNow support, and canonical-only `llms.txt`.
- [x] Tie public app version, build number, and minimum macOS to `Resources/Info.plist` through build-breaking assertions.
- [x] Raise Next.js, React, and React DOM to patched security releases and regenerate the lockfile.
- [x] Pass SEO/GEO invariants, TypeScript, production Webpack build, high-severity dependency audit, and `git diff --check`.
- [x] Document the competitor critique, operating contract, honest authority boundary, and post-merge distribution plan.

## Specialist Review

- The implementation can outperform the reviewed competitors in technical clarity, visible evidence, privacy specificity, source verifiability, and discovery measurement.
- It cannot manufacture AltTab's accumulated backlinks, downloads, press coverage, community discussion, branded demand, or localization. Those remain product-distribution work after live validation.
- The custom dependency assertion initially failed because it required an exact patch. It was corrected to enforce a minimum secure semantic version, after which the full validation gate passed.

## 2026-03-27 — Website Motion Pass

- [x] Add a lightweight motion primitive for section reveals without introducing a new animation library.
- [x] Add restrained hero movement and ambient linear drift to the key visuals.
- [x] Apply reveal/stagger motion across the main website sections with reduced-motion safety.
- [x] Verify the website still typechecks and builds, then update `README.md` and review notes here.

## Website Motion Review

- Added a small `MotionReveal` primitive so sections can fade and translate into place on first scroll entry without pulling in a separate animation dependency.
- Added CSS-first motion in `globals.css` for hero entrances, grid drift, and subtle linear screenshot movement, with `prefers-reduced-motion` handling baked into the same layer.
- Applied staged reveal motion across the proof strip, mode cards, walkthrough, feature bands, permissions, FAQ, waitlist, and footer so the page now has visible structure instead of appearing all at once.
- Added restrained movement to the hero screenshots and CTA surfaces so the first screen feels alive without turning into a noisy marketing animation.
- `npm run typecheck` passed in `website/`.
- `npx next build --webpack` passed in `website/`.

## 2026-03-27 — Feature Visibility Pass (Website + Settings)

- [x] Expose every shipped product-differentiation feature clearly in the macOS Settings window.
- [x] Update the marketing site copy and structure so the same feature set is visible on the website.
- [x] Verify the Swift package and website builds still pass after the visibility pass.
- [x] Update `README.md` and record the review notes here.

## Feature Visibility Review

- Renamed the top Settings card from an overloaded quick-actions label to `Session Tools`, and added explicit surfaces for preview warmup, command-palette memory, quick actions, selection clarity, space/display awareness, and decluttering.
- Added a dedicated workflow layer in Settings so quick actions are visible as first-class capabilities instead of being discoverable only through keyboard shortcuts.
- Expanded the website copy to explicitly cover preview reliability, learned search, space/display targeting, quick actions, decluttering rules, alternate triggers, and radial selection clarity.
- Added new website screenshot asset aliases and richer feature-band content so the landing page now presents the shipped differentiators as product features instead of leaving them implicit.
- `swift test --scratch-path /tmp/CmdTab-test` passed with 67 tests.
- `npm run typecheck` passed in `website/`.
- `npx next build --webpack` passed in `website/`.

## 2026-03-27 — CmdTab Trigger Flexibility And Preview Readiness

- [x] Add a persisted alternate-trigger preference for modifier tap / double-tap flows.
- [x] Extend the hotkey pipeline with a safe state machine for right-side modifier triggers without regressing `⌘Tab`.
- [x] Expose the alternate trigger and preview warmup controls in Settings (and quick controls where appropriate).
- [x] Add unit coverage for the new trigger-state behavior.
- [x] Re-run Swift verification and update `README.md` plus review notes.

## Trigger Flexibility Review

- Added `AlternateTriggerMode` so CmdTab can optionally launch from right-command or right-option tap / double-tap flows while keeping `⌘Tab` and `⌥Tab` unchanged as the primary triggers.
- Added `AlternateModifierTriggerState` in `HotkeyManager.swift` so standalone modifier taps are only recognized when no other key interrupted the press, which avoids corrupting the existing `⌘Tab` pipeline.
- Exposed the new trigger setting in both the main Settings window and the menu-bar quick controls.
- Added a visible `Preload Previews` control in Settings so the preview-speed work is surfaced as a user-facing feature instead of remaining entirely background behavior.
- Added `AlternateModifierTriggerStateTests.swift` to cover single-tap activation, double-tap activation, long-hold rejection, interruption cancellation, and expired double-tap windows.
- `swift test --scratch-path /tmp/CmdTab-test` passed with 67 tests.

## 2026-03-27 — CmdTab Product Differentiation Pass

- [x] Add deterministic command-palette search scoring and persistent query memory.
- [x] Add window visibility and display-placement preferences for space/display targeting.
- [x] Add switcher quick actions plus exclusion/decluttering rules.
- [x] Improve permission diagnostics and radial-mode selection clarity.
- [x] Update website copy for the founder-price / direct-sale launch path.
- [x] Verify the Swift package and website builds, then update `README.md` and record review notes here.

## Product Differentiation Review

- Added `PaletteSearch`, `SearchMemoryStore`, and new unit coverage so command-palette filtering now ranks acronym matches, remembers prior selections, and keeps deterministic result ordering.
- Replaced the old background-window toggle with `WindowVisibilityScope` plus `SwitcherDisplayPreference`, and mirrored the switcher to every display when `All Displays` is selected.
- Added quick actions (`⌘H`, `⌘M`, `⌘W`, `⌘Q`), exclusion text rules, and a stronger permissions status surface in Settings.
- Tightened the radial UI so the selected item is called out in the center with a stronger ring/indicator treatment.
- Updated the marketing copy to mention the planned 14-day trial, founder pricing, and one-time-license positioning without adding checkout.
- `swift test --scratch-path /tmp/CmdTab-test` passed with 62 tests.
- `npm run typecheck` passed in `website/`.
- `npx next build --webpack` passed in `website/`.

## 2026-03-27 — CmdTab Marketing Website

- [x] Scaffold a standalone `website/` Next.js App Router project inside the repo.
- [x] Build the homepage, privacy page, metadata routes, and screenshot-led marketing sections.
- [x] Add typed content/config modules plus shared UI primitives for the site.
- [x] Implement the hardened `/api/waitlist` endpoint with validation, rate limiting, and Resend integration.
- [x] Create the first batch of website visuals and wire them into the landing page.
- [x] Install dependencies and verify the site builds cleanly.
- [x] Update `README.md` with the new website task context and record review notes here.

## Website Review

- `npm install` completed successfully in `website/`.
- `npm run typecheck` passed.
- `npx next build --webpack` passed and generated the homepage, privacy page, metadata routes, and dynamic waitlist endpoint.
- Plain `next build` hit a Turbopack sandbox panic while processing PostCSS (`binding to a port`); the Webpack-backed production build succeeded, so the issue appears environment-specific rather than app-code-specific.
- Runtime waitlist delivery still needs real values for `RESEND_API_KEY`, `WAITLIST_FROM_EMAIL`, and `WAITLIST_TO_EMAIL` before the API can send notifications.

## 2026-03-27 — Reliable 100ms `⌘Tab` Hold-to-Show

- [x] Refactor `HotkeyManager` pending state into an explicit trigger helper/state model.
- [x] Lock hidden `⌘Tab` reveal timing to the first keydown while keeping `⌥Tab` on its legacy repeated-keydown path.
- [x] Clear pending hotkey trigger state for `Esc`, `Return`, and click commits so modifier release cannot double-activate.
- [x] Add focused trigger-state tests and verify the package test suite passes.
- [x] Update `README.md` and record review notes for the completed fix.

## Review

- `swift test --scratch-path /tmp/CmdTab-test` passed with 38 tests at the time of the original hotkey repair.
- Follow-up fixes anchored hidden `⌘Tab` timing to the event tap's original `CGEvent` timestamp instead of a later main-queue uptime sample.
- Live packaged-app hotkey QA is now complete under the Phase 1 acceptance record; the full current suite passed 132 tests.
