# CmdTab

Last Updated: 2026-03-28
Active Task: Website launch polish — interactive live walkthroughs plus security-hardened waitlist and launch docs.

## Project Summary

CmdTab is a custom macOS app switcher built with Swift, AppKit, and SwiftUI. It replaces the default switcher with a window-aware overlay, multiple visual styles, and a settings surface for controlling behavior.

The repo now also contains a standalone Next.js marketing site under `website/` for the private beta waitlist and public product story.

## Current Status

- Agent context entrypoints exist in `AGENTS.md`, `CLAUDE.md`, and `CODEX.md`.
- All prior bug fixes and refinements remain in place.
- Browser tab feature fully removed (Phase 1 optimization).
- CGEvent.tap callback refactored to be fully non-blocking (Phase 2 latency fix).
- Both `⌘Tab` and `⌥Tab` now reveal the same app-window switcher immediately.
- First-use cache priming is synchronous for the fast icon phase so the overlay does not stall on an empty cache.
- Refreshes now preserve previously captured thumbnails instead of flashing back to app icons before the next capture pass completes.
- The visible list now forces the most recent different app to the front, even when extra windows from the current app are still in the snapshot.
- Frontmost ordering now uses a short-lived validated override after a switch, instead of permanently assuming the selected app became frontmost.
- Command Palette search now uses deterministic ranking with acronym matching, token matching, and remembered selections for repeated short queries.
- Switcher preferences now support scoped window visibility (`current space`, `visible spaces`, `all spaces`) plus display targeting (`active window display`, `cursor display`, `all displays`).
- Switcher preferences now also support alternate standalone triggers based on right-side modifier tap / double-tap flows.
- The switcher now supports inline quick actions on the selected item: hide app, minimize window, close window, and quit app.
- Preferences now support decluttering rules for excluded apps and ignored window-title patterns.
- Settings now surface live permission diagnostics for Accessibility, Screen Recording, and secure-input interference.
- Settings now expose a preview preload action so users can explicitly warm the thumbnail cache before the next session.
- Settings now explicitly surface the shipped workflow features, including search memory, quick actions, selection clarity, space/display awareness, trigger flexibility, and decluttering.
- Radial Menu selection emphasis is stronger, with a clearer selected state and center detail label.
- A standalone `website/` Next.js App Router project now exists for the marketing homepage, privacy page, OG assets, and waitlist API.
- The website ships a screenshot-led landing page with generated product visuals for Classic Grid, Command Palette, Radial Menu, walkthrough steps, and permissions guidance.
- The website waitlist flow is implemented as a hardened `POST /api/waitlist` route with strict validation, rate limiting, same-origin checks, honeypot handling, and Resend server-side delivery hooks.
- The website copy now positions the launch around a private beta, founder pricing, a planned 14-day trial, and a one-time license rather than a subscription.
- The website feature layer now explicitly presents the shipped app differentiators instead of relying on vague “better switcher” language.
- The website now includes restrained motion: hero entrance choreography, ambient linear drift on supporting visuals, and scroll-reveal movement across the main content sections.
- The website now includes Vercel Web Analytics / Speed Insights wiring plus client-side CTA event tracking using the existing `data-analytics-*` markers.
- The walkthrough section now includes a browser-based interactive switcher demo for Classic Grid, Command Palette, and Radial Menu so visitors can click, search, and step through the modes directly on the site.
- The website now includes a launch/checkout section that can be activated with hosted provider URLs for checkout and trial download.
- A website owner dashboard now exists at `/dashboard` to summarize the live offer, launch configuration state, and the traffic / funnel / preference metrics that are being tracked.
- A launch handoff file now exists at `LAUNCH.md`, and `website/.env.example` documents the required website env vars for waitlist delivery and deployment.
- A root `SECURITY.md`, a website security page, and `/.well-known/security.txt` now document disclosure contact, security controls, and launch-stage operational requirements.
- Security verification now includes repeatable repo automation through `.github/workflows/security.yml`, Dependabot updates, and `npm run security:check`.
- Window capture now prefers the cleaner WindowServer hardware capture path with explicit full-size / best-resolution flags, reducing white-bar artifacts in thumbnails and selected-window backdrops.
- Candidate window enumeration now deduplicates repeated CG entries by real window identity, preventing duplicate non-window tiles for the same underlying window from appearing in the switcher.
- Local verification passed with `swift test --scratch-path /tmp/CmdTab-test`, `npm run typecheck`, and `npx next build --webpack`.

