# CmdTab Native Production-Readiness Implementation Plan

**Created:** 2026-07-22  
**Implementation branch:** `agent/native-release-readiness`  
**Target release:** `v1.0.0-rc1`  
**Primary goal:** produce a reproducible, signed, notarized, stapled, testable CmdTab application whose real macOS behavior matches the public website and licensing contract.

---

## 1. Why this plan exists

CmdTab has a strong automated foundation for exact-window membership, ordering, selection, licensing, and website delivery. It is not yet ready for a public native release because the repository does not currently prove the complete distribution path:

- deterministic `.app` assembly;
- permanent bundle identity;
- Developer ID signing;
- Hardened Runtime;
- notarization and ticket stapling;
- clean-account installation;
- real Accessibility and Screen Recording transitions;
- exact focused `CGWindowID` after keyboard and mouse commits;
- Spaces, fullscreen, displays, Stage Manager, Secure Input, and sleep/wake behavior;
- automatic update and rollback behavior;
- production diagnostics and support evidence.

The implementation order therefore prioritizes release truth over new marketing or convenience features.

---

## 2. Release principles

1. **One source of truth:** `main` is the only long-lived integration branch. Feature and release branches must be deleted after merge or abandonment.
2. **No claim without evidence:** public claims must be supported by source, automated tests, measured real-machine evidence, or a clearly stated limitation.
3. **Exact-window proof:** screenshots are supporting evidence only. Acceptance requires requested identity, committed identity, actual frontmost PID, and actual focused `CGWindowID`.
4. **Private API containment:** SkyLight and private AX capabilities must be isolated behind providers and must degrade explicitly.
5. **No unsigned public artifact:** paid or public distribution is blocked until Developer ID signing, Hardened Runtime, notarization, stapling, Gatekeeper assessment, and clean-machine installation all pass.
6. **QA after every phase:** no phase starts until the previous phase has a completed QA/QC record and explicit pass/fail decision.
7. **No silent test substitution:** Vercel website success does not substitute for Swift/macOS verification. SwiftPM tests do not substitute for packaged-app testing.

---

## 3. Branch and evidence strategy

### Branches

- `main`: production integration branch.
- `agent/native-release-readiness`: implementation branch for Phases 0–2.
- `release/native-rc1`: created only after Phase 2 passes.
- Subsequent feature branches: one phase or one protected capability per branch.

### Required evidence directory

All phase evidence must be recorded under:

```text
docs/release/evidence/<phase-id>/
```

Each phase must contain:

- `README.md` — scope, environment, result, known limitations;
- `commands.log` — commands executed and exit codes;
- `checksums.txt` — artifact checksums where applicable;
- `failures.md` — every failure and its disposition;
- machine-readable results when available;
- screenshots or screen recordings only as supplementary evidence.

### Severity definitions

- **P0:** can switch to the wrong target, hide eligible windows, lose user access, break distribution, violate trust/security, or prevent recovery.
- **P1:** materially harms reliability, accessibility, supportability, or update safety.
- **P2:** polish, discoverability, convenience, or optimization.

---

# Phase 0 — Governance, repository hygiene, and trustworthy gates

## Objective

Establish one trustworthy source of truth and remove known release-process regressions before packaging work begins.

## Implementation tasks

### 0.1 Restore CI execution

- Determine why GitHub Actions jobs are failing before checkout with no steps or logs.
- Verify account billing/quota, repository Actions permissions, runner availability, and workflow restrictions.
- Re-run all permanent workflows on the exact branch head.
- Add a lightweight `workflow-health` job that reaches its first shell step and publishes runner metadata.
- Require independent checks for:
  - Swift macOS 14;
  - Swift macOS 15;
  - Website Security;
  - SEO/GEO and rendered/browser verification;
  - Vercel preview.

### 0.2 Clean repository-generated output

- Remove tracked `.build/`, `.DS_Store`, debug symbols, and other generated output from the index.
- Preserve `.gitignore` coverage.
- Do not rewrite history during this phase.
- Record repository size before and after index cleanup.

### 0.3 Reconcile documentation and current source

