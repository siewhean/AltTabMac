# CmdTab Public-Beta Release Status

**Updated:** 2026-08-04
**Candidate baseline:** `origin/main@dcd02faafbe4cd944fa9899d4e5ddcd6d5f70407`
**Canonical gate ledger:** [`public-beta-readiness.md`](public-beta-readiness.md)

## Release decision

**Public beta: BLOCKED.** The repository has a deterministic local packaging
baseline and a fail-closed commerce boundary, but it has not produced a
Developer-ID-signed, notarized, stapled, clean-machine-tested beta artifact.
No public download, beta appcast, checkout, fulfillment, or outbox processing
is authorized from this baseline.

## Repository truth at the candidate baseline

- The app identity is `net.cmdtab.CmdTab`; the declared minimum macOS version
  is 13.0. This release branch has a verified `arm64-only` packaging policy
  and two byte-identical unsigned packages from distinct scratch directories.
  Intel remains unsupported and must not be claimed.
- The accepted Phase 1 record is historical evidence for
  `516a9476...`/PR #31: host-architecture local ad-hoc packaging and
  byte-repeatability on one Mac. It does not prove the current candidate,
  Developer ID distribution, notarization, beta updates, or Intel support.
- Commerce source implements licensing, refund/revocation, webhooks, and an
  outbox, but current launch control is fail-closed: when
  `CMDTAB_REQUIRE_COMMERCE_READY` is absent or not exactly `1`, checkout is
  hidden; trial, license, recovery, device, and license-help routes return
  generic `503 commerce_disabled` before rate limits, body parsing, database,
  KMS, or email work; webhooks return `503 commerce_disabled`; and workers
  no-op before opening commerce infrastructure.
- The next draft candidate packages a beta-only Sparkle feed at
  `https://cmdtab.net/releases/beta/appcast.xml`. The stable web manifest and
  appcast routes remain `503` with `no-store` until GA. The repository can
  prepare beta metadata only. Its prerelease label is bound to the numeric
  short bundle version and build in the mounted notarized DMG before a beta
  manifest and appcast are emitted; it has not published an appcast, manifest,
  DMG, or download.
- Dynamic SkyLight/SLS/CGS, `_AXUIElementGetWindow`, and Secure Input calls
  remain intentionally scoped native capabilities. Their source contract now
  requires an observable sanitized status, explicit fallback/degraded state,
  and regression coverage. Real-machine observation remains required.

## Security remediation and remaining acceptance boundary

The source static audit found no P0. Repository-owned corrections now include
Screen Recording denial cache clearing, pre-lookup reminder-worker bearer
validation, observable native private-capability fallback states, and beta copy
with no payment offer or personal-Gmail contact. Native telemetry is opt-in,
uses an intentionally fixed five-field aggregate-only wire contract, and the
package verifier requires its matching privacy manifest. These are source-level
controls, not signed-artifact evidence.

Gate 2 remains blocked on real signed-artifact permission transitions and
clean-machine observation. The source P0/P1 disposition and independent
candidate-SHA review are recorded for `081ec041` in
[`SECURITY_CHECKLIST.md`](../../SECURITY_CHECKLIST.md) and the per-gate source
record. The privacy manifest decision is documented in the runbooks and must
be revalidated against the final signed bundle and dependencies. Source tests
do not substitute for those observations.

## Evidence boundaries

The following records are historical and must not be promoted to current-beta
acceptance without an exact-candidate rerun:

- `docs/release/evidence/phase-0/` and `phase-1/`;
- website or Vercel results from earlier branches;
- test totals recorded in old task ledgers or status documents.

The application-source candidate
`081ec04199885dffb5c7dddd30b6dcd23279bd55` has executed, non-zero-step passes
for macOS 14/15, Security, SEO/GEO/browser QA, Release Readiness, Workflow
Health, Audit Source Export, and Vercel. `4f714e7` and `616a78f` are older
historical evidence. GitHub Actions capacity is restored, but `main` remains
unprotected and release-environment controls remain unconfigured. The
documentation-only follow-up `2bcb2275b41cc6712dec8abcb2a4b62f3569143c`
repeated the same hosted source-CI set. Neither record transfers to a later
source candidate. The operational-controls candidate
`5c6bf288baae9f20bc5b43e5ddfe351539b4a08d` and its documentation/evidence head
`db78652ee357352b1ad77959e37a00625f912f84` passed replacement QA/QC and the
executed hosted workflow set. A later source candidate still requires its own
evidence.

## External blockers

- Developer ID identity/team reconciliation, notarization profile, and Sparkle
  public update key;
- verified `support@cmdtab.net` mailbox and operational owners;
- clean Apple-silicon Ventura and current-stable macOS accounts; real beta
  testers for soak/update/rollback proof;
- configured `main` branch protection and a trusted release environment
  (executed GitHub Actions capacity is already evidenced, but these controls
  remain absent);
- explicit beta go-live approval.

See the gate checklist, risk register, evidence contract, and runbooks in
[`public-beta-readiness.md`](public-beta-readiness.md) and
[`public-beta-runbooks.md`](public-beta-runbooks.md).