## Active Constraints / Non-Negotiables

- Read this file before planning or coding.
- Update this file whenever task context, progress, decisions, or blockers change.
- Do not refactor or redesign working core switcher internals unless the user explicitly asks for it or there is a proven bug with a reproducible case.
- Treat these paths as protected: hotkey event routing, modifier-release quick switch behavior, MRU/history ordering, frontmost resolution, activation confirmation, quick-action dispatch, and visible-item removal/suppression animations.
- Treat hot swap trigger logic as frozen. Do not change the hot swap state machine, modifier-tap counting, `Tab` reset behavior, or activation semantics unless the user explicitly asks for a hot swap change.
- When touching protected core paths, prefer the smallest possible patch, preserve current behavior by default, and verify with tests plus a rebuilt app.
- Settings interactions must be safe and avoid crash-prone force unwraps.
- Early modifier release must still quick-switch cleanly if the overlay has not committed yet.
- Hidden hotkey handling must remain instant; do not reintroduce fixed hold-to-show latency.
- CGEvent.tap callback must return in under 20ms — all UI work dispatched asynchronously.

## Decisions Already Made

- Canonical shared context file: `README.md`
- Repo instruction entrypoints: `AGENTS.md`, `CLAUDE.md`, `CODEX.md`
- Dock presence re-enabled; Dock clicks reopen the live switcher.
- Browser tab feature intentionally removed to reduce overhead and eliminate AppleScript latency.
- Both ⌘Tab and ⌥Tab now trigger the same app switcher (no separate tab mode).
- Browser-tab Apple Events permissions and messaging should stay removed from the bundle.
- The product should optimize for the fastest path to the correct window, not expand into a broad launcher or browser-tab automation tool.
- `⌘Tab` remains the headline trigger, but CmdTab now supports optional right-command / right-option tap-based alternate triggers as a secondary access path.
- The marketing site lives in `website/` and stays waitlist-only for private beta; there is still no checkout, testimonials, or public download flow in v1.
- The website targets broad Mac users with a premium, screenshot-first presentation and Mac-native system typography instead of a generic SaaS treatment.
- The website must avoid vibe-coded patterns. Start from a design system first, then keep color, type, spacing, radius, motion, and copy consistent across pages.
- Website visual constraints:
  - no default purple gradients unless they are explicitly brand-appropriate
  - no sparkles or emojis in hero headings
  - no generic glowing hover effects
- Website typography constraints:
  - use a consistent weight hierarchy
  - keep line-height and paragraph spacing uniform
  - define a type scale and stick to it
- Website layout and component constraints:
  - keep core component placement consistent across pages
  - define at most two or three border-radius values
  - keep hover states subtle, with at most a small lift
  - keep icon sizing proportional to nearby text
  - remove non-functional social icons
- Website animation and interaction constraints:
  - use intentional easing curves
  - stagger timing deliberately
  - every animation must serve a purpose
- Website UX constraints:
  - all async actions need loading states
  - buttons should show clear progress while pending
  - toggles, carousels, and interactive demos must be functional
  - data-heavy sections should use skeleton states where appropriate
- Website copy constraints:
  - avoid em-dash overuse
  - avoid vague claims like "Launch faster", "Build your dreams", or "Create without limits"
  - do not use fake testimonials
  - do not use placeholder personas or generic AI face motifs
- The waitlist inbox is the source of truth for v1; there is no database dependency for the website launch.
- The commercial direction is `14-day free trial -> one-time perpetual license`, with founder pricing communicated in copy before any live commerce flow exists.

## Open Issues / Next Steps

