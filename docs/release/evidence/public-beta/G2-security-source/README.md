# G2 Security Source-Review Record — 2026-08-04

## Candidate and scope

- **Application-source SHA:**
  `081ec04199885dffb5c7dddd30b6dcd23279bd55`
- **Scope:** native private-capability fallbacks, Screen Recording/preview
  degradation, Secure Input diagnostics, telemetry and privacy manifest,
  beta updater isolation, disabled commerce lifecycle routes, website legal
  disclosures, dependency/secret checks, and workflow least privilege.

## P0/P1 disposition

| Severity | Disposition |
| --- | --- |
| P0 | No open source P0 found in the candidate static audit. |
| P1 | Remediated before the candidate: Screen Recording cache clearing, reminder authorization before mail/configuration work, observable private-capability fallbacks, fixed aggregate-only telemetry/privacy manifest, fail-closed lifecycle ingress, beta metadata binding, and truthful unpublished-beta copy. |
| Signed/real-machine P0/P1 classes | Still unresolved evidence, not waived: permissions/TCC transitions, Developer-ID entitlements/Hardened Runtime, notarization, deployed service configuration, and clean-machine observation. |

## Evidence and QA/QC

The combined source suite reported 285 Swift tests, release-update pipeline,
workflow-action, repository-hygiene, website security/API/SEO/build/retrieval,
and browser checks passing. PR #49 then executed actual macOS 14/15, Security,
SEO/GEO, Release Readiness, Workflow Health, Audit Source Export, and Vercel
checks for this SHA. Independent QA/QC reviewed the combined diff and hosted
logs; the completion is recorded in [`tasks/todo.md`](../../../../../tasks/todo.md).

## Status and next action

**PASS (repository source review only).** Gate 2 remains **BLOCKED** until the
final signed artifact is audited on real machines through all permission states.
The later operational-controls candidate
`5c6bf288baae9f20bc5b43e5ddfe351539b4a08d` is local-verified only and needs a
replacement independent source review and executed hosted CI rather than
inheriting this record.
