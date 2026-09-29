# Public-beta release matrix

Last reviewed: 2026-09-29

CmdTab remains **BLOCKED**. This matrix is fail-closed: source checks do not
replace signed-artifact or physical-Mac evidence.

This candidate preserves the tested universal arm64/x86_64, macOS 14+, public-beta
configuration. Unmerged PR #49 proposes a different arm64-only/macOS 13 policy;
that policy conflict requires an explicit release decision before promotion.

| Requirement | Result | Evidence / remaining gate |
| --- | --- | --- |
| Source candidate clean/exact SHA | IN PROGRESS | Candidate branch is based on `origin/main@dcd02faafbe4cd944fa9899d4e5ddcd6d5f70407`; freeze and record its committed SHA and clean-tree receipt. |
| Full Swift source suite | PASS (local source) | 378 XCTest and 2 Swift Testing tests passed in the candidate worktree on 2026-09-29. This is not hosted CI or signed-artifact acceptance. |
| CG-first membership | PASS (source) | `AppSwitcher` evaluates Core Graphics candidates before positive mapped AX exclusion. |
| AX omission preserves CG windows | PASS (source) | Membership regression matrices cover silent AX omission and missing ID bridge. |
| Window completeness | PARTIAL (local ad-hoc app) | One-display v9 PDFgear/WindowLab checks passed; second display, Stage Manager, and final signed-candidate matrix remain untested. |
| Exact-window activation | PARTIAL (local ad-hoc app) | Exact WindowLab desktop/fullscreen round-trip passed on the attached v9 app. Repeat on the final signed candidate and supported Mac matrix. |
| Wrong-sibling activation | UNPROVEN | Exact sibling fallback is removed; physical canary/soak must show zero wrong siblings. |
| Preview integrity | PARTIAL (local ad-hoc app) | Sampled v9 cards had saved previews and controlled PDFgear transition displayed the current document. Signed-candidate soak must rule out stale cross-window previews. |
| Fresh beta entitlement | UNPROVEN | Trial KMS/KID/public-keyring inputs are unset locally; requires deployed trial-only KMS/OIDC/keyring and clean-user receipt. |
| macOS support policy consistent | PASS (source) | Package, release config, and generated plist require macOS 14+. |
| Private capability degradation | UNPROVEN | Retain candidate-bound macOS 14 and 15 private-capability canary receipts; deterministic CI validates only their schema/harness. |
| Cmd-Q semantics | PASS (source) | Exact and fallback items route Cmd-Q to the owning application. |
| Normal termination | PASS (source) | The general termination veto is removed; lifecycle cleanup is non-blocking. |
| Developer UI absent | PASS (source) | Developer controls compile only under `DEBUG`; packaged-release inspection remains required. |
| Native palette input | UNPROVEN | Native `NSSearchField` is implemented; IME, Dictation, and VoiceOver must pass on an authorized Mac. |
| Reveal p50 | UNPROVEN | Acceptance threshold is <=80 ms on the signed candidate. |
| Reveal p95 | UNPROVEN | Acceptance threshold is <=150 ms on the signed candidate. |
| 1,000-session soak | UNPROVEN | Run the hash-bound authorized-Mac procedure on Apple Silicon and Intel. |
| Search privacy | PASS (source) | Existing hashed search-memory storage remains in place; update persistence is still part of N-to-N+1 validation. |
| Telemetry copy matches wire contract | UNPROVEN | Requires an exact-candidate payload/copy review receipt. |
| VoiceOver | UNPROVEN | Re-run field, result, selection, and failure-announcement procedure after native-input focus changes. |
| Beta entitlement | UNPROVEN | Requires production licensing receipt for the candidate. |
| Beta update wording/feed | PASS (source) | Typed beta configuration derives `https://cmdtab.net/releases/beta/appcast.xml`. |
| Sparkle N->N+1 | UNPROVEN | Real signed beta update, persistence, relaunch, and Gatekeeper receipt required. |
| Developer ID signing | UNPROVEN | `security find-identity` reports zero valid identities; no Developer ID artifact exists. |
| Hardened Runtime | UNPROVEN | Enforced for release packaging; no accepted signed artifact supplied. |
| Notarization | UNPROVEN | No `CmdTabNotary` Keychain profile; requires accepted `notarytool` receipt and stapling validation. |
| Gatekeeper | UNPROVEN | Requires clean-account DMG installation assessment. |
| CI | NOT_RUN (candidate SHA) | Open a candidate PR and obtain executed macOS 14/15, release, website and workflow-health checks. Existing PR #49 hosted jobs failed before any step; they do not qualify this candidate. |

## Required external receipts

Use [the signed update runbook](signed-update-runbook.md),
[the performance evidence procedure](../qa/performance-evidence.md), and
[the private-capability canary](../qa/private-capability-canary.md). Retain
the source SHA, artifact checksums, signing/notary/stapler/Gatekeeper outputs,
raw performance JSON, updater logs, and Apple Silicon plus Intel results.
