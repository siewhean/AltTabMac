# Public-Beta Evidence Index

## Identity and decision

| Field | Value |
| --- | --- |
| Candidate baseline | `dcd02faafbe4cd944fa9899d4e5ddcd6d5f70407` |
| Intended tag | `v1.0.0-beta.N` only |
| Public-beta decision | BLOCKED |
| Baseline architecture / minimum OS | universal-arm64-x86_64 / macOS 13.0+ |
| Public-beta target architecture | arm64 only; Gate 1 must commit and verify it |
| Commerce state | Disabled: `CMDTAB_REQUIRE_COMMERCE_READY` unset or not `1` |
| Stable release state | No stable DMG, manifest, or appcast publication |

## Gate 0 draft record - 2026-08-01

| Item | Evidence | Status |
| --- | --- | --- |
| Baseline ancestry | Before Gate 0 documentation changes, `HEAD` was `dcd02fa...`; `git merge-base --is-ancestor dcd02fa HEAD` exited 0 | NOT TESTED - observation captured |
| Worktree preservation | Release worktree uses `release/public-release-readiness`; pre-existing `tasks/todo.md` change was preserved | NOT TESTED - observation captured |
| PR lineage | PR #31, #35, and #40 are merged; PR #40 merge commit is the candidate baseline | NOT TESTED - observation captured |
| Issue #30 | Open; hosted Actions capacity remains a release blocker | BLOCKED |
| Candidate CI | Release Readiness run `30651686577` has four failed jobs with zero steps | BLOCKED |
| Branch protection | GitHub API reports `main` is not protected | BLOCKED |
| Releases/tags | No beta release/tag evidence recorded for the candidate | NOT TESTED |
| Deployment | No candidate-bound Vercel deployment evidence retained in this gate | NOT TESTED |
| Signing/mail/clean machines | Credentials, verified support mailbox, and clean-machine evidence absent | BLOCKED / NOT TESTED |

**Gate 0 status:** **PASS (repository governance only).** Its dedicated commit
contains the reconciled ledger, runbooks, matrices, and evidence index. The
independent documentation review on 2026-08-01 corrected baseline architecture,
stable-appcast, and pre-commit-HEAD attribution errors. The external rows above
remain blocked or not tested; this is not evidence that any launch gate passed.

## Historical evidence - do not promote

- [`../phase-0/`](../phase-0/) documents a prior governance pass with a CI
  waiver; it predates the current candidate.
- [`../phase-1/`](../phase-1/) documents host-architecture, local ad-hoc
  packaging at `516a9476...`; it is not signed-beta evidence.
- [`../five-feature-suite/`](../five-feature-suite/) is feature evidence, not
  a signed artifact, clean-machine, or release-operations acceptance record.

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
