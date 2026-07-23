# PR #35 packaged-app feedback regression contract

This document turns observed tester feedback into explicit acceptance criteria. It does not itself constitute a PASS; every row must be exercised against the exact packaged artifact produced by the current candidate.

## Shortcut timing and quick switching

- A deliberate Command-Tab or Option-Tab chord must be accepted when the primary modifier and Tab key-down arrive within 160 ms.
- Holding Command or Option first and pressing Tab later must be swallowed without switching and without allowing Apple’s native switcher to appear.
- The Hot Swap Command-plus-Option chord modes use the same 160 ms maximum separation. The configured double-tap modes remain intentional double taps.
- A quick accepted chord released before 200 ms must commit without showing or flashing the CmdTab overlay.
- Holding the primary modifier for 200 ms reveals the overlay; subsequent Tab presses cycle while it is visible.
- Shift-Command-Tab and Shift-Option-Tab are the reverse shortcuts. Arrow keys remain available while the overlay is visible.
- A stale/provisional item order must never make a quick trigger commit the already-focused exact window when another item exists.

## Minimized-window control

- Clicking the CmdTab menu-bar item opens the quick-control menu.
- **Show Minimized Windows** is visible in that menu. Checked means minimized windows are included; clicking it again disables inclusion.
- A minimized top-level window exposed as `AXDialog` on macOS 26.6 is eligible only while minimized and only when inclusion is enabled. Non-minimized dialogs remain excluded.

## Thumbnail continuity

- A transient capture failure for the same exact preview key may reuse its last known good in-memory thumbnail for up to 120 seconds.
- Another window or a changed preview key must never inherit that image.
- The continuity cache is bounded, is never persisted, and is cleared for the affected key when Screen Recording access is unavailable.
- Arc and Telegram should therefore remain visually stable through intermittent GPU/private-capture misses while permission is still granted.

## Required evidence

- Record a screen observation for quick release, held reveal, delayed chord rejection, reverse cycling, and native-switcher isolation.
- Record the before/after focused `CGWindowID` for a valid quick switch and the minimized A2 restoration row.
- Confirm the menu checkmark can enable and disable minimized inclusion.
- Repeatedly open the switcher with Arc and Telegram for at least two minutes and record whether either stable exact window falls back to an icon after previously showing a valid thumbnail.
- Revoke Screen Recording and confirm cached window content is not displayed; a safe placeholder remains.
