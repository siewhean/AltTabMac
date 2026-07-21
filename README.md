# CmdTab

Last Updated: 2026-07-22
Active Task: Website copy simplification and readability pass.

## Project Summary

CmdTab is a custom macOS app switcher built with Swift, AppKit, and SwiftUI. It replaces the default switcher with a window-aware overlay, multiple visual styles, and a settings surface for controlling behavior.

The repo also contains the Next.js product site, trial and commerce APIs, license delivery, opt-in app telemetry ingestion, and an owner dashboard under `website/`.

## Current Status

- Agent context entrypoints exist in `AGENTS.md`, `CLAUDE.md`, and `CODEX.md`.
- 2026-07-20: Continued security hardening from `019f7fe9-4471-78e1-9075-2def5e64a508` by (1) centralizing and tightening same-origin `POST` admission checks for waitlist/license-help routes, (2) removing `unsafe-inline` from website CSP `script-src`, and (3) forcing remote license-status refresh before switcher gate checks in app usage paths.
- All prior bug fixes and refinements remain in place.
- 2026-07-20: Expanded website SEO and GEO surface for discoverability with new `/faq` and `/how-it-works` pages, JSON-LD emission, strengthened metadata/robots/sitemap policy for public + protected routes, and `llms.txt`.
- Browser tab feature fully removed (Phase 1 optimization).
- CGEvent.tap callback refactored to be fully non-blocking (Phase 2 latency fix).
- Both `⌘Tab` and `⌥Tab` use the same app-window switcher. `⌘Tab` quick-releases without UI before 100 ms and reveals at 100 ms when held; `⌥Tab` retains its existing immediate path.
- First use publishes the complete provisional window list without synchronous capture; thumbnail work stays off the hotkey-installation and reveal-critical paths.
- Refreshes preserve previously captured thumbnails instead of flashing back to app icons or skeletons before the next capture pass completes.
- Every trusted real window is a distinct tile in strict window-level MRU order; per-app grouping, fallback tiles, and per-app caps are not used.
- Frontmost ordering now uses a short-lived validated override after a switch, instead of permanently assuming the selected app became frontmost.
- Frontmost resolution now falls back to the most recent visible same-PID history window when AX cannot resolve the exact focused window for a multi-window app.
- Candidate enumeration deduplicates only repeated records for the same `ownerPID + CGWindowID`; distinct window IDs remain distinct tiles even when their titles, frames, or overlap are identical.
- Classic grid thumbnails now fill and clip inside the card frame instead of letterboxing already-cropped captures.
- Window enumeration prefers AX-resolved window IDs; if every running app has an unusable AX policy, a global heuristic fallback keeps real WindowServer surfaces available instead of producing an empty switcher.
- Classic grid previews now follow the AltTab-style approach more closely: the tile frame stays fixed, but the preview image is aspect-fit within that frame instead of being crop-filled edge to edge.
- The unused space around aspect-fit previews now renders with a glass-like backing layer, and true no-preview tiles now use the skeleton fallback treatment instead of centered app-icon cards.
- Previewless tiles keep the app icon and application name in the label row while the unavailable preview area renders as a skeleton.
- Classic grid tiles with real previews now use a larger app icon and title row so switcher labels read more clearly at a glance.
- In the classic grid, mouse-wheel input now scrolls the page itself instead of stepping selection, and tile selection follows real mouse movement rather than changing just because content scrolled underneath a stationary pointer.
- The cold-start switcher path never blocks hotkey installation on thumbnail capture; warm thumbnails are reused immediately and cold thumbnails populate asynchronously.
- Continuous trackpad scroll is no longer swallowed by the global hotkey tap while the switcher is visible, and hover-driven selection is now suppressed during scroll until a real mouse-move event occurs.
- New switcher sessions now start with hover selection suppressed, so the initial selection stays on the first tab until the user actually moves the mouse.
- In the classic grid, pointer hover no longer moves the selector at all; mouse position is only used to identify click targets.
- Command Palette search now uses deterministic ranking with acronym matching, token matching, and remembered selections for repeated short queries.
- Switcher preferences now support scoped window visibility (`current space`, `visible spaces`, `all spaces`) plus display targeting (`active window display`, `cursor display`, `all displays`).
- Switcher preferences now also support alternate standalone triggers based on right-side modifier tap / double-tap flows.
- The switcher now supports inline quick actions on the selected item: hide app, minimize window, close window, and quit app.
- Preferences now support decluttering rules for excluded apps and ignored window-title patterns.
- Settings now surface live permission diagnostics for Accessibility, Screen Recording, and secure-input interference.
- Settings now expose a preview preload action so users can explicitly warm the thumbnail cache before the next session.
- Settings now explicitly surface the shipped workflow features, including search memory, quick actions, selection clarity, space/display awareness, trigger flexibility, and decluttering.
- The app includes a dedicated Licensing pane with a server-registered 14-day trial, signed offline license activation, and direct buy/help actions. Cached licensed state is accepted only after signature verification.
- Developer licensing simulations and the Developer settings pane are compiled out of release builds.
- Diagnostics telemetry is disabled by default, can be opted into from Settings, and excludes window titles, thumbnails, and app contents.
- Expired-trial sessions now route the user into the Licensing pane instead of opening the switcher.
- Radial Menu selection emphasis is stronger, with a clearer selected state and center detail label.
- A standalone `website/` Next.js App Router project provides the marketing, privacy, security, buy, help, and protected dashboard surfaces.
- The website ships a screenshot-led landing page using privacy-safe captures from the rebuilt app for Classic Grid, Command Palette, Radial Menu, and walkthrough states. The permissions illustration remains until clean-Mac onboarding media is recorded.
- The website waitlist flow is implemented as a hardened `POST /api/waitlist` route with strict validation, rate limiting, same-origin checks, honeypot handling, and Resend server-side delivery hooks.
- The website supports a 14-day trial and one-time-license purchase flow through hosted Lemon Squeezy checkout and signed license fulfillment.
- The website feature layer now explicitly presents the shipped app differentiators instead of relying on vague “better switcher” language.
- The website now includes restrained motion: hero entrance choreography, ambient linear drift on supporting visuals, and scroll-reveal movement across the main content sections.
- The website now includes Vercel Web Analytics / Speed Insights wiring plus client-side CTA event tracking using the existing `data-analytics-*` markers.
- The walkthrough section now includes a browser-based interactive switcher demo for Classic Grid, Command Palette, and Radial Menu so visitors can click, search, and step through the modes directly on the site.
- The website now includes a launch/checkout section that can be activated with hosted provider URLs for checkout and trial download.
- A protected website owner dashboard at `/dashboard` summarizes waitlist, trial, purchase, fulfillment, support, and opt-in app-usage data.
- A launch handoff file now exists at `LAUNCH.md`, and `website/.env.example` documents the required website env vars for waitlist delivery and deployment.
- A root `SECURITY.md`, a website security page, and `/.well-known/security.txt` now document disclosure contact, security controls, and launch-stage operational requirements.
- Security verification now includes repeatable repo automation through `.github/workflows/security.yml`, Dependabot updates, and `npm run security:check`.
- Window capture uses ScreenCaptureKit first on macOS 14+ and a circuit-broken, time-bounded WindowServer/Core Graphics compatibility path when shareable-window discovery fails; macOS 13 retains the legacy capture path.
- Candidate window enumeration now deduplicates repeated CG entries by real window identity, preventing duplicate non-window tiles for the same underlying window from appearing in the switcher.
- Production gates are automated through Swift tests/build checks, website tests/typecheck/build/audit, secret scanning, and fail-closed release scripts. Actual notarization and clean-Mac QA still require owner credentials and hardware validation.
- Live Aqua-session QA confirmed ScreenCaptureKit populated three distinct Classic Grid thumbnails with app icons and names. A 100-invocation warm first-frame test found a populated preview at 50 ms on every invocation, and a 400-step forward/reverse selection cycle kept the previews intact.
- The app now builds as a universal `arm64 + x86_64` macOS 13+ bundle, exposes privacy-safe `--diagnostics-json` output, and records hotkey, reveal, capture, and activation timing with `os_signpost`.
- An opt-in runtime QA evidence channel now correlates hardware-event, reveal-deadline, first AppKit-frame, cache/capture, event-tap, selection-step, and exact-window activation results in privacy-safe JSONL. The release validator enforces warm/cold latency, callback, duplicate, multi-window, and forward/reverse-cycle gates; physical-keyboard and clean-Mac checks remain operator requirements.
- Local builds use the team Apple Development identity when available so Accessibility and Screen Recording grants survive rebuilds; permission onboarding opens only one missing System Settings pane, never loops automatic requests, and completes its first-launch decision before the global event tap is installed.
- Upgrades from the legacy `com.user.CmdTab` identity migrate only known preferences and validated licensing state; explicit reopens present the standalone switcher, while first launch and login-item startup remain background-only.
- If AX window IDs or Screen Recording metadata are unavailable in the launched app process, CmdTab now falls back to visible or titled WindowServer surfaces so `⌘Tab` still opens a skeleton-only switcher instead of an empty session.
- Public mutation and dashboard-login throttles now use fail-closed Upstash Redis state; Preview has a configured store, while Production still requires a separately provisioned store.
- PostgreSQL now uses checksum-verified advisory-lock migrations, an authenticated health endpoint, least-privilege role bootstrap, bounded daily retention, and automated backup/restore-drill workflows. Before Production SQL runs, the protected workflow creates and verifies a real Neon recovery branch and derives PITR retention from the authenticated project response; migration, backup/restore, final-QA, and aggregate receipts all bind that same provider evidence. Reusable `db:backup` and `db:restore:verify` commands keep credentials out of process arguments, and PostgreSQL 17 CI covers clean install, migration idempotency, checksum drift, and role isolation. The workflows still require live AWS/KMS, Better Stack, and Neon credentials.
- Production website operations now have fail-closed Preview/Production environment-isolation validation, exact WAF enforcement checks, clean-tag immutable-SHA deployment receipts, and verified Vercel Blob DMG publishing with post-upload checksum validation. Root and website Vercel ignore manifests prevent local secrets and heavyweight macOS build artifacts from entering deployment uploads.
- Release publication is two-phase: privacy-safe Preview smoke plus protected zero-alias Production staging feed the final aggregate, then a separate checksum-authorized action publishes the immutable DMG, promotes the staged deployment, verifies canonical health, and records the rollback target.
- Lemon Squeezy fulfillment now requires explicit store/product allowlists, rejects test-mode orders, atomically claims delivery, and preserves refund tombstones before issuing a signed license.
- 2026-04-23 aspect-ratio experiment reverted:
  - Reverted the per-tile aspect-ratio-driven height logic in `ClassicGridView` after it made the grid read worse in practice.
  - Restored the previous fixed thumbnail frame with crop/fill rendering, which matches the prior working switcher layout.