- Rebuild and manually validate after each change set.
- Manually validate the new space/display placement behavior on single-display and multi-display setups, especially mirrored overlay behavior for `All Displays`.
- Manually validate quick actions (`⌘H`, `⌘M`, `⌘W`, `⌘Q`) while the switcher is visible to confirm AX close/minimize behavior across common apps.
- Manually validate the new alternate trigger options (`Right ⌘`, `Right ⌘ ×2`, `Right ⌥`, `Right ⌥ ×2`) in real apps to confirm they never misfire during ordinary modifier shortcuts.
- Decide when to add a real direct-sale stack for trial download, checkout, licensing, and purchase recovery.
- Configure the website runtime env vars (`RESEND_API_KEY`, `WAITLIST_FROM_EMAIL`, `WAITLIST_TO_EMAIL`) before deploying or testing the live waitlist email path.
- Configure the launch env vars (`NEXT_PUBLIC_CHECKOUT_PROVIDER`, `NEXT_PUBLIC_CHECKOUT_URL`, `NEXT_PUBLIC_TRIAL_URL`, `NEXT_PUBLIC_SUPPORT_EMAIL`) before turning on paid traffic.
- Provision and monitor `security@cmdtab.net` before public launch so security reports do not depend on the privacy inbox alone.
- Repair Vercel CLI auth on this machine with `vercel login`; the installed CLI currently has an invalid saved token.
- Authenticate Vercel on the owner side or install/configure the Vercel CLI before attempting a real deployment from this machine.
- Enable Vercel edge protections or an equivalent shared rate-limit layer before public launch; the in-repo limiter is intentionally lightweight and process-local.
- Run a browser pass against the local or deployed website to review the final composition, responsive behavior, and screenshot pacing visually.
- Tune the new website motion against a real browser session to confirm the reveal cadence and ambient drift feel polished rather than decorative.
- Feature 3 (Appearance Previews) was already implemented — `StylePreviewCard` + `StyleMockPreview` exist in `PreferencesView.swift`.
- Keep this file current whenever the active task or implementation status changes.

## Recent Changes Log

- 2026-03-28: Added an interactive switcher simulator to the website walkthrough.
  - The walkthrough section now includes a live browser demo where visitors can click through Classic Grid, search inside Command Palette, and step around Radial Menu.
  - The demo uses the same concise product framing as the rest of the site, so it adds hands-on interaction without bringing back low-signal sections.
- 2026-03-28: Added launch conversion plumbing for checkout and distribution.
  - Added a launch section to the website with founder-price / trial messaging and hosted checkout/download CTA support driven by public environment variables.
  - Added `scripts/release_notarization_checklist.sh` so release packaging, signing, notarization, stapling, and clean-machine validation have one script-based checklist entrypoint.
- 2026-03-28: Added an owner-facing website dashboard and preference metrics instrumentation.
  - Added `/dashboard` to summarize the active offer, website launch config state, and which metrics are tracked through Vercel Analytics and Speed Insights.
  - Added aggregate-safe preference metrics to the live demo: mode selection, navigation, demo target selection, and bucketed Command Palette search usage without storing raw queries.
- 2026-03-28: Added a documented website security pass and disclosure surface.
  - Hardened `POST /api/waitlist` with request-size enforcement, malformed-JSON handling, and explicit HEAD/OPTIONS rejection while preserving the existing response shape.
  - Added stronger browser isolation headers in `website/next.config.ts`.
  - Added `SECURITY.md`, a public `/security` page, and `/.well-known/security.txt`.
  - Added `npm run security:deps` / `npm run security:check`, a dedicated security workflow, and Dependabot config for recurring dependency review.
- 2026-03-28: Added website launch handoff and real analytics plumbing.
  - Added `@vercel/analytics` and `@vercel/speed-insights` to `website/`.
  - Wired page tracking in `website/src/app/layout.tsx` and CTA event tracking through a new `SiteEventTracker`.
  - Added `website/.env.example` for the waitlist email env vars and created `LAUNCH.md` with the launch checklist covering website deployment, commerce, and notarized macOS distribution.
  - Confirmed the Vercel connector is not authenticated in this environment and the Vercel CLI is not installed locally, so final deploy/auth steps still need the owner side.
- 2026-03-27: Tightened duplicate-window suppression in switcher enumeration.
  - `AppSwitcher` now deduplicates CGWindow candidates by `(ownerPID, windowID)` and keeps the best-quality candidate instead of allowing multiple CG entries for the same real window through.
  - Added regression coverage proving duplicate entries for one underlying window collapse while distinct windows with different IDs remain visible.
