# Lessons

- 2026-03-27: For deterministic hotkey hold delays, carry the original event tap timestamp through async main-queue handling; sampling uptime later on the main queue reintroduces variable delay under load.
- 2026-03-27: For delayed hotkey overlays, ignore repeated hidden keydowns on deterministic paths; otherwise auto-repeat can silently stretch the reveal threshold.
- 2026-03-27: Accessibility close operations do not expose a `kAXCloseAction`; close windows by pressing the `kAXCloseButtonAttribute` instead of inventing a direct AX action constant.
- 2026-03-27: When a testable state machine keeps private helper structs, keep the exposed stored properties private too; Swift will reject an internal type that surfaces private-type-backed state.
- 2026-03-27: If a feature is only accessible through hidden shortcuts or buried implementation details, users will treat it as missing; surface shipped features explicitly in Settings and on the marketing site.
- 2026-03-27: For marketing-site motion, start with CSS-first reveal primitives and ambient keyframes, and always keep `prefers-reduced-motion` as a first-class constraint instead of bolting it on later.