- 2026-04-23 AltTab-style thumbnail refinement:
  - Kept the fixed `ClassicGridView` tile height and overall grid geometry.
  - Switched preview rendering to aspect-fit inside the fixed thumbnail frame, with a subtle dark backing layer so non-standard window shapes stay visible without destabilizing the grid.
- 2026-04-23 fallback polish after AltTab-style fit:
  - Replaced the dark letterbox backing with a glass-like background so empty preview space blends into the switcher surface more naturally.
  - Removed the app-icon fallback card path so genuinely previewless tiles return to the skeleton treatment instead of implying a valid rendered thumbnail exists.
- Recent local verification passed with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test` and `./build.sh`; earlier website verification passed with `npm run typecheck` and `npx next build --webpack`.

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
- The product site lives in `website/`; checkout, trial registration, license fulfillment/recovery, and the protected owner dashboard are active code paths, while public launch still depends on production configuration.
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
- Postgres is required for persistent waitlist, trial, dashboard, telemetry, and license-fulfillment records.
- The commercial model is `14-day free trial -> one-time perpetual license` through Lemon Squeezy-hosted checkout.

## Open Issues / Next Steps

- Rebuild and manually validate after each change set.
- Manually validate duplicate-window suppression on real apps that expose internal extra surfaces (browser windows, Electron apps, IDEs) and confirm one visible window yields one switcher tile.
- Manually validate multi-window MRU ordering on a live desktop, especially when switching back into apps that have several visible windows and slow AX focus updates.
- Manually validate the new space/display placement behavior on single-display and multi-display setups, especially mirrored overlay behavior for `All Displays`.
- Manually validate quick actions (`⌘H`, `⌘M`, `⌘W`, `⌘Q`) while the switcher is visible to confirm AX close/minimize behavior across common apps.
- Manually validate the new alternate trigger options (`Right ⌘`, `Right ⌘ ×2`, `Right ⌥`, `Right ⌥ ×2`) in real apps to confirm they never misfire during ordinary modifier shortcuts.
- Split Neon Preview and Production, configure the least-privilege database roles, enable at least seven days of PITR, then apply the validated migrations and activate backup/monitoring workflows.
- Configure the website runtime env vars (`RESEND_API_KEY`, `WAITLIST_FROM_EMAIL`, `WAITLIST_TO_EMAIL`) before deploying or testing the live waitlist email path.
- Configure the launch env vars (`NEXT_PUBLIC_CHECKOUT_PROVIDER`, `NEXT_PUBLIC_CHECKOUT_URL`, `NEXT_PUBLIC_TRIAL_URL`, `NEXT_PUBLIC_SUPPORT_EMAIL`) before turning on paid traffic.
- Configure Production Upstash, database role URLs, dashboard secrets, Lemon Squeezy webhook/signing secrets, and checkout/download URLs before production traffic.
- Back up `.secrets/cmdtab-license-private-key.pem` somewhere safe. The app embeds only the public key; this private key is required to generate real license tokens.
- Use `swift scripts/generate_license_key.swift --email user@example.com --name "User Name"` to issue a signed activation key for the app.
- Upgrade Vercel before enforcing the configured WAF rule; Hobby accepted the validated log-only rule but rejected the `429` rate-limit action.
- Resolve the Apple team identity before release: the plan names `T6CDNA9H92`, while the installed development certificate and current app signature report `TeamIdentifier=94R58J6LA2`. Then install the matching Developer ID Application identity and notary profile and produce the notarized `CmdTab-1.0.0-universal.dmg` receipt.
- Provision and monitor `security@cmdtab.net` and `ops@cmdtab.net`; the domain currently has no mail exchanger configured.
- Run a browser pass against the local or deployed website to review the final composition, responsive behavior, and screenshot pacing visually.
- Tune the new website motion against a real browser session to confirm the reveal cadence and ambient drift feel polished rather than decorative.
- Feature 3 (Appearance Previews) was already implemented — `StylePreviewCard` + `StyleMockPreview` exist in `PreferencesView.swift`.
- Verify search console query ownership before further title/H1 reshaping for new commercial pages.
- Keep this file current whenever the active task or implementation status changes.

## Recent Changes Log

- 2026-07-22: Simplified and humanized public website copy across `FAQ`, `How it works`, comparison pages, and commerce surfaces (`/buy`, `/trial`, `/help`) to reduce dense phrasing and keep page-level scannability high.

- 2026-07-21: Implemented SEO and GEO audit enhancements & competitor comparison pages.
  - Fixed JSON-LD schema issues in `website/src/lib/seo.ts` (removed invalid `SearchAction`, set offer availability to `InStock`, enriched `SoftwareApplication` with macOS 13.0+ and hardware specs).
  - Stabilized `website/src/app/sitemap.ts` with fixed release timestamp constant and added `/vs/alttab` & `/vs/contexts` routes.
  - Created `website/public/llms-full.txt` machine documentation surface with ScreenCaptureKit latency benchmarks (<50ms thumbnail render), hardware requirements, and AI RAG Q&A pairs.
  - Created public competitor comparison pages `/vs/alttab` and `/vs/contexts` with side-by-side matrices, canonical metadata, and JSON-LD schemas.
  - Verified clean compilation with `npm run typecheck` and `npx next build --webpack`.

- 2026-07-20: Implemented SEO + GEO website optimization rollout.
  - Added `/faq` and `/how-it-works` public routes with dedicated crawl metadata and FAQ schema for AI extraction.
  - Expanded `sitemap.ts` to include all public routes and updated `robots.ts` with protected dashboard/API disallow rules.
  - Added global and page-level JSON-LD (`WebSite`, `SoftwareApplication`, `Product`, `Offer`, `FAQ`, `BreadcrumbList`) and added `website/public/llms.txt` for model indexing.
  - Added `noindex` metadata to protected dashboard routes and explicit canonical metadata for public commerce/legal routes.
  - Added macOS intent copy and platform metadata blocks on `/` and `/buy` plus Open Graph / Twitter alt/title clarifications.

- 2026-07-20: Replaced generated website product visuals with real CmdTab captures.
  - Captured Classic Grid, Command Palette, and Radial Menu directly from the packaged app using isolated neutral windows; the published frames contain real thumbnails, app icons, names, and selection states without private desktop content.
  - Added optional self-hosted MP4 rendering with poster fallback and reduced-motion handling, plus asset-integrity tests that reject product SVG regressions and mismatched PNG dimensions.
  - Full interaction recordings remain a clean-QA-account launch task because this desktop's command-line video capture resolves to the macOS lock screen rather than the active CmdTab panel; no lock-screen or synthesized footage is published.

- 2026-07-20: Security review deepened around website CSRF and license revocation paths.
  - Hardened website POST intake by making `/api/license-help` and `/api/waitlist` fail hard when `Origin`/`Referer` are missing instead of treating that as same-origin.
  - Added immediate license-status revocation checks for the macOS client (`/api/license/status`), and introduced a dedicated license-status rate-limit bucket to control abuse.
  - Completed a focused sweep of app, website, and transaction surfaces for #1 CSRF controls and #3 refund-driven access revocation, with remaining risks limited to timing-window behavior for revocation propagation.

- 2026-07-20: Replaced self-asserted Neon recovery markers with provider-verified release evidence.
  - The protected migration workflow now creates a protected recovery branch, waits for the exact Neon `create_branch` operation, and verifies its parent LSN and configured history retention before SQL runs.
  - Migration, backup/restore, final-QA, and aggregate receipts bind the same redacted Neon API response hashes and immutable source/tag; regression coverage rejects missing credentials, weak retention, operation mismatch, and receipt tampering.

- 2026-07-17: Added production database backup and restore verification tooling.
  - Added reusable custom-format backup and isolated restore-verification commands with SHA-256 validation and credential-safe PostgreSQL process invocation.
  - Backup CI now downloads its uploaded S3 dump and checksum and revalidates both before reporting success; backup and monthly restore drills support Better Stack success/failure heartbeats.
  - Added PostgreSQL 17 integration CI for clean migration install, second-run idempotency, checksum-drift rejection, schema checks, and runtime/maintenance/backup role boundaries.

- 2026-07-16: Fixed the cold-start app list dropping windows whose thumbnails were not ready during synchronous priming. The initial session now retains the full enumerated app/window list and overlays ready thumbnails onto it.

- 2026-07-16: Fixed stale Cmd-Tab trigger state after dismissal. All switcher hide paths now cancel the pending trigger before Command release, preventing a dismissed session from launching a hidden quick-switch action.

- 2026-07-16: Hardened touchpad outside-click dismissal by handling all mouse-down variants and converting event-tap clicks through `NSEvent.mouseLocation`, avoiding Quartz/Cocoa screen-coordinate mismatches.

- 2026-07-16: Activated outside-click dismissal by including left/right mouse-down events in the global CGEvent tap mask. The existing dismissal handler was unreachable because those event types were not subscribed to.

- 2026-07-16: Routed outside mouse-down events through the existing Accessibility event tap so switcher dismissal does not depend on AppKit global monitor delivery.

- 2026-07-16: Fixed switcher dismissal when the user clicks outside the visible switcher panel. A global mouse monitor now hides the active session while preserving clicks inside the primary or mirrored switcher panels.

- 2026-04-23: Fixed duplicate switcher tiles and tightened thumbnail presentation.
  - Superseded: semantic same-app pruning was removed because distinct `CGWindowID`s are distinct switcher windows even when their frames overlap; current deduplication uses exact stable window identity only.
  - Regression coverage now preserves distinct same-app IDs with identical or overlapping frames and collapses only duplicate records for one window ID.
  - Updated `ClassicGridView` so live previews now render with fill-and-clip inside the thumbnail card instead of fitting with visible framing artifacts.
  - Verified with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test` and rebuilt the packaged app with `./build.sh`.
