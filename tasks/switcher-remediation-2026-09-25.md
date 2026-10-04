# Switcher remediation — 2026-09-25

## Confirmed causes and correction

- Base AX eligibility disagreed with AXWindowCatalog for minimized AXDialog windows. Calendar, Settings and Reminders showed this live. Base discovery now delegates to the canonical policy, recognizing the real sibling even when minimized inclusion is off and rejecting its unnamed offscreen helper surfaces under the existing guarded rule.
- Serial all-app AX inspection could age early results beyond the one-second helper-evidence limit. Discovery refreshes stale inspections and classifies each process’s CG rows contiguously, retaining original orderIndex before deduplication/ranking. Incomplete/untrusted/unknown evidence still fails open.
- Failed preview recovery recorded retry deadlines without scheduling work. The first two transient failures now schedule bounded retries; denial stops retries. Process generation is checked before retries and capture publication. Failure diagnostics contain IDs/reasons, not titles or image content.

No app-name allowlist or preview-dependent membership filtering was introduced. Distinct real windows remain distinct targets.

## Evidence

Old authorized bundle PID25401: both permissions Ready. Practice switcher reproduced Calendar/Chrome extra surfaces. Read-only exact inventory confirmed minimized Telegram2265, Antigravity21944 and Reminders23733. UI Show Minimized Windows was off; app-only fallbacks cannot capture an exact window and legitimately show icons. Chrome address-bar surface and Calendar popup were visually present; corrected live membership still needs verification.

- Final full suite: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --scratch-path /tmp/CmdTab-discovery-tests --jobs 4`; exit0, **317 XCTest +2 Swift Testing passed**, log `/tmp/CmdTab-sept25-tests-final.log`.
- Membership focused:15/15 passed, `/tmp/cmdtab-membership-sept25-tests.log`.
- `git diff --check`: passed. Existing compiler warnings remain.
- Independent QA: no unresolved scoped P0/P1/P2; this is source review, not live acceptance.
- Packaging: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer CMDTAB_BUILD_JOBS=4 CMDTAB_OUTPUT_APP=/tmp/CmdTab-switcher-QA-20260925.app bash scripts/release/package-app.sh`; exit0, universal arm64/x86_64 and ad-hoc signature verification passed. Log `/tmp/CmdTab-sept25-package.log`; manifest/checksums adjacent to app.
- Executable SHA256: `35b7ad4fe80a2caf878152a3f70a828cdbee24e3c363ddbe4b4215660ac88778`.

## Current device boundary

Old QA process terminated and corrected bundle launched, PID2386 at00:25. Its General pane reports both Accessibility and Screen Recording Required, and current logs confirm capture denial. Approval to reauthorize this build requested; no security settings changed. Live duplicate reduction and thumbnail recovery therefore remain unverified.

AppKit negative geometry faults persist. All21 width faults investigated on prior PID25401 resolve to NSThemeFrame._positionSharingIndicator / NSWindowSharingSessionRecipientIndicator, not settings SwiftUI sizing. Symbolicated evidence `/tmp/cmdtab-position-sept25-symbolicated.txt`. Fresh PID2386 faults also observed. No speculative layout patch or error-free runtime claim.

This is a local QA artifact, not a signed/notarized release. Unrelated dirty work preserved.

## Authorized follow-up

User authorized permission enablement and requested geometry resolution. Added the exact CmdTab bundle to Accessibility. Recording toggle refresh alone did not restore capture; removed only the CmdTab recording entry and re-added the exact bundle, then explicitly relaunched it. System Settings Quit & Reopen had opened a same-bundle-ID sibling checkout; that process was caught/stopped before explicitly launching the correct app. No unrelated permission changed.

CurrentPID17971 runs the unchanged verified artifact and reports both permissionsReady. Diagnostics8exact/10fallback/8preview/0unavailable. Live18-entry practice showed real thumbnails for all8 exact items; Calendar and Chrome extra helper cards no longer appeared. App-only icon entries remain expected with minimized inclusionoff. This observation is a current desktop check, not universal coverage of every application/state.

Geometry remains unresolved: debugger identified Settings native sharing indicator intrinsic size(-1,-1) passed directly into setFrameSize. Native toolbar and resizable-window A/B both reproduced3width+3height faults. Independent pureAppKit fixturePID18696 reproduced the same at00:41:06. Source/reproduction retained under Tests/Fixtures/AppKitSharingGeometry, compiled and plist linted successfully. Temporary runtime experiments died with oldPID12488; no production geometry change was retained. No evidence supports a safe application-level correction; error-free runtime gate remains unmet.