- 2026-03-27: Aligned window capture with AltTab’s cleaner thumbnail path.
  - `AppSwitcher` now prefers the SkyLight / WindowServer hardware capture path earlier in the screenshot pipeline and uses explicit capture flags equivalent to AltTab’s `ignoreGlobalClipShape + bestResolution + fullSize`.
  - `SwitcherView` no longer paints an opaque fill behind the selected-window backdrop layer, reducing visible edge gutters when a captured image still has transparent margins.
- 2026-03-27: Added protected-core guidance for future agents.
  - `README.md` and `AGENTS.md` now explicitly mark the working switcher core as protected.
  - Agents should avoid casual refactors in hotkey routing, MRU/history ordering, frontmost resolution, activation confirmation, quick actions, and removal animations unless there is a proven bug or an explicit user request.
- 2026-03-27: Added the standalone marketing site under `website/`.
  - Scaffolded a Next.js App Router project with a private-beta homepage, privacy page, sitemap, robots, and generated social cards.
  - Built typed content/config modules plus reusable section/UI components for the hero, mode comparison, walkthrough, feature bands, permissions, FAQ, and footer.
  - Implemented `POST /api/waitlist` with strict payload validation, same-origin checks, honeypot handling, in-memory duplicate suppression, rate limiting, and Resend integration via env vars.
  - Added the first website asset pack under `website/public/screenshots/` plus the copied app icon in `website/public/brand/`.
  - Verified the site with `npm run typecheck` and `npx next build --webpack`; plain Turbopack build panicked in the sandbox while processing PostCSS, so local production verification currently uses the Webpack path.
- 2026-03-27: Applied the product differentiation pass from the launch strategy.
  - Added deterministic Command Palette ranking with acronym matching, token scoring, and query memory via `PaletteSearch.swift` and `SearchMemoryStore.swift`.
  - Added scoped window visibility and display placement preferences, including passive mirrored overlay panels for `All Displays`.
  - Added quick actions on the selected switcher item and wired keyboard shortcuts while the switcher is visible: `⌘H`, `⌘M`, `⌘W`, `⌘Q`.
  - Added decluttering controls for excluded apps and ignored window-title patterns, plus a shared exclusion matcher model.
  - Added live permission diagnostics in Settings for Accessibility, Screen Recording, and secure-input status.
  - Increased Radial Menu selection clarity with stronger emphasis, a clearer selected node treatment, and richer center labeling.
  - Updated website copy to support the planned founder-price / one-time-license launch story without adding checkout or trial delivery yet.
  - Verified the app with `swift test --scratch-path /tmp/CmdTab-test` and added coverage for palette search memory and exclusion matching.
- 2026-03-27: Closed the remaining trigger-flexibility gap from the product strategy.
  - Added `AlternateTriggerMode` preferences for right-command and right-option tap / double-tap launch flows.
  - Added a separate modifier-tap state machine in `HotkeyManager.swift` so alternate triggers do not interfere with the primary `⌘Tab` / `⌥Tab` path.
  - Exposed the alternate trigger in Settings and the menu-bar quick controls, and added a `Preload Previews` action to make preview readiness visible in the app.
  - Added `AlternateModifierTriggerStateTests.swift` and re-ran `swift test --scratch-path /tmp/CmdTab-test`.
- 2026-03-27: Added a feature-visibility pass across the website and Settings.
  - Expanded the Settings window so command-palette memory, quick actions, selection clarity, display/space targeting, and decluttering are visible as product features instead of buried implementation details.
  - Reworked the website feature narrative to explicitly cover preview reliability, learned search, quick actions, alternate triggers, decluttering, space/display awareness, and radial clarity.
  - Added new screenshot asset aliases and richer feature-band bullets so the site can present the full shipped differentiation layer without changing the waitlist-only launch model.
  - Verified the repo again with `swift test --scratch-path /tmp/CmdTab-test`, `npm run typecheck`, and `npx next build --webpack`.
- 2026-03-27: Added a CSS-first motion pass to the marketing site.
  - Added `MotionReveal` for section-entry animation without introducing a separate motion library.
  - Added hero entrance timing, ambient grid drift, and subtle linear movement on the supporting screenshot stack.
  - Applied staggered reveal motion across the proof strip, modes, walkthrough, feature bands, permissions, waitlist, FAQ, and footer, while preserving `prefers-reduced-motion`.
  - Verified the site again with `npm run typecheck` and `npx next build --webpack`.