- 2026-04-23: Fixed multi-window frontmost resolution when exact AX identity is unavailable.
  - `FrontmostResolution` now uses the most recent visible same-PID history identity before giving up when the frontmost app has multiple visible windows and the exact focused window cannot be resolved yet.
  - Added regression coverage in `FrontmostResolutionTests` and `SwitcherOrderingTests` for the previously untested ambiguous same-app multi-window path.
  - Verified the Swift package with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test`; plain SwiftPM sandboxing is blocked in this environment by nested `sandbox-exec`.
  - Confirmed that a second terminal-launched `CmdTab` instance exits immediately by design because the app is a singleton accessory app; that lifecycle behavior is separate from the MRU bug.
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
  - Vercel access was unavailable during that historical pass; authenticated CLI access is now working and was used for the current production audit.
- 2026-03-27: Tightened duplicate-window suppression in switcher enumeration.
  - `AppSwitcher` now deduplicates CGWindow candidates by `(ownerPID, windowID)` and keeps the best-quality candidate instead of allowing multiple CG entries for the same real window through.
  - Added regression coverage proving duplicate entries for one underlying window collapse while distinct windows with different IDs remain visible.
- 2026-03-27: Aligned window capture with AltTab’s cleaner thumbnail path.
  - Superseded: macOS 14+ now uses ScreenCaptureKit first, then a single-worker, time-bounded WindowServer/Core Graphics compatibility path so unavailable capture services cannot wedge the refresh queue.
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
