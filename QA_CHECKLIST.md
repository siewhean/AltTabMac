# CmdTab Manual QA Checklist

## Switching reliability

- Quick press and release `Cmd+Tab` twice between two apps. Expected: it alternates on every invocation, not only the first one.
- Hold `Cmd` and press `Tab` repeatedly. Expected: each key press advances exactly one item and release activates the highlighted item.
- Hold `Cmd+Shift` and press `Tab`. Expected: the initial highlight starts on the previous item in reverse order, and additional presses continue backward.
- Open the switcher, use arrow keys to change selection, then press `Return`. Expected: the highlighted item activates and the overlay closes.

## Ordering and window identity

- Arrange recent usage across multiple Finder and Arc windows. Expected: every real window is a distinct tile in strict window-level MRU order, with the current frontmost window moved to the cycle end.
- Open four or more windows from the same app alongside other apps. Expected: all trusted windows remain present and interleaved by recency; no per-app cap or grouped app tile appears.
- Toggle "Include background and minimized windows" on and off. Expected: minimized/background windows appear only when enabled, while visible-window ordering remains stable.

## Visual polish

- Compare selected and unselected cards in single-row and multi-row layouts. Expected: the selected card has a noticeably thicker blue border and a stronger blue glow.
- Open apps with wide, tall, and small previews. Expected: previews sit inside a clean framed stage with consistent padding and do not look cropped or cluttered.
- Invoke the switcher repeatedly after previews are warm. Expected: cached thumbnails appear immediately while refresh happens silently, without a skeleton flash.
- Deny Screen Recording or select an uncapturable window. Expected: the preview area uses a skeleton fallback while the app icon and application name remain visible in the label row, and Settings reports the permission problem.

## Licensing and privacy

- Attempt to unlock using only a fabricated cached payload. Expected: the app remains unregistered because no valid signed token exists.
- Activate a valid signed license, restart, and switch offline. Expected: the verified cached token unlocks without a network request.
- In a release build, inspect Settings and the binary. Expected: no Developer pane or simulated licensing controls are present.
- Leave diagnostics disabled and use the app. Expected: no activation or heartbeat requests are emitted; enabling diagnostics starts only the disclosed events.

## Distribution and permissions

- Download `CmdTab-1.0.0-universal.dmg` through a browser on clean Apple Silicon and Intel macOS 13+ machines. Expected: Gatekeeper accepts the stapled DMG and app, drag-install works, and diagnostics report the native architecture.
- Exercise first launch with Accessibility and Screen Recording granted, denied, revoked, and re-granted. Expected: onboarding appears once and opens only the first missing System Settings pane, no automatic permission-request loop occurs, denial is recoverable from Settings, and uncapturable items remain skeleton-only.
- Rebuild twice with the same Apple Development identity and relaunch. Expected: the designated requirement remains stable and existing Accessibility/Screen Recording grants remain valid.
- Remove the legacy `com.user.CmdTab` entry once from System Settings > General > Login Items after upgrading to bundle ID `net.cmdtab.app`; do not reset unrelated background-item approvals.
- Verify launch at login, Secure Input interference/recovery, fullscreen apps, multiple Spaces, and single/multiple displays. Expected: no stuck overlay, lost shortcut, wrong display, or duplicate window.
- Complete trial start, signed license activation, offline restart, recovery/help, telemetry opt-out, and uninstall/reinstall. Expected: licensing remains signature-backed and opt-out emits no telemetry.

## Performance and cycle integrity

- Build the packaged app, choose a new local JSONL path, set `CMDTAB_RUNTIME_QA_OUTPUT` with `launchctl setenv`, then relaunch CmdTab. Evidence recording is completely disabled unless this variable is explicitly present. The file is mode `0600` and contains only timing, counts, directions, booleans, and random session/operation IDs; it never contains titles, PIDs, window IDs, bundle IDs, or images.
- Use a physical keyboard for the release run. Synthetic `CGEvent`, AppleScript keystrokes, Dock/app reopens, and endpoint-only screenshots are not accepted as evidence for the global shortcut path.
- Record 100 warm invocations after previews are populated. Required: post-deadline reveal p95 at most 50 ms, maximum at most 100 ms, and at least one cached preview in the first AppKit-committed frame for 100/100 invocations. Total hardware-event-to-frame latency is reported separately and includes the intentional 100 ms Command hold threshold.
- For each of 20 cold invocations, quit CmdTab, set `CMDTAB_RUNTIME_QA_COLD_START=1`, relaunch, invoke once, and commit the selected window. This safely gates the deterministic in-memory reset and suppresses launch warming only while runtime QA output is enabled. Required: hardware-event-to-first-populated-frame p95 at most 250 ms.
- While recording, run 100 completed switch sessions with at least two windows from one application visible. Required: every activation is confirmed against the exact window, every recorded panel has zero duplicate identities, and all sessions finish successfully.
- In one held switcher session, perform at least 200 forward and 200 reverse Tab steps before committing. Required: every step reaches its exact expected wrapped index, event-tap callback p95 is at most 5 ms, no callback reaches 20 ms, and the event tap is never disabled.
- Validate the evidence with `./scripts/validate_runtime_qa.sh /absolute/path/runtime-qa.jsonl`. Default thresholds enforce all counts and limits above. Clear both launch variables afterward with `launchctl unsetenv CMDTAB_RUNTIME_QA_OUTPUT` and `launchctl unsetenv CMDTAB_RUNTIME_QA_COLD_START`.
- Treat `firstFrameCommitted` as the first AppKit backing-store commit observed after ordering the panel, not proof of physical display scanout. Final release QA still requires an operator-observed clean-Mac pass on the notarized artifact.
