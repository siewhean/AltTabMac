# Todo

## 2026-07-17 — Switcher MRU, Completeness, And Activation Reliability

### Phase 1 — Contract And Regression Baseline

- [x] Create `agent/fix-switcher-mru-completeness` from `main`.
- [x] Add the implementation review, exhaustive test matrix, model checker, and model results to the repository.
- [x] Add focused regressions for preview-independent membership, strict global window MRU, and ambiguous frontmost resolution.
- [x] Define the protected acceptance invariants in code comments and test names before changing production behavior.

### Phase 2 — Complete And Stable Membership

- [x] Decouple switcher membership from preview-capture success so every eligible window remains visible as a placeholder when capture fails.
- [x] Calculate fallback suppression from emitted window items rather than raw candidates.
- [x] Keep fallback identities distinct by running PID rather than bundle identifier.
- [x] Default `Max windows per application` to unlimited for new installations.
- [x] Preserve existing explicit exclusions, title filters, visibility scopes, and user-configured caps.

### Phase 3 — Strict Global Window MRU

- [x] Remove PID-based initial-selection skipping so forward and reverse switching follow the displayed global window sequence exactly.
- [x] Resolve ambiguous multi-window frontmost PIDs from the immutable MRU history snapshot.
- [x] Reconcile the exact focused window at session start.
- [x] Track same-application focused-window changes through Accessibility notifications where permission is available.
- [x] Capture one history snapshot for each ordering operation instead of reading mutable history repeatedly from the sort comparator.

### Phase 4 — Activation Truth And Rapid Re-press Safety

- [x] Establish a short-lived provisional frontmost identity at commit time for deterministic immediate re-presses without prematurely changing permanent MRU.
- [x] Persist MRU only after the target app/window is verified as frontmost.
- [x] Treat retry exhaustion as activation failure rather than success.
- [x] Prefer focused/main standard windows for app-fallback activation instead of blindly raising the first AX window.

### Phase 5 — Automation, Repository Hygiene, And Release Evidence

- [x] Add a permanent macOS 14/15 GitHub Actions workflow for model, focused, and full Swift verification.
- [x] Ignore future Swift build, index, app-bundle, dSYM, and Finder metadata artifacts.
- [x] Run focused tests, then the complete SwiftPM suite on macOS.
- [x] Open draft PR #10 with explicit automated validation and remaining manual macOS QA.
- [x] Update `README.md`, this file, and `tasks/lessons.md` with the completed work and evidence.
- [ ] Execute and attach the P0 live desktop rows from the 136-case matrix before merge.

### Automated Review Evidence

- The assertion-based protected-core repair applied cleanly on macOS 15.7.7 arm64.
- `StrictMRUAndCompletenessRegressionTests`: 4 tests passed.
- Complete SwiftPM suite: 123 tests passed after aligning one contradictory legacy fallback expectation with the exact-window contract.
- PID-level fallback follow-up: complete SwiftPM suite passed again.
- `git diff --check` passed for both validated repair phases.
- The exact CSV matrix contains 136 unique rows with every required field populated; SHA-256 is `62d8d636648d2afc0e5d22d21f114b7aaaaf54403cead8705acf76691341432f`.
- Permanent macOS 14/15 CI is configured in `.github/workflows/swift.yml`.
- Live Accessibility, Screen Recording, Spaces, fullscreen, Stage Manager, multi-display, secure-input, sleep/wake, private-API focus, and packaged-app QA remain pending and are not represented as automated passes.
- Existing tracked historical `.build` artifacts remain outside this focused code diff; `.gitignore` prevents new generated output from being added accidentally.

### Acceptance Invariants

- Every eligible top-level application window produces one unique switcher item.
- A regular running process with no eligible window produces exactly one fallback item.
- Preview availability affects presentation only and never changes membership.
- Exact window identities form one global MRU sequence; windows are never grouped or skipped by PID or bundle.
- The current exact window remains in the list but is moved to the end for cycling.
- Forward selection uses the first ordered item; reverse selection uses the adjacent prior item.
- Permanent history changes only after verified activation.
- Explicit preferences are the only accepted source of intentional omission.

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