- 2026-03-27: Removed the fixed hold-to-show delay from the hotkey path and kept the switcher app-only.
  - `HotkeyTriggerPolicy` reveal delay is now zero for both `⌘Tab` and `⌥Tab`.
  - `scheduleReveal` now executes immediately when the deadline is already due.
  - `SwitcherWindowController` primes the fast icon cache before first reveal and no longer spins on a retry loop waiting for items.
  - Dock reopen now opens the live switcher instead of the settings window.
  - Removed stale browser-tab Apple Events metadata from `Resources/Info.plist`, `Resources/CmdTab.entitlements`, and `build.sh`.
- 2026-03-27: Preserved cached thumbnails across refreshes.
  - `AppSwitcher` now keeps a thumbnail cache keyed by switcher identity and reuses those previews during the fast refresh pass.
  - Forced refreshes no longer replace existing thumbnail tiles with icon-only placeholders while the new capture pass is still running.
- 2026-03-27: Tightened MRU ordering for current-app windows.
  - `SwitcherOrdering` now pushes any leading entries from the current frontmost app behind the most recent different app after the active window is rotated to the end.
  - This keeps `⌘Tab` visibly ordered by last-used app instead of occasionally starting with another window from the same current app.
- 2026-03-27: Hardened frontmost tracking after switch commits.
  - Added `FrontmostResolution` so quick re-presses can still use a very short optimistic override, but failed activations no longer poison the next Alt-Tab ordering.
  - `SwitcherWindowController` now resolves frontmost identity from the live system app plus the short override window, instead of eagerly rewriting the observed frontmost PID on every commit.
  - `AppSwitcher` now times out stale `pendingActivationPID` values so failed app activations do not leave suppression state behind.
- 2026-03-27: Fixed `⌘Tab` hold-to-show timing drift.
  - Replaced loose pending hotkey fields in `HotkeyManager` with `HotkeyTriggerState` and `PendingHotkeyTrigger`.
  - Hidden `⌘Tab` now schedules reveal from the first keydown and ignores repeated hidden `Tab` events, preventing auto-repeat from stretching the 100ms threshold.
  - Anchored hidden `⌘Tab` timing to the original `CGEvent` timestamp from the event tap instead of `ProcessInfo.systemUptime` sampled later on the main queue, eliminating queue-induced extra delay.
  - Reveal-deadline races where the hardware modifier is already up now fall back to quick-switch instead of dropping the action.
  - Wired `SwitcherWindowController.onClickCommit` to `HotkeyManager` so click commits clear pending hotkey state before modifier release.
  - Added `HotkeyTriggerStateTests` covering fixed-delay reveal, early quick-switch, reverse handling, escape cleanup, and unchanged `⌥Tab` reschedule semantics.
- 2026-03-27: Two-phase optimization — feature deletion + event tap latency fix:
  - Phase 1 (Feature Deletion): Completely removed browser tab switching feature.
    - Deleted `TabSwitcher.swift` (AppleScript tab enumeration, preview generation, tab activation).
    - Removed `SwitcherMode.tab`, `SwitcherItemKind.browserTab`, `SwitcherHistoryIdentity.browserTab`.
    - Removed preferences: `includeTabsInAppSwitcher`, `maxBrowserTabsShown`, `primaryMode`, `alternateMode()`.
    - Removed `browserBundleIDs` filter from `AppSwitcher.makeCandidate()`.
    - Cleaned up Settings UI: removed "Show Browser Tabs" button, primary mode picker, tab toggle, tab limit picker.
    - Cleaned up menu bar: removed browser tab toggle, primary mode selector.
    - Simplified `SwitcherWindowController`: removed `tabSwitcher`, simplified `items()` to AppSwitcher-only.
    - Updated all test files to remove browser tab test cases.
  - Phase 2 (Event Tap Latency Fix): Fixed CGEvent.tap timeout causing native macOS switcher bleed-through.
    - Replaced `runOnMain` (which executed synchronously on main thread) with `dispatchToMain` (always async).
    - ALL side-effects in the event tap callback now dispatched asynchronously — callback returns in microseconds.
    - Added `os_log` timing instrumentation: logs a warning when callback exceeds 5ms (target < 20ms).
    - Added `os_log` when tap is re-enabled after system disable.
    - Both ⌘Tab and ⌥Tab now trigger the same app switcher (no mode switching).
