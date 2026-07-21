# AltTabMac / CmdTab implementation review and exhaustive switcher test plan

**Reviewed repository:** `siewhean/AltTabMac`  
**Reviewed commit:** `627475bfbb30b4ed16c9aafe610be252b43c2b5c`  
**Scope:** app/window completeness, global MRU ordering, selection, activation, cache/permissions, and the quality of the work already recorded in GitHub.

## Executive verdict

The implementation has several good building blocks—exact `(PID, CGWindowID)` identities, candidate deduplication, an explicit MRU store, a two-phase cache, exact-window activation attempts, and focused unit tests—but it does **not yet satisfy** the requested acceptance contract.

Two deterministic P0 problems are visible directly in the current logic:

1. **Preview capture is incorrectly treated as an eligibility requirement.** In the final cache phase, an eligible candidate with no preview is dropped. Fallback suppression is then calculated from all candidates rather than emitted items, so the app is not recovered as a fallback. A missing screenshot can therefore become a missing app.
2. **The session deliberately skips a more-recent window when it shares the current app's PID.** The ordered list can be globally interleaved, but initial forward and reverse selection scan for a different PID. That is app-switching semantics, not strict window-MRU semantics.

The exact model checks included with this review found:

- **3,900 strict-MRU selection mismatches among 19,500 meaningful activation sequences (20.0%)** in a fixed five-window universe. This is a logic-state-space result, not an estimate of real-world failure frequency.
- **120 completeness failures among 126 preview-success combinations (95.2%)** for one through six apps. Only the all-previews-succeed case at each app count preserves every app under the modeled final-phase rules.

## Acceptance contract used for this review

The word “app” is ambiguous in a window-aware switcher. This plan adopts the stricter and more useful contract:

1. Every eligible top-level application window is one switcher tile.
2. A regular running app with no eligible window receives exactly one fallback tile.
3. Screenshot availability changes presentation only; it never changes membership.
4. The history is one global sequence of exact tile identities. Windows from the same app may be separated by windows from other apps.
5. The current exact frontmost tile remains visible but is moved to the end for Alt-Tab cycling.
6. Every remaining ranked tile is sorted by exact last-focus time, newest first. No PID or bundle grouping is allowed.
7. Forward selection chooses index 0 of that ordered list. Reverse selection chooses the adjacent previous tile. Neither scans for a different PID.
8. An MRU entry becomes permanent only after activation is verified. A short-lived provisional selection may be used solely to make immediate re-presses deterministic.
9. Explicit preferences—app exclusions, title exclusions, visibility scope, and a deliberate window cap—are the only valid reasons for omission, and debug diagnostics must identify them.

If the product is intended to be app-first rather than window-first, item 7 must be changed explicitly. The current code and tests mix both contracts.

## Priority findings

### P0-1 — Active apps/windows can disappear when capture fails

`AppSwitcher.assembleItems` emits a window item only when `shouldDisplayWindowItem` accepts the preview state. During the final thumbnail pass, a nil preview is rejected. The fallback calculation then treats every candidate PID/app identifier as represented—even candidates that did not produce a tile. The resulting snapshot can omit one app, several apps, or all apps.

This is especially serious because `ClassicGridView` already supports a preview placeholder. The data layer is deleting an item that the presentation layer is explicitly capable of rendering.

**Smallest safe fix**

- Make eligibility and preview assets independent.
- Build one item for every eligible candidate, with `previewImage=nil` when capture fails.
- Reconcile phase-two images onto the phase-one identity set rather than rebuilding membership from capture results.
- Compute fallback suppression from emitted window identities, or preferably make candidate items unconditional so that fallback recovery is unnecessary.
- Replace the existing test `testPreviewlessWindowTilesAreDroppedInFinalThumbnailPass` with the opposite assertion.

### P0-2 — Strict window MRU is overridden by “different app first”

`SwitcherOrdering` correctly contains logic and comments intended to avoid same-app grouping. `SwitcherCycleSession.initialSelectionIndex`, however, finds the first tile whose PID differs from the current PID in both forward and reverse directions. Existing test `testInitialSelectionSkipsOtherWindowsFromCurrentApp` locks in that contradiction.

**Concrete failure**

Activation sequence: `B → A1 → A2`, with A2 current.

- Strict global MRU presentation: `[A1, B, A2-current]`
- Required initial selection: `A1`
- Current initial selection: `B`

