# Switcher presentation audit — 2026-09-14

Scope: positioning, missing thumbnails, and missing applications. Audit only; no implementation, preference changes, rebuild, or app restart.

## Live evidence

- Dirty source HEAD: `3408c9c`. Running PID 8489 uses repository `CmdTab.app`, started September 11; executable modification time September 11 06:34. Current source is not proven identical to that binary.
- One built-in display: frame 1496×967, visible frame 1496×938.
- Both saved profiles: classic grid, all applications, all Spaces, active-window display, minimized windows excluded; global app exclusions empty.
- Read-only AppKit probe found 17 regular applications. This is not a measurement of published switcher membership.
- Initial follow-up supplied six screenshots showing open windows for Telegram, Claude, Reminders, GitHub Desktop, Canva, and Antigravity. These are examples, not an exhaustive affected-app list. The screenshots show the applications and macOS Dock, not an open CmdTab overlay; actual switcher geometry and tile membership remain unverified.

## Findings

1. **Reproduced thumbnail-validation defect.** `AppSwitcher.swift:1600–1655` interprets alpha/color memory offsets from alphaInfo without byte order. Exact source validator methods run against equivalent opaque red CGContext images rejected little-endian premultiplied-first BGRA and accepted big-endian ARGB. ScreenCaptureKit recovery shares this validator (`ReliableWindowPreviewRecovery.swift:185`). This can discard valid captures; attribution to the running app's missing thumbnails remains unproven.
2. **Conditional application disappearance.** `AppSwitcher.swift:1298–1308` approves focused/main window IDs even when previously rejected as minimized. If CG emits that window, the base item suppresses the app fallback. Production enrichment subsequently rejects minimized metadata (`ProductionAppSwitcher.swift:494–498,658–660`) without rebuilding the fallback. The live minimized-exclusion setting matches this condition, but the missing app's AX/CG state has not been reproduced.
3. **Window suppression race.** `ProductionAppSwitcher.swift:518–531,618–631` treats an unmatched CG ID as absent when AX enumerated other resolved windows. Its catalog can be 350 ms old (`741–750`), allowing newly created legitimate windows to be suppressed. This is a source-level race, not a captured live event.
4. **Overflow can look like missing membership.** `ProductionSwitcherVisuals.swift:176` hides scroll indicators. Executing the actual layout function with 17 items and the live visible frame produced four columns, 318×226 cards, and a 1344×769.16 panel. Five rows exceed that viewport. This explains why all entries need not be visible simultaneously; actual switcher item count is unknown.
5. **Separate multi-display positioning defects.** `ProductionSwitcherWindowController.swift:899–906` compares raw CG bounds with AppKit screen coordinates; mirrored panels also reuse primary layout dimensions (`944–947`). These can select the wrong display or overflow smaller monitors, but do not explain the currently observed single-display topology. Single-display centering appears correct in source.

## Verification and limitations

- Specialized positioning, preview, and membership audits completed; independent QA confirmed the thumbnail and conditional minimized-app mechanisms without claiming live reproduction.
- Swift image-validator reproduction and actual layout-function probe exited successfully. AppKit display/application probe exited successfully.
- A 20-minute CmdTab error/fault unified-log query returned no entries. Capture errors are discarded in ScreenCaptureKit callbacks, so this does not prove successful captures.
- The probe's Screen Recording preflight returned true; this is not proof of CmdTab's own permission state.
- Preference inspection initially encountered Python plist parsing errors (non-seekable stream, then a year-zero date); targeted XML extraction succeeded. No remaining diagnostic-command failure is being presented as an app fault.
- No SwiftPM build/test suite or simulator run: no implementation was performed. No visual or full-runtime acceptance claim.

## Comprehensive remediation acceptance criteria (not implemented)

- Fix shared discovery, reconciliation, capture validation, and presentation paths; do not add app-name or bundle-ID exceptions for the six examples.
- For the reported all-applications/all-Spaces configuration, reconcile every eligible regular running PID against the final production snapshot. Each must have eligible exact-window entries or one application fallback when no eligible window remains. Keep multiple eligible windows distinct; remove redundant fallbacks only after final membership is known.
- Preserve explicit application exclusions and profile/Space restrictions. A fallback must not bypass a deliberately restrictive profile. Background agents, accessory apps, and CmdTab itself remain outside the existing eligibility contract.
- Preview denial, blank/unsupported captures, and failed recovery must never remove eligible membership. Validate byte orders and alpha formats consistently; retain only correctly identified cached frames, otherwise use an app icon.
- Do not infer that a CG window is nonexistent solely because a stale or incomplete AX snapshot omits it. Distinguish positive exclusion evidence from unknown metadata.
- Cover native and Electron apps, multiple windows per app, newly opened/closed windows, hidden applications, minimized windows with inclusion on/off, off-Space windows, and unavailable Accessibility/Screen Recording permissions. Include all six reported apps in packaged-app checks and compare the complete eligible running-app inventory, not just those examples.
- Verify every published item is reachable by keyboard and scrolling, overflow is discoverable, and panel geometry remains within each target display. Obtain a full-desktop switcher screenshot to diagnose absolute screen position.
- Run focused regressions and the complete Swift package suite for protected membership-path changes, then verify the actual rebuilt package and final production diagnostics. Base-snapshot counts alone cannot prove that enrichment retained all apps.

The screenshots establish that the reported apps can have visible windows; the conditional minimized-window defect alone is therefore insufficient to explain the whole report. Text displayed inside the screenshots is contextual evidence, not implementation instructions or independently verified technical claims.

## Follow-up: switcher screenshot and activation-dependent discovery

The 16:02:10 screenshot shows CmdTab with previews for Antigravity, Canva, GitHub Desktop, Reminders, Claude, and other apps. Spotify and Finder have icon-only cards; another row is partially visible at the bottom. An icon-only card does not establish whether it is a process fallback or an exact window with unavailable capture. The image shows the panel without enough surrounding desktop to measure its screen position; partial bottom rows establish viewport overflow, not offscreen panel placement.

The user reports that missing apps appear only after opening/activating their windows. This is a required regression scenario for all eligible applications: open CmdTab before manually visiting any app and verify complete final membership. Activation may change MRU order and improve preview availability, but must not be a prerequisite for membership. A running app with no eligible window must remain reachable through the appropriate app fallback under the all-Spaces profile; no new window should be created merely to populate the switcher.

Source evidence: `AppSwitcher.configure` already requests startup enumeration; `getItems` requests refresh when stale. `appActivated` additionally forces a refresh (`AppSwitcher.swift:86–97`). Activation therefore provides a plausible recovery trigger, not proof that enumeration is intentionally limited to visited apps. Incomplete discovery/reconciliation or stale cached results remain suspects; distinguish these using before/after final snapshots. The earlier pixel-format reproduction remains a separate capture defect, not a proven cause of activation-dependent membership.

Next diagnostic evidence needed: final membership/preview diagnostics before and after visiting an affected app, bound to the running package, and a full-desktop view if absolute panel position remains a concern. No fix was applied; the original audit-only constraint remains in effect.
