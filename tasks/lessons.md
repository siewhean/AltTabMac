# Lessons

- 2026-07-17: Treat switcher membership and thumbnail capture as separate concerns; an eligible window must remain visible as an icon or placeholder when Screen Recording or capture fails.
- 2026-07-17: The displayed MRU order and the initial selection algorithm must implement the same contract; a PID scan can silently reintroduce application grouping after the list itself has been fixed.
- 2026-07-17: `NSWorkspace.didActivateApplication` cannot observe A1 → A2 focus changes inside one frontmost app; exact window history needs Accessibility focused-window notifications plus session-start reconciliation.
- 2026-07-17: A rapid re-press needs a provisional selected identity, not an eager permanent history write; promote MRU only after the selected target is verified as frontmost.
- 2026-07-17: A regular running-process fallback is a PID-level identity. Bundle-level deduplication can hide a second legitimate process that shares the same bundle identifier.
- 2026-07-17: Capture one immutable history snapshot before sorting; comparator calls that repeatedly read mutable shared history can observe inconsistent ranks during one sort.
- 2026-07-17: Test failure logs from connector-backed Actions runs can be truncated; upload the complete log as an artifact before drawing conclusions or changing code.
- 2026-07-17: One-time write workflows must use one normalized branch/event trigger or a shared concurrency key; separate push and PR copies can race at the final push even when both validations pass.
- 2026-03-27: For deterministic hotkey hold delays, carry the original event tap timestamp through async main-queue handling; sampling uptime later on the main queue reintroduces variable delay under load.
- 2026-03-27: For delayed hotkey overlays, ignore repeated hidden keydowns on deterministic paths; otherwise auto-repeat can silently stretch the reveal threshold.
- 2026-03-27: Accessibility close operations do not expose a `kAXCloseAction`; close windows by pressing the `kAXCloseButtonAttribute` instead of inventing a direct AX action constant.
- 2026-03-27: When a testable state machine keeps private helper structs, keep the exposed stored properties private too; Swift will reject an internal type that surfaces private-type-backed state.
- 2026-03-27: If a feature is only accessible through hidden shortcuts or buried implementation details, users will treat it as missing; surface shipped features explicitly in Settings and on the marketing site.
- 2026-03-27: For marketing-site motion, start with CSS-first reveal primitives and ambient keyframes, and always keep `prefers-reduced-motion` as a first-class constraint instead of bolting it on later.
