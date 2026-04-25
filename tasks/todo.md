# Todo

## 2026-04-23 - Remove Mouse-Driven Selector Movement

- [x] Stop hover events in the classic grid from mutating the selected index.
- [x] Keep hover state only for click targeting so mouse clicks can still activate the tile under the pointer.
- [x] Re-run the Swift test suite and update project notes.

## Remove Mouse-Driven Selector Movement Review

- Updated `ClassicGridView` so continuous hover only updates `hoveredIndex` and no longer changes `selectedIndex`.
- Preserved the existing click path in `SwitcherWindowController`, so clicking a hovered tile still works without making pointer hover drive the selector.
- Verified with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test`.

## 2026-04-23 - Stable Initial Selection On Reveal

- [x] Keep hover selection suppressed when a new switcher session first appears.
- [x] Prevent the pointer’s existing screen position from stealing selection before the first real mouse move.
- [x] Re-run the Swift test suite and update project notes.

## Stable Initial Selection On Reveal Review

- Updated `SwitcherWindowController` so each new reveal explicitly clears `hoveredIndex` and keeps hover selection suppressed until the user actually moves the mouse.
- Reused the existing mouse-move unlock path, which means the initial selection now remains on the first tab instead of briefly jumping to whatever tile sits under the resting cursor.
- Verified with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test`.

## 2026-04-23 - Trackpad Scroll And Stable Hover Selection

- [x] Stop the global hotkey tap from swallowing continuous trackpad scroll while the switcher is visible.
- [x] Suppress hover-based selection changes during scroll, and only re-enable them after a real mouse-move event.
- [x] Re-run the Swift test suite and update project notes.

## Trackpad Scroll And Stable Hover Selection Review

- Updated `HotkeyManager` so visible-switcher scroll-wheel events are no longer consumed at the CGEvent tap layer, allowing the panel scroll view to receive trackpad scrolling.
- Added explicit hover suppression in `SwitcherWindowController` and `SwitcherViewModel`, then gated `ClassicGridView` hover selection on that state so selection no longer drifts while content scrolls under a stationary pointer.
- Verified with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test`.

## 2026-04-23 - Cold-Start Thumbnail Prime

- [x] Reduce first-reveal skeleton flashes by priming a bounded set of real thumbnails synchronously on the empty-cache path.
- [x] Keep the asynchronous two-phase cache refresh for the full set of windows after the initial reveal.
- [x] Re-run the Swift test suite and update project notes.

## Cold-Start Thumbnail Prime Review

- Updated `AppSwitcher.primeCacheIfNeeded()` so the cold-start path first attempts to capture real previews for the first few visible windows instead of always seeding the cache with previewless placeholders.
- Kept the existing background warm-cache pass intact so the full switcher still refreshes asynchronously after the initial reveal.
- Verified with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test`.

## 2026-04-23 - Classic Grid Mouse Scroll And Hover Selection

- [x] Stop panel-level wheel handling from consuming mouse-scroll input so the classic-grid scroll view can move normally.
- [x] Make tile selection follow actual mouse movement over cards rather than passive hover residency while content scrolls underneath.
- [x] Re-run the Swift test suite and update project notes.

## Classic Grid Mouse Scroll And Hover Selection Review

- Updated `ClassicGridView` to use movement-driven hover tracking so the selected tile follows the mouse only when the pointer actually moves across cards.
- Updated `SwitcherWindowController` so wheel events are no longer swallowed at the panel layer, allowing the switcher page to scroll instead of treating the wheel as selection input.
- Verified with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test`.

## 2026-04-23 - Larger Classic Grid Labels

- [x] Increase the icon size in the classic-grid tile label row.
- [x] Increase the title text size and spacing so labels are easier to read in the switcher.
- [x] Re-run the Swift test suite and update project notes.

## Larger Classic Grid Labels Review

- Updated `ClassicGridView` so tiles with real previews now use a 24pt app icon, 15pt title text, and slightly looser spacing in the bottom label row.
- Left the previewless skeleton state untouched, so those tiles remain metadata-free.
- Verified with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test`.

