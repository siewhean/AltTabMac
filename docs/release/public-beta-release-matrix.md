# Public-beta release matrix

Last reviewed: 2026-09-09

CmdTab remains **BLOCKED**. This matrix is fail-closed: source checks do not
replace signed-artifact or physical-Mac evidence.

| Requirement | Result | Evidence / remaining gate |
| --- | --- | --- |
| Source candidate clean/exact SHA | FAIL | Active worktree is dirty and behind upstream; it cannot be a candidate receipt. |
| CG-first membership | PASS (source) | `AppSwitcher` evaluates Core Graphics candidates before positive mapped AX exclusion. |
| AX omission preserves CG windows | PASS (source) | Membership regression matrices cover silent AX omission and missing ID bridge. |
| Window completeness | UNPROVEN | Requires final signed-candidate desktop matrix. |
| Exact-window activation | UNPROVEN | Source records verified exact activation separately from application fallback; physical cross-Space proof remains required. |
| Wrong-sibling activation | UNPROVEN | Exact sibling fallback is removed; physical canary/soak must show zero wrong siblings. |
| Preview integrity | UNPROVEN | Physical soak receipt must report no stale cross-window previews. |
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
| CI | UNPROVEN | No CmdTab workflow ran for the candidate SHA; unrelated Dependabot and historical-branch runs are not evidence. |

## Required external receipts

Use [the signed update runbook](signed-update-runbook.md),
[the performance evidence procedure](../qa/performance-evidence.md), and
[the private-capability canary](../qa/private-capability-canary.md). Retain
the source SHA, artifact checksums, signing/notary/stapler/Gatekeeper outputs,
raw performance JSON, updater logs, and Apple Silicon plus Intel results.
