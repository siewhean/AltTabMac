# Native AppKit sharing-indicator geometry reproduction

This standalone fixture contains only `NSApplication`, a standard titled,
closable, miniaturizable, resizable `NSWindow`, and an `NSTextField`. It imports
no CmdTab implementation and uses no SwiftUI or private APIs. It is intentionally
outside the Swift package target graph.

## Run

Compile and run in a temporary directory using the configured macOS SDK:

```sh
mkdir -p /tmp/CmdTab-GeometryFixture.app/Contents/MacOS
cp Tests/Fixtures/AppKitSharingGeometry/Info.plist /tmp/CmdTab-GeometryFixture.app/Contents/Info.plist
xcrun swiftc Tests/Fixtures/AppKitSharingGeometry/main.swift \
  -o /tmp/CmdTab-GeometryFixture.app/Contents/MacOS/GeometryFixture
open -n /tmp/CmdTab-GeometryFixture.app
```

Capture/share the fixture window with a window-specific ScreenCaptureKit client.
Record the fixture PID and exact capture interval, then inspect its unified log:

```sh
/usr/bin/log show --last 5m --style compact \
  --predicate 'processIdentifier == REPLACE_WITH_PID AND eventMessage CONTAINS "Invalid view geometry"'
```

The placeholder must be replaced with the numeric process ID before running.
Merely launching the fixture is not the reproduction trigger.

## Observed result, 2026-09-25

The locally compiled fixture (PID 18696) produced three negative-width and three
negative-height AppKit runtime faults during window capture at 00:41:06 +0800,
matching CmdTab's capture-triggered fault. The fixture used AppKit 6.9,
build 2685.70.101. This independently reproduces the fault without CmdTab code.

A debugger inspection of CmdTab Settings showed
`NSWindowSharingSessionRecipientIndicator.intrinsicContentSize` returning
`(-1, -1)` (the unspecified intrinsic-size sentinel). AppKit's
`NSThemeFrame._positionSharingIndicator` passes that size directly to
`NSView.setFrameSize`, where validation reports the faults. Settings already had
a normal visible native titlebar. Temporary public-API probes adding a native
preference toolbar or making the window resizable still produced the same six
faults; neither probe was retained.

No supported application-level remedy has been demonstrated. Do not suppress the
logs, replace/swizzle the private sharing indicator, or disable capture to claim
a clean runtime gate. Keep the AppKit fault separate from CmdTab's switcher
membership, preview, permission, and placement acceptance results. This fixture
is a reproduction artifact, not a passing automated regression test.

## Feedback package

[APPLE_FEEDBACK_DRAFT.md](APPLE_FEEDBACK_DRAFT.md) is an unsubmitted Apple feedback
draft. The `evidence/` directory retains the narrow fixture fault log and
separately labelled CmdTab native stacks; it contains no desktop images.

## Fresh retest, 2026-09-25

Freshly compiled fixture PID 39758 launched at 00:58:59 +0800 and was captured
at 00:59:11. The same geometry-message predicate over 00:58:59–00:59:30
returned no geometry faults; see
[evidence/2026-09-25-fixture-retest.txt](evidence/2026-09-25-fixture-retest.txt).
This attempt did not reproduce the issue. It does not establish a fix: no
production remedy was applied, and additional capture/session conditions remain
unisolated. Other startup diagnostics were present, so this is not a claim that
the process logged no errors. The earlier six-fault reproduction remains valid.
