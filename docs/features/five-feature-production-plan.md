# CmdTab Five-Feature Production Implementation Plan

**Branch:** `agent/five-feature-production-suite`  
**Based on:** current `main` after Phase 1 evidence reconciliation  
**Scope:** implement the five missing switcher capabilities identified by the repository audit without mixing them into the Developer ID distribution branch.

## Current decision

**Implementation source: complete on this branch.**  
**Production acceptance: pending exact-head macOS automation and packaged-app observations.**

“Complete” here means every planned source, UI, persistence, fixture, diagnostic, and verification path exists and is wired into production startup. It does **not** mean private macOS behaviour has been proven on every target configuration. The PR remains draft until the evidence below passes.

## Decision boundary

The five capabilities are implemented as one integrated product slice because they share window metadata, shortcut routing, session configuration, persistence, and exact-window activation. They still receive independent acceptance criteria and regression tests.

This branch must not be merged merely because source files exist. Acceptance requires:

- the complete Swift package suite;
- dedicated tests for every new model and state transition;
- `scripts/release/run-phase1-qa.sh` on the exact branch head;
- packaged-app manual validation on a real Mac;
- objective focused PID and `CGWindowID` evidence for activation-sensitive rows;
- no wrong-window activation, sibling-window mutation, ambiguous MRU restoration, or silent workspace misclassification;
- explicit degraded states when private workspace capability is unavailable.

## Architecture

### Shared window catalogue

One Accessibility-backed catalogue is constructed for each regular application. Every window descriptor records:

- exact `(PID, CGWindowID)` session identity;
- role, subrole, and parent role;
- minimized and fullscreen state;
- title and optional document URL;
- bounds, display identity, and on-screen state;
- workspace membership and capability status;
- supported exact-window actions.

The catalogue is the shared input for eligibility, minimized-window synthesis, durable MRU fingerprints, workspace filtering, state badges, diagnostics, and action availability. This avoids five independent metadata paths that can disagree.

### Session configuration

A `SwitcherShortcutProfile` owns the complete switcher configuration for one trigger:

- recorded forward and reverse shortcuts;
- switcher style;
- window visibility scope;
- minimized-window policy;
- application filter;
- display placement;
- release behaviour;
- enabled state.

Existing global preferences remain the migration source for the default profiles. Runtime code resolves one immutable `SwitcherSessionConfiguration` at trigger time through `SwitcherSessionConfigurationFreeze` and keeps it for the life of that switcher session. Changes made while an overlay is open apply to the next session.

### Capability reporting

Workspace and window-action providers report:

```text
available
degraded(reason)
unavailable(reason)
failed(reason)
```

A missing private symbol or unsupported Accessibility attribute must never silently produce a stronger product claim. The UI exposes degraded state, Diagnostics gives a sanitized explanation, and the switcher retains safe membership.

### Production polish and safety controls

The integrated slice also includes:

- visible Minimized, Fullscreen, Other Space, and inferred Hidden Set state in all three styles;
- fallback suppression when an exact synthesized window represents the same process;
- post-synthesis enforcement of the global per-app window cap while preserving the active window;
- Secure Event Input pass-through and stale-overlay cancellation;
- native/system shortcut pass-through when licensing does not allow CmdTab handling;
- Accessibility event-tap installation retry and timeout recovery;
- display topology and wake observation with debounced refresh;
- safe profile editing with validation, installed-app selection, Save/Revert, and Save/Discard/Cancel close handling;
- sanitized Diagnostics and durable-MRU reset;
- deterministic WindowLab and WindowProbe fixtures.

## Feature 1 — Minimized-window inclusion and exact restoration

### Implementation status

- [x] Add `includeMinimizedWindows` to global preferences, default session configuration, and profile model.
- [x] Retain eligible minimized AX windows when the active profile permits them.
- [x] Synthesize exact AX candidates when a minimized window has no useful Core Graphics row.
- [x] Suppress duplicate application fallback tiles once an exact window is represented.
- [x] Apply the existing per-app cap after AX synthesis and exact MRU ordering.
- [x] Add a visible and accessible Minimized badge to Classic Grid, Command Palette, and Radial Menu.
- [x] Preserve cached previews and otherwise use the existing safe placeholder.
- [x] Resolve the exact AX window by `CGWindowID`, clear `AXMinimized`, activate the owner, raise/focus the same window, and verify the exact focused ID before changing permanent MRU.
- [x] Keep sibling windows unchanged.

