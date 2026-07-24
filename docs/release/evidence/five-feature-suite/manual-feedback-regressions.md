# PR #35 packaged-app feedback regression contract

This document turns observed tester feedback into explicit acceptance criteria. It does not itself constitute a PASS; every row must be exercised against the exact packaged artifact produced by the current candidate.

## Shortcut timing and quick switching

- A deliberate Command-Tab or Option-Tab chord must be accepted when the primary modifier and Tab key-down arrive within 160 ms.
- Holding Command or Option first and pressing Tab later must be swallowed without switching and without allowing Apple’s native switcher to appear.
- Optional Hot Swap accepts either a same-side Command double tap completed within 250 ms or a side-matched Command-plus-Option chord with no more than 160 ms between the two modifier key-downs.
- A single Command press and a single Option press must do nothing. Two Command taps whose release-to-release gap exceeds 250 ms must do nothing, including the reported sequence with a delay of several seconds.
- A quick accepted Command-Tab or Option-Tab chord released before 200 ms must commit without showing or flashing the CmdTab overlay.
- Holding the primary modifier for 200 ms reveals the overlay; subsequent Tab presses cycle while it is visible.
- Shift-Command-Tab and Shift-Option-Tab are the reverse shortcuts. Arrow keys remain available while the overlay is visible.
- A stale/provisional item order must never make a quick trigger commit the already-focused exact window when another item exists.
- After any successful switch, Command-V must paste into the selected application and must not switch back to the previous window.
- Any unrelated key-down while Command or Option is held disarms a stale release owner before that key is passed through. Releasing the modifier afterward must not complete an old CmdTab session.
- Command and Shift-Command character commands other than Tab are application commands, not global profile triggers. CmdTab must pass them through even if an old profile document attempted to assign one.

## Minimized-window control

- Clicking the CmdTab menu-bar item opens the quick-control menu.
- **Show Minimized Windows** is visible in that menu. Checked means minimized windows are included; clicking it again disables inclusion.
- A minimized top-level window exposed as `AXDialog` on macOS 26.6 is eligible only while minimized and only when inclusion is enabled. Non-minimized dialogs remain excluded.

## Thumbnail continuity and recovery

- A transient capture failure for the same exact preview key may reuse its last known good in-memory thumbnail for up to 120 seconds.
- When only the window title or frame changes, the same `(PID, CGWindowID, process launch generation)` may reuse its last known good image for up to 600 seconds.
- A different exact window or a restarted process must never inherit that image.
- One transient false Screen Recording preflight must not erase a valid thumbnail. A sustained denial is confirmed before cached protected content is cleared.
- When both SkyLight and Core Graphics fail, CmdTab schedules an asynchronous ScreenCaptureKit capture for the exact window and refreshes the visible switcher when recovery succeeds.
- Recovery requests are deduplicated and rate-limited, the continuity cache is bounded, and no thumbnail is ever persisted to disk.
- Arc and Telegram should therefore remain visually stable through intermittent GPU/private-capture misses while permission is still granted.

## Required evidence

- Record a screen observation for quick release, held reveal, delayed chord rejection, reverse cycling, and native-switcher isolation.
- Select Left or Right Command Double Tap. Two short taps completed within 250 ms must Hot Swap; a single tap, a gap just above 250 ms, and a delay of two seconds or more must not switch.
- Enable Left Command + Left Option Hot Swap. Option alone and Command alone must do nothing. The pair may activate only when both same-side keys arrive inside the 160 ms chord window. Repeat for the right-side pair.
- Record the before/after focused `CGWindowID` for a valid quick switch and the minimized A2 restoration row.
- Immediately after a successful quick switch, use Command-V in a text field. Record that paste succeeds, the focused PID and `CGWindowID` remain unchanged, and no overlay appears.
- Repeat the pass-through check with at least Command-C and Command-Z; neither may create or commit a switcher session.
- Confirm the menu checkmark can enable and disable minimized inclusion.
- Repeatedly open the switcher with Arc and Telegram for at least ten minutes and record whether either stable exact window falls back to an icon after previously showing a valid thumbnail.
- Revoke Screen Recording, wait longer than the denial confirmation interval, and confirm cached window content is not displayed; a safe placeholder remains.
