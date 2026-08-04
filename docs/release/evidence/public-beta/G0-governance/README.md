# G0 Governance Record — 2026-08-04

## Scope and identity

- **Baseline:** `dcd02faafbe4cd944fa9899d4e5ddcd6d5f70407`
- **Governance/evidence candidate:**
  `2bcb2275b41cc6712dec8abcb2a4b62f3569143c`
- **PR:** #49, draft, base `main@dcd02fa...`; head was clean and mergeable
  when queried.
- **Changed governance surfaces:** `README.md`, canonical release status and
  gate ledger, public-beta evidence index, task ledger, and security checklist.

## Evidence

| Check | Command or source | Result |
| --- | --- | --- |
| Baseline ancestry | `git merge-base --is-ancestor dcd02fa HEAD` before this record | PASS (recorded at Gate 0) |
| PR state | `gh pr view 49 --json isDraft,headRefOid,baseRefOid,mergeStateStatus,statusCheckRollup` | PASS — draft, clean, exact head recorded above |
| Branch protection | `gh api repos/siewhean/AltTabMac/branches/main/protection` | BLOCKED — GitHub returned `404 Branch not protected` |
| Actions capacity | exact `2bcb227` runs in [`../G8-ci/`](../G8-ci/) | PASS — non-zero-step hosted jobs |

## QA/QC and disposition

Independent QA/QC reviewed the combined operational candidate and its hosted
logs before this reconciliation; the task ledger records that review as passed.
This G0 record is **PASS (repository governance only)**. It does not close
branch protection, release environment, signing, machine, support, update,
soak, or go-live evidence.

**Next action:** configure branch protection and trusted release environment
under owner control; then retain a new exact-candidate record after each source
change.
