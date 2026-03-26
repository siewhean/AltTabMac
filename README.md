# AltTabMac

Last Updated: 2026-03-27
Active Task: App-only switcher polish — instant reveal, cold-cache priming, and stale browser-tab metadata cleanup.

## Project Summary

AltTabMac is a custom macOS app switcher built with Swift, AppKit, and SwiftUI. It replaces the default switcher with a window-aware overlay, multiple visual styles, and a settings surface for controlling behavior.

## Current Status

- Agent context entrypoints exist in `AGENTS.md`, `CLAUDE.md`, and `CODEX.md`.
- All prior bug fixes and refinements remain in place.
- Browser tab feature fully removed (Phase 1 optimization).
- CGEvent.tap callback refactored to be fully non-blocking (Phase 2 latency fix).
- Both `⌘Tab` and `⌥Tab` now reveal the same app-window switcher immediately.
- First-use cache priming is synchronous for the fast icon phase so the overlay does not stall on an empty cache.

## Active Constraints / Non-Negotiables

- Read this file before planning or coding.
- Update this file whenever task context, progress, decisions, or blockers change.
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

## Open Issues / Next Steps

- Rebuild and manually validate after each change set.
- Feature 3 (Appearance Previews) was already implemented — `StylePreviewCard` + `StyleMockPreview` exist in `PreferencesView.swift`.
- Keep this file current whenever the active task or implementation status changes.

## Recent Changes Log

- 2026-03-27: Removed the fixed hold-to-show delay from the hotkey path and kept the switcher app-only.
  - `HotkeyTriggerPolicy` reveal delay is now zero for both `⌘Tab` and `⌥Tab`.
  - `scheduleReveal` now executes immediately when the deadline is already due.
  - `SwitcherWindowController` primes the fast icon cache before first reveal and no longer spins on a retry loop waiting for items.
  - Dock reopen now opens the live switcher instead of the settings window.
  - Removed stale browser-tab Apple Events metadata from `Resources/Info.plist`, `Resources/AltTabMac.entitlements`, and `build.sh`.
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
  - Refinement 1 (Vibrancy): Removed opacity caps from `VisualEffectBlur` in all three style views; reduced overlay gradient.
  - Refinement 3 (Crash Prevention): No WIP buttons found; all controls have real actions.

## Agent Update Protocol

1. Read `AGENTS.md`.
2. Read this file before planning or coding.
3. Treat this file as the current shared context unless the latest user prompt overrides it.
4. Update `Current Status`, `Decisions Already Made`, `Open Issues / Next Steps`, and `Recent Changes Log` whenever work changes them.
5. Prefer updating existing sections over appending duplicate notes.
