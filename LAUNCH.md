# CmdTab Launch Checklist

This checklist separates repository-ready implementation from evidence that
requires production accounts, Apple credentials, and clean hardware.

## Offer and customer contract

- US$12 one-time perpetual personal license.
- Up to three personally owned Macs with immediate self-service deactivation.
- All CmdTab 1.x updates.
- 14-day trial and 14-day full-refund policy.
- Partial refunds preserve access. Documented full-refund webhooks and
  repository-owned manual revocation create persistent revocation tombstones.
  Production chargeback, dispute, and fraud enforcement requires a validated
  provider reconciliation path and remains an external launch gate.

The canonical purchase entry is `https://cmdtab.net/buy`. The website must not
publish a download until `release/stable.json` references a verified immutable
DMG.

## Repository-ready paths

- Versioned onboarding and contextual Accessibility/Screen Recording prompts.
- Keychain-backed signed, install-bound trial entitlements with exact 14-day
  UTC expiry and rollback detection.
- Opaque purchase credentials exchanged for device-bound paid entitlements;
  three-device activation, deactivation, recovery, refund, and delivery-outbox
  contracts.
- Default-off native telemetry and website analytics with withdrawal.
- Auth0-compatible owner-only dashboard sessions and audited mutations.
- Sparkle 2.9.2 stable-channel integration, immutable release manifest,
  signed-appcast tooling, and Sparkle-aware packaging verification.
- Desktop/mobile/zoom/reflow browser gates and deterministic showcase media at
  no more than five seconds.

Repository implementation is not proof that the production services or signed
artifact have been configured successfully.

## Production infrastructure

1. Provision isolated production Postgres, rate-limit storage, Resend, Auth0,
   AWS KMS, Vercel, WAF, and backup/restore operations.
2. Apply `website/db/migrations/001_commerce_lifecycle.sql` twice and verify the
   second application is idempotent.
3. Configure the variables documented in `website/.env.example`; production
   must not contain trial/license private PEM variables.
4. Provision separate P-256 trial and license KMS keys. Restrict the
   production Vercel OIDC role to `kms:Sign` and `kms:GetPublicKey` on those
   exact keys.
5. Configure Auth0 callback/logout URLs, the exact owner subject, and tenant
   MFA set to Always.
6. Configure Lemon Squeezy webhooks at
   `https://cmdtab.net/api/lemonsqueezy/webhook`, Resend sender validation,
   operational support/refund mailboxes, and the internal outbox worker.

## Required sandbox customer lifecycle

Using Lemon Squeezy test mode and disposable customer data, prove without
manual database edits:

1. Website discovery and hosted checkout.
2. Webhook persistence, fulfillment email, immutable download instructions,
   and opaque activation credential delivery.
3. Installation, onboarding, trial start, clock-safe local use, and purchase.
4. Activation on three named Macs; fourth distinct activation returns
   `slot_full`.
5. Deactivation frees a slot immediately; recovery remains enumeration-safe.
6. Partial refund preserves access; full refund and authoritative revocation
   prevent recovery.
7. N-to-N+1 signed update succeeds from the published stable appcast.

## Developer ID and update release

Follow `docs/release/signed-update-runbook.md`.

1. Install the intended Developer ID Application identity and reconcile its
   Team ID with `net.cmdtab.CmdTab`.
2. Configure a protected `notarytool` profile and Sparkle EdDSA public key.
3. Run `scripts/release/build-notarized-dmg.sh`.
4. Retain notarization JSON, stapler validation, nested signature checks,
   Gatekeeper assessment, manifest, and DMG checksum.
5. Upload the immutable DMG, commit/deploy its exact `release/stable.json`,
   verify `/trial` and `/releases/stable.json`, then publish the appcast last.
6. Never roll clients back to a lower build; publish reverted code as a newly
   signed higher build.

## Hardware and performance acceptance

- Run clean-install and N-to-N+1 update tests on current Apple Silicon and
  Intel hardware for the supported macOS range.
- Run `scripts/performance/run-performance-evidence.sh --mode acceptance` on
  each accepted hardware class.
- Retain exact-SHA evidence for 10/25/50-window runs and the 1,000-session soak.
- Mark unavailable hardware, permissions, credentials, or service evidence
  `NOT TESTED`; never infer it from unit tests or source inspection.

## Public-launch gate

Public launch is allowed only when repository automation passes on the exact
candidate and every production, Apple, commerce, mailbox, clean-hardware,
update, backup/restore, and live-domain item above has retained evidence.
