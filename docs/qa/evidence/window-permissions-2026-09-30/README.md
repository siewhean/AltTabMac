# Claude/Finder windows and floating permission setup — 2026-09-30

Local dirty-working-tree evidence; not release certification.

- Base SHA: `3408c9c24e283e94583e303b2b04d5476775300f`.
- Branch: `codex/fix-intermittent-cmdtab-interception`; no task commit created.
- Unrelated pre-existing edits and earlier hotkey fixes preserved.
- Environment: macOS 27.2, Xcode-beta, actual Apple Silicon Mac.
- Package: universal arm64/x86_64, local-QA ad-hoc signing.
- Running path: `dist/interception-fix/CmdTab.app`; PID 35997 at validation.
- Executable SHA-256:
  `880b0a27242b50ff74da27498f25ebd6f5e92254261404fdaa780a57bf503c45`.
- Previous app retained at `dist/interception-fix-rollback/CmdTab.app`.
- Separately packaged identical candidate: `dist/window-permission-fix/CmdTab.app`.

## Root causes and changes

Finder's AX window list contains an `AXScrollArea` desktop element with no exact
window ID. Counting it as an unresolved window prevented helper rejection.
Explicit non-window roles now bypass window identity resolution; unreadable roles
and unresolved real windows retain the existing conservative safeguards.

Trusted live source-pipeline inspection before the change published Finder's
unnamed offscreen ghost `6589` alongside real windows `58` and `7193`. After the
change, `6589` disappeared and the real windows remained with previews.
Finder windows `649` (GitHub) and `3225` (Claude) are genuine minimized folder
windows, not duplicate Claude/GitHub applications. Claude helpers `5968` and `5974`
are unnamed offscreen CG surfaces; fresh complete AX inspection excludes them.

Production's synthesis of Accessibility-only/minimized windows previously skipped
the immediate SkyLight/Core Graphics capture used by the base inventory. That
path now performs the same validated capture on the background enrichment queue,
checking exact owner PID/window ID and process generation before and after capture.
Existing identity-specific continuity and deferred ScreenCaptureKit recovery remain.
Read-only live capture confirmed useful images for real Claude `5965` and Finder
`58`, `649`, `3225`, and `7193`; no capture-threshold weakening was needed.

Classic Grid now shows owning app plus distinct window title and production state
badges, distinguishing Finder folders and minimized windows at a glance.

Permission setup now opens a native floating, nonactivating panel with a draggable
file URL for `Bundle.main.bundleURL`. It supports Accessibility and Screen Recording
from onboarding, General settings, and diagnostics, and provides a Finder/add-button
alternative, permission refresh, and dismissal. It never grants permissions itself.

## Validation

- PASS: 47 focused tests, including real asynchronous publication of an injected
  Accessibility-only minimized window with a fresh preview, off-main capture,
  non-window AX role handling, exact drag URL and floating-panel behavior.
- PASS: full suite, 396 XCTest + 2 Swift Testing = 398 tests, zero failures.
- PASS: canonical universal package and deep strict bundle verification.
- PASS: `git diff --check`.
- QA/QC: independent source/test/package review found no actionable defects.
  Existing unrelated compiler warnings remain; no test or package errors.
- CI: NOT_RUN for this uncommitted working tree.
- Simulator: not applicable.

The corrected binary was installed at the existing running path and launched.
The first process (35830) briefly reported Screen Recording denial, with expected
ScreenCaptureKit `-3801` errors. After another restart, process 35997 reported both
Accessibility and Screen Recording Ready. Root did not change permission switches.
Live diagnostics showed 19 exact windows, 0 application fallbacks, 19 saved previews,
0 pending/denied/unavailable previews. No CmdTab error/fault messages appeared in the
final two-minute runtime query saved beside this record. The retained activation
outcome counters are historical and were not reset or claimed as new proof.

Live floating-panel check: window `7511`, title Enable CmdTab Permissions,
AXSystemFloatingWindow, layer 3, visible while CmdTab was not frontmost. Both the
Screen & System Audio Recording page and the Accessibility destination (named
Device Control and Data Access on this macOS) opened, with CmdTab listed and enabled.
The panel exposes the app icon, Finder alternative, permission state and Done.
No OS permission settings were changed during these checks.

User chose to check the final Claude/Finder tiles themselves. Complete visual
switcher acceptance and an actual drop into an ungranted permission list remain
NOT_RUN by the agent; do not equate aggregate diagnostics or transport tests with
those interactions. Legitimate minimized/dialog/multiple Finder windows remain
eligible according to the user's configured scope.

Files changed: AXWindowCatalog.swift, AppSwitcher.swift, ProductionAppSwitcher.swift,
ClassicGridView.swift, ProductionSwitcherVisuals.swift, PermissionSetupWindowController.swift,
OnboardingCoordinator.swift, PreferencesView.swift, ProductionDiagnosticsWindow.swift,
three targeted test files, and README. Source/executable hashes, test/package logs,
live panel probe and diagnostics screenshot accompany this record.

## User acceptance and badge follow-up

User reported "Everything is okay" after choosing to check the tiles themselves.
This is user acceptance, not an agent-recorded full visual switcher receipt.
At the user's request, visible window-state badges were then removed from classic,
list and radial layouts; accessibility state values and clearer window labels remain.
The original 398-test result above predates this presentation-only follow-up.

Follow-up PASS: independent source QA and canonical universal ad-hoc package;
deep strict verification passed and the badge-free build was launched at the same
persistent app path. Executable SHA-256: `c41fe2d2d0118928d86dc916169cb6f3cc0b7f7b299d455771c08f476296aff6`.
The preceding badge-bearing build is retained at
`dist/window-permission-with-badges-rollback/CmdTab.app`. No new behavioral tests
were added or rerun for this cosmetic removal. See `no-badges-package.log`.
