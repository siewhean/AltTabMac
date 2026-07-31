# CmdTab Signed Public-Beta Gate Ledger

**Candidate source:** `origin/main@dcd02faafbe4cd944fa9899d4e5ddcd6d5f70407`
**Target:** direct-download `v1.0.0-beta.N`, Apple silicon (`arm64`) only,
macOS 13.0 Ventura or later, bundle ID `net.cmdtab.CmdTab`.

## Decision and rules

**Release decision: BLOCKED.** This ledger is authoritative for the
repository-owned public-beta work. `PASS` requires exact-candidate evidence;
`BLOCKED` needs an external dependency or an unfinished repository gate;
`NOT TESTED` means no observation exists. Historical records are context only.

Commerce is disabled for the beta: `CMDTAB_REQUIRE_COMMERCE_READY` must be
unset or not `1`. No payment CTA, checkout, fulfillment, or outbox processing
may be public. Any US$12 reference must be clearly future-tense (planned at
GA); no `Product` or `Offer` structured data may advertise a transaction.
At GA, stable download and appcast must be controlled independently. Gate 5
must make stable download and appcast unavailable with `503` and `no-store`
until GA and add a separate beta manifest/appcast namespace; the baseline has
no stable-appcast route evidence yet.

## Master checklist

| Gate | Required decision evidence | Current status |
| --- | --- | --- |
| G0 Governance | Candidate ancestry, evidence index, risk register, matrices, runbooks, and truthful source-status reconciliation | PASS (repository governance only); external release rows remain independently blocked or not tested |
| G1 Artifact integrity | `arm64` beta configuration; current full/focused tests; clean unsigned builds; bundle/entitlement/resource/secret/dSYM review | BLOCKED - baseline is universal/stable; the arm64 beta change and current rerun evidence remain incomplete |
| G2 Security/privacy/permissions | Candidate-SHA security audit; P0/P1 triage; private capability/fallback review; privacy and real permission-state evidence | BLOCKED - four P1 findings; permission matrix NOT TESTED |
| G3 Developer ID artifact | Team-ID-confirmed Developer ID signature, Hardened Runtime, timestamp, notarization, staple, Gatekeeper, checksum | BLOCKED - credentials absent |
| G4 Functional acceptance | Exact quarantined signed DMG on clean arm64 Ventura/current macOS accounts; protected-window matrix and performance/soak | NOT TESTED |
| G5 Beta update/rollback | Isolated beta feed/manifest; signed N-to-N+1, tamper/interruption/cache failure, withdrawal, rollback rehearsal | BLOCKED / NOT TESTED |
| G6 Website/support/commerce | Beta-only website pages, tested support mailbox, disabled commerce proof, production browser/accessibility/header evidence | BLOCKED |
| G8 CI/CD | Executed candidate SHA logs for Security, SEO/GEO, Release Readiness, macOS 14/15; branch protection; trusted release environment | BLOCKED - runs have no steps and `main` is unprotected |
| G9 RC/soak | Frozen `v1.0.0-beta.N`, private-beta soak, P0/P1 closure, immutable evidence bundle | NOT TESTED |
| G10 Publication/operations | Explicit owner approval; prerelease/feed/manifest/download publication; 1h/1d/3d/1w checks and withdrawal control | BLOCKED - approval and prerequisites absent |

Gates may not be skipped. Each completion gets one logical commit and an
evidence record with candidate SHA, commands/exits, artifact hashes, manual
environment, risks, status, owner, and next action. An independent QA/QC review
is required before any gate `PASS`.

## Risk register

| Risk | Control and release disposition |
| --- | --- |
| Unsigned/unnotarized artifact | Do not publish; G3 requires nested signing, notarization, staple, `codesign`, `spctl`, `stapler`, DMG and hash evidence. |
| Architecture/support mismatch | G1 must make configuration, verifier, appcast, manifest, and HTML `arm64`-only; Intel is unsupported and never inferred. |
| Private API regression | G2 must prove documented detection, public fallback, truthful degraded UI, and regression coverage per SkyLight/SLS/CGS/AX use. |
| Revoked Screen Recording privacy leak | Clear cached previews and block every capture path on confirmed denial; prove revoke and re-grant regressions. |
| Unauthenticated reminder delivery | Require a strong cron bearer secret before any reminder work; test absent, weak, invalid, and valid cases. |
| Permission identity drift | G2/G4 run the exact signed bundle through denied/revoked/reset/update states on clean accounts. |
| Unsafe/incorrect update | G5 binds signed appcast, immutable manifest, DMG, checksum, source SHA, and deployment; reject tampered/mismatched inputs. |
| Customer payment while beta infrastructure is disabled | Keep the commerce switch off; independently verify hidden checkout, webhook 503, and pre-database worker no-op. |
| Security/privacy disclosure drift | G2/G6 reconcile security policy, CSP, telemetry/logging, support/legal copy, Apple privacy requirements, and real deployed headers. |
| No operating recovery path | G6/G10 require tested support/recovery, incident, monitoring, backup/restore, and KMS-compromise procedures. |
| Non-executing CI presented as green | G8 accepts workflow logs with actual steps only; zero-step runs are failures to execute. |
| Uncontrolled launch | G9/G10 require private soak, immutable evidence, explicit go-live approval, and tested withdrawal/rollback controls. |

## Supported-test matrix

| Configuration | Required beta evidence | Status |
| --- | --- | --- |
| Apple silicon, macOS 13 Ventura, clean account, one display | Quarantined signed DMG install, permissions, core matrix, update/rollback | NOT TESTED |
| Apple silicon, current stable macOS, clean account, one display | Same as Ventura plus current OS compatibility | NOT TESTED |
| Apple silicon, exercised multi-display/Spaces/fullscreen/Stage Manager setup | Exact configuration matrix and evidence | NOT TESTED |
| Intel or macOS below 13 | Out of public-beta support; do not claim support | NOT SUPPORTED |

For every real-machine result record hardware, OS/build, display topology,
language/keyboard layout, permission state, candidate SHA, app/DMG SHA-256,
and tester. Do not generalize from an untested configuration.

## Evidence contract

Evidence lives in [`evidence/public-beta/`](evidence/public-beta/). The index
links prior Phase 0/1 records as historical and defines the required records
for every gate. Runbooks for support/recovery, incidents, monitoring,
backup/restore, KMS compromise, commerce GA, and known limitations are in
[`public-beta-runbooks.md`](public-beta-runbooks.md).

The beta tag is `v1.0.0-beta.N`, never `v1.0.0`. Final publication is a
separate owner action after written go-live approval; this branch must not
create a tag, GitHub release, beta appcast, beta manifest, or public download.
