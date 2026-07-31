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

## Security remediation and remaining acceptance boundary

The candidate-SHA static audit found no P0. Its four repository-owned P1
findings are remediated: confirmed Screen Recording denial clears every preview
cache; the reminder worker requires a strong bearer secret before lookup; native
private-capability failures are exposed through diagnostics and truthful
fallback status; and beta copy has no payment offer or personal-Gmail contact.

Gate 2 remains blocked on real signed-artifact permission transitions, current
Apple privacy-manifest applicability evidence, and independent candidate-SHA
review. Source tests do not substitute for those observations.

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
