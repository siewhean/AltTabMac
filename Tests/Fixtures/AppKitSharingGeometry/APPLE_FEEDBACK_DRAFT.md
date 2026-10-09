# Apple Feedback draft — not submitted

**Title:** AppKit sharing indicator passes unspecified intrinsic size (-1, -1) to NSView.setFrameSize during native-window capture

**Area:** macOS / AppKit / Window sharing and ScreenCaptureKit

**Environment:** Apple Silicon; macOS 26.6 (25G70), as reported by `sw_vers` on the reproduction host; AppKit 6.9 (2685.70.101). Reproduction recorded 2026-09-25. Other macOS builds and Intel have not been tested.

## Summary

Capturing a standard AppKit window produces six AppKit runtime faults: three `Invalid view geometry: width is negative.` and three corresponding height faults. An independent fixture contains only NSApplication, an ordinary titled/closable/miniaturizable/resizable NSWindow, and an NSTextField. It imports no application implementation, SwiftUI, or private APIs.

## Steps to reproduce

1. Build and launch the supplied `main.swift` and `Info.plist` using the commands in [README.md](README.md).
2. Note the fixture process ID. Its window is titled **Native Geometry Fixture** and bundle identifier is `local.cmdtab.geometryfixture`.
3. Capture that window using a window-specific ScreenCaptureKit client. The observed trigger was the desktop automation client's `get_app_state` capture. Launching the fixture alone is not the trigger. A standalone capture-client reproduction is not included; equivalent behavior across other capture clients is not yet verified.
4. Read the fixture process's unified log over the capture interval, filtering for `Invalid view geometry` as described in the README.

## Expected result

A normal native window can be captured and its native sharing indicator laid out without negative-size runtime faults. An unspecified intrinsic-size sentinel should not be passed directly to `setFrameSize`.

## Actual result

The independent fixture, PID 18696, logged three width and three height faults at **2026-09-25 00:41:06.875–.876 +0800**. The retained log contains all six messages. The same fault occurs in CmdTab Settings despite a normal, visible native titlebar and explicit positive content dimensions.

A live debugger inspection of CmdTab's native titlebar identified its `NSWindowSharingSessionRecipientIndicator`. Immediately after `intrinsicContentSize` returned, arm64 registers `d0` and `d1` were both `-1`. Disassembly of `NSThemeFrame._positionSharingIndicator` showed a call to `intrinsicContentSize` followed by passing those two values directly to `setFrameSize`. These private symbols were inspected for diagnosis only; the application and fixture do not override or modify them.

The native stack includes:

```text
_NSViewValidateGeometry
NSViewValidateSize
-[NSView setFrameSize:]
-[NSThemeFrame _positionSharingIndicator]
-[NSWindowSharingSessionRecipientIndicator invalidateIntrinsicContentSize]
...
-[NSWindow _updateButtonsForWindowSharingSession]
-[NSWindow _setIsSelectivelyShared:]
_windowSelectiveSharingStateChangedNotification
```

## Isolation and attempted supported configurations

- The independent fixture reproduces the faults without CmdTab code or SwiftUI.
- The affected Settings window was confirmed live with styleMask 7: titled, closable, miniaturizable, and not full-size-content.
- Adding a native preference toolbar still produced three width and three height faults.
- Adding resizability still produced the same six faults.
- Both temporary probes were discarded. No private-method replacement, diagnostic suppression, or disabling of capture/privacy indicators was used.

## Fresh retest, 2026-09-25

The same retained fixture was freshly compiled and launched from
`/tmp/CmdTab-GeometryFeedback-Retest.app` as PID 39758 at 00:58:59 +0800.
The desktop automation client successfully captured it at 00:59:11. A bounded
unified-log query covering 00:58:59–00:59:30 with the same geometry-message
predicate found **no geometry faults**. The retained
[retest log](evidence/2026-09-25-fixture-retest.txt) therefore contains only the
log header. Other startup diagnostics were observed, so this is not an
error-free-process claim.

The fault did not reproduce in this attempt. No production remedy was applied;
this negative attempt does not establish resolution and indicates that the
trigger is intermittent or depends on additional capture/session state not
yet isolated. Preserve the earlier positive reproduction alongside this result.

## Impact and remaining uncertainty

The faults prevent an error-free runtime validation result. No crash or visible corruption is established by this reproduction. The evidence locates the failing native sizing operation; it does not establish why the sharing indicator lacks intrinsic dimensions or whether the capture client's configuration contributes. No supported application-level remedy has been demonstrated.

## Proposed attachments

- [main.swift](main.swift) and [Info.plist](Info.plist): minimal native-window fixture.
- [README.md](README.md): compilation, launch, and log instructions.
- [Fixture fault log](evidence/2026-09-25-fixture-faults.txt): exact six independent-fixture faults.
- [Symbolicated AppKit stacks](evidence/2026-09-25-appkit-stack.txt): earlier CmdTab process evidence; explicitly distinct from the fixture process.

Do not attach private desktop screenshots or unfiltered system logs. This is a prepared draft only; no Apple feedback has been submitted.
