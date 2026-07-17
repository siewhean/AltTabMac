#!/usr/bin/env python3
"""Synchronize canonical project docs with the validated switcher repair."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(relative_path: str, old: str, new: str) -> None:
    path = ROOT / relative_path
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(
            f"Expected exactly one match in {relative_path}, found {count}:\n{old}"
        )
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_once(
    "README.md",
    """Last Updated: 2026-04-02
Active Task: App-side licensing flow with local trial enforcement, signed license activation, and direct buy/help entry points.
""",
    """Last Updated: 2026-07-17
Active Task: Strict global window MRU, complete switcher membership, activation truth, and live macOS release QA.
""",
)

replace_once(
    "README.md",
    """- The visible list now forces the most recent different app to the front, even when extra windows from the current app are still in the snapshot.
- Frontmost ordering now uses a short-lived validated override after a switch, instead of permanently assuming the selected app became frontmost.
""",
    """- The visible list now follows one global exact-window MRU sequence; same-application windows are neither grouped nor skipped during initial forward or reverse selection.
- The current exact window remains visible at the end of the ordered sequence, and ambiguous multi-window frontmost PIDs resolve from the immutable history snapshot.
- A short-lived provisional frontmost override makes immediate re-presses deterministic without changing permanent MRU before activation is confirmed.
""",
)

replace_once(
    "README.md",
    """- Candidate window enumeration now deduplicates repeated CG entries by real window identity, preventing duplicate non-window tiles for the same underlying window from appearing in the switcher.
- Local verification passed with `swift test --scratch-path /tmp/CmdTab-test`, `npm run typecheck`, and `npx next build --webpack`.
""",
    """- Candidate window enumeration now deduplicates repeated CG entries by real window identity, preventing duplicate non-window tiles for the same underlying window from appearing in the switcher.
- Eligible window membership no longer depends on screenshot success; preview failures now degrade to the existing icon/placeholder presentation instead of removing the tile.
- Fallback items are process-scoped, so two regular processes sharing a bundle identifier cannot hide each other.
- New installations default to unlimited windows per application; an existing user-configured cap is still respected.
- Accessibility focused-window observers now capture A1 → A2 changes inside one already-frontmost app, with exact session-start reconciliation as a safety net.
- Candidate and visible-item ordering use one immutable history snapshot per operation rather than repeated mutable rank reads from a sort comparator.
- Activation retry exhaustion is recorded as failure rather than success, and fallback activation prefers focused/main standard windows before arbitrary AX array order.
- Focused strict-MRU/completeness regressions and the complete 123-test SwiftPM suite passed on a macOS 15.7.7 arm64 GitHub runner; permanent macOS 14/15 Swift CI now protects the path.
- The implementation review, reproducible model evidence, and exact 136-case QA matrix live under `docs/qa/`.
- Existing website verification remains `npm run typecheck` plus `npx next build --webpack`.
""",
)

replace_once(
    "README.md",
    """## Open Issues / Next Steps

- Rebuild and manually validate after each change set.
""",
    """## Open Issues / Next Steps

- Complete the P0 live switcher matrix in `docs/qa/AltTabMac_comprehensive_test_matrix.csv` before merging this repair.
- Manually prove exact focused `CGWindowID` activation for keyboard, modifier-release, and mouse commits, including same-title sibling windows.
- Manually validate Accessibility and Screen Recording denied/granted/revoked transitions; automated SwiftPM tests cannot grant or revoke these permissions.
- Manually validate current/visible/all-Spaces behavior, native fullscreen Spaces, Stage Manager, and off-Space exact activation.
- Manually validate single-display, multi-display, mixed-scale, display disconnect/reconnect, and mirrored `All Displays` behavior.
- Manually validate rapid re-press timing, secure-input interference, event-tap recovery, sleep/wake, and the packaged signed/ad-hoc release bundle.
- `.gitignore` now prevents future generated build output; existing historical tracked `.build` artifacts were not mass-deleted in this focused repair because that would create a large unrelated diff.
- Rebuild and manually validate after each change set.
""",
)

replace_once(
    "README.md",
    """## Recent Changes Log