- Update `README.md` to identify native release readiness as the active task.
- Update `tasks/todo.md` with this phased plan and current gates.
- Reconcile media provenance, current version, package state, and manual-test boundaries.
- Remove stale source references such as old PNG showcase paths or dimensions.
- Keep unsupported ScreenCaptureKit, processor, memory, architecture, or latency claims blocked.

### 0.4 Repair website autoplay accessibility

The visual design may keep autoplay without visible controls only if autoplaying movement does not exceed five seconds.

- Make maintained autoplay videos one-shot rather than infinite loops.
- Set each autoplay clip to five seconds or less.
- Freeze on a useful final frame.
- Keep static posters for `prefers-reduced-motion`.
- Do not replay a clip every time it re-enters the viewport.
- Add source, rendered, and browser assertions for:
  - no `loop` on autoplay media;
  - duration at or below five seconds;
  - no autoplay under Reduce Motion;
  - no replay after completion;
  - no hidden playback control dependency.

### 0.5 Branch cleanup plan

After this branch merges:

- delete merged implementation branches;
- delete superseded and one-time operational branches;
- delete `pre-exam-status-(BAD)` after recreating only safe artifact cleanup from current `main`;
- retain only `main` and the active release branch.

## Phase 0 QA/QC checklist

### Source checks

- [ ] `git ls-files .build` returns no files.
- [ ] `git ls-files | grep -E '(^|/)\.DS_Store$'` returns no files.
- [ ] README and task files name native release readiness as the active task.
- [ ] No unsupported specification appears in source or public retrieval files.
- [ ] Showcase metadata and current media files agree.

### Website checks

- [ ] Dependency audit passes at moderate threshold.
- [ ] TypeScript passes.
- [ ] Production build passes.
- [ ] All canonical routes render.
- [ ] Browser verification passes at desktop and mobile sizes.
- [ ] Every CTA target is at least 44 CSS pixels.
- [ ] Autoplay media is muted, inline, one-shot, and no longer than five seconds.
- [ ] Reduce Motion shows a static poster.

### CI checks

- [ ] Every required GitHub workflow reaches checkout and at least one shell step.
- [ ] Swift macOS 14 passes.
- [ ] Swift macOS 15 passes.
- [ ] Website Security passes.
- [ ] SEO/GEO passes.
- [ ] Vercel preview is READY for the exact head.

## Phase 0 exit criteria

- All Phase 0 checks pass on the same commit.
- No workflow fails before step execution.
- No tracked generated artifacts remain.
- Accessibility regression is corrected.
- A clean branch inventory and deletion list is recorded.

---

# Phase 1 — Deterministic application bundle and unsigned release artifact

## Objective

Build the same unsigned or ad-hoc signed `.app` from a clean checkout on every supported build machine.

## Implementation tasks

### 1.1 Permanent application identity

- Replace `com.user.CmdTab` with a permanent identifier owned by the project.
- Document the chosen identifier and team relationship.
- Keep version and build numbers generated from a single release source.
- Prevent website, Info.plist, update feed, and artifact names from diverging.

### 1.2 App-bundle assembly

Create:

```text
scripts/release/build-app.sh
scripts/release/package-app.sh
scripts/release/verify-bundle.sh
release/ReleaseConfig.json
```

The scripts must:

- compile `CmdTab` in release mode;
- create `CmdTab.app/Contents/MacOS` and `Contents/Resources`;
- copy the release binary, Info.plist, application icon, and required resources;
- produce deterministic file permissions;
- fail on missing or unexpected nested executables;
- generate SHA-256 checksums;
- produce an ad-hoc signed artifact for local QA only.

### 1.3 Entitlements baseline

Create the minimum entitlements file required by actual source behavior.

- Start with no exceptions.
- Add an entitlement only when a verified runtime failure proves it is required.
- Keep App Sandbox disabled for direct distribution unless the architecture is redesigned.
- Record every entitlement with a source reason and a verification test.

### 1.4 Reproducibility

- Build twice from clean scratch directories.
- Compare file lists, Info.plist, entitlements, binary architecture, and checksums.
- Document expected nondeterministic signing or timestamp fields separately.

## Phase 1 QA/QC checklist

