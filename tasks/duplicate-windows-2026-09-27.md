# Duplicate icon-only windows — 2026-09-27

## Live reproduction and cause

Running repository bundle PID 59536, executable SHA256 `421ae12c98ad72501ae13ede8a6128364e111fe29228c13cf3a1914bd75b177b`, had both permissions Ready. Practice switcher displayed separate icon-only Spotify, Telegram, Terminal and Antigravity cards alongside real windows. Read-only CG/AX inventory confirmed unnamed offscreen 500x500 helpers, including Spotify 1375 beside real 104, Telegram 770 beside minimized 89, and Antigravity 213 beside real 113. The current source already rejects these helpers with fresh complete trusted AX sibling evidence; the running bundle was outdated.

## Correction and checks

- Rebuilt existing working-tree source at base HEAD `3408c9c24e283e94583e303b2b04d5476775300f`; this is a dirty local QA candidate, not release evidence. Refreshed origin/main has only unrelated website/docs changes.
- Added a regression for the three observed helper/real pairs in `UnknownCGSurfaceMembershipTests`. Genuine minimized and visible targets remain included.
- Focused surrounding suite: 70 tests passed; updated membership suite: 16 passed. Universal arm64/x86_64 packaging and strict deep signature verification passed. Independent QA found no scoped source/build defects; existing compiler warnings remain.
- Replaced repository `CmdTab.app` and relaunched exact path, PID 65366, SHA256 `3544aee30732cd0fde12280833a87350d2609fe9d17c3ae89b794e71fd644ca0`. Backup: `/tmp/CmdTab-before-duplicate-fix-20260927.app`.
- Retained build/test logs in `docs/qa/evidence/duplicate-windows-2026-09-27/`.

## Pending live acceptance

The initial replacement required permission reauthorization after its ad-hoc signature changed. The user re-enabled both permissions. Subsequent live review confirmed helper duplicates were gone, but PDFgear retained a hidden Welcome card; VS Code initially had no real window and gained a thumbnail after opening its Welcome window.

## Remaining hidden-window correction

- Fresh reproduction after host restart: PDFgear Welcome 238 was initially a visible AX window. Opening an existing PDF hid 238 internally, removing it from AX while CG retained it on current desktop 1. Real document 259 remained visible. Selecting the hidden card failed exact activation; the runtime log records window 238.
- Shared discovery now rejects an offscreen AX-omitted surface only with fresh complete trusted AX sibling evidence, a nonhidden application, exact current-desktop/empty membership, and disabled Stage Manager. Uncertain/offspace states remain eligible. This uses no application name, title, geometry or capture-success check.
- Last confirmed minimized state is retained per live process generation/window ID to protect temporary AX omissions; explicit restoration clears it. Both capture phases use the filtered candidate inventory, so saved previews cannot resurrect excluded cards.
- Final source tests: 69 passed, zero failures, including 19 membership tests. Independent QA passed after fixing minimized-state and observation-freshness gaps. Initial Command Line Tools macro errors and an intermediate stale-compilation test failure were superseded by the successful Xcode run.
- Changed source: `AppSwitcher.swift`; comment clarification in `ProductionAppSwitcher.swift`; regression coverage in `UnknownCGSurfaceMembershipTests.swift`.
- Universal packaging and strict deep signature verification passed. Installed at the same repository path, PID 23320, executable SHA256 `158f67067a9c7b60713cbd22319cfcfac116897c814a3f397d66e84c019b5cb6`; base Git SHA remains `3408c9c24e283e94583e303b2b04d5476775300f` with uncommitted source changes. Backup: `/tmp/CmdTab-before-hidden-window-fix.app`.
- Both permissions returned to Required after the changed ad-hoc binary was installed. The user prefers to enable permissions personally; reauthorization and exact rebuilt-app live acceptance remain BLOCKED pending that action. The prior authorized build showed real previews for all 11 displayed cards, including VS Code, but still included hidden PDFgear Welcome. This is not acceptance of the new artifact.
- Final successful test, package and prior authorized activation-failure logs retained under `docs/qa/evidence/duplicate-windows-2026-09-27/hidden-window/`. No CI or signed release deployment was performed.

## Exact rebuilt-app live verification

User reauthorized and relaunched the unchanged corrected executable, PID 24439. Both permissions report Ready. At 22:34, the live switcher showed one PDFgear document card; the still-registered hidden Welcome 238 was absent. VS Code Welcome 243 had a real thumbnail. All 13 cards in that observation had previews, including other applications' minimized windows. The user's app/window inventory continued changing during QA, so the count is an observation, not a fixed expected inventory.

Minimizing PDFgear document 259 preserved its single card and saved preview; restoring it returned CG/AX state to visible and not minimized. Hidden Welcome remained excluded. These observed duplicate/thumbnail cases PASS on SHA256 `158f67067a9c7b60713cbd22319cfcfac116897c814a3f397d66e84c019b5cb6`. Offspace/Stage Manager/temporary AX omission safeguards have automated regression coverage, not exhaustive live state coverage.

The authorized process's retained five-minute error sample has no `CmdTab:AppSwitcher` entries. It does contain macOS AppIntents `autoShortcut` service/registration errors and a BaseBoard task-port error; earlier startup also logged AppKit warnings. No error-free runtime claim is made. `runtime-authorized-final.log` is retained with the other evidence. This completes the scoped window correction; it is not release certification.
