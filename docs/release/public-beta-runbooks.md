# CmdTab Public-Beta Operating Runbooks

These are release controls, not proof that the associated service is already
available. Every execution records the candidate/artifact SHA, UTC timestamps,
operator, redacted command/log locations, result, and follow-up in the public
beta evidence index.

## Support and license recovery

**Precondition:** `support@cmdtab.net` has successful inbound and outbound
send-and-reply evidence, an accountable owner, and access recovery. Until then
the public beta is blocked; do not replace the currently documented disclosure
address by assertion.

1. Triage security reports privately; do not request activation credentials or
   secret material by email.
2. For license recovery, verify the account through the production recovery
   flow without disclosing whether an address has a license; use the audited
   dashboard only after authorization.
3. Record a minimal case ID, request type, action, and disposition. Do not put
   license tokens, full payment data, window titles, screenshots, or secrets in
   support notes.
4. Escalate suspected compromise, revocation/refund conflicts, delivery loss,
   or inaccessible recovery to the incident owner; preserve evidence.

## Security incident

1. Declare severity, appoint an incident lead, preserve immutable logs and
   artifact/source hashes, and stop nonessential changes.
2. Contain: withdraw beta appcast/download if affected, disable exposed
   endpoint/credential, and prevent further payment or issuance. Do not erase
   evidence.
3. Rotate/revoke affected credentials, remediate, independently review, and
   reproduce the release/security checks before restoration.
4. Assess impact and notification obligations with the owner/legal adviser;
   publish only verified facts. Close with root cause, corrective action, and
   a dated evidence reference.

## Monitoring and beta withdrawal

Before publication, name the monitored owners and verify access to GitHub,
Vercel, mail, updater hosting, and error/availability logs. At 1 hour, 1 day,
3 days, and 1 week record feed/manifest/download HTTP status and cache headers,
artifact checksum, support/incident volume, update failures, and availability.

To withdraw: first remove or invalidate the beta appcast/manifest from public
delivery, then remove the beta download/CTA and restore the prior known-good
deployment. Retain the prior beta artifact and signed higher-build recovery
path. Never downgrade clients to a lower build.

## Backup and restore

Before enabling any production data, assign backup owner, encrypted location,
retention, access control, RPO/RTO, and restore approver. Perform a timed
restore into isolated infrastructure; verify migrations, lifecycle rows,
revocation tombstones, outbox idempotency, recovery safety, and audit data.
Record the restore SHA/time/result. No backup policy without a restore exercise
is a release pass.

## AWS KMS rotation or compromise

1. Stop affected signing/issuance and identify key IDs, callers, time window,
   and affected token generations; preserve CloudTrail/KMS evidence.
2. On suspected compromise, disable/revoke the affected key according to the
   owner-approved incident response, create a replacement under least privilege,
   and rotate public keyrings through a signed compatible release.
3. Keep verification for previously issued valid tokens only when security
   assessment permits it; use server-side revocation/tombstones for invalid
   licenses. Never export production private key material.
4. Test issuance, verification, rollback compatibility, IAM boundaries, and
   recovery before closing. Record the key IDs and results, never secret data.

## Commerce GA transition - explicitly out of beta scope

Do not set `CMDTAB_REQUIRE_COMMERCE_READY=1` for this beta. GA requires a
separate approved change with production Postgres migration/idempotency,
least-privilege KMS, Lemon Squeezy test lifecycle, verified sender/domain
mailboxes, webhook/retry/outbox proof, three-device/recovery/refund/revocation
tests, backup/restore, fraud/chargeback handling, legal copy, and explicit
commerce go-live approval. Re-run the disabled-path test after any change so
the beta cannot accidentally take payment.

## Privacy manifest decision

The 2026-08-04 review uses Apple's [privacy-manifest guidance](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files),
[macOS bundle placement guidance](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk),
and [required-reason API guidance](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).
Collected-data declarations are relevant across Apple platforms; Apple documents
required-reason API declarations and App Store Connect enforcement separately
for the listed iOS-family distribution paths. Direct Developer-ID distribution
does not remove the need for a truthful bundle decision.

CmdTab therefore packages `Resources/PrivacyInfo.xcprivacy` into
`Contents/Resources/PrivacyInfo.xcprivacy` and validates it during packaging
and bundle verification. It declares opt-in, aggregate-only native telemetry:
event name/time, license state without a license identifier, app version, and
macOS version. It declares no tracking and no unreviewed required-reason API.
The native/server contract is closed to identifiers, local window content,
previews, screenshots, tokens, secrets, and metadata. Before Gate 3, recheck
the final SDK and every embedded dependency against current Apple guidance and
bind the exact signed bundle and manifest hash to the evidence record.

## Known beta limitations

- `arm64` only; Intel and macOS below 13 are unsupported.
- No GA/stable download, appcast, purchase, or commerce fulfillment.
- Developer ID, notarization, clean-machine, beta-update, permission,
  multi-display/Spaces/fullscreen/Stage Manager, and performance evidence are
  incomplete until their gate records say `PASS`.
- Private macOS capabilities can change across OS releases; absent capability
  evidence must surface degraded behavior rather than be represented as support.
- No support response-time promise. The product must not claim continuous
  availability or a tested configuration that lacks retained evidence.