The list may look interleaved, but the actual switch skips the most-recent tile and behaves as though windows were grouped by application.

**Smallest safe fix**

- After `SwitcherOrdering` moves current to the end, forward initial index is `0`.
- Reverse initial index is the adjacent item before current (`count - 2` when current is last).
- Remove PID scanning from `initialSelectionIndex`.
- Replace the existing “skip same app” test with the supplied strict-MRU tests.

### P0-3 — Same-app window focus changes are not continuously observed

The switcher observes app activation, launch, termination, and preference changes. It does not observe focused-window changes inside an already-frontmost application. Clicking A2 from A1, using Cmd-`, Mission Control, or Stage Manager can change the exact active window without an `NSWorkspace.didActivateApplication` event.

**Fix**

- Install AX observers for focused-window changes on regular apps (`kAXFocusedWindowChangedNotification`), with lifecycle handling for launch/terminate.
- Normalize the event to `(PID, CGWindowID)` and call `history.noteActivation`.
- At session start, resolve and note the exact current frontmost identity as a safety reconciliation.
- Add fixture-driven tests for mouse focus, Cmd-`, Mission Control, and rapid same-app focus changes.

### P0-4 — Ambiguous frontmost resolution ignores the supplied history

`FrontmostResolution.effectiveIdentity` accepts `historyEntries`, but does not use it. When the OS supplies only a PID and two window tiles share that PID, the function returns nil unless an app-fallback tile exists. In the normal multi-window case, fallback tiles are suppressed.

**Fix**

For the effective PID, choose the first exact visible identity found in the immutable history snapshot. Use an app fallback only if no exact visible identity can be matched.

### P0-5 — Rapid re-press tests simulate behavior production does not implement

Several tests describe an “eager history note” before async activation. `commitCurrentSelection` does not update history or set a provisional override. The override is set only after `onActivationConfirmed`. A second press that arrives before system focus/confirmation can still resolve the old frontmost identity and select the same target again.

**Fix**

- Create a provisional pending-selection override at commit time.
- Do not write permanent history at that point.
- Promote it to permanent MRU only after exact activation confirmation.
- Clear it on timeout/failure.
- Add a host integration loop at 20, 50, 100, 180, and 250 ms re-press intervals.

### P0-6 — Activation retry exhaustion is counted as success in one path

`ensureApplicationFrontmost` calls `confirmActivation` after retries are exhausted even when the target PID is not frontmost. `confirmActivation` updates history. The window-specific path is more conservative, so behavior is inconsistent.

**Fix**

Separate `activationSucceeded`, `activationFailed`, and `activationTimedOut`. Only the success transition writes history and emits `onActivationConfirmed`.

### P1-1 — The default three-window cap conflicts with “show all”

`maxWindowsPerApp` documents `0` as unlimited, but defaults to `3`. Four or more windows from one app are intentionally omitted on a fresh install. That may be a valid decluttering preference, but it is incompatible with an unconditional “all active windows” acceptance criterion.

**Recommendation:** default to `0`, or state clearly that the product is capped and make completeness tests evaluate against the configured cap.

### P1-2 — Fallback deduplication is bundle-centric, not process-centric

Fallback suppression and deduplication use `sourceAppIdentifier`. Two regular processes with the same bundle ID can collapse into one fallback, and a windowed sibling process can suppress a windowless sibling. Decide whether “all apps” means bundle, process, or window; encode that identity contract in tests.

### P1-3 — Sorting reads mutable history repeatedly

Candidate/app comparators call live history lookups during sorting. A focus event arriving during a sort can make the comparator observe different rank states across comparisons. It also adds repeated synchronous queue traffic.

**Fix:** capture one history snapshot and precompute rank maps before every build/order operation.

### P1-4 — The fallback activation path raises `windows.first`

For an app fallback, the implementation raises the first AX window, not the focused/main preferred standard window. AX array order is not a user-intent guarantee.

**Fix:** focused window → main window → first standard top-level window → app-only activation.

### P1-5 — The tests are helper-heavy but system-light

Current tests are useful pure-logic checks, but they do not execute the full chain:

`NSWorkspace catalog → CG window list → AX eligibility/identity → snapshot assembly → preview failure → global ordering → session selection → actual focused CGWindowID`.

Some tests also test a story rather than production wiring:

- the previewless test asserts the undesired omission;
- “eager history” is simulated manually;
- the “PID matching across window-ID changes” test does not force ambiguous same-PID resolution;
- a test demonstrating buggy behavior still passes rather than serving as a red regression.

## Review of GitHub work practices

The repository contains no PR or issue history for the reviewed work; the switcher was changed through direct commits with titles covering recency, activation, double-Tab, hot swap, mouse clicks, and fullscreen previews. That makes the repeated fixes difficult to connect to acceptance criteria and release evidence.

Improvements:

1. Open one issue per behavioral invariant, not per symptom.
2. Use PRs with a reproducible sequence, expected identity order, focused-window proof, and before/after test evidence.
3. Require a macOS Swift test workflow. The current workflow is website/security-only.
4. Stop tracking generated `.build`, index-store, app-bundle, dSYM, and `.DS_Store` artifacts. The current `.gitignore` only lists `.vercel` and `.secrets/`.
5. Add a release checklist artifact containing macOS version, architecture, permissions, display/Space setup, fixture sequence, expected order, actual order, and focused CGWindowID.
6. Keep task documentation synchronized with production behavior. Tests/comments must not describe an eager mechanism that no longer exists.

## Tests actually performed for this review

### Performed

- Reviewed the current repository metadata, direct commit history, relevant source files, existing XCTest files, task notes, README, and workflow configuration through the connected GitHub repository.
- Traced membership from running apps/candidates through both cache phases and fallback suppression.
- Traced exact history ordering, frontmost resolution, session initial selection, commit, and activation confirmation.
- Ran exhaustive dependency-free model checks over:
  - all activation sequences of length 1–6 in a five-window/three-PID universe;
  - every preview-success/failure combination for one through six apps.
- Produced four proposed XCTest regressions expected to fail on the reviewed commit.
- Produced a comprehensive release matrix with **136 test cases**.

### Not performed in this environment

The available execution host is Linux and cannot import AppKit, create a macOS event tap, inspect AX windows, grant Screen Recording, or focus real macOS windows. Therefore I did not claim that the current SwiftPM suite or live app passed. The repository's own notes record historical local Swift test passes, while also stating that live hotkey/manual QA remained pending.

## Detailed critical live tests

### LQA-01 — Completeness with Screen Recording denied

**Purpose:** prove presentation failure never changes membership.

1. Quit CmdTab.
2. Grant Accessibility; deny Screen Recording.
3. Open one normal window each in three regular apps or fixture apps A, B, and C.
4. Close other regular apps or record them as expected extras.
5. Launch CmdTab cold.
6. Invoke the switcher immediately, then again after 3 seconds.
7. Record running regular-app PIDs, visible switcher identities, and selected identity.

**Expected:** A/B/C remain visible on both invocations, using icons/placeholders. Counts and identities do not change when the final capture phase completes.

**Current prediction:** after the final phase, any window without a usable capture can disappear; a cold all-failure state can become empty.

### LQA-02 — Partial capture failure

**Purpose:** prove one bad thumbnail cannot erase one app.

1. Use a test seam to make preview capture succeed for A/C and fail for B.
2. Build the phase-one and phase-two snapshots.
3. Compare item identity sets and order.

**Expected:** identity sets and order are identical. Only B's image state differs.

### LQA-03 — Strict same-app MRU

**Purpose:** reproduce the PID-skip conflict.

1. Create windows A1 and A2 in App A and one window B in App B.
2. Focus in this exact order: `B → A1 → A2`.
3. Invoke the switcher while A2 remains current.
4. Record the full tile order and initially selected identity.

**Expected:** `[A1, B, A2-current]`; A1 selected.

**Current prediction:** the list can be `[A1, B, A2]`, but B is selected because A1 shares A2's PID.

### LQA-04 — Long interleaving sequence

1. Create A1/A2, B1/B2, and C1.
2. Focus: `A1 → B1 → A2 → C1 → B2`.
3. Invoke while B2 is current.

**Expected ranked prefix:** `[C1, A2, B1, A1, B2-current]`. Never reorder to `[B1, B2, A1, A2, C1]` or any bundle/PID grouping.

### LQA-05 — Same-app focus without app activation

