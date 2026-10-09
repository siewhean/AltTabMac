# Switcher discovery implementation — 2026-09-15

User authorized implementation after the September 14 audit. Scope is shared behavior for all eligible apps, not special cases for the six examples. Existing unrelated dirty work is preserved; this is a local QA package, not a release candidate.

## Changes

- `ProductionAppSwitcher.swift`: final all-Spaces reconciliation supplies one app fallback for each eligible running PID not represented by an exact window. Positive metadata and explicit filters remain effective; absent AX rows do not prove a CG window is invalid. Expired enrichment can run again even when base identities are unchanged. Cached merges deduplicate fallback/exact targets and do not reintroduce suppressed windows, including empty enriched results. Narrow profiles reject unscoped fallbacks.
- `AppSwitcher.swift`: shared fallback factory preserves existing activation/history behavior. Preferred AX main/focused windows obey the same minimized/role eligibility as other windows. Capture validation converts to a bounded 64×64 RGBA sample; border trimming uses alpha-only conversion, handles no-alpha formats, and fixes asymmetric crop coordinates.
- `ReliableWindowPreviewRecovery.swift`: capture failures retain stage and NSError domain/code for diagnosis.
- `ProductionSwitcherVisuals.swift`: classic-grid scroll indicators are enabled and flash on first appearance. Card geometry and existing centering remain unchanged because the screenshot did not establish a specific placement error.
- Regression coverage: 14 finalizer/merge/gate tests and 6 capture-format tests, including cold app coverage, multiple windows/processes, exclusions, minimized states, stale metadata, byte orders, grayscale, transparency, dark content, and asymmetric cropping.
- Test maintenance required to run the existing suite: corrected five licensing test-helper argument labels; reconciled three chord tests with the already-documented short key-up contract and one ordering test with the already-documented exact-window MRU contract. No licensing, hotkey, or ordering production behavior changed for these test repairs.

## Verification

Commands used `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`.

| Check | Result |
| --- | --- |
| `swift build --scratch-path /tmp/CmdTab-discovery-tests --jobs 4` | PASS; compiler warnings remain |
| `swift test --scratch-path /tmp/CmdTab-discovery-tests --jobs 4 --filter 'ProductionWindowReconciliationTests\|CapturePixelFormatTests\|CaptureFallbackTests\|PreviewContinuitySafetyTests\|MembershipDiagnosticsTests\|ProductionHotSwapPolicyTests'` | PASS: 36 tests, zero failures |
| `swift test --scratch-path /tmp/CmdTab-discovery-tests --jobs 4` | PASS: 290 XCTest tests and 2 Swift Testing tests, zero failures after test maintenance |
| `CMDTAB_BUILD_JOBS=4 ./build.sh` | PASS: universal x86_64/arm64 bundle, ad-hoc signature and package verification |
| `git diff --check` | PASS |
| Independent scoped code QA | No actionable findings; no P0/P1 findings in reviewed implementation |
| Packaged app restart | PASS: old PID 8489 terminated; new PID 23917 launched from repository CmdTab.app |
| Full live switching/preview acceptance | BLOCKED: rebuilt app reports Accessibility and Screen Recording required |

Local logs: `/tmp/CmdTab-discovery-build.log`, `/tmp/CmdTab-discovery-focused.log`, `/tmp/CmdTab-discovery-full.log`, `/tmp/CmdTab-discovery-package.log`. These are local diagnostic logs, not frozen-SHA release evidence.

Executable SHA-256: `421ae12c98ad72501ae13ede8a6128364e111fe29228c13cf3a1914bd75b177b`.
Package: `CmdTab.app`; receipts: `CmdTab.manifest.json`, `CmdTab.sha256`.

## Live evidence boundary

The old app reported permissions ready. After replacing the ad-hoc package and restarting, the new app's Settings and Diagnostics report both permissions required. Logs corroborate denied ScreenCaptureKit operations (`SCStreamErrorDomain`, code `-3801`). Permissions were not reset or changed by this task. Reauthorize the rebuilt app in System Settings, then quit/reopen it before verifying all app entries and thumbnails without first visiting those apps.

AppKit also logged negative width/height geometry faults while inspecting Settings. These occurred in old PID 8489 at 16:18:53 and 16:19:48, before the new PID launched at 16:20:23, and recurred afterward. These faults were already present before replacement; their exact source is unproven. They are not evidence that this task corrected absolute switcher position. No speculative layout patch was applied.

The Diagnostics membership counters describe the base snapshot and cannot prove final production membership. No screenshot after permission reauthorization, physical multi-display check, or complete per-app live inventory comparison has been obtained. Source implementation and deterministic verification are complete; full runtime acceptance remains pending.
