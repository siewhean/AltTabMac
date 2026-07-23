# Five-Feature Production Suite Evidence

**Branch:** `agent/five-feature-production-suite`  
**Pull request:** #35  
**Decision:** **SOURCE IMPLEMENTATION COMPLETE / EXACT-HEAD MACOS ACCEPTANCE PENDING**

This directory records the source-side implementation boundary for CmdTab's five-feature production suite. It does not convert unexecuted macOS behaviour into a pass. PR #35 remains draft until an exact branch head produces `AUTOMATED_PASS` and the packaged-app matrix is completed against the same artifact.

## Implemented product surface

### Minimized windows

- Accessibility catalogue keyed by exact `(PID, CGWindowID)`;
- opt-in minimized membership globally and per profile;
- synthesized exact tiles for eligible minimized windows omitted from the public Core Graphics catalogue;
- fallback suppression and post-synthesis per-app cap enforcement;
- exact unminimize, focus verification, and MRU update only after success;
- visible and accessible Minimized state in all three profile styles;
- previewless safe fallback instead of silent membership loss.

### Spaces, fullscreen, displays, and Stage Manager

- serialized capability-detected managed-space provider;
- exact managed-space membership, current Space IDs, display identity, and fullscreen Space classification where symbols are available;
- managed-space preparation before exact activation when supported;
- explicit `available`, `degraded`, `unavailable`, and `failed` states;
- Stage Manager active/hidden state identified as inferred rather than falsely presented as exact;
- visible workspace-capability banner and sanitized Diagnostics;
- debounced display-topology and wake refresh.

### Shortcut profiles

- versioned recorded-shortcut and profile documents;
- Command-Tab and Option-Tab defaults;
- forward/reverse shortcuts, hold-release and press-toggle sessions;
- per-profile style, visibility, minimized policy, display placement, and app filter;
- duplicate, reserved, unsafe Command-only, modifierless-character, empty Include Only, and no-enabled-profile validation;
- immutable configuration for the life of a visible session;
- native AppKit recorder that suspends global shortcut routing while recording;
- Secure Event Input pass-through and stale-overlay cancellation;
- native/system shortcut pass-through when licensing does not allow CmdTab handling;
- Accessibility event-tap installation retry and timeout recovery;
- installed-app picker, manual bundle-ID editing, deterministic export, atomic validated import, Save/Revert, and Save/Discard/Cancel close handling;
- unambiguous legacy bundle-ID exclusions carried into newly created default profile filters.

### Durable exact-window MRU

- exact session identity remains `(PID, CGWindowID)`;
- durable privacy-minimised fingerprints use hashes rather than raw title or document URL;
- ambiguity rejection, one-to-one matching, expiry, and current-session precedence;
- atomic owner-only persistence;
- externally observed exact focus changes enriched off the main thread;
- pending writes flushed on deliberate termination;
- user reset and sanitized diagnostics with no account-specific home path.

### Exact-window actions

- restore, zoom/maximize, fullscreen, next display, center, halves, thirds, and confirmed force quit;
- exact AX target resolution and capability checks;
- unsupported actions disabled with explanations;
- destination-visible-frame constraints and readback verification;
- deterministic membership refresh after success;
- right-click action hint exposed in every profile style.

## Performance and reliability boundaries implemented

- Accessibility/workspace enrichment runs on a coalescing serial background queue;
- stale enrichment results are discarded by generation and profile configuration;
- opening the switcher returns an immutable cached or safe Phase 1 provisional snapshot immediately;
- focused-window durable metadata enrichment no longer performs the whole AX catalogue walk on the main thread;
- private workspace calls are serialized and status reads are lock-protected;
- recorder, Secure Input, licensing, and passed-through key-up pairs cannot be swallowed by the profile router;
- display/wake observers remove tokens from their owning notification centers.

## Verification infrastructure

The branch contains:

```text
scripts/release/verify-five-feature-source.py
scripts/release/run-five-feature-qa.sh
scripts/release/build-windowlab-fixture.sh
scripts/release/build-windowprobe-fixture.sh
Tests/Fixtures/WindowLab/main.swift
Tests/Fixtures/WindowProbe/main.swift
```

The focused automated groups are:

```text
MinimizedWindowPolicyTests
WorkspaceProviderModelTests
SwitcherProfileTests
SwitcherProfileSafetyTests
SwitcherSessionConfigurationFreezeTests
DurableSwitcherHistoryTests
WindowManagementActionTests
ProductionMembershipPolicyTests
ProductionVisualStateTests
FiveFeatureIntegrationTests
```

The one-command gate also runs the complete Swift suite and the Phase 1 deterministic packaging/reproducibility regression.

## Required exact-head automated evidence

On the target Mac:

```bash
python3 scripts/release/verify-five-feature-source.py
bash scripts/release/run-five-feature-qa.sh
```

The run must create:

```text
dist/five-feature-evidence/result.txt
dist/five-feature-evidence/commit.txt
dist/five-feature-evidence/commands.log
dist/five-feature-evidence/manual-checks.md
dist/five-feature-evidence/windowlab-checksums.txt
dist/five-feature-evidence/windowprobe-checksum.txt
```

Required automated result:

```text
AUTOMATED_PASS
```

`commit.txt` must equal `git rev-parse HEAD` exactly. A pass from an earlier head is not transferable to a later polish commit.

## Required packaged-app evidence

The generated `manual-checks.md` is authoritative. It requires real observations for:

- minimized eligibility, exact restore, sibling preservation, fallback suppression, and per-app cap;
- current/visible/all Spaces, off-Space activation, fullscreen, Stage Manager inference, mixed-scale displays, disconnect/reconnect, and sleep/wake;
- profile isolation, forward/reverse, hold/toggle, recording, Secure Input, licensing pass-through, immutable active sessions, import/export, installed-app filtering, and unsaved-close handling;
- durable restart matching, duplicate-title ambiguity, reused IDs, failed activation, file privacy/mode, and reset;
- every exact-window action and unsupported state;
- visible state badges, VoiceOver state, capability degradation, Diagnostics, event-tap recovery, Launch at Login, and a mixed-feature stress run.

WindowProbe must record the actual focused PID and `CGWindowID` for activation-sensitive rows. A screenshot or apparent foreground window is insufficient evidence.

## Current blockers to merge

- no exact-head source/Swift/package PASS has been supplied after the latest production-polish commits;
- no packaged-app matrix has been completed;
- no objective WindowProbe focus log has been reviewed;
- no macOS-version and real workspace/Stage Manager evidence has been supplied;
- GitHub Actions capacity remains a separate repository release-control issue.

## Merge rule

Do not mark PR #35 ready, merge it into `main`, merge it into the Developer ID branch, or copy selected files into another branch until all applicable rows pass on one exact head. If a source fix is made after testing, rerun the complete automated and packaged-app gates.
