# Lessons

## 2026-10-10 — Shared modules must not import `node:` modules

- **What happened:** `waitlist-referral.ts` imported `node:crypto` for code generation and was also bundled into the browser form. `next build` (Turbopack) accepted it locally; CI builds with `--webpack` and failed with `UnhandledSchemeError`.
- **Rule:** a file imported by any `"use client"` component must be browser-safe. Put Node-only helpers (`node:crypto`, `postgres`) in separate server-only files (`*-code.ts`, `*-signals.ts`, `*-store.ts`).
- **Check before pushing website changes:** run `npm run security:check` (webpack build, as CI does), not only `next build`.

- 2026-08-01: A public launch switch must gate every commerce ingress, public purchase surface, and background path before it reaches customer payment, databases, queues, KMS, or email providers. Gating fulfillment while leaving checkout visible can charge a customer for an order the system deliberately refuses to fulfill.
- 2026-08-01: A source-order assertion must prove the fail-closed branch contains an actual `return`, not merely that its `if` statement appears before the protected sink. Otherwise a later edit can remove the return while the security gate still passes.
- 2026-07-27: In zsh, `path` is a special array tied to `PATH`; never use
  `path` as a loop or script variable because it can make every subsequent
  command unavailable. Use a task-specific name such as `file_path`.
- 2026-07-23: A resumable QA marker is not evidence by itself. Bind it to the exact clean HEAD and hash-seal its phase log and artifacts; rerunning an earlier phase must invalidate every dependent phase.
- 2026-07-23: Generated-output exclusions may apply only to untracked outputs. Tracked or staged changes under `dist/` or `.build/` must still fail the source-integrity gate.
- 2026-07-23: A durable-history ambiguity fixture must remove stronger document identity and exercise the production matcher with candidates inside its ambiguity margin.
- 2026-07-23: AppKit fixture windows must disable state restoration and reapply intended frames after assigning a content controller; otherwise prior minimized state and fitting-size geometry can invalidate cross-scenario evidence.
- 2026-07-23: Objective probes must represent unavailable Accessibility state as unknown (`null`), never as a false minimized or fullscreen result.
- 2026-07-20: Security dependency guards should enforce a minimum safe semantic version, not one exact patch string; package resolution may legitimately select a newer patched release.
- 2026-07-20: Structured data is not a substitute for visible evidence. Product facts, review dates, breadcrumbs, source links, privacy disclosures, and limitations should exist in canonical HTML and schema together.
- 2026-07-20: GEO measurement should classify broad discovery sources without collecting prompts or search queries, and it must be interpreted alongside webmaster-platform data because referrers can be stripped.
- 2026-07-20: A competitor can be beaten on clarity, transparency, and verification through code, but backlinks, press, downloads, community discussion, and localization require distribution rather than synthetic claims.
- 2026-03-27: For deterministic hotkey hold delays, carry the original event tap timestamp through async main-queue handling; sampling uptime later on the main queue reintroduces variable delay under load.
- 2026-03-27: For delayed hotkey overlays, ignore repeated hidden keydowns on deterministic paths; otherwise auto-repeat can silently stretch the reveal threshold.
- 2026-03-27: Accessibility close operations do not expose a `kAXCloseAction`; close windows by pressing the `kAXCloseButtonAttribute` instead of inventing a direct AX action constant.
- 2026-03-27: When a testable state machine keeps private helper structs, keep the exposed stored properties private too; Swift will reject an internal type that surfaces private-type-backed state.
- 2026-09-09: macOS App Lifecycle & Termination: Never return `.terminateCancel` or block on internal helper window close in `applicationShouldTerminate(_:)` unless user work would be irrevocably destroyed. Always allow clean OS-level logout, reboot, and Command-Q shutdown by returning `.terminateNow`.
- 2026-09-09: Window Membership & Accessibility Invariants: Core Graphics window list (`CGWindowListCopyWindowInfo`) must be the primary authority for window candidates. Never treat AX window list enumeration failure as a reason to drop an active application's main window; positive exclusion is required to avoid missing windows from non-standard or partially-responsive applications.
- 2026-09-09: Multi-layer Release Integrity: In release packaging (`package-app.sh`), release metadata must be strictly synchronized across `ReleaseConfig.json`, `Package.swift`, `Resources/Info.plist`, and marketing site metadata (`product-facts.ts`) — the packaging pipeline guards against divergence at build time.

- 2026-09-15: Missing/duplicate tile remediation must inspect live PID/window IDs and exercise the entire publication pipeline. Passing finalizer-only tests does not establish that unknown CG surfaces are useful windows; never infer duplicate app fallbacks from icon-only presentation alone.

- 2026-09-25: A freshness-sensitive per-process membership decision must run immediately after that process’s inspection. Group its candidates together and preserve original ranking indexes; one slow sibling must not invalidate helper evidence. Use one AX eligibility policy for base and enriched discovery.

- 2026-09-25: Process-level geometry stacks do not identify the affected window or prove an app layout defect. Inspect the actual native window and size arguments; reproduce in plain AppKit before changing SwiftUI sizing or disabling system UI. Same-bundle-ID QA checkouts can confuse macOS Quit & Reopen; verify the executable path after every restart.

- 2026-09-27: Permission acceptance must use one persistent exact bundle and distinguish identical-binary restart from ad-hoc rebuilds. Retain logs outside `/tmp`; never report a replaced or disappeared QA copy as the active authorized app.

## 2026-10-10 — Use /usr/bin/log for unified-log checks
- The user's zsh defines a `log` function, so `log show ...` fails ("too many arguments") and piping it through `grep`/`tail` hides the failure as "no results". Always call `/usr/bin/log show`, and treat an empty result as suspect until a known-present message is found.