- 2026-03-28: Added an interactive switcher simulator to the website walkthrough.
""",
    """## Recent Changes Log

- 2026-07-17: Repaired complete membership, strict global window MRU, exact focus history, and activation truth.
  - Preview capture failure no longer removes eligible windows, and process-scoped fallbacks cover regular apps without emitted windows.
  - Forward/reverse session start now follows the displayed exact-window sequence rather than scanning for a different PID.
  - Added AX focused-window observation, immutable history snapshots, ambiguous-PID resolution, provisional rapid-repress state, verified-only MRU confirmation, and safer fallback activation.
  - Added focused acceptance regressions, a reproducible exhaustive model, the exact 136-case QA matrix, permanent macOS 14/15 Swift CI, and generated-artifact ignores.
  - Automated macOS 15 arm64 verification passed all focused tests, all 123 SwiftPM tests, and `git diff --check`; live permissions, Spaces, displays, private-API activation, and packaged-app QA remain explicit pre-merge work.
- 2026-03-28: Added an interactive switcher simulator to the website walkthrough.
""",
)

old_todo = """## 2026-07-17 — Switcher MRU, Completeness, And Activation Reliability

### Phase 1 — Contract And Regression Baseline

- [x] Create `agent/fix-switcher-mru-completeness` from `main`.
- [ ] Add the implementation review, exhaustive test matrix, model checker, and model results to the repository.
- [ ] Add focused red tests for preview-independent membership, strict global window MRU, and ambiguous frontmost resolution.
- [ ] Define the protected acceptance invariants in code comments and test names before changing production behavior.

### Phase 2 — Complete And Stable Membership

- [ ] Decouple switcher membership from preview-capture success so every eligible window remains visible as a placeholder when capture fails.
- [ ] Calculate fallback suppression from emitted window items rather than raw candidates.
- [ ] Default `Max windows per application` to unlimited for new installations.
- [ ] Preserve existing explicit exclusions, title filters, visibility scopes, and user-configured caps.

### Phase 3 — Strict Global Window MRU

- [ ] Remove PID-based initial-selection skipping so forward and reverse switching follow the displayed global window sequence exactly.
- [ ] Resolve ambiguous multi-window frontmost PIDs from the immutable MRU history snapshot.
- [ ] Reconcile the exact focused window at session start.
- [ ] Track same-application focused-window changes through Accessibility notifications where permission is available.
- [ ] Capture one history snapshot for each ordering operation instead of reading mutable history repeatedly from the sort comparator.

### Phase 4 — Activation Truth And Rapid Re-press Safety

- [ ] Establish a short-lived provisional frontmost identity at commit time for deterministic immediate re-presses without prematurely changing permanent MRU.
- [ ] Persist MRU only after the target app/window is verified as frontmost.
- [ ] Treat retry exhaustion as activation failure rather than success.
- [ ] Prefer focused/main standard windows for app-fallback activation instead of blindly raising the first AX window.

### Phase 5 — Automation, Repository Hygiene, And Release Evidence

- [ ] Add a macOS GitHub Actions workflow for `swift test` on switcher-related changes.
- [ ] Ignore Swift build, index, app-bundle, dSYM, and Finder metadata artifacts.
- [ ] Run focused tests, then the full SwiftPM test suite on macOS CI.
- [ ] Inspect the final branch diff and open a draft PR with explicit validation and remaining manual macOS QA.
- [ ] Update `README.md`, this file, and `tasks/lessons.md` with the completed work and evidence.

### Acceptance Invariants

- Every eligible top-level application window produces one unique switcher item.
- A regular running app with no eligible window produces exactly one fallback item.
- Preview availability affects presentation only and never changes membership.
- Exact window identities form one global MRU sequence; windows are never grouped or skipped by PID or bundle.
- The current exact window remains in the list but is moved to the end for cycling.
- Forward selection uses the first ordered item; reverse selection uses the adjacent prior item.
- Permanent history changes only after verified activation.
- Explicit preferences are the only accepted source of intentional omission.
"""

new_todo = """## 2026-07-17 — Switcher MRU, Completeness, And Activation Reliability

