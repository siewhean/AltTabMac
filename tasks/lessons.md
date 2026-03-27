# Lessons

- 2026-03-27: For deterministic hotkey hold delays, carry the original event tap timestamp through async main-queue handling; sampling uptime later on the main queue reintroduces variable delay under load.
- 2026-03-27: For delayed hotkey overlays, ignore repeated hidden keydowns on deterministic paths; otherwise auto-repeat can silently stretch the reveal threshold.
- 2026-03-27: Accessibility close operations do not expose a `kAXCloseAction`; close windows by pressing the `kAXCloseButtonAttribute` instead of inventing a direct AX action constant.
