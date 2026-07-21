# Switcher QA Evidence

This directory contains the durable acceptance contract and release evidence for the 2026-07-17 switcher reliability repair.

## Artifacts

- `AltTabMac_implementation_review_and_test_plan.md` explains the reviewed defects, required invariants, architecture recommendations, and critical live macOS procedures.
- `AltTabMac_comprehensive_test_matrix.csv` contains 136 unique test cases across membership, MRU, session input, activation, Spaces/displays, permissions, performance, compatibility, release, and CI.
- `AltTabMac_model_results.json` records the exact pre-fix counterexamples produced by `scripts/qa/switcher_mru_visibility_model_check.py`.

The CSV is committed byte-for-byte from the reviewed matrix:

```text
Size: 33,303 bytes
SHA-256: 62d8d636648d2afc0e5d22d21f114b7aaaaf54403cead8705acf76691341432f
Rows: 136
Unique IDs: 136
```

## Automated execution

The permanent `.github/workflows/swift.yml` workflow runs on macOS 14 and macOS 15 and verifies:

1. reproducibility of the pre-fix model evidence;
2. the focused strict-MRU/completeness regression class;
3. the complete SwiftPM test suite;
4. patch whitespace hygiene.

The protected repair was separately validated on a macOS 15.7.7 arm64 runner before it was committed:

- four focused acceptance tests passed;
- all 123 SwiftPM tests passed;
- the PID-level fallback follow-up passed the complete suite again;
- `git diff --check` passed in both repair phases.

## Manual execution requirement

Automated SwiftPM tests are not evidence that the full macOS desktop experience works. Before this draft PR is merged, execute and attach results for the P0 live rows, especially:

- Accessibility and Screen Recording permission transitions;
- exact selected-versus-focused `CGWindowID` checks;
- same-app focus changes through mouse, Cmd-`, Mission Control, and Stage Manager;
- rapid repeated Cmd-Tab timings;
- fullscreen and off-Space activation;
- single- and multi-display placement/mirroring;
- secure input, event-tap recovery, sleep/wake, and the packaged app bundle.

For every live case, record the macOS version, architecture, display/Space setup, permissions, activation sequence, expected identity list, actual identity list, selected identity, and actual focused PID/window ID. A visual screenshot alone is insufficient proof of ordering or activation correctness.
