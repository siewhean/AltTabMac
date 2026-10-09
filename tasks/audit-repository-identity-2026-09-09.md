# Repository identity audit — 2026-09-09

Captured before further remediation changes, per P-1.1 of the Truth, Reliability & Release Remediation specification.

| Field | Recorded value |
| --- | --- |
| Repository URL | `https://github.com/siewhean/AltTabMac.git` |
| Branch | `main` |
| HEAD | `3408c9c24e283e94583e303b2b04d5476775300f` |
| Upstream | `origin/main` |
| Ahead / behind upstream | `0 / 11` (`git rev-list --left-right --count origin/main...HEAD` returned `11 0`) |
| Worktree | dirty: 65 tracked paths changed/deleted and 226 untracked paths at capture time |
| Staged files | none (`git diff --cached --quiet` exit 0) |
| Unstaged files | tracked changes present (`git diff --quiet` exit 1); see capture command below |
| Untracked files | 226, including active CmdTab source/tests and local `.claude-flow` logs/caches |
| Swift package deployment | macOS 14.0 (`Package.swift`) |
| Release minimum OS | macOS 14.0 (`ReleaseConfig.json`, `Info.plist`) |
| Architecture policy | `universal-arm64-x86_64` |
| Distribution / update channel | `public-beta` / `beta` |
| Sparkle feed | `https://cmdtab.net/releases/beta/appcast.xml` |
| Bundle version / build | `1.0.0` / `1` |
| Audit host | macOS 26.6 (25G70), arm64 |

## Dirty implementation inspection

The dirty tracked changes include the claimed-remediation implementation across
membership, activation, native palette input, release tooling, and tests. The
initial diff inspection specifically confirmed active changes in
`AppSwitcher.swift`, `ProductionAppSwitcher.swift`, and `AXWindowCatalog.swift`;
they are not treated as a release candidate or as evidence for `HEAD`.

## Capture commands

```text
git remote -v
git branch --show-current
git rev-parse HEAD
git rev-parse --abbrev-ref @{upstream}
git rev-list --left-right --count @{upstream}...HEAD
git status --porcelain=v1
git diff --cached --name-only
git diff --name-only
git ls-files --others --exclude-standard
sw_vers; uname -m
```

This record is an audit snapshot only. It is intentionally not a PASS receipt:
the worktree is dirty and `HEAD` does not contain the active remediation.

## P-1.2 claimed-fix reconciliation

Every entry below is **CLAIMED** by the active remediation. “Present” describes
the dirty working tree at audit time, not `HEAD` and not a real-macOS PASS.

| Claimed fix | Current source state | Evidence |
| --- | --- | --- |
| `ApplicationEligibilityPolicy.swift` | PRESENT | `Sources/CmdTab/ApplicationEligibilityPolicy.swift:4-21`; primary enumeration at `AppSwitcher.swift:488-495` |
| Positive-only AX exclusion | PARTIAL | Primary membership is positive-disallow / unknown-include at `AppSwitcher.swift:1430-1455`; legacy `allowedWindowIDsByPID` remains in the frontmost-identity path at `771-783`, `1229`, `1271-1278`, `1406-1419`, `1457-1474` |
| macOS 14 minimum | PRESENT | `Package.swift:4-8`, `release/ReleaseConfig.json:8`, `Resources/Info.plist:35-37` |
| SHA-256 search-memory keys | PRESENT | `SearchMemoryStore.swift:140-150` |
| Legacy search-memory migration | PRESENT | normalized plaintext-to-SHA migration at `SearchMemoryStore.swift:35-62`; regression at `PaletteSearchTests.swift:121-144` |
| Clear Search History | PRESENT | `PreferencesView.swift:252-258`, `SearchMemoryStore.swift:83-88` |
| `.terminateNow` normal termination | PRESENT | `AppDelegate.swift:197-199` |
| Developer preferences gated by `#if DEBUG` | PARTIAL | UI selection/rendering is guarded in `PreferencesPaneSelection.swift:3-11,27-30,46-49` and `PreferencesView.swift:160-166`; `DeveloperSettings.swift` and trial test overrides still compile in release sources |
| Simplified Settings categories | PRESENT | `PreferencesPaneSelection.swift:3-31`, `PreferencesView.swift:141-167` |
| Simplified menu bar | PRESENT | `MenuBarController.swift:108-162` |
| Cmd-Q quits owning application | PARTIAL | implementation terminates owning app at `SwitcherPreferenceModels.swift:190-200` and `AppSwitcher.swift:292-295`, but `SwitcherQuickActionShortcutTests.swift:76-86` still asserts the old close-window behavior |
| Native Command Palette input | PRESENT | `NativePaletteSearchField.swift:4-74`, `ProductionSwitcherWindowController.swift:810-821`, `ProfileHotkeyManager.swift:440-457` |
| Beta update channel | PRESENT | beta authority at `ReleaseConfig.json:14-17`; derived beta feed in `Resources/Info.plist:50-59` and `release_config.py:38-42,113-120,145-163` |
| Fresh-user beta entitlement | ABSENT | no independent `BETA_TRIAL_READY` / `COMMERCE_READY` path; trial remains server-issued in `LicensingController.swift:351-390` and gates use at `630-647` |

## P-1.3 candidate-bound evidence audit

Existing scripts separately reject dirty publication/notarization builds and
record portions of provenance, but no canonical receipt binds all required
fields. Missing from one fail-closed public-release attestation are: requested
candidate SHA and branch, release-config SHA-256, full generated artifact
SHA-256, structured test-command/result records, host OS/architecture, and a
verification that all inputs/artifacts came from the requested clean SHA.

Therefore no existing audit or release report may report this dirty worktree as
PASS. The next implementation phase must add a single fail-closed candidate
receipt/finalizer and correct the four P-1.2 gaps above.

## Hosted-CI observation — 2026-09-09 post-remediation

Read-only GitHub inspection confirmed that no CmdTab workflow has run for
`3408c9c24e283e94583e303b2b04d5476775300f`, nor can one be associated with the
active dirty worktree. The newest listed successful runs are Dependabot-only on
`dcd02faafbe4cd944fa9899d4e5ddcd6d5f70407`; the newest listed Swift workflow
failure is on the separate historical branch
`release/public-release-readiness` at
`b6eaa941ee4ad0955e7a9cb3ee71d513f92a78a5`. Neither is evidence for this
candidate. Exact-SHA hosted CI remains `UNPROVEN`, not failed source quality.

Observed with:

```text
gh run list --limit 12 --json databaseId,workflowName,headSha,headBranch,status,conclusion,createdAt,updatedAt,url
```

## Local release-credential observation — 2026-09-09 post-remediation

The host has zero valid code-signing identities, no `CmdTabNotary` Keychain
profile, and no configured Developer ID, Sparkle public key, trial KMS/KID, or
trial public-keyring input. `CMDTAB_PACKAGE_MODE=release
scripts/release/package-app.sh` rejected before build because its mandatory
Developer ID/Sparkle/notary requirements are absent. This is an intentional
external-credential block, not a source test failure; no credential values were
recorded.