### Acceptance

- minimized windows appear only when enabled;
- selecting A2 restores A2, not A1;
- A1 remains unchanged;
- failed restoration does not mutate permanent MRU;
- Screen Recording denial preserves the item and badge;
- WindowProbe confirms the focused exact ID.

## Feature 2 — Space, fullscreen, display, and Stage Manager identity

### Implementation status

- [x] Introduce `WindowWorkspaceProvider` and `WindowWorkspaceSnapshot`.
- [x] Use capability-detected SkyLight read APIs for exact window-space membership and current managed spaces.
- [x] Parse managed-display metadata defensively.
- [x] Model fullscreen spaces and display identifiers.
- [x] Model Stage Manager visibility separately from Space membership.
- [x] Report Stage Manager set identity as degraded/inferred when macOS exposes no exact stable set identifier.
- [x] Use provider-backed current/visible/all-space filtering when exact membership is available.
- [x] Retain the on-screen fallback when workspace capability is unavailable.
- [x] Prepare the managed Space before exact off-Space activation when supported.
- [x] Observe screen topology changes and wake, invalidate stale metadata, and reposition visible panels.
- [x] Surface capability state in every production presentation and Diagnostics.

### Acceptance

- current, visible, and all-space scopes produce deterministic membership;
- off-space selection activates the target space and exact window when the provider is available;
- provider unavailability is visible and falls back safely;
- display disconnect/reconnect cannot leave stale workspace identity or overlay state;
- fullscreen and Stage Manager cases record capability status;
- WindowProbe confirms focused exact IDs.

## Feature 3 — Configurable shortcuts and scoped switcher profiles

### Implementation status

- [x] Add codable `RecordedShortcut`, modifier mask, release behaviour, application filter, and `SwitcherShortcutProfile` models.
- [x] Seed Command-Tab and Option-Tab default profiles from current global style, visibility, display, and minimized-window settings.
- [x] Preserve unambiguous legacy bundle-ID exclusions in new default profile filters without deleting legacy defaults.
- [x] Keep the existing alternate modifier-only hot-swap trigger as an orthogonal global compatibility path rather than falsely converting it into a per-profile recorded shortcut.
- [x] Add duplicate, reserved, unsafe Command-only, modifierless character, empty Include Only, and no-enabled-profile validation.
- [x] Add an AppKit-backed recorder with explicit start, cancel, and clear behaviour.
- [x] Suspend profile routing while the recorder is active.
- [x] Match profile shortcuts in the existing CGEvent tap without blocking work in the callback.
- [x] Respect Secure Event Input and active CmdTab text fields.
- [x] Preserve the native/system shortcut when licensing disallows custom switching.
- [x] Freeze the resolved profile configuration until the active session ends.
- [x] Support forward/reverse shortcuts, hold-to-release and press-to-toggle sessions, per-profile style/scope/filter/placement, enable/disable, duplicate, delete, and reset.
- [x] Add versioned JSON import/export with validation and atomic replacement.
- [x] Add installed-application selection plus manual bundle-ID editing.
- [x] Add unsaved-change indicators, Save/Revert, and Save/Discard/Cancel close handling.
- [x] Retry event-tap installation after Accessibility is granted and recover from tap disablement.

### Acceptance

- default profiles preserve existing behaviour;
- duplicate or unsafe shortcuts cannot be saved silently;
- one profile cannot leak style, scope, or filters into another;
- text fields and Secure Input remain respected;
- licensing denial never swallows the native/system shortcut;
- import/export round-trips and rejects malformed or incompatible data;
- event-tap callback remains non-blocking;
- invalid or unsaved profile edits are never silently lost.

## Feature 4 — Durable MRU across restarts

### Implementation status

