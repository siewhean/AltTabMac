# Complete window coverage and permission persistence

## Implemented

- Enabled minimized inclusion in this installation’s global preference and both standard profile IDs. All unrelated profile fields preserved; application defaults unchanged.
- Complete atomic enrichment publication; no redundant process fallback alongside an eligible exact window. Cold overlay requests wait for inventory and cancel when their gesture ends.
- Explicit application-only, pending, permission-denied, unavailable, live and saved-preview states, including accessibility text and diagnostic counts.
- 128 MiB LRU thumbnails capped at900px, original capture time preserved; matching process generation and AX element required for long minimized retention. Complete closure/replacement/termination/denial purges continuity; incomplete AX does not. Per-process observation times reject stale catalog rollback.
- Recovery uses existing capture APIs, bounded retries, lifecycle tokens, and bounded settled metadata. No focus/restore for capture.

## Verification

`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --scratch-path /tmp/CmdTab-coverage-tests --jobs 4`:343 XCTest +2 Swift Testing passed, zero failures. Includes24-window asynchronous capture/cache/notification coverage plus real ProductionAppSwitcher serial enrichment/main publication across3 process identities. These injected integration tests do not prove the OS can capture every minimized window.

Independent QA:0 unresolved scoped P0/P1/P2 after fixing clone timestamp/purge resurrection, stale lifecycle observations and canceled-retry metadata. Diff checks passed.

Universal local-qa packaging and strict deep signature verification passed. Installed `/Users/Siew Hean/Applications/CmdTab.app`; executable SHA256 `53ac23c2c8b55ab14227daa7734f56803376f7746a3a9308d3e26d37056c3100`. Retained logs: `docs/qa/evidence/window-coverage-2026-09-27/`.

## Permission persistence

No automatic permission-request loop was found: launch performs preflight checks; explicit onboarding controls request grants. The old temporary QA bundle disappeared and a different repository binary ran after restart. The current ad-hoc code requirement is binary-hash based; the host has0 certificate-backed signing identities. A persistent installation removes temporary-path/alternate-copy churn but cannot guarantee permission continuity across changed ad-hoc binaries.

Old repository copy login registration disabled; persistent installed copy login registration enabled. Both permissions on the replacement initially Required. System Settings is awaiting user Touch ID/password to modify authorization. Restart persistence and full live inventory reconciliation remain pending; do not claim completion.

## AppKit evidence

The retained plain AppKit fixture previously reproduced6 geometry faults on macOS26.6. A subsequent same-host capture did not reproduce; neither establishes a supported fix. Apple feedback draft remains unsubmitted. Current host is macOS27.2 (26B5091g); this version needs separate live retest. No private swizzle, log suppression or capture disabling was used.