- 2026-03-26: Structural audit — 3 critical regressions (thumbnails, tab filter, latency):
  - Bug 1+3 (Thumbnails + Latency): Refactored monolithic `buildItems()` into two-phase cache build. Phase 1 enumerates windows and caches items with app icons only (instant UI). Phase 2 captures thumbnails via `CGWindowListCreateImage` on the background queue and updates the cache. Removed dead `PreparedWindowEntry` / `preparedWindowEntries`. Added `os_log` when Screen Recording permission is missing.
  - Bug 2 (Tab Filter): Added `browserBundleIDs` set to `AppSwitcher`. When `includeTabsInAppSwitcher` is false, `makeCandidate()` now drops windows belonging to Chrome, Safari, Arc, Edge, Firefox, Brave during enumeration. Browser apps still appear as fallback entries.
- 2026-03-26: Third bug-fix pass — 4 event-routing / performance bugs:
  - Bug 4 (Bleed-through): Added `keyUp` suppression for Tab (keycode 48) in CGEventTap so the WindowServer never sees orphaned Tab-up events during an active session.
  - Bug 2 (Double Escape): Added `keyDown(with:)` override in `SwitcherPanel` as backup Esc handler for when CGEventTap is momentarily disabled by system timeout.
  - Bug 1 (Quick Switch): Implemented fast-path in `handleModifierRelease` — early modifier release now calls `commitTriggerSession` for instant MRU[0] switch without showing UI.
  - Bug 3 (Ghost Window): Added 50ms post-show deferred hardware check in `scheduleReveal` to catch missed `flagsChanged` events when CGEventTap is disabled.
- 2026-03-25: Added the agent context system scaffold and seeded the current CmdTab project status.
- 2026-03-25: Reverted the app behavior/UI changes to the previous iteration while keeping the agent context system files and shared README workflow.
- 2026-03-26: Second bug-fix pass — 3 race-condition / latency bugs:
  - Bug 1 (Delay Bloat): Removed CGWindowListCopyWindowInfo + AppleScript fallbacks from `currentFrontmostIdentity`; pure PID-based lookup now, zero blocking I/O on main thread at render time.
  - Bug 2 (Double Escape): Introduced `SwitcherPanel` subclass with `canBecomeKey = true`; `showPanel()` always calls `makeKeyAndOrderFront` (hotkey mode included) so the panel reliably receives Esc via both CGEventTap and NSApp's event loop.
  - Bug 3 (Ghost Window): Added `NSEvent.modifierFlags` live hardware check inside `scheduleReveal`'s work item to catch the tight race where the modifier is released at the exact 100ms deadline.
- 2026-03-26: Updated `AGENTS.md` with full workflow rules from `CLAUDE.md`.
- 2026-03-25: Applied full bug-fix + feature pass:
  - Bug 1 (Event Tap): `tapDisabledByTimeout` now returns `nil` instead of forwarding synthetic event.
  - Bug 2 (Early Release): Removed `commitTriggerSession` branch from `handleModifierRelease`; early release aborts cleanly.
  - Bug 3 (Switch Delay): Removed redundant `warmCache(force:)` calls from `activateWindow`/`activateFallbackApplication`; `appActivated` notification handles the rebuild.
  - Bug 4 (Double Escape): Escape now suppresses when `pendingMode != nil` (reveal in-flight) in addition to when panel is visible.
  - Bug 5 (App Sorting): `SwitcherOrdering.orderedItems` falls back to `rankForApp(bundleID:pid:)` when exact window-ID match fails.
  - Feature 1 (Dock Icon): `LSUIElement` set to `false`; `applicationShouldHandleReopen` opens Settings.
  - Refinement 1 (Vibrancy): Removed opacity caps from `VisualEffectBlur` in all three style views; reduced overlay gradient.
  - Refinement 3 (Crash Prevention): No WIP buttons found; all controls have real actions.

## Agent Update Protocol

1. Read `AGENTS.md`.
2. Read this file before planning or coding.
3. Treat this file as the current shared context unless the latest user prompt overrides it.
4. Update `Current Status`, `Decisions Already Made`, `Open Issues / Next Steps`, and `Recent Changes Log` whenever work changes them.
5. Prefer updating existing sections over appending duplicate notes.
