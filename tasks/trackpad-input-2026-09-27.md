# Trackpad selector pacing — 2026-09-27

Base commit: `3408c9c24e283e94583e303b2b04d5476775300f`; working-tree changes, no new commit.

## Behavior

Precise trackpad input needs 24 points of deliberate movement for one selection step. Each new gesture can move immediately after reaching that threshold. Continued movement within one gesture repeats at most once per second. Momentum is ignored. Discrete mouse-wheel and keyboard navigation retain their existing responsiveness.

Global event-tap and panel input share one timing state. Duplicate, out-of-order, prior-session, and packets older than 250 ms are rejected. Delivery time enforces repeat pacing after UI stalls.

## Verification

- PASS: 23 focused XCTest tests, zero failures.
- PASS: independent QA of timing, backlog, and session guards.
- PASS: synthetic CGEvent-to-NSEvent adapter check covering precision, timestamps, five gesture phases, and three momentum phases.
- Physical trackpad feel: NOT_RUN.
- Hosted CI: NOT_RUN; local working-tree candidate.

Evidence: `docs/qa/evidence/trackpad-input-2026-09-27/`.

PASS: universal arm64/x86_64 local QA package built and installed at this repository's `CmdTab.app`; strict code-signature verification passed. Executable SHA-256: `b608c2499e13cc8c6c25212843310d8c7e19d55bea883ae93887bb17a3bc0d9f`.

Running copy verified as PID 38236. Settings reports Accessibility and Screen Recording Required after the ad-hoc rebuild; user reauthorization requested. Live input acceptance remains BLOCKED pending reauthorization. A transient computer-use inspection timeout recovered on retry. Build has existing compiler warnings, no compiler errors. Independent artifact QC passed signature, architectures, executable hash, and package log checks.

Rollback copy: `/tmp/CmdTab-before-trackpad-fix.app`.