- [ ] Clean checkout builds without existing `.build` state.
- [ ] `CmdTab.app` has valid bundle layout.
- [ ] `plutil -lint` passes for Info.plist and entitlements.
- [ ] Main executable is present and executable.
- [ ] Bundle identifier, version, and build match release config.
- [ ] No development-only file exists inside the bundle.
- [ ] Ad-hoc signature verification passes for local QA.
- [ ] App launches on the build machine.
- [ ] App remains a menu-bar agent and does not appear unexpectedly in Dock or native switcher.
- [ ] Clean rebuild produces the expected reproducibility result.

## Phase 1 exit criteria

- One command creates a verified local `.app` from a clean checkout.
- Bundle contents, metadata, and checksums are recorded.
- No Apple credentials are required for the local artifact.

---

# Phase 2 — Developer ID signing, Hardened Runtime, notarization, and stapling

## Objective

Produce a Gatekeeper-accepted direct-distribution artifact.

## Implementation tasks

Create:

```text
scripts/release/sign-app.sh
scripts/release/notarize-app.sh
scripts/release/staple-app.sh
scripts/release/verify-distribution.sh
scripts/release/create-zip.sh
```

### 2.1 Credential handling

- Import Developer ID credentials through CI secrets or a temporary keychain.
- Never commit certificates, passwords, API keys, profiles, or keychain files.
- Support App Store Connect API credentials or a named `notarytool` keychain profile.
- Delete temporary keychains after the job.

### 2.2 Signing

- Sign nested code first, then the application bundle.
- Use `Developer ID Application` identity.
- Enable Hardened Runtime.
- Include a secure timestamp.
- Apply only the reviewed entitlement file.

### 2.3 Notarization

- Archive the signed app as a ZIP or DMG suitable for notarization.
- Submit with `xcrun notarytool submit --wait`.
- Persist submission ID and notarization log.
- Fail on any non-accepted result.

### 2.4 Stapling and distribution checks

- Staple the ticket to the `.app` or distribution container.
- Validate the staple.
- Assess with Gatekeeper.
- Verify signatures deeply and strictly.
- Publish checksums and a signed release manifest.

## Phase 2 QA/QC checklist

- [ ] `security find-identity -p codesigning -v` finds the intended identity in the signing environment.
- [ ] `codesign -dvvv --entitlements :-` shows expected identity, Hardened Runtime, timestamp, and only reviewed entitlements.
- [ ] `codesign --verify --deep --strict --verbose=2` passes.
- [ ] Notarization result is Accepted.
- [ ] Notarization log contains no ignored warning.
- [ ] `xcrun stapler validate` passes.
- [ ] `spctl --assess --type execute --verbose=4` passes.
- [ ] Artifact checksum matches the release manifest.
- [ ] App launches after download on a clean, non-development Mac account.
- [ ] Gatekeeper shows the expected developer identity.

## Phase 2 exit criteria

- A signed, notarized, stapled artifact passes clean-machine installation.
- Release credentials remain secret and are not embedded in artifacts or logs.
- `release/native-rc1` may now be created.

---

# Phase 3 — Real macOS acceptance harness and P0 desktop matrix

## Objective

Prove that the packaged app selects and activates the exact intended window under real macOS conditions.

## Implementation tasks

### 3.1 Fixture applications

Build test fixtures that can deterministically create:

- several windows in one process;
- duplicate titles;
- untitled windows;
- minimized and restored windows;
- sheets, dialogs, and floating panels;
- fullscreen windows;
- delayed and failed focus;
- windows on different displays and Spaces;
- an intentionally unresponsive process.

### 3.2 Acceptance recorder

Record for every action:

```text
requested identity
visible item identities
selected identity
committed identity
actual frontmost PID
actual focused AX element
actual focused CGWindowID
history before and after
permission state
Space and display state
activation duration
```

### 3.3 Test environments

At minimum:

- macOS 13;
- macOS 14;
- macOS 15;
- latest supported macOS;
- Apple Silicon;
- Intel only if the release artifact actually contains and supports x86_64.

### 3.4 Required scenarios

