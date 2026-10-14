# CmdTab Native Release — Current Implementation Status

**Updated:** 2026-10-15
**Canonical long-form plan:** `docs/release/native-production-readiness-plan.md`  
**Implementation branch:** `codex/implementation-plan-phase1`
**Base:** `origin/main@5a2b2ff7a68b5d901824f2c04933b8b5e54d2d2a`

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

Local automated evidence currently includes 233 passing Swift tests plus two
updater-configuration tests, 28 passing website security/unit tests,
TypeScript/build/browser verification, zero
moderate dependency vulnerabilities, and release/update/performance harness
tests. Final package/reproducibility and independent integration/security
results are recorded in `tasks/todo.md` before push.

## Recent merges (2026-10-14 to 2026-10-15)

- Interactive website demo app-parity (PR #110): H/M/W quick keys in Grid and
  Radial; Quit (⌘Q) is button-only because ⌘ shortcuts stay with the browser;
  minimized windows are hidden by default behind an "Include minimized
  windows" toggle; the radial view scrolls past eight slots using the app's
  viewport logic (`RadialMenuViewportState`); palette-memory copy now says
  memory persists across launches in the app but not in the demo; a
  hold-to-show hint notes the ~200 ms reveal delay. Details:
  `docs/qa/interactive-demo-fidelity.md`.
- `security.txt` now points to `cmdtab.net` (PR #112).
- October marketing posts and reel, recompressed logo, and `.playwright-mcp`
  added to `.gitignore` (PR #111).
- Dependabot: `actions/setup-node` 4.4.0 → 7.1.0 (PR #93) and `postgres`
  3.4.8 → 3.4.9 (PR #97) merged on 2026-10-14; `zod` 4.3.6 → 4.6.6 (PR #98)
  is still open as of 2026-10-15.

Hosted CI on `main`: Security, Swift (macOS 14 and 15 plus deterministic
release configuration), SEO and GEO, and Release Readiness all succeeded on
`52462b10` (2026-10-14, runs 38528443164, 38528443181, 38528443163,
38528443171); later merges passed Security, SEO and GEO, and Release Readiness
(for example `3e03270d`). The nightly database backup workflow succeeded on its three most recent
runs (38182233318, 38331701445, 38483214973; latest 2026-10-13 23:16 UTC). None of this is a release-candidate run.

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

- none of the production service configuration remains open. Done on 10–11
  October 2026: Auth0 owner login with enforced MFA
  (`docs/security/dashboard-authentication.md`), database backup/restore on a
  CmdTab-only Neon project (`docs/operations/database-backups.md`), the Vercel
  firewall (`docs/security/vercel-firewall.md`), KMS signing with Vercel OIDC,
  and waitlist email from a verified `cmdtab.net` Resend domain with
  `trycmdtab@gmail.com` as the contact mailbox;
- a real Lemon Squeezy test-mode purchase-to-update lifecycle with no manual
  database intervention;
- the intended Developer ID identity, Team ID reconciliation, Hardened Runtime
  signing, notarization, stapling, and Gatekeeper acceptance;
- clean Apple Silicon and Intel installation and N-to-N+1 update evidence;
- real 10/25/50-window and 1,000-session performance acceptance on the final
  signed candidate;
- a hosted CI run for the exact release-candidate commit. Runner capacity was
  restored on 2026-10-09 and the required workflows now execute; a candidate
  still needs its own successful run.

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
