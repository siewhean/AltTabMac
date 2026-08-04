# G8 CI Record — 2026-08-04

## Exact candidate

- **SHA:** `2bcb2275b41cc6712dec8abcb2a4b62f3569143c`
- **PR:** #49 (draft)
- **Event:** pull request to `main`

## Executed hosted evidence

| Workflow | Run | Result |
| --- | --- | --- |
| Release Readiness | [`30884018506`](https://github.com/siewhean/AltTabMac/actions/runs/30884018506) | PASS — repository health, website security/SEO/GEO/browser QA, macOS 14 and macOS 15 jobs executed |
| Security | [`30884018492`](https://github.com/siewhean/AltTabMac/actions/runs/30884018492) | PASS — executed `website-security` job |
| SEO and GEO | [`30884018515`](https://github.com/siewhean/AltTabMac/actions/runs/30884018515) | PASS — executed verifier job |
| Swift | [`30884018493`](https://github.com/siewhean/AltTabMac/actions/runs/30884018493) | PASS — `macos-14` and `macos-15` jobs executed |
| Workflow Health | [`30884018553`](https://github.com/siewhean/AltTabMac/actions/runs/30884018553) | PASS — hosted-runner health executed |
| Audit Source Export | [`30884018524`](https://github.com/siewhean/AltTabMac/actions/runs/30884018524) | PASS — retained one-day private archive executed |
| Vercel | PR #49 status check | PASS — preview check completed |

Security and Audit Source Export run for each candidate change. The export is
bound to the submitted PR head and its approved one-day retention is preserved.
This record deliberately does not classify a zero-step historical run as a
pass.

## Issue #30 and remaining controls

Issue #30 remains open as a historical quota/capacity remediation record. The
runs above show capacity has been restored; the issue is not closed here
because it needs owner review and its acceptance text has not been reconciled.
The branch-protection endpoint returned `404 Branch not protected`; trusted
release-environment controls are likewise not configured.

## Operational-controls evidence refresh

The source commit `5c6bf288baae9f20bc5b43e5ddfe351539b4a08d` and its
documentation/evidence head `db78652ee357352b1ad77959e37a00625f912f84` passed
the following executed checks: Swift macOS 14/15, Security, SEO and GEO,
Release Readiness (including website/browser QA), Workflow Health, Audit Source
Export, and Vercel. The PR remained a clean draft. Independent QA/QC reviewed
the combined `5c6bf28` + `db78652` diff and the hosted logs; no repository-owned
release boundary breach was found. These runs do not make the later documentation
commit an artifact or signed-app candidate.

## Status and next action

**PASS for executed CI capacity at this exact SHA; G8 remains BLOCKED.**
Owner-controlled branch protection, required checks, trusted release
environment, and an intentional action SHA-pinning policy must be configured
and evidenced. A later source SHA must rerun the listed workflows.
