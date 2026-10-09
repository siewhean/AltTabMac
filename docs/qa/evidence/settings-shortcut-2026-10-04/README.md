# Settings appearing during shortcuts — 2026-10-04

Local dirty-working-tree fix; not release certification.
Base SHA `3408c9c24e283e94583e303b2b04d5476775300f`, branch
`codex/fix-intermittent-cmdtab-interception`. No task commit or CI run.
Existing unrelated worktree edits preserved. Xcode-beta on the actual macOS host.

## Cause and remediation

Before the fix, switcher session authorization always called the licensing Settings
callback when denied. App reopen also unconditionally opened Settings when onboarding
was absent. Native command-palette activation could bring retained Settings forward.
The initial read-only probe found Settings window 7876 onscreen in PID 50347 even
while CmdTab was not frontmost; this alone does not prove the original shortcut trigger.

Shared window identifiers now let shortcut entry and pre-activation ordering hide
only Settings and Shortcut Profiles, preserving contents and unsaved drafts.
Both production and legacy shortcut controllers hide before early-return guards.
Deferred inventory keeps explicit versus shortcut invocation distinct. Shortcut access
checks still fail closed, but never request the licensing Settings pane. Explicit menu
opening retains licensing recovery. Reopen delegates suppress default AppKit ordering
and do not open Settings. Manual menu Settings remains available.

## Validation

PASS: focused 45 tests. PASS: full 400 XCTest plus 2 Swift Testing, zero failures.
Real NSWindow regression verifies hiding/draft preservation/unrelated-window retention;
production shortcut entry verifies hiding and no licensing callback. A separate denied
licensing test verifies enforcement and explicit presentation remain intact.
PASS: independent source/full-test review and git diff --check.
Initial test-development failures were corrected: missing signing helper argument,
and notification API assertion from constructing AppDelegate in an unbundled XCTest
runner. The final reopen test uses the actual shared handler, avoiding unrelated
notification initialization; production notifications were not modified.

PASS: canonical universal arm64/x86_64 ad-hoc package and deep strict verification.
Installed and launched at `dist/interception-fix/CmdTab.app`. Previous binary retained
at `dist/settings-shortcut-rollback/CmdTab.app`. Executable SHA-256:
`249b31dca71967904ec6ab3c845260c5f1366284667aa4f9ffda1d1b2763f89f`.

Live PID 16849 and same-binary restart PID 17278: Accessibility trusted; Settings
and onboarding windows offscreen. Runtime has Screen Recording permission denial
(SCK -3801), persisting after one restart. Preview authorization remains BLOCKED
until this rebuilt app is enabled in Screen Recording by the user. No permission
switches were changed. OS AppIntents/linkd.autoShortcut registration errors (4097)
also appear; they are recorded, not claimed clean or attributed to this fix.
Source/tests/package QA passes; live long-duration shortcut acceptance is NOT_RUN. No global held-key
manual shortcut reproduction or long-duration intermittent acceptance is claimed.
No simulator applies to this macOS app. CI is NOT_RUN for the uncommitted tree.
