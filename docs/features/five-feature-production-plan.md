# CmdTab Five-Feature Production Implementation Plan

**Branch:** `agent/five-feature-production-suite`  
**Based on:** current `main` after Phase 1 evidence reconciliation  
**Scope:** implement the five missing switcher capabilities identified by the repository audit without mixing them into the Developer ID distribution branch.

## Decision boundary

The five capabilities are implemented as one integrated product slice because they share window metadata, shortcut routing, session configuration, persistence, and exact-window activation. They still receive independent acceptance criteria and regression tests.

This branch must not be merged merely because source files exist. Acceptance requires:

- the complete Swift package suite;
- dedicated tests for every new model and state transition;
- `scripts/release/run-phase1-qa.sh` on the exact branch head;
- packaged-app manual validation on a real Mac;
- no wrong-window activation, sibling-window mutation, ambiguous MRU restoration, or silent workspace misclassification;
- explicit degraded states when private workspace capability is unavailable.

## Architecture

### Shared window catalogue

Create one Accessibility-backed catalogue for each regular application. Every window descriptor records:

- exact `(PID, CGWindowID)` session identity;
- role and subrole;
- minimized state;
- title and optional document URL;
- bounds and display identity;
- workspace membership and capability status;
- supported exact-window actions.

The catalogue is the shared input for eligibility, minimized-window synthesis, durable MRU fingerprints, workspace filtering, and action availability. This avoids five independent metadata paths that can disagree.

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

Existing global preferences remain the migration source for the default profiles. Runtime code resolves one immutable `SwitcherSessionConfiguration` at trigger time and keeps it for the life of that switcher session.

### Capability reporting

Workspace and window-action providers report:

```text
available
degraded(reason)
unavailable(reason)
failed(reason)
```

A missing private symbol or unsupported Accessibility attribute must never silently produce a stronger product claim. The UI must expose the degraded state and the switcher must retain safe membership.

## Feature 1 — Minimized-window inclusion and exact restoration

### Implementation

1. Add `includeMinimizedWindows` to the default session configuration and profile model.
2. Stop rejecting minimized AX windows during catalogue construction when the profile permits them.
3. Synthesize candidates from Accessibility when a minimized window has no useful Core Graphics row.
4. Add a visible minimized badge to every presentation style.
5. Preserve cached previews; otherwise use the existing safe placeholder.
6. On activation, resolve the exact AX window by `CGWindowID`, clear `AXMinimized`, activate the owner, raise/focus the same window, and verify the exact focused ID before changing permanent MRU.
7. Never unminimize sibling windows.

### Acceptance

- minimized windows appear only when enabled;
- selecting A2 restores A2, not A1;
- A1 remains unchanged;
- failed restoration does not mutate permanent MRU;
- Screen Recording denial preserves the item and badge.

## Feature 2 — Space, fullscreen, display, and Stage Manager identity

### Implementation

1. Introduce `WindowWorkspaceProvider` and `WorkspaceSnapshot`.
2. Use capability-detected SkyLight read APIs for exact window-space membership and current managed spaces.
3. Parse managed-display metadata defensively and preserve unknown fields as diagnostics rather than assumptions.
4. Model fullscreen spaces and display UUIDs.
5. Model Stage Manager visibility separately from Space membership. When an exact Stage Manager set identifier is unavailable, report `degraded` rather than fabricating one.
6. Replace rectangle-intersection filtering with provider-backed current/visible/all-space filtering when available.
7. Keep the present on-screen/screen-intersection algorithm as an explicit fallback.
8. Before focusing an off-space target, request its managed space through the provider when supported, then run exact-window activation and verification.

### Acceptance

- current, visible, and all-space scopes produce deterministic membership;
- off-space selection activates the target space and exact window when the provider is available;
- provider unavailability is visible and falls back safely;
- display disconnect/reconnect cannot leave stale workspace identity or overlay state;
- fullscreen and Stage Manager cases record capability status.

## Feature 3 — Configurable shortcuts and scoped switcher profiles

### Implementation

