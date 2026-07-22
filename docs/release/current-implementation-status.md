# CmdTab Native Release — Current Implementation Status

**Updated:** 2026-07-23  
**Canonical long-form plan:** `docs/release/native-production-readiness-plan.md`  
**Current accepted integration commit:** `f37e47029344e191682bd02ade8d7daf4ea241bd`

## Completed phases

### Phase 0 — PASS WITH HOSTED-ACTIONS QUOTA WAIVER

Completed:

- repository-generated output cleanup;
- one-shot showcase motion and Reduce Motion behavior;
- README, metadata, provenance, and task reconciliation;
- Vercel source, dependency, TypeScript, and production-build verification;
- deferred hosted-runner work recorded under issue #30.

Hosted GitHub macOS and browser workflows remain deferred, not passed.

### Phase 1 — PASS

Accepted source commit:

```text
516a9476c01f4d59981f35dc44b6eb09dcd6d790
```

Merged through PR #31:

```text
f37e47029344e191682bd02ade8d7daf4ea241bd
```

Accepted evidence includes:

- permanent bundle identifier `net.cmdtab.CmdTab`;
- deterministic local `.app` assembly;
- empty reviewed entitlement baseline;
- rollback-safe legacy beta migration logic;
- strict bundle, metadata, architecture, resource, checksum, and ad-hoc signature verification;
- byte-for-byte reproducible unsigned builds from the canonical scratch path;
- bundle migration tests: 6/6;
- Arc capture fallback tests: 3/3;
- full Swift package suite: 132/132;
- packaged menu-bar launch and Command-Tab interception;
- permission reset and exact-bundle re-grant behavior;
- Arc real thumbnail and Arc activation.

The complete record is `docs/release/evidence/phase-1/README.md`.

## Active implementation order

The next sequence is:

```text
Phase 1 evidence reconciliation
        ↓
Phase 2 owner prerequisite confirmation
        ↓
Developer ID signing and timestamping
        ↓
Notarization and stapling
        ↓
Gatekeeper and clean-account installation
        ↓
Private API capability providers
        ↓
Full interactive macOS acceptance matrix
        ↓
Signed updates, rollback, diagnostics, and licensing recovery
        ↓
release/native-rc1
```

Optional switcher features do not enter this sequence before the first safe release candidate.

## Active branch boundaries

### Current branch

```text
agent/phase-1-evidence-reconciliation
```

Scope:

- documentation and evidence reconciliation only;
- no production Swift behavior change;
- no release artifact change.

### Next implementation branch

```text
agent/phase-2-developer-id-distribution
```

Do not create `release/native-rc1` until Developer ID signing, notarization, stapling, Gatekeeper, clean-account installation, capability-provider hardening, desktop acceptance, and release recovery have passed.

## Phase 2 owner prerequisites

The following must be confirmed before Phase 2 can be accepted:

- Apple Developer Program membership;
- intended Apple Developer Team ID;
- `net.cmdtab.CmdTab` registered to the intended team;
- valid `Developer ID Application` certificate;
- App Store Connect API credentials or a protected `notarytool` profile;
- first-RC architecture policy;
- restored GitHub Actions allowance and passing issue #30 acceptance criteria.

Local script implementation may begin before hosted capacity returns, but Phase 2 cannot receive a pass while issue #30 remains unresolved.

## Recommended first-RC architecture policy

Use arm64-only for the first release candidate unless Intel users are an explicit supported audience and a Universal Binary is independently built, packaged, signed, notarized, installed, and tested.

Do not infer processor support from the minimum macOS version.

## Release truth rules

- Reproducibility applies to the unsigned input bundle.
- Secure timestamps and notarization metadata may make signed outputs nondeterministic.
- Signed outputs require traceability to the exact unsigned manifest and checksum.
- Ad-hoc QA identity is not a public-distribution identity.
- Website and support claims must match the exact accepted artifact.
- A screenshot is not proof of exact-window activation; the full matrix must record the actual focused `CGWindowID`.

## Parallel website obligation

PR #32 tracks deployment of the already-accepted one-shot showcase source to production. It must not merge while its Vercel result is a build-rate-limit failure. The native Phase 2 implementation may proceed independently, but public production HTML must be reconciled before a release candidate is approved.