# CmdTab Native Release — Current Implementation Status

**Updated:** 2026-09-29
**Canonical long-form plan:** `docs/release/native-production-readiness-plan.md`  
**Candidate branch:** `codex/release-candidate-20260929`
**Base:** `origin/main@dcd02faafbe4cd944fa9899d4e5ddcd6d5f70407`

## Current candidate boundary

The branch is consolidating the tested switcher, preview, licensing, and
release-tooling source on current `origin/main`. The 2026-09-28 live functional
and bounded CPU checks apply to an ad-hoc local app, not automatically to this
rebuilt candidate. See [the exact observation record](../qa/evidence/attached-app-live-2026-09-28/observations.md).
The candidate retains universal arm64/x86_64 packaging, macOS 14+, and the
public-beta channel. Full candidate tests, package verification, hosted CI,
signed-artifact and physical release checks need their own exact-SHA evidence.

## Accepted baseline

Phase 1 remains the accepted local ad-hoc packaging baseline through PR #31.
It proved deterministic application assembly, permanent bundle identity,
rollback-safe beta migration, bundle verification, and local packaged behavior.
It did not prove Developer ID distribution, notarization, clean hardware,
production commerce, or updates.

## Repository-owned implementation

The current candidate adds:

- versioned, reopenable onboarding with contextual permission requests,
  first-switch practice, safe resume, and proactive trial warnings;
- default-off native telemetry and website analytics with withdrawal;
- signed install-bound trial tokens, secure trial clock state, opaque purchase
  credentials, device-bound paid tokens, grandfathered v1 verification, and
  offline-indefinite paid authorization;
- atomic three-device activation, deactivation, enumeration-safe recovery,
  delivery retry/outbox, and distinct partial/full refund and revocation state;
- Auth0-compatible owner-only MFA dashboard sessions with idle/absolute limits,
  generation invalidation, CSRF checks, and audited actions;
- Sparkle 2.9.2, a typed beta/stable/development update configuration,
  immutable release manifest, signed appcast tooling, and Sparkle-aware nested
  packaging verification;
- a single US$12 offer, terms/refund/device/update/recovery policies, immutable
  download gating, and deterministic showcase clips no longer than five
  seconds;
- hash-bound 10/25/50-window performance tooling and a 1,000-session soak
  contract that refuses to fabricate unavailable measurements;
- immutable GitHub Action pins and release-readiness coverage for every PR and
  `main` push.

The earlier baseline recorded 233 passing Swift tests plus two
updater-configuration tests, 28 passing website security/unit tests,
TypeScript/build/browser verification, zero
moderate dependency vulnerabilities, and release/update/performance harness
tests. Final package/reproducibility and independent integration/security
results are recorded in `tasks/todo.md` before push.

## Release truth

The repository is configured to fail closed when production release material is
absent:

- without the production KMS keyrings, production trial/license issuance is
  unavailable;
- without `SUPublicEDKey`, local QA builds do not enable the production updater;
- without `release/stable.json`, `/releases/stable.json` returns 503/no-store
  and the website exposes no DMG;
- without complete Auth0 production configuration, the dashboard denies access.

## External public-launch blockers

The following cannot be accepted from repository automation alone:

- production Vercel/Postgres/rate-limit storage/Resend/KMS/Auth0/WAF
  configuration, operational mailboxes, and backup/restore evidence;
- a real Lemon Squeezy test-mode purchase-to-update lifecycle with no manual
  database intervention;
- the intended Developer ID identity, Team ID reconciliation, Hardened Runtime
  signing, notarization, stapling, and Gatekeeper acceptance;
- clean Apple Silicon and Intel installation and N-to-N+1 update evidence;
- real 10/25/50-window and 1,000-session performance acceptance on the final
  signed candidate;
- restored GitHub-hosted runner/account capacity. Current required workflows
  fail before their first step and therefore provide no source-quality signal.

No release branch or public download may be promoted until every applicable
external item is evidenced. Unsupported hardware or unavailable credentials
remain `NOT TESTED`, never inferred.

# Public-beta blocker remediation — 2026-09-09

The current candidate uses a typed `beta` release channel and the dedicated
`https://cmdtab.net/releases/beta/appcast.xml` feed. Native palette input,
activation-outcome accounting, signing/notarization guards, deterministic CI
configuration validation, centralized status-bearing private-window capability
providers, and physical-evidence procedures are repository complete. The
macOS-14/15 private-capability canary is a physical receipt gate, not CI proof.
The release remains **BLOCKED** until the exact candidate has hosted
CI, authorized-Mac performance/soak and VoiceOver receipts, Developer ID
signing/notarization/Gatekeeper proof, and a real signed beta N->N+1 update.
