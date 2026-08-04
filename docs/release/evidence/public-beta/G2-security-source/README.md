# G2 Security Source-Review Record — 2026-08-04

## Candidate and scope

- **Earlier application-source SHA:**
  `081ec04199885dffb5c7dddd30b6dcd23279bd55`
- **Operational-controls source SHA:**
  `5c6bf288baae9f20bc5b43e5ddfe351539b4a08d`
- **Fresh CI documentation head:**
  `52e7a9d02092e16ce6849599fcbd9d5710e06402`
- **Scope:** native private-capability fallbacks, Screen Recording/preview
  degradation, Secure Input diagnostics, telemetry and privacy manifest,
  beta updater isolation, disabled commerce lifecycle routes, website legal
  disclosures, dependency/secret checks, workflow least privilege, the
  index-backed credential scanner, release preflight, isolated Sparkle tool
  resolution, beta filename binding, and the unavailable `/thank-you` route.

## P0/P1 disposition

| Severity | Disposition |
| --- | --- |
| P0 | No open source P0 found in either reviewed source scope. |
| P1 | Remediated before `081ec041`: Screen Recording cache clearing, reminder authorization before mail/configuration work, observable private-capability fallbacks, fixed aggregate-only telemetry/privacy manifest, fail-closed lifecycle ingress, beta metadata binding, and truthful unpublished-beta copy. No new P1 was found in `5c6bf28`. |
| Signed/real-machine P0/P1 classes | Still unresolved evidence, not waived: permissions/TCC transitions, Developer-ID entitlements/Hardened Runtime, notarization, deployed service configuration, and clean-machine observation. |

## Evidence and QA/QC

The combined source suite reported 285 Swift tests, release-update pipeline,
workflow-action, repository-hygiene, website security/API/SEO/build/retrieval,
and browser checks passing. PR #49 then executed actual macOS 14/15, Security,
SEO/GEO, Release Readiness, Workflow Health, Audit Source Export, and Vercel
checks for the stated candidate heads. Independent QA/QC reviewed the combined
diff and hosted logs; the completion is recorded in
[`tasks/todo.md`](../../../../../tasks/todo.md).

The `5c6bf28` review verified the scanner reads index blobs and a blob-bound
allowlist (with only exact line-hash suppressions); preflight checks run before
credential reads/output; Sparkle tools resolve only from paired secure overrides
or an explicit isolated scratch path; beta names bind to numeric bundle
version/build; Security CI is pinned and least privilege; and `/thank-you` has
no reachable commerce delivery/activation sink. No commerce or telemetry
source/sink was changed by that commit.

## Status and next action

**PASS (repository source review only) for `081ec041` and `5c6bf28`; fresh CI
is green through `52e7a9d`.** Gate 2 remains **BLOCKED** until the final signed
artifact is audited on real machines through all permission states. This record
does not establish Developer ID/Hardened Runtime inspection, notarization,
TCC transitions, deployed-service configuration, or clean-machine behavior.
