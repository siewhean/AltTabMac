# Lessons

- 2026-08-01: A public launch switch must gate every commerce ingress and background path before it reaches databases, queues, KMS, or email providers. Making the UI or one worker fail closed is insufficient when a webhook or another scheduled job can still execute against unprovisioned infrastructure.
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
- 2026-03-27: If a feature is only accessible through hidden shortcuts or buried implementation details, users will treat it as missing; surface shipped features explicitly in Settings and on the marketing site.
- 2026-03-27: For marketing-site motion, start with CSS-first reveal primitives and ambient keyframes, and always keep `prefers-reduced-motion` as a first-class constraint instead of bolting it on later.