### Phase 1 — Contract And Regression Baseline

- [x] Create `agent/fix-switcher-mru-completeness` from `main`.
- [x] Add the implementation review, exhaustive test matrix, model checker, and model results to the repository.
- [x] Add focused regressions for preview-independent membership, strict global window MRU, and ambiguous frontmost resolution.
- [x] Define the protected acceptance invariants in code comments and test names before changing production behavior.

### Phase 2 — Complete And Stable Membership

- [x] Decouple switcher membership from preview-capture success so every eligible window remains visible as a placeholder when capture fails.
- [x] Calculate fallback suppression from emitted window items rather than raw candidates.
- [x] Keep fallback identities distinct by running PID rather than bundle identifier.
- [x] Default `Max windows per application` to unlimited for new installations.
- [x] Preserve existing explicit exclusions, title filters, visibility scopes, and user-configured caps.

### Phase 3 — Strict Global Window MRU

- [x] Remove PID-based initial-selection skipping so forward and reverse switching follow the displayed global window sequence exactly.
- [x] Resolve ambiguous multi-window frontmost PIDs from the immutable MRU history snapshot.
- [x] Reconcile the exact focused window at session start.
- [x] Track same-application focused-window changes through Accessibility notifications where permission is available.
- [x] Capture one history snapshot for each ordering operation instead of reading mutable history repeatedly from the sort comparator.

### Phase 4 — Activation Truth And Rapid Re-press Safety

- [x] Establish a short-lived provisional frontmost identity at commit time for deterministic immediate re-presses without prematurely changing permanent MRU.
- [x] Persist MRU only after the target app/window is verified as frontmost.
- [x] Treat retry exhaustion as activation failure rather than success.
- [x] Prefer focused/main standard windows for app-fallback activation instead of blindly raising the first AX window.

### Phase 5 — Automation, Repository Hygiene, And Release Evidence

- [x] Add a permanent macOS 14/15 GitHub Actions workflow for model, focused, and full Swift verification.
- [x] Ignore future Swift build, index, app-bundle, dSYM, and Finder metadata artifacts.
- [x] Run focused tests, then the complete SwiftPM suite on macOS.
- [x] Open draft PR #10 with explicit automated validation and remaining manual macOS QA.
- [x] Update `README.md`, this file, and `tasks/lessons.md` with the completed work and evidence.
- [ ] Execute and attach the P0 live desktop rows from the 136-case matrix before merge.

### Automated Review Evidence

- The assertion-based protected-core repair applied cleanly on macOS 15.7.7 arm64.
- `StrictMRUAndCompletenessRegressionTests`: 4 tests passed.
- Complete SwiftPM suite: 123 tests passed after aligning one contradictory legacy fallback expectation with the exact-window contract.
- PID-level fallback follow-up: complete SwiftPM suite passed again.
- `git diff --check` passed for both validated repair phases.
- The exact CSV matrix contains 136 unique rows with every required field populated; SHA-256 is `62d8d636648d2afc0e5d22d21f114b7aaaaf54403cead8705acf76691341432f`.
- Permanent macOS 14/15 CI is configured in `.github/workflows/swift.yml`.
- Live Accessibility, Screen Recording, Spaces, fullscreen, Stage Manager, multi-display, secure-input, sleep/wake, private-API focus, and packaged-app QA remain pending and are not represented as automated passes.
- Existing tracked historical `.build` artifacts remain outside this focused code diff; `.gitignore` prevents new generated output from being added accidentally.

### Acceptance Invariants

- Every eligible top-level application window produces one unique switcher item.
- A regular running process with no eligible window produces exactly one fallback item.
- Preview availability affects presentation only and never changes membership.
- Exact window identities form one global MRU sequence; windows are never grouped or skipped by PID or bundle.
- The current exact window remains in the list but is moved to the end for cycling.
- Forward selection uses the first ordered item; reverse selection uses the adjacent prior item.
- Permanent history changes only after verified activation.
- Explicit preferences are the only accepted source of intentional omission.
"""

replace_once("tasks/todo.md", old_todo, new_todo)
print("Finalized README and task documentation.")