## 2026-04-23 - Skeleton-Only Previewless Tiles

- [x] Remove app icon and text metadata from the previewless skeleton state in `ClassicGridView`.
- [x] Hide the standard title row beneath a tile when that tile is rendering the skeleton fallback.
- [x] Re-run the Swift test suite and update project notes.

## Skeleton-Only Previewless Tiles Review

- Updated `ClassicGridView` so previewless tiles now render as pure skeletons with no icon, no title/subtitle copy, and no bottom metadata row.
- Kept the existing thumbnail and label treatment for tiles that do have a real preview image.
- Verified with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test`.

## 2026-04-23 - Glass Letterbox And Skeleton Fallback

- [x] Replace the plain backing behind aspect-fit previews with a glass-like background that matches the switcher surface.
- [x] Remove the centered app-icon fallback card path so true no-preview tiles use the skeleton placeholder again.
- [x] Re-run the Swift test suite, rebuild the app, and update project notes.

## Glass Letterbox And Skeleton Fallback Review

- Updated `ClassicGridView` so the empty space around aspect-fit thumbnails now uses the same vibrancy-aware glass treatment as the rest of the switcher instead of a flat dark backing.
- Simplified the no-preview path so both windowless fallback entries and previewless windows now use the skeleton placeholder rather than a centered app icon card.
- Verified with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test` and `./build.sh`.

## 2026-04-23 - AltTab-Style Thumbnail Fit

- [x] Keep the classic-grid tile size fixed instead of reviving the dynamic-height aspect-ratio experiment.
- [x] Render preview images aspect-fit inside the fixed thumbnail frame so unusual window shapes remain visible.
- [x] Re-run the Swift test suite, rebuild the app, and update project notes.

## AltTab-Style Thumbnail Fit Review

- Updated `ClassicGridView` to keep the existing fixed tile geometry while switching preview rendering from crop/fill to aspect-fit.
- Added a subtle dark backing layer behind previews so pillarboxing/letterboxing reads intentional instead of looking like a missing render.
- Verified with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test` and `./build.sh`.

## 2026-04-23 - Aspect Ratio Experiment Revert

- [x] Revert the per-tile aspect-ratio-driven thumbnail sizing change in `ClassicGridView`.
- [x] Restore the previous fixed thumbnail frame and crop/fill rendering path.
- [x] Re-run the Swift test suite, rebuild the app, and update project notes.

## Aspect Ratio Experiment Revert Review

- Removed the dynamic thumbnail-height logic introduced for native aspect ratio preservation in `ClassicGridView`.
- Restored the previous fixed `layout.thumbnailHeight` framing and `aspectRatio(contentMode: .fill)` rendering path that was working better in the switcher.
- Verified with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test` and `./build.sh`.

## 2026-04-23 - Fallback Thumbnail Recovery

- [x] Keep the safer AX fallback activation path, but recover representative thumbnails for fallback app tiles from best-effort CG windows.
- [x] Reuse cached preview/backdrop assets for fallback tiles when the representative window stays stable.
- [x] Re-run the Swift test suite, rebuild the app, and update project notes.

## Fallback Thumbnail Recovery Review

- Extended `BuildContext` with the raw window snapshot and app lookup so fallback item assembly can choose a representative CG window candidate without changing activation semantics.
- Fallback app tiles now attempt the same preview capture pipeline as trusted window tiles, but only for display; activation remains `activateFallbackApplication`.
- Verified with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test` and `./build.sh`.

## 2026-04-23 - Previewless Tile Presentation

- [x] Replace the empty window skeleton treatment for fallback app tiles with an app-centric card so unresolved AX entries do not look broken.
- [x] Improve previewless window fallback cards so missing captures present clear app identity instead of a generic placeholder-only tile.
- [x] Re-run the Swift test suite, rebuild the app, and update project notes.

## Previewless Tile Presentation Review

- Updated `ClassicGridView` so `appFallback` items now render a centered app icon and title rather than reusing the generic window skeleton placeholder.
- Updated previewless window tiles to include the app icon, title, and an explicit `Preview unavailable` fallback treatment while keeping real preview rendering unchanged.
- Verified with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test` and `./build.sh`.