1. Add codable `RecordedShortcut`, modifier mask, release behaviour, application filter, and `SwitcherShortcutProfile` models.
2. Migrate existing `Command-Tab`, `Option-Tab`, style, visibility, display, exclusion, and alternate-trigger settings into two default profiles without deleting legacy defaults.
3. Add conflict validation for duplicate profiles and protected/reserved shortcut shapes.
4. Add an AppKit-backed recorder with explicit start/cancel/clear behaviour.
5. Match profile shortcuts in the existing CGEvent tap without adding blocking work to the callback.
6. Pass the selected profile ID into `SwitcherWindowController`; freeze the resolved session configuration until the session ends.
7. Support custom forward and reverse shortcuts, hold-to-release and press-to-toggle sessions, per-profile style/scope/filter/placement, enable/disable, duplicate, delete, and reset.
8. Add import/export using versioned JSON with validation and atomic replacement.

### Acceptance

- default profiles preserve existing behaviour;
- duplicate or unsafe shortcuts cannot be saved silently;
- one profile cannot leak style, scope, or filters into another;
- text fields and Secure Input remain respected;
- import/export round-trips and rejects malformed or future-incompatible data;
- event-tap callback remains non-blocking.

## Feature 4 — Durable MRU across restarts

### Implementation

1. Keep exact session identity `(PID, CGWindowID)` authoritative.
2. Add a local durable fingerprint containing only privacy-minimised hashes and metadata:
   - bundle identifier;
   - normalized-title hash;
   - document-URL hash when available;
   - role/subrole;
   - rounded bounds/display identity;
   - last-seen time.
3. Store versioned JSON atomically in Application Support with file mode `0600`.
4. Restore only unique, high-confidence matches:
   - exact bundle required;
   - document hash wins when unique;
   - title/role/bounds matching is rejected when ambiguous;
   - one stored record maps to at most one live window;
   - stale records expire.
5. Merge restored ranks beneath current-session observations.
6. Update durable order only after exact activation confirmation.
7. Provide reset and diagnostics controls.

### Acceptance

- restart preserves unique, high-confidence order;
- duplicate titles do not restore ambiguously;
- reused PID or window ID never inherits unrelated rank;
- stale entries expire;
- failed activation does not persist rank;
- persisted data contains no raw title, URL, preview, search query, or screenshot.

## Feature 5 — Expanded exact-window management actions

### Implementation

Add capability-checked actions:

- restore minimized window;
- zoom/maximize;
- toggle fullscreen;
- move to next display;
- center;
- tile left, right, first third, centre third, last third;
- force quit with explicit confirmation.

Each action resolves the exact AX window by `CGWindowID`, validates support, applies the smallest mutation, and verifies the resulting state/frame. Unsupported actions are disabled in the UI rather than pretending to succeed. Window-frame actions constrain to the target display's visible frame and preserve sibling windows.

### Acceptance

- unsupported actions are unavailable;
- exact-window actions never alter a sibling;
- frame actions stay within the destination visible frame;
- fullscreen and minimize state are verified;
- force quit requires confirmation and targets only the selected process;
- membership and selection refresh deterministically after an action.

## Implementation sequence

1. Shared models and catalogue.
2. Durable history store and matching tests.
3. Minimized-window membership/restoration.
4. Workspace provider and scoped filtering.
5. Profile persistence, migration, validation, recorder, and trigger routing.
6. Expanded actions and capability UI.
7. Settings and presentation badges.
8. Full regression and packaged-app acceptance runner.

## Required test groups

```text
WindowCatalogueTests
MinimizedWindowPolicyTests
WorkspaceProviderTests
WorkspaceFilteringTests
ShortcutProfilePersistenceTests
ShortcutConflictTests
ShortcutRoutingTests
DurableHistoryMatchingTests
DurableHistoryPrivacyTests
WindowActionCapabilityTests
WindowGeometryActionTests
FiveFeatureIntegrationTests
```

## Manual packaged-app matrix

- minimized windows with duplicate titles;
- same-app normal + minimized + fullscreen windows;
- current/visible/all Spaces;
- two displays with mixed scale and disconnect/reconnect;
- Stage Manager enabled and disabled;
- at least three shortcut profiles with conflicting and non-conflicting keys;
- press-to-toggle and modifier-release sessions;
- restart with unique and ambiguous windows;
- every exact-window action, including unsupported applications;
- Screen Recording denied;
- Accessibility revoked and restored;
- rapid repeated triggers and event-tap recovery.

## Merge rule

Keep the pull request in draft until the exact head passes the complete automated suite and the manual packaged-app matrix. Feature source can be reviewed before those observations, but it must not be described as production-ready until the evidence exists.
