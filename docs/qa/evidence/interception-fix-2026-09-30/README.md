# Intermittent Command-Tab interception fix — 2026-09-30

Local working-tree evidence, not release certification.

- Base commit: `3408c9c24e283e94583e303b2b04d5476775300f`.
- Branch: `codex/fix-intermittent-cmdtab-interception`.
- Changes are uncommitted; pre-existing unrelated working-tree edits were preserved.
- Environment: macOS 27.2 (26B5091g), Xcode-beta toolchain.

## Findings and changes

The production event callback synchronously called licensing `refreshStatus()`
on shortcut presses, including Keychain access, token verification, and trial-clock
writes. The previously running local app logged callbacks between 8 and 48 ms
in the initial 30-minute log query. Its event tap uses the main run loop; slow
callbacks or main-thread stalls can let the native shortcut handler take over.
No live timeout notification was captured, so timeout remains a supported cause,
not a reproduced account of the user's exact incident.

Another deterministic fallback existed while editing CmdTab text fields: the
router bypassed Command-Tab, including when a background visible window retained
a text responder. It now checks the key window and keeps Command-Tab global.
Secure Input and shortcut recording retain precedence.

Licensing now supplies a previously verified memory snapshot for event callbacks,
refreshes asynchronously while idle, and fails closed for unknown security reads,
expired trials, clock rollback, or stale validation. Secure trial-clock writes
and clears use a serial background queue with immediate monotonic session state
and ordered clears. A one-second watchdog recovers disabled/invalid event taps
and restores installation after Accessibility is granted. Missing Secure Input
symbols now correctly report false rather than bypassing all shortcuts.

Affected sources: `ProfileHotkeyManager.swift`, `EventTapWatchdog.swift`,
`LicensingController.swift`, `LicensingStore.swift`, `SecureInputMonitor.swift`.
Regression coverage: `EventTapRecoveryTests.swift`,
`SecureTrialClockPersistenceTests.swift`, `LicensingControllerTests.swift`.
README describes the updated interception contract.

## Validation

- PASS: final `swift test`, 391 XCTest tests plus 2 Swift Testing tests;
  zero failures. Includes idle licensing refresh, callback store-access isolation,
  disabled/invalid-tap recovery, Accessibility restoration, editing Command-Tab,
  Secure Input symbol fallback, blocked clock writer, and save/clear ordering.
- PASS: canonical `scripts/release/package-app.sh`, universal arm64/x86_64 local-QA
  bundle with ad-hoc signing; bundle verification completed.
- PASS: `git diff --check`.
- QA/QC: independent agent reviewed source and terminal results. Existing build
  warnings remain in unrelated code; no compilation or test errors occurred.
- CI: NOT_RUN for this uncommitted working tree. Previously green CI at another
  SHA does not qualify these changes.
- Live packaged-app switching/idle/sleep/permission testing: NOT_RUN.
- Simulator: not applicable to this macOS app.

Test/build transcripts and source/executable SHA-256 hashes are stored beside
this record. The built app is `dist/interception-fix/CmdTab.app`.

The currently running `CmdTab.app` was not replaced or restarted. Quit that
instance before opening the corrected build; macOS may require Accessibility
approval for the new ad-hoc signature. Validate repeated Command-Tab, an idle
interval, text-field focus, and sleep/wake against this exact executable.
Keep the previous app as the rollback artifact.

Residual limits: event routing and recovery still use the main run loop, so
arbitrary long UI stalls can delay interception. Trial-clock persistence is
eventual; writes can queue during prolonged securityd stalls. Actual Secure Input
or unavailable license/Accessibility intentionally permits macOS handling.
