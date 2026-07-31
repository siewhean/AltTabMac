# CmdTab Public-Beta Release Status

**Updated:** 2026-08-01
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
  is 13.0. At the candidate baseline, the release configuration is
  `universal-arm64-x86_64` with a stable update channel/feed. Gate 1 must
  change and verify the target `arm64` beta configuration without presenting
  the uncommitted work as baseline evidence.
- The accepted Phase 1 record is historical evidence for
  `516a9476...`/PR #31: host-architecture local ad-hoc packaging and
  byte-repeatability on one Mac. It does not prove the current candidate,
  Developer ID distribution, notarization, beta updates, or Intel support.
- Commerce source implements licensing, refund/revocation, webhooks, and an
  outbox, but current launch control is fail-closed: when
  `CMDTAB_REQUIRE_COMMERCE_READY` is absent or not exactly `1`, checkout is
  hidden, webhooks return `503 commerce_disabled`, and workers no-op before
  opening commerce infrastructure.
- The committed website and release surfaces still describe stable commerce
  and stable updates in places. They require a beta-specific copy/configuration
  pass before public-beta publication; no current source claim is beta-launch
  evidence.
- Dynamic SkyLight/SLS/CGS and `_AXUIElementGetWindow` calls remain in the
  native code. Some capability-status/fallback paths exist, but a fresh
  candidate-SHA audit must establish every private capability's need, failure
  signal, public fallback, truthful UI, and regression coverage.

## Current P1 security blockers

The candidate-SHA static audit found no P0, but the following P1 items block
beta publication until remediated and independently rechecked:

- Screen Recording revocation can retain cached previews of other apps instead
  of clearing them after sustained denial.
- The public trial-reminder cron authorizes execution when `CRON_SECRET` is
  missing, enabling unauthenticated bulk reminder attempts.
- Normal preview, exact-ID, and focus paths still invoke undocumented native
  APIs directly without the required observable provider/degraded boundary.
- Active website copy/navigation still presents a current trial/purchase offer
  and personal-Gmail support contact, contrary to the beta commerce/support
  boundary.

## Evidence boundaries

The following records are historical and must not be promoted to current-beta
acceptance without an exact-candidate rerun:

- `docs/release/evidence/phase-0/` and `phase-1/`;
- website or Vercel results from earlier branches;
- test totals recorded in old task ledgers or status documents.

The latest candidate GitHub runs for Release Readiness, Security, and SEO/GEO
were created but had zero job steps. They are **BLOCKED**, not passing CI.
Issue #30 remains open, and `main` has no branch-protection configuration.

## External blockers

- Developer ID identity/team reconciliation, notarization profile, and Sparkle
  public update key;
- verified `support@cmdtab.net` mailbox and operational owners;
- clean Apple-silicon Ventura and current-stable macOS accounts; real beta
  testers for soak/update/rollback proof;
- restored GitHub Actions capacity with executed logs and protected release
  controls;
- explicit beta go-live approval.

See the gate checklist, risk register, evidence contract, and runbooks in
[`public-beta-readiness.md`](public-beta-readiness.md) and
[`public-beta-runbooks.md`](public-beta-runbooks.md).
