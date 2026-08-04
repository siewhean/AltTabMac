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
- `SECURITY.md` names `support@cmdtab.net` as the private disclosure channel.
  The mailbox still requires inbound/outbound send-and-reply and monitoring
  evidence before a public beta can be published; do not claim that operation
  is live before it is tested.
- The old checklist's statements that authentication, sessions, webhooks, and
  database controls were out of scope are stale. Their implementation and
  deployment contracts are in scope even when production is deliberately
  disabled.

## Candidate P1 findings remediated in this branch

- Confirmed Screen Recording denial clears retained previews, fences deferred
  capture, and preserves tile identity through a safe placeholder.
- `POST /api/trial/reminder` requires a strong bearer secret before reading
  mail configuration or recipients; missing, weak, wrong, and valid states are
  covered.
- Dynamic SkyLight/AX/front-process outcomes now report observable capability
  state and explicit degraded/failure diagnostics without changing protected
  routing or activation verification.
- Opt-in native telemetry has a fixed aggregate-only payload with no stable
  identifier, local window content, token, secret, or metadata field. The
  privacy manifest is package- and bundle-verified; its final signed-artifact
  applicability still needs Gate 2 review.
- Public beta copy has no checkout/offer schema or current purchase promise and
  uses `support@cmdtab.net`; mailbox verification is still external.

## Mandatory candidate evidence

| Area | Required evidence | Status |
| --- | --- | --- |
| Fresh security review | Candidate SHA, P0/P1 triage, disposition, and independent review | BLOCKED - no P0; repository P1 remediations need signed-artifact review |
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