- Accessibility denied, granted, and revoked while running;
- Screen Recording denied, granted, and revoked while running;
- keyboard commit, modifier-release commit, Return, and mouse click;
- repeated switching at 20, 50, 100, 180, and 250 ms;
- same-app focus via mouse, Command-`, Mission Control, and Stage Manager;
- current, visible, and all Spaces;
- minimized, fullscreen, hidden, and off-Space windows;
- one display, multiple displays, mixed scale, mirrored display, disconnect/reconnect;
- Secure Input;
- event-tap timeout recovery;
- sleep/wake;
- app launch and termination while overlay is visible.

## Phase 3 QA/QC checklist

- [ ] Every P0 row records actual focused `CGWindowID`.
- [ ] No wrong-window activation is observed.
- [ ] Failed activation never mutates permanent MRU.
- [ ] Preview failure never removes eligible membership.
- [ ] Same-app windows preserve global exact-window order.
- [ ] Permission changes produce clear user guidance and safe degradation.
- [ ] Event tap never allows native-switcher bleed-through under accepted load.
- [ ] No crash, hang, or orphaned overlay remains after each scenario.

## Phase 3 exit criteria

- All P0 rows pass on supported operating systems and architectures.
- Every unresolved failure is fixed or explicitly narrows the supported contract.
- Screenshots alone are not accepted as proof.

---

# Phase 4 — Private API isolation and compatibility hardening

## Objective

Contain OS-fragile behavior behind explicit capability providers.

## Implementation tasks

Introduce protocols:

```swift
WindowIdentityProvider
WindowCaptureProvider
WindowFocusProvider
WindowWorkspaceProvider
```

Each provider reports:

```text
available
degraded(reason)
unavailable(reason)
failed(reason)
```

- Move SkyLight, private AX lookup, and front-process calls out of `AppSwitcher.swift`.
- Keep public or safer fallbacks.
- Add capability diagnostics to Settings and support bundles.
- Version-test private symbols and semantics.
- Ensure one failed capability cannot remove switcher membership.

## Phase 4 QA/QC checklist

- [ ] `AppSwitcher` no longer resolves private symbols directly.
- [ ] Each provider has unit tests and injected fake implementations.
- [ ] Missing private symbols produce deterministic degradation.
- [ ] Public fallback activation is tested.
- [ ] Compatibility diagnostics identify the active provider and degradation reason.
- [ ] Website and support docs match the provider contract.

## Phase 4 exit criteria

- Private API failure is diagnosable, testable, and non-catastrophic.
- Supported macOS versions have recorded capability results.

---

# Phase 5 — Highest-value missing switcher capabilities

Implement only after Phases 0–4 pass.

## 5.1 Minimized-window inclusion and exact restoration

- Add a preference for minimized-window inclusion.
- Represent minimized windows without filtering them out.
- Add a minimized badge and safe preview fallback.
- Restore only the selected window before exact activation.
- Verify sibling windows remain unchanged.

### QA/QC

- [ ] Selected minimized window restores and receives exact focus.
- [ ] Siblings remain unchanged.
- [ ] History records only confirmed selected window.
- [ ] Screen Recording denial still preserves the item.

## 5.2 True Space, fullscreen, and Stage Manager identity

- Replace screen-rectangle heuristics with a workspace provider.
- Model Space, display, fullscreen Space, and Stage Manager set.
- Provide an explicit degraded mode when exact identity is unavailable.

### QA/QC

- [ ] Current/visible/all Spaces produce expected membership.
- [ ] Off-Space selection activates the correct Space and exact window.
- [ ] Stage Manager set changes do not corrupt MRU.
- [ ] Display disconnect does not leave stale overlay state.

## 5.3 Configurable shortcuts and scoped switcher profiles

- Add shortcut recording and conflict detection.
- Support multiple named profiles with style, scope, filter, and placement.
- Keep existing Command-Tab and Option-Tab defaults.

### QA/QC

- [ ] System conflicts are detected before saving.
- [ ] Secure Input and text fields are respected.
- [ ] Per-profile scope and style remain isolated.
- [ ] Import/export round-trips.

## 5.4 Durable MRU across CmdTab restarts

- Persist a durable window fingerprint rather than raw PID/CGWindowID only.
- Restore only unique, high-confidence matches.
- Expire stale identities.

### QA/QC

- [ ] Restart preserves high-confidence order.
- [ ] Reused PID or window ID never inherits unrelated rank.
- [ ] Duplicate titles do not map ambiguously.
- [ ] Stale data expires safely.

## 5.5 Expanded exact-window management actions

- restore;
- zoom/maximize;
- fullscreen toggle;
- move to next display;
- center;
- tile left/right/thirds;
- force quit with confirmation.

### QA/QC

- [ ] Unsupported actions are disabled rather than falsely succeeding.
- [ ] Exact-window actions never affect a sibling unexpectedly.
- [ ] Force quit requires explicit confirmation.
- [ ] Actions update membership and selection deterministically.

---

# Phase 6 — Updates, rollback, crash diagnostics, and support bundles

## Objective

Make release failures recoverable after distribution.

## Implementation tasks

- Add a signed automatic-update framework and signed feed.
- Support stable and beta channels.
- Verify upgrade and downgrade behavior.
- Add release rollback instructions.
- Add opt-in crash reporting or local crash-log discovery.
- Add a user-exportable support bundle containing:
  - app version and build;
  - macOS version and architecture;
  - permission state;
  - capability-provider state;
  - anonymized event-tap and activation diagnostics;
  - no window titles, previews, screenshots, clipboard contents, or search queries.

## Phase 6 QA/QC checklist

- [ ] Signed update installs successfully.
- [ ] Tampered update is rejected.
- [ ] Interrupted update recovers.
- [ ] Stable and beta channels remain isolated.
- [ ] Rollback procedure works.
- [ ] Support bundle contains no prohibited private content.
- [ ] Diagnostics can identify common permission and capability failures.

## Phase 6 exit criteria

- A bad release can be stopped, diagnosed, and rolled back without manual file replacement.

---

# Phase 7 — Security and owner-operated production controls

## Objective

Complete the non-code release obligations.

## Implementation tasks

- Provision and monitor `support@`, `privacy@`, and `security@` domain addresses.
- Verify the Resend sender domain.
- Enable and review Vercel WAF and bot protections.
- Validate production rate limits and abuse response.
- Review telemetry, retention, and consent posture for launch jurisdictions.
- Document key rotation and incident response.
- Confirm no secrets in source, artifacts, screenshots, build logs, or support bundles.

## Phase 7 QA/QC checklist

- [ ] Domain mailboxes receive and reply successfully.
- [ ] Security mailbox has an owner and response SLA.
- [ ] Sender-domain verification passes.
- [ ] WAF/rate-limit test traffic behaves as expected.
- [ ] Secret scan is clean.
- [ ] Telemetry disclosure matches emitted fields.
- [ ] Incident tabletop exercise is completed.

## Phase 7 exit criteria

- Support, security, privacy, abuse, and credential ownership are operational.

---

# Phase 8 — Release candidate and launch gate

## Objective

Approve one exact artifact for public distribution.

## Required release record

```text
release/native-rc1
v1.0.0-rc1
artifact SHA-256
Developer ID identity
notarization submission ID
staple validation
Gatekeeper assessment
supported macOS versions
supported architectures
P0 acceptance result
known limitations
rollback instructions
```

## Final QA/QC checklist

- [ ] Phases 0–7 are passed and linked.
- [ ] All required workflows are green on the release commit.
- [ ] Signed/notarized artifact checksum is published.
- [ ] Clean-account installation passes.
- [ ] Update and rollback pass.
- [ ] Trial start and license activation pass against production.
- [ ] Public website facts match the release artifact.
- [ ] No unsupported compatibility, architecture, performance, memory, or privacy claim is published.
- [ ] Release notes and known limitations are complete.
- [ ] Owner explicitly approves the release artifact checksum.

## Launch decision

- **GO:** all P0 checks pass, no unresolved release blocker, and owner approves the exact checksum.
- **NO-GO:** any wrong-window activation, unsigned/unnotarized artifact, failed Gatekeeper assessment, broken update/rollback, unverified licensing path, or misleading public claim.

---

# Implementation order beginning now

The first implementation slice is Phase 0:

1. commit this plan;
2. repair autoplay accessibility without restoring visible controls;
3. align source metadata and README;
4. remove tracked generated artifacts available through the repository API;
5. add workflow-health verification;
6. run Vercel and GitHub checks;
7. produce the Phase 0 QA/QC record;
8. open a focused PR before beginning packaging.
