# Switcher reliability A/B test plan (2026-11-08)

Branch under test (B): `claude/project-thread-g09ima`. Baseline (A): `main` at `578e4db`.

This plan covers the four reported problems and the extra glitches found in the same review:

| # | Symptom | Root cause | Fix |
|---|---------|------------|-----|
| 1 | The first tile is not the app used most recently | An activation whose focused window was not resolved in about 120 ms (busy app, 0.25 s AX timeout, window still opening) was recorded at app level only, and app-level entries never ranked that app's windows. A, then B (app level), then C made Command-Tab return to A. | App-level entries rank one representative window of that app (`SwitcherOrdering.effectiveRanks`); focused-window lookup retries 6 times (about 0.6 s) instead of 3. |
| 2 | The switcher sometimes takes a while to appear | Up to five synchronous AX frontmost walks on the main thread per open; a SwiftUI root rebuild on every open; finished enrichment results thrown away whenever a newer pass had been scheduled (starvation under steady publications); the profile inventory discarded on every profile change; AX observer registration retried for every unsupported app on every activation. | Frontmost resolved once per presentation; roots rebuilt only on style change; finished passes publish unless explicitly invalidated; per-profile inventory cache (60 s); registration retry backoff (5 s). |
| 3 | High CPU | Every app activation forced a full rebuild that recaptured every window at full resolution, rasterized each full capture to RGBA for trimming, walked every app twice through AX, recaptured minimized windows, and rewrote the durable history JSON. | Activation bursts coalesce into one rebuild after 0.25 s that reuses captures younger than 20 s; trimming rasterizes only the border strips; the AX catalogue is reused for preview-only publications; minimized-window captures are reused for 60 s; durable history is rewritten only on change or every 5 minutes. |
| 4 | Alt-Tab sometimes does not bring the app on screen | A window of a hidden (Command-H) app was focused without unhiding the app; a minimized window on the base (CG-listed) path was raised without being restored. | `unhide()` before the exact focus; restore `AXMinimized` before raising. |
| 5 | Tiles jump while the switcher is open | Later publications (capture pass, enrichment) re-sorted the open session, so a late window could be inserted ahead of the selection. | Open sessions keep their order, drop closed windows and append new ones (`stableSessionOrder`). |
| 6 | Switcher opens on the wrong display with a display above or below the main one | The active-window screen compared CG window bounds with AppKit screen frames. | Convert to AppKit before matching (`DisplayGeometry.screenIndex`). |

## Automated coverage

`Tests/CmdTabTests/SwitcherReliabilityRegressionTests.swift` (CI on macOS 14 and 15):

- MRU: A → B (app level) → C offers B first; one representative window per app; an older app-level entry never demotes a newer exact window; bundle-only entries match case-insensitively; other processes are ignored; the same scenario through `SwitcherHistoryStore`.
- Session stability: visible order kept, closed windows dropped, new windows appended before the current window, current window last on first publication.
- CPU: capture reuse age rules (zero, inside, outside, clock moved backwards); asymmetric transparent-border trim with opaque corners; opaque images untouched.
- Enrichment: publication gate (epoch and profile), catalogue reuse only for unchanged membership, a finished pass publishes even when a newer one is queued (async), inventory cache freshness, profile isolation and bounds, synthetic preview cache ages, frame and minimized-state invalidation.
- Multi-display: windows on the main display, a display above (negative CG y) and below, and off-screen.
- Observation: retries outlast one AX timeout but finish within a second; registration backoff.
- Durable history: no rewrite for a lastSeen-only reconcile, periodic save after 5 minutes.

The full existing suite must still pass (protected behavior: hotkey routing, exact-window MRU, frontmost resolution, activation confirmation, focused-window observation, membership, quick actions).

## Manual A/B procedure

Run every case on build A, then on build B, on the same Mac and the same window set. Record PASS, FAIL, BLOCKED (with the reason) or NOT_RUN. Never record a result that was not observed.

Setup: Accessibility and Screen Recording granted; at least Safari (3 windows), Finder (2 windows), Notes, TextEdit, Terminal, Xcode or another heavy app; one window minimized; one app hidden with Command-H; two Spaces; a second display if available. Note the macOS version and Mac model.

### MRU order

| ID | Steps | Expected (B) |
|----|-------|--------------|
| MRU-1 | Click Safari, then Notes, then Terminal. Command-Tab once and release. | Notes comes forward. |
| MRU-2 | Launch a heavy app (Xcode, a large Electron app) and immediately click into it while it is still loading; then click TextEdit. Command-Tab. | The heavy app comes forward, not the app used before it. |
| MRU-3 | Use Safari window 1, then Safari window 2, then Finder. Command-Tab. | Safari window 2 (the most recent Safari window), not window 1. |
| MRU-4 | Repeat Command-Tab quickly 10 times. | Toggles between the same two windows every time. |
| MRU-5 | Use the Dock to activate an app (no click on a window), then Command-Tab from another app. | That app's most recent window is first. |
| MRU-6 | Quit and relaunch CmdTab; Command-Tab. | Order restored from durable history; the app last used before quitting is first. |
| MRU-7 | Hold Command, Tab through to the third tile, release. Then Command-Tab once. | Returns to the window you came from. |
| MRU-8 | Open a new window in Safari (Command-N), then switch to Notes and Command-Tab. | The new Safari window is first. |