1. Focus A1.
2. Click A2 without activating another app.
3. Invoke the switcher.
4. Repeat using Cmd-` and Mission Control.

**Expected:** A2 is the exact current identity on every path, and A1 receives the immediately preceding MRU position when no other focus occurred.

### LQA-06 — Immediate repeated switch

1. Use A/B with A current and B previous.
2. Generate two quick Cmd-Tab taps separated by 20 ms.
3. Repeat at 50, 100, 180, and 250 ms, 50 runs each.
4. Log intended selection, confirmation, system frontmost PID, and focused CGWindowID.

**Expected:** first tap A→B; second tap B→A. Never B twice. Failed activations do not alter permanent history.

### LQA-07 — Exact-window activation

1. Create A1/A2 with identical titles and similar frames.
2. Select A1 50 times from another app, then A2 50 times.
3. After each commit, query focused AX window and `_AXUIElementGetWindow` when available.

**Expected:** 100/100 focused IDs equal selected IDs. The heuristic fallback path is separately tested with private lookup disabled.

### LQA-08 — Live launch/close reconciliation

1. Open switcher with A1/B1.
2. Launch C and open A2 while visible.
3. Close A1 and terminate B.
4. Observe every emitted snapshot.

**Expected:** no duplicates; C/A2 are inserted once; A1/B removed once; selected identity is preserved when still present; each snapshot satisfies completeness.

### LQA-09 — Space/display matrix

Run `currentSpaceOnly`, `visibleSpaces`, and `allSpaces` across:

- one display;
- two displays;
- native fullscreen Space;
- window on another Space;
- All Displays mirroring;
- cursor-display versus active-window-display placement.

For every state, record the expected eligible identity set before invoking. Compare set equality, order, selection, and actual focused ID after commit.

### LQA-10 — Permission transition matrix

For Accessibility and Screen Recording, test:

- granted at launch;
- denied at launch;
- granted while running;
- revoked while running;
- revoked during a visible session.

**Expected:** no crash, no unexplained omission, no false activation confirmation, and recovery without relaunch where macOS permits it.

## Recommended test architecture

### 1. Pure snapshot builder

Extract `SwitcherSnapshotBuilder` with injected inputs:

- running-app records;
- CG-window records;
- AX eligibility/ID records;
- preferences;
- history snapshot;
- preview assets or failures;
- clock.

Its output should include:

- emitted items;
- rejected candidates with reason codes;
- fallback decisions;
- ordered identities;
- diagnostics.

This makes the complete membership rule testable without AppKit.

### 2. Activation coordinator state machine

Extract activation into explicit states:

`idle → provisionalSelection → activating → exactFocusConfirmed | appFocusConfirmed | failed | timedOut`

Inject app activation, AX focusing, WindowServer focusing, clock, and scheduler. Permanent MRU updates occur only in confirmed states.

### 3. macOS fixture apps

Build tiny fixture apps with stable bundle IDs and commands to:

- create/close N titled windows;
- duplicate titles/frames;
- minimize/fullscreen/hide;
- delay or reject activation;
- create sheets and floating panels;
- publish focused CGWindowID.

Use at least three bundle IDs so global MRU is deterministic.

### 4. Debug snapshot endpoint

In unsigned debug/test builds only, expose a local JSON snapshot containing:

- regular running apps;
- candidate windows and rejection reasons;
- emitted tiles;
- preview status;
- history;
- resolved current identity;
- final order and selection;
- pending/provisional/confirmed activation.

Tests should compare identity sets rather than screenshots.

## CI gates

A switcher-related change should not merge unless:

1. `swift test --scratch-path /tmp/CmdTab-test` passes on macOS.
2. The supplied strict-MRU/completeness regressions pass.
3. Property tests pass for generated histories and preview failures.
4. A packaged-app smoke test launches the signed/ad-hoc bundle.
5. The debug fixture verifies exact focused CGWindowID for keyboard and mouse commits.
6. No generated artifacts are added.
7. P0 manual matrix is attached for changes involving private APIs, Spaces, displays, permissions, or event taps.

## Definition of done

The switcher is consistent only when, for every tested snapshot:

- `actual identities == expected eligible identities`;
- identities are unique;
- screenshots do not affect membership;
- ranked order equals exact global MRU with current moved last;
- initial selection is the adjacent tile dictated by that order;
- actual focused PID/window ID equals the committed identity;
- only verified activation changes permanent history;
- refreshes preserve those invariants under launch, close, permissions, Spaces, displays, and rapid input.
