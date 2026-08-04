# Public-Beta Evidence Index

## Identity and decision

| Field | Value |
| --- | --- |
| Candidate baseline | `dcd02faafbe4cd944fa9899d4e5ddcd6d5f70407` |
| Intended tag | `v1.0.0-beta.N` only |
| Public-beta decision | BLOCKED |
| Baseline architecture / minimum OS | arm64 only / macOS 13.0+ |
| Public-beta target architecture | arm64 only; Intel is unsupported |
| Commerce state | Disabled: `CMDTAB_REQUIRE_COMMERCE_READY` unset or not `1` |
| Stable release state | No stable DMG, manifest, or appcast publication |

## Gate 0 draft record - 2026-08-01

| Item | Evidence | Status |
| --- | --- | --- |
| Baseline ancestry | Before Gate 0 documentation changes, `HEAD` was `dcd02fa...`; `git merge-base --is-ancestor dcd02fa HEAD` exited 0 | NOT TESTED - observation captured |
| Worktree preservation | Release worktree uses `release/public-release-readiness`; pre-existing `tasks/todo.md` change was preserved | NOT TESTED - observation captured |
| PR lineage | PR #31, #35, and #40 are merged; PR #40 merge commit is the candidate baseline | NOT TESTED - observation captured |
| Issue #30 | Open historical remediation issue. The later executed `4f714e7` checks demonstrate restored hosted Actions capacity; this replacement candidate still needs its own runs | NOT TESTED |
| Candidate CI | Historical Release Readiness run `30651686577` had four failed jobs with zero steps; it is retained as a non-pass, not as the current capacity state | NOT TESTED (historical failure) |
| Hosted Actions capacity | `4f714e7` later had actual non-zero-step macOS 14/15, Security, SEO/GEO, Release Readiness, Workflow Health, Audit Source Export, and Vercel results | PASS (historical evidence only) |
| Branch protection | GitHub API reports `main` is not protected | BLOCKED |
| Releases/tags | No beta release/tag evidence recorded for the candidate | NOT TESTED |
| Deployment | No candidate-bound Vercel deployment evidence retained in this gate | NOT TESTED |
| Signing/mail/clean machines | Credentials, verified support mailbox, and clean-machine evidence absent | BLOCKED / NOT TESTED |

## Executed-CI refresh - historical `4f714e7`

The draft PR #49 candidate `4f714e70a2d25db0f1b1e0a353a0532df8a98679`
had actual, non-zero-step passes for macOS 14/15, Security, SEO/GEO, Release
Readiness, Workflow Health, Audit Source Export, and Vercel. Earlier
`616a78fd1f29716c2d0183dc8aff792d58d5b1f7` evidence is also historical. The
current Gate 2/Gate 5/Gate 8 correction creates a new candidate SHA that must
receive its own executed checks. Source workflow hardening now runs Security
and Audit Source Export for every candidate change and binds the private
one-day archive to the submitted PR head. This record does not authorize
signing, publication, commerce, or a beta download.

**Gate 0 status:** **PASS (repository governance only).** Its dedicated commit
contains the reconciled ledger, runbooks, matrices, and evidence index. The
independent documentation review on 2026-08-01 corrected baseline architecture,
stable-appcast, and pre-commit-HEAD attribution errors. The external rows above
that require a replacement-candidate run remain blocked or not tested; this is
not evidence that any launch gate passed.

## Historical evidence - do not promote

- [`../phase-0/`](../phase-0/) documents a prior governance pass with a CI
  waiver; it predates the current candidate.
- [`../phase-1/`](../phase-1/) documents host-architecture, local ad-hoc
  packaging at `516a9476...`; it is not signed-beta evidence.
- [`../five-feature-suite/`](../five-feature-suite/) is feature evidence, not
  a signed artifact, clean-machine, or release-operations acceptance record.
- The Gate 0 zero-step CI row above is a 2026-08-01 historical observation,
  not a description of restored Actions capacity or a current candidate result.

## Required per-gate record

Create `G<N>-<short-name>/README.md` plus raw redacted logs/checksums/results.
Each README must list the exact source SHA, commit, changed files, operator,
UTC time, hardware/OS and permissions where relevant, commands and exits,
artifact SHA-256/size, manual observations, risk disposition, independent
QA/QC reviewer, status, and next action. Keep credentials, tokens, private
customer data, and raw personal screenshots out of the repository.

The publication record must bind one immutable source SHA to the signed app,
DMG, checksum, notarization result, beta appcast, beta manifest, Vercel
deployment, manual matrix, CI run IDs, and rollback rehearsal. It is required
before the owner grants go-live approval.