### Panel latency

| ID | Steps | Expected (B) |
|----|-------|--------------|
| LAT-1 | With 20+ windows open, press Command-Tab and hold. Time from key press to panel (screen recording at 60 fps, count frames). | Panel within the same frames budget as A or faster; never a visible pause. |
| LAT-2 | Click into a different app and press Command-Tab within 0.2 s. | Panel appears without delay. |
| LAT-3 | Switch between two shortcut profiles alternately 10 times. | The second and later opens of each profile appear immediately with the full list. |
| LAT-4 | Make an app unresponsive (for example `kill -STOP <pid>` on a test app), then switch between other apps and press Command-Tab. Resume it afterwards with `kill -CONT <pid>`. | Panel still appears promptly. |
| LAT-5 | Open the Command Palette and type 10 characters quickly. | Each keystroke filters without lag. |
| LAT-6 | Change the switcher style in Settings, then open the switcher. | New style shows correctly (style change still rebuilds the view). |

### CPU and energy

| ID | Steps | Expected (B) |
|----|-------|--------------|
| CPU-1 | Idle 5 minutes with CmdTab running. Activity Monitor: CPU % and Energy Impact. | Near zero; not above A. |
| CPU-2 | Click between 5 apps once per second for 60 s. Record average CPU (`top -pid <pid> -l 60 -s 1`). | Clearly below A. |
| CPU-3 | Same as CPU-2 with 3 minimized windows and "Include minimized windows" on. | Below A. |
| CPU-4 | Open and close the switcher 30 times in 60 s. | Not above A; previews still current. |
| CPU-5 | Watch the modification time of `~/Library/Application Support/CmdTab/window-history-v1.json` while switching apps for 2 minutes without opening the switcher. | B: file written only on switcher activations or every 5 minutes, not on every app switch. |

### Activation reaches the screen

| ID | Steps | Expected (B) |
|----|-------|--------------|
| ACT-1 | Hide TextEdit with Command-H. Command-Tab to a TextEdit window. | TextEdit unhides and the chosen window is in front. |
| ACT-2 | Minimize a Notes window; enable "Include minimized windows". Select it in the switcher. | The window un-minimizes and is in front. |
| ACT-3 | Window on another Space: select it. | macOS switches to that Space and the window is in front. |
| ACT-4 | Full-screen app window: select it. | Its full-screen Space comes forward. |
| ACT-5 | Select a window on the second display. | Window focused on that display; keyboard input goes to it. |
| ACT-6 | Quit an app while the switcher is open (Q quick action), then select another tile. | The other window comes forward; no stale tile is activated. |
| ACT-7 | Select a window while its app is launching or beachballing. | The window comes forward once the app responds; no wrong app activated. |

### Session stability and display placement

| ID | Steps | Expected (B) |
|----|-------|--------------|
| SES-1 | With minimized windows included, hold Command-Tab right after a cold launch and watch the tiles for 2 s. | Tiles do not reorder under the selection; late windows appear at the end. |
| SES-2 | While holding the switcher, close a window in the background (for example a timed AppleScript). | That tile disappears; the selection stays on the same window. |
| DSP-1 | Arrange a second display above the main one (Displays settings). Focus a window on it and press Command-Tab with placement "Active window display". | The switcher opens on the upper display. |
| DSP-2 | Same with the second display below and to the left. | Opens on the display that holds the active window. |

### Regression sweep (protected behavior)

| ID | Steps | Expected |
|----|-------|----------|
| REG-1 | Command-Shift-Tab reverses selection. | Unchanged from A. |
| REG-2 | Quick actions H, M, W, Q in the switcher. | Unchanged from A. |
| REG-3 | Escape cancels without activation. | Unchanged from A. |
| REG-4 | Mouse click on a tile activates it. | Unchanged from A. |
| REG-5 | Per-profile app filter: excluded apps never appear, even briefly after switching profiles. | Unchanged from A. |
| REG-6 | Quick tap of Command-Tab (under 0.1 s). | Switches to the previous window as in A. |

## Results

| Case | A (`main`) | B (branch) | Notes |
|------|-----------|------------|-------|
| All manual cases | NOT_RUN | NOT_RUN | Needs a Mac with the signed build; this cloud environment cannot run macOS apps. |
| Automated suite | n/a | Pending macOS CI | See the pull request checks. |
