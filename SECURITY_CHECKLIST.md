# CmdTab Security Checklist

**Reviewed against:** baseline `origin/main@dcd02faafbe4cd944fa9899d4e5ddcd6d5f70407`;
application-source candidate `081ec04199885dffb5c7dddd30b6dcd23279bd55`;
documentation/CI refresh `2bcb2275b41cc6712dec8abcb2a4b62f3569143c`.
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

## Candidate disposition and independent source review

The static source audit at
`081ec04199885dffb5c7dddd30b6dcd23279bd55` found **no open P0**. The P1
findings listed above were remediated before that candidate's executed checks.
The combined diff and the non-zero-step macOS 14/15, Security, SEO/GEO,
Release Readiness, Workflow Health, Audit Source Export, and Vercel results
were independently QA/QC reviewed as recorded in
[`tasks/todo.md`](tasks/todo.md). The follow-up documentation candidate
`2bcb2275b41cc6712dec8abcb2a4b62f3569143c` repeated the hosted CI set; run
identifiers and exact scope are retained in
[`docs/release/evidence/public-beta/G8-ci/`](docs/release/evidence/public-beta/G8-ci/).

This is a **source-review disposition only**. It does not close an item that
requires Developer-ID signing, a notarized artifact, real permission states,
production services, or a clean machine. Any commit after `2bcb2275` must
receive replacement-candidate review and executed evidence.

The operational-controls source candidate
`5c6bf288baae9f20bc5b43e5ddfe351539b4a08d` adds an index-backed tracked-secret
scanner, beta-DMG preflight/name binding, and an unavailable purchase-confirmation
surface. Its local checks, independent combined source review, and the executed
hosted check set passed on documentation/evidence head
`db78652ee357352b1ad77959e37a00625f912f84`; run links are retained in the G8
record. It must not inherit the `081ec041` P0/P1 source disposition.

## Mandatory candidate evidence

| Area | Required evidence | Status |
| --- | --- | --- |
| Fresh security review | Candidate SHA, P0/P1 triage, disposition, and independent review | PASS (source review at `081ec041`; no open source P0/P1); signed-artifact review remains BLOCKED |
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
