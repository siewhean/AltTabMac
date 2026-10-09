# AltTab thumbnail audit

Scope: improve CmdTab window previews while preserving existing uncommitted work,
window membership, activation and recent-window ordering.

## Upstream source

Audited AltTab commit `f3e01d123c83de4a63b95b625dc4ab17cdc97a2d`:

- [Capture routing](https://github.com/lwouis/alt-tab-macos/blob/f3e01d123c83de4a63b95b625dc4ab17cdc97a2d/src/events/WindowCaptureEvents.swift)
- [Thumbnail refresh and sizing](https://github.com/lwouis/alt-tab-macos/blob/f3e01d123c83de4a63b95b625dc4ab17cdc97a2d/src/switcher/state/WindowThumbnails.swift)
- [Private capture definitions](https://github.com/lwouis/alt-tab-macos/blob/f3e01d123c83de4a63b95b625dc4ab17cdc97a2d/src/macos/api-wrappers/SkyLight.framework.swift)
- [License](https://github.com/lwouis/alt-tab-macos/blob/f3e01d123c83de4a63b95b625dc4ab17cdc97a2d/LICENCE.md)

AltTab is GPL-3.0. This change independently implements API usage and recovery
behavior in CmdTab; it does not vendor or copy upstream implementation source.

## Comparison

| Area | AltTab behavior | CmdTab finding before this change |
| --- | --- | --- |
| Older macOS capture | SkyLight hardware capture with ignoreGlobalClipShape, bestResolution and fullSize | Same options already implemented; copying them adds no capability |
| macOS 26 capture | ScreenCaptureKit screenshot for ordinary windows; sample buffer for fullscreen windows | Deferred ScreenCaptureKit recovery always used captureImage |
| Other Spaces | Enumerates shareable windows with onScreenWindowsOnly false | Already matches |
| Continuity | Keeps a previous successful image after a failed capture | Already present, but a cached image suppressed fresh recovery attempts for up to 600 seconds |
| Sizing | One scale preserves aspect ratio | Width and height independently capped at 1800 |
| Async work | Global cap of eight; five-second watchdog; per-window throttling | Per-identity deduplication only |
| Identity | Tracks windows individually | Recovery matched only window ID, without checking the owning process |

The upstream capture implementation, rather than its adjacent specification, is
the source of truth: current code routes only fullscreen windows through sample
buffers. It deliberately avoids a general screenshot-to-stream fallback because
repeated short-lived captures can create WindowServer resource pressure.

## Integration and review (2026-09-20)

Implemented independent recovery changes: process-owner validation, proportional
capture dimensions, a two-second successful-capture cooldown, newer continuity
frames taking precedence over stale metadata-key frames, and macOS 26 ordinary
screenshot versus fullscreen sample-buffer routing. Earlier systems retain the
existing captureImage recovery path. This is a deferred recovery integration;
CmdTab still attempts its existing synchronous capture before ScreenCaptureKit.

Independent QA caught caller interactions during verification: reused cache
images were indistinguishable from fresh captures, base items could schedule
recovery before fullscreen enrichment, and provisional refreshes could trigger
unnecessary recovery. Corrections carry fresh/reused provenance through base
assembly and enriched clones, avoid renewing reused capture timestamps, collect
fullscreen state in the existing AX scan, and disable recovery during provisional
phase-one assembly. The final independent review found zero unresolved P0/P1/P2
issues in this bounded delta.

Verification on macOS 26.6 with Xcode-beta:

- `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --scratch-path /tmp/CmdTab-alt-tab-qa`: exit 0, 308 XCTest tests plus 2 Swift Testing tests passed, including six preview-recovery regressions.
- Test log: `/tmp/CmdTab-thumbnail-tests-final-20260920.log`.
- `git diff --check`: exit 0.
- Existing deprecation warnings remain; this is not a warning-free build claim.
- Modern API declarations are compiler-gated; older SDK/runtime execution was not performed.
- Final package command: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer CMDTAB_OUTPUT_APP=/tmp/CmdTab-thumbnail-final-QA-20260920.app scripts/release/package-app.sh`.
- Final packaging exit 0, confirmed 2026-09-22: universal arm64/x86_64 bundle and ad-hoc signature verification passed. Log: `/tmp/CmdTab-thumbnail-package-final-20260920.log`; manifest and checksums are adjacent to the app. The earlier `/tmp/CmdTab-thumbnail-QA-20260920.app` predates caller corrections and must not be used for final acceptance.
- The running app was not replaced/relaunched. The final package is local QA only, not a signed/notarized release or live-thumbnail acceptance evidence.

Global asynchronous concurrency limits, enumeration coalescing, watchdogs and
autonomous retry scheduling are not included in this bounded patch. Current
retry timestamps permit a later refresh attempt; they do not schedule one.

## Live acceptance boundary

The supplied screenshot demonstrates missing and black previews, but does not
identify whether each tile is an actual window, a windowless application, or an
uncapturable surface. Windowless applications must retain icon fallbacks. Preview
availability must not decide whether an otherwise eligible window is listed.

The existing README records that the previous local ad-hoc rebuild needed renewed
Accessibility and Screen Recording authorization. That is historical evidence,
not confirmation of the current running app's permission state. Build and unit
tests cannot prove live capture permission, minimized/fullscreen behavior, or
thumbnail freshness across Spaces. Live acceptance must be reported separately.
