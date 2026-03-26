# AltTabMac

Last Updated: 2026-03-25
Active Task: Reliability upgrade, settings improvements, Dock behavior changes, and agent context setup.

## Project Summary

AltTabMac is a custom macOS app switcher built with Swift, AppKit, and SwiftUI. It replaces the default switcher with a window-aware overlay, optional browser-tab switching, multiple visual styles, and a settings surface for controlling behavior.

## Current Status

- Agent context entrypoints exist in `AGENTS.md`, `CLAUDE.md`, and `CODEX.md`.
- All 5 critical bug fixes, 2 of 3 feature requests, and all 3 UI/UX refinements from the 2026-03-25 task have been applied (see Recent Changes Log).

## Active Constraints / Non-Negotiables

- Read this file before planning or coding.
- Update this file whenever task context, progress, decisions, or blockers change.
- Settings interactions must be safe and avoid crash-prone force unwraps.
- Browser tab limits must remain separate from app-window limits.
- Early modifier release before overlay reveal performs instant switch to next MRU window (quick-switch).

## Decisions Already Made

- Canonical shared context file: `README.md`
- Repo instruction entrypoints: `AGENTS.md`, `CLAUDE.md`, `CODEX.md`
- The current single `Primary Shortcut` control stays unless a true duplicate is found.
- Dock presence should be re-enabled and Dock clicks should open Settings.

## Open Issues / Next Steps

- Rebuild and manually validate after each change set.
- Feature 3 (Appearance Previews) was already implemented in the prior iteration — `StylePreviewCard` + `StyleMockPreview` exist in `PreferencesView.swift`.
- Settings Redundancy (Refinement 2): no true duplicate "Primary Shortcut" section exists in code; the "Shortcuts" card is a reference table only. No action taken per README constraint.
- Keep this file current whenever the active task or implementation status changes.

## Recent Changes Log

- 2026-03-26: Structural audit — 3 critical regressions (thumbnails, tab filter, latency):
  - Bug 1+3 (Thumbnails + Latency): Refactored monolithic `buildItems()` into two-phase cache build. Phase 1 enumerates windows and caches items with app icons only (instant UI). Phase 2 captures thumbnails via `CGWindowListCreateImage` on the background queue and updates the cache. Removed dead `PreparedWindowEntry` / `preparedWindowEntries`. Added `os_log` when Screen Recording permission is missing.
  - Bug 2 (Tab Filter): Added `browserBundleIDs` set to `AppSwitcher`. When `includeTabsInAppSwitcher` is false, `makeCandidate()` now drops windows belonging to Chrome, Safari, Arc, Edge, Firefox, Brave during enumeration. Browser apps still appear as fallback entries.
- 2026-03-26: Third bug-fix pass — 4 event-routing / performance bugs:
  - Bug 4 (Bleed-through): Added `keyUp` suppression for Tab (keycode 48) in CGEventTap so the WindowServer never sees orphaned Tab-up events during an active session.
  - Bug 2 (Double Escape): Added `keyDown(with:)` override in `SwitcherPanel` as backup Esc handler for when CGEventTap is momentarily disabled by system timeout.
  - Bug 1 (Quick Switch): Implemented fast-path in `handleModifierRelease` — early modifier release now calls `commitTriggerSession` for instant MRU[0] switch without showing UI.
  - Bug 3 (Ghost Window): Added 50ms post-show deferred hardware check in `scheduleReveal` to catch missed `flagsChanged` events when CGEventTap is disabled.
- 2026-03-25: Added the agent context system scaffold and seeded the current AltTabMac project status.
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
  - Feature 2 (Tab Limiter): `maxBrowserTabsShown` preference added; `TabSwitcher.buildItems` sorts by MRU then caps.
  - Refinement 1 (Vibrancy): Removed opacity caps from `VisualEffectBlur` in all three style views; reduced overlay gradient.
  - Refinement 3 (Crash Prevention): No WIP buttons found; all controls have real actions.

## Agent Update Protocol

1. Read `AGENTS.md`.
2. Read this file before planning or coding.
3. Treat this file as the current shared context unless the latest user prompt overrides it.
4. Update `Current Status`, `Decisions Already Made`, `Open Issues / Next Steps`, and `Recent Changes Log` whenever work changes them.
5. Prefer updating existing sections over appending duplicate notes.