## 2026-04-23 - AX Allow-List Fallback Safety

- [x] Replace the ambiguous `nil` allow-list contract with an explicit policy that distinguishes unrestricted, restricted, and no-trusted-window cases.
- [x] Route apps with unresolved AX-backed window IDs to safe fallback app tiles instead of allowing unsafe per-window CG candidates.
- [x] Add regression coverage for the new policy behavior, rerun the Swift test suite, rebuild the app, and record the live runtime probe result.

## AX Allow-List Fallback Safety Review

- Added `AllowedWindowPolicy` in `AppSwitcher` so the window filter no longer conflates `no filter` with `AX failed to resolve any trusted window IDs`.
- Apps whose AX-backed display and preferred window IDs both fail now use `.noneTrusted`, which blocks unsafe window-level candidates and lets the existing fallback-app path represent the app once.
- Updated the targeted activation tests to lock in the new policy semantics, including the explicit `noneTrusted` rejection case.
- Verified with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test`, rebuilt with `./build.sh`, and confirmed the live policy probe reports `Arc -> restricted([134])` while `VS Code`, `Terminal`, and `Finder` now resolve to `noneTrusted`.

## 2026-04-23 - Switcher Duplicate Windows And Thumbnail Presentation

- [x] Reproduce the duplicate-window candidate pattern with regression tests that cover same-app overlapping surfaces with different CGWindowIDs.
- [x] Add a semantic candidate-pruning pass so near-identical same-app window surfaces collapse to the best real window candidate instead of producing duplicate tiles.
- [x] Tighten switcher thumbnail presentation so captured previews fill and clip correctly inside the card frame.
- [x] Verify the Swift package tests pass and update `README.md` plus review notes.

## Switcher Duplicate Windows And Thumbnail Review

- Added a second pruning pass in `AppSwitcher` that collapses overlapping same-app window-server surfaces even when they have different `CGWindowID`s, which prevents one real window from appearing twice in the switcher.
- Added regression coverage for both exact-ID deduplication and semantic same-app overlapping-surface pruning.
- Updated the classic grid thumbnail view so captured previews now fill and clip to the card frame instead of letterboxing inside the tile.
- Verified with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test` and rebuilt the packaged app with `./build.sh`.

## 2026-04-23 - Multi-Window Frontmost Resolution Fix

- [x] Reproduce the ambiguous multi-window same-app frontmost path in unit tests.
- [x] Update frontmost resolution so a multi-window frontmost PID falls back to the most recent visible same-PID window identity from history when exact resolution is unavailable.
- [x] Verify the Swift package tests pass and update `README.md` plus review notes.

## Multi-Window Frontmost Resolution Review

- Added a history-backed fallback in `FrontmostResolution` so multi-window frontmost apps no longer drop to `nil` when AX cannot resolve the exact focused window in time.
- Added regression coverage for both the resolver and the visible ordering path when multiple windows from the same app are present.
- Verified with `swift test --disable-sandbox --scratch-path /tmp/CmdTab-test` because plain SwiftPM sandboxing is blocked in this environment by nested `sandbox-exec`.
- Confirmed the “launch from terminal then it closes immediately” behavior is a separate singleton/accessory-app lifecycle path, not the MRU ordering bug.

## 2026-03-27 — Website Motion Pass

- [x] Add a lightweight motion primitive for section reveals without introducing a new animation library.
- [x] Add restrained hero movement and ambient linear drift to the key visuals.
- [x] Apply reveal/stagger motion across the main website sections with reduced-motion safety.
- [x] Verify the website still typechecks and builds, then update `README.md` and review notes.

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

- `swift test --scratch-path /tmp/CmdTab-test` passed with 38 tests.
- Follow-up fix anchored hidden `⌘Tab` timing to the event tap's original `CGEvent` timestamp instead of a later main-queue uptime sample.
- Manual hotkey QA on a live macOS desktop is still pending.