- [x] Keep exact session identity `(PID, CGWindowID)` authoritative.
- [x] Add a privacy-minimised durable fingerprint containing bundle identifier, hashed normalized title, hashed document URL when available, role/subrole, rounded bounds, display/workspace metadata, and last-seen/activation time.
- [x] Store versioned JSON atomically in Application Support with mode `0600`.
- [x] Restore only unique high-confidence matches.
- [x] Reject ambiguous title matches and cross-bundle inheritance.
- [x] Enforce one stored record to one live window and expire stale records.
- [x] Merge restored ranks beneath current-session observations.
- [x] Update durable order only after exact activation confirmation.
- [x] Flush pending writes during deliberate application termination.
- [x] Provide reset controls and sanitized diagnostics without raw titles, document paths, previews, search text, screenshots, clipboard data, or account-specific home paths.

### Acceptance

- restart preserves unique, high-confidence order;
- duplicate titles do not restore ambiguously;
- reused PID or window ID never inherits unrelated rank;
- stale entries expire;
- failed activation does not persist rank;
- persisted data contains no forbidden raw data;
- reset does not delete preferences or licensing.

## Feature 5 — Expanded exact-window management actions

### Implementation status

- [x] Restore minimized window.
- [x] Zoom/maximize.
- [x] Toggle fullscreen.
- [x] Move to next display.
- [x] Center.
- [x] Tile left and right halves.
- [x] Tile first, centre, and last thirds.
- [x] Force quit with explicit confirmation.
- [x] Resolve the exact AX target by `CGWindowID`.
- [x] Disable unsupported actions with a visible explanation.
- [x] Constrain frame actions to the destination display's visible frame.
- [x] Verify resulting frame/state before reporting success.
- [x] Refresh membership after successful actions.
- [x] Make the right-click action surface discoverable in every profile style.

### Acceptance

- unsupported actions are unavailable;
- exact-window actions never alter a sibling;
- frame actions stay within the destination visible frame;
- fullscreen and minimize state are verified;
- force quit requires confirmation and targets only the selected process;
- membership and selection refresh deterministically after an action;
- WindowProbe confirms the exact target after non-destructive actions.

## Verification implementation

- [x] Cross-platform structural and Swift parse gate: `scripts/release/verify-five-feature-source.py`.
- [x] Focused model, policy, profile, privacy, geometry, integration, visual-state, and configuration-freeze tests.
- [x] Complete Swift package suite in the one-command runner.
- [x] Phase 1 deterministic packaging/reproducibility regression in the same runner.
- [x] Deterministic WindowLab fixture with standard, minimized, duplicate-title, fullscreen, floating-panel, delayed-focus, and unresponsive scenarios.
- [x] WindowProbe for sanitized objective PID/`CGWindowID` evidence.
- [x] Generated exact-head evidence and comprehensive packaged-app checklist.
- [x] Sanitized in-app Diagnostics for permissions, private capabilities, profile validity, Secure Input, and durable-MRU state.

## Required test groups

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

## Manual packaged-app matrix

The generated `dist/five-feature-evidence/manual-checks.md` is authoritative. It covers:

- minimized windows with duplicate titles;
- same-app normal, minimized, and fullscreen windows;
- current, visible, and all Spaces;
- two displays with mixed scale and disconnect/reconnect;
- Stage Manager enabled and disabled;
- at least three shortcut profiles with conflicting and non-conflicting keys;
- press-to-toggle and modifier-release sessions;
- mid-session profile edits and unsaved-close handling;
- Secure Input and licensing pass-through;
- restart with unique and ambiguous windows;
- every exact-window action, including unsupported applications;
- Screen Recording denied;
- Accessibility revoked and restored;
- rapid repeated triggers, event-tap recovery, sleep/wake, and a mixed-feature stress run;
- objective WindowProbe PID and focused `CGWindowID` observations.

## Merge rule

Keep PR #35 in draft until the exact head passes the complete automated suite and every applicable packaged-app row. Feature source can be reviewed before those observations, but it must not be described as production-ready or merged into `main`, the Developer ID branch, or another feature branch until the evidence exists and is reviewed.
