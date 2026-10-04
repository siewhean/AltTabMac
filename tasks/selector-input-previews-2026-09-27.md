# Selector badges, previews, and trackpad input — 2026-09-27

Base HEAD: `3408c9c24e283e94583e303b2b04d5476775300f`; uncommitted local working-tree candidate.

## Changes

- Removed compact top-right badges from grid thumbnails and radial items. Accessibility state and descriptive list labels remain.
- Background preview recovery now tries five captures over roughly 3.5 seconds rather than stopping after roughly 0.3 seconds. Later independent refreshes can start a fresh bounded burst after cooldown. Automatic retries cannot restart their own burst; repeated failure notifications remain deduplicated.
- Saved previews survive failed refreshes; a successful deferred capture updates the selector without activating the target app.
- Global scroll input is stamped on receipt using the same uptime clock as presentation and delivery. Native event timestamps no longer reject otherwise valid input. A scoped local monitor intercepts selector scroll events before child scroll views consume them.
- One step per deliberate swipe, one-second sustained repeat limit, ignored momentum, session and backlog guards retained.

## Verification

- PASS: 26 focused input tests, zero failures.
- PASS: 28 focused preview tests, zero failures, including delayed background recovery without activation and saved-frame retention.
- PASS: independent source QA; whitespace check.
- Physical trackpad acceptance: NOT_RUN. A bounded listen-only diagnostic received no physical packets; the reported hardware failure was not reproduced.
- Real GPU/minimized/offspace preview recovery: NOT_RUN for this candidate. Tests use an injected capture transport.
- CI: NOT_RUN; local candidate only.

Evidence: `docs/qa/evidence/selector-input-previews-2026-09-27/`.

The removed picture badge represented unavailable capture, not a refresh control. Transient unrendered or missing capture surfaces can recover automatically; protected content, windowless apps, and some minimized or offspace windows may still have no capturable frame. Existing saved frames help where available. Accessibility and Screen Recording authorization must be valid for the exact installed copy.

PASS: universal arm64/x86_64 local QA package installed in repository `CmdTab.app`; strict signature and executable hash verified by independent artifact QC. SHA-256: `42c72a44fe6b6abb0a16c8db1f6429cb12f7cd09e28caabbdb1be63384b428b8`. Exact repository copy running as PID 48361 after installation.

Live acceptance remains pending. Computer-use inspection timed out twice after installation. Runtime reports ScreenCaptureKit error -3801 (`userDeclined` in the local SDK), confirming capture authorization needs attention; Accessibility status is unverified. User asked to check permissions, restart, and try gestures/background previews. Existing AppIntents service connection errors also remain. Do not infer live success from source or injected tests. Rollback copy: `/tmp/CmdTab-before-selector-input-previews.app`.
