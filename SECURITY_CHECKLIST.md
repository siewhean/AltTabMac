# CmdTab Security Checklist

**Reviewed against:** `origin/main@dcd02faafbe4cd944fa9899d4e5ddcd6d5f70407`
**Release status:** **BLOCKED** - this is a scope and evidence ledger, not a
security certification. The canonical beta gate is
[`docs/release/public-beta-readiness.md`](docs/release/public-beta-readiness.md).

## In-scope surfaces

- Native macOS app: Accessibility, Screen Recording, hotkey/event-tap paths,
  window capture, activation, updater, licensing, telemetry, and settings.
- Dynamic native capabilities: SkyLight/SLS/CGS, `_AXUIElementGetWindow`,
  secure-input probing, and their public/degraded alternatives.
- Website, middleware/CSP/security headers, public waitlist/trial/license/help
  endpoints, Auth0 owner dashboard, analytics, and disclosure surfaces.
- Commerce code: checkout gating, Lemon Squeezy webhook, lifecycle database,
  outbox, fulfillment email, refunds/revocation, recovery, AWS KMS signing,
  and Vercel/runtime secrets.
- Release chain: source SHA, signing/notarization, Sparkle appcast, immutable
  manifest/DMG, Vercel deployment, GitHub Actions, and rollback controls.

## Repository observations - not a pass

- Source checks document strict request parsing, waitlist throttling,
  no-store responses, security headers, release configuration checks, and a
  commerce-disabled boundary. Re-run them on the exact beta candidate.
- `CMDTAB_REQUIRE_COMMERCE_READY != 1` is mandatory for this beta. It must
  keep checkout hidden, return `503 commerce_disabled` from the webhook, and
  make outbox workers no-op before configuration/database access.
- Existing `SECURITY.md` legitimately retains the personal disclosure channel
  until a domain mailbox is verified. `support@cmdtab.net` is required before a
  public beta can be published; do not claim it is live before send-and-reply
  evidence exists.
- The old checklist's statements that authentication, sessions, webhooks, and
  database controls were out of scope are stale. Their implementation and
  deployment contracts are in scope even when production is deliberately
  disabled.

## Candidate P1 findings requiring remediation

- Screen Recording revocation can continue to expose retained previews of
  other apps; denial must clear continuity/cache and prevent all capture
  providers until a confirmed re-grant.
- `POST /api/trial/reminder` currently treats a missing `CRON_SECRET` as
  authorized despite public cron reachability. Missing, weak, wrong, and valid
  bearer secret cases need a fail-closed implementation and tests.
- Normal preview, exact-window identity, and focus paths retain direct
  undocumented SkyLight/AX/front-process calls. They need injectable providers,
  observable status, public fallback, and regression proof for missing symbols
  and runtime failures.
- Current public buy/trial/refund copy, Buy navigation, and personal-Gmail
  support contact violate the beta commerce/support boundary even though
  checkout execution is hidden while commerce is disabled.

## Mandatory candidate evidence

| Area | Required evidence | Status |
| --- | --- | --- |
| Fresh security review | Candidate SHA, P0/P1 triage, disposition, and independent review | BLOCKED - four P1 findings; no P0 found |
| Web hardening | State-changing route origin/fetch-site review, CSP decision, headers, dependency/secret scans | BLOCKED |
| Native privacy | Entitlements, Hardened Runtime, logging/telemetry data-flow review, privacy-manifest/required-reason applicability | BLOCKED |
| Private capabilities | Need, detection, public fallback, degraded UI, tests, and clean-machine observation for each capability | BLOCKED |
| Permissions | Unrequested, denied, granted, revoked, Settings change, TCC reset, and post-update behavior | NOT TESTED |
| Auth0/dashboard | Production configuration, MFA, session invalidation, CSRF, authorization, and audit-log proof | BLOCKED |
| Commerce boundary | Disabled checkout/webhook/outbox paths plus proof no customer can pay | BLOCKED |
| KMS/lifecycle | Least-privilege keys, rotation/compromise rehearsal, sandbox lifecycle, refund/revocation and recovery proof | BLOCKED |
| Release/update | Signed appcast/manifest, tamper rejection, rollback rehearsal, and delivery integrity | BLOCKED |
| Operations | Mailbox, monitoring, incident response, backup/restore, contacts, and audit retention | BLOCKED |

## Severity and exit rule

- **P0:** compromise, unauthorized payment/access, unrecoverable loss, unsafe
  distribution/update, or switching to a wrong user target.
- **P1:** material reliability, privacy, accessibility, support, or update
  safety defect.

Open P0/P1 items block beta publication. A passing source test, build, Vercel
deployment, or zero-step workflow failure cannot close an item requiring a
signed artifact, production service, or real machine.
