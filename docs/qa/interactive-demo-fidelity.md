# Interactive demo fidelity

## App-parity follow-up (2026-10-14)

Each change was checked against `Sources/CmdTab` before editing:

- Quick-action keys: `SwitcherQuickAction.action(...)` and
  `ProductionSwitcherWindowController.handlePanelKeyEvent`. H/M/W act bare or with
  Command (not with Option or Control); Q needs Command; Command Palette returns before
  the mapping. The demo handles bare keys only while the switcher stage has focus and
  never intercepts modified keys, so Quit is button-only. Buttons show ⌘H/⌘M/⌘W/⌘Q.
- Minimized windows: `SwitcherPreferences.includeMinimizedWindows` defaults to false
  and `ProductionAppSwitcher` filters them. The demo adds the same toggle, default off.
- Palette memory: `SearchMemoryStore` persists to `UserDefaults`; copy now says the app
  keeps it across launches and the demo forgets it on reload.
- Radial: `demo-radial-viewport.ts` ports `RadialMenuViewportState` and its tests;
  the demo has ten sample windows so paging is visible.
- Palette ranking already matched `PaletteSearch.swift` (same recurrence, weights,
  thresholds); constants are now named and the native `PaletteSearchTests` cases ported.
- Hold-to-show hint follows `ProfileHotkeyTimingPolicy` (200 ms reveal, quick switch
  on early release). Copy only.

Local validation on the branch: PASS typecheck; PASS unit groups 104 + 14 and 27
licensing tests (3 PostgreSQL store tests skipped, no disposable DB); PASS release,
commerce, beta-trial, five-feature, analytics-privacy, API-security, dependency-audit
and SEO/showcase checks; PASS `next build --webpack` (Turbopack refused the worktree's
symlinked `node_modules`); PASS `demo:check` interactions at 1440, 390 and 320 px with
screenshot writes disabled because the disk was full. No lint script exists. Hosted CI,
native acceptance and production publication are pending.

## Radial alignment follow-up (2026-10-14)

Both the native view and browser demo were corrected. Native selectors use an
84-point square with a centred, aspect-preserving 52-point icon; a bottom label
overlay does not alter the positioned selector's centre. The capability banner
has its own bottom-right overlay, leaving the hub centred.

Browser selectors share evenly spaced polar coordinates, contain centred icons,
and place app labels outside the selector. PNG icons are local AppKit exports
from the installed Finder, Claude, Visual Studio Code, PDFgear, and Calendar app
icons; they are illustrative assets, not live window captures.

PASS: 428 XCTest plus 2 Swift Testing tests, including rendered four-cardinal
selector/icon centroid, icon size and aspect-ratio regressions. Website groups
93 + 14 and 27 licensing tests pass; three unrelated PostgreSQL store tests were
skipped locally. Production build and Chrome profiles at 1440, 390, and 320px pass:
icon-to-selector centre error below 0.5px, non-overlapping selectors, keyboard
and action behavior, reduced motion, and no browser exceptions. Independent QA
and hosted CI receipts are retained outside source.

The installed app has not been replaced; physical-device acceptance and website
production publication remain pending. The native rotating inventory is unchanged.

Native reference: tracked `main` at `ce04adecefbe0c7e4f47cd76991850ecf72678f8`.
The website uses sample data and browser controls; it cannot intercept macOS global
shortcuts, capture live windows, or manipulate real applications.

The demo must preserve these product distinctions:

- Separate windows from one app remain separate targets. Activation moves only the
  selected window into recent history; cancel leaves the active target unchanged.
- Click commits a target. Return confirms and Escape cancels. Browser Tab remains
  available to leave the demo; native shortcuts are configurable profile settings.
- Palette search is a direct port of `PaletteSearch.swift` (Smith-Waterman, 0.4
  minimum, 0.05 remembered-choice tolerance, whitespace-insensitive, acronym bonus),
  with stable ordering for equal scores. The app persists query memory across
  launches; the demo keeps it in page memory only and says so.
- Grid navigation follows columns vertically. The demo contains ten sample
  windows; the Radial Menu shows eight and scrolls the rest in with a port of
  `RadialMenuViewportState.swift`.
- Minimize hides a window from the switcher unless "Include minimized windows" is
  on (off by default, as in the app); hide affects an app's windows; close removes
  one window; quit removes all windows of that app. These operations are simulated.
- Quick-action keys follow `SwitcherQuickAction`: in Classic Grid and Radial Menu,
  bare H, M and W act while the demo has focus and bare Q does nothing. Command
  shortcuts are left to the browser, so Quit is button-only. In Command Palette,
  letters type into search.
- Preview artwork represents sample content; unavailable previews are labelled.
  Animation respects reduced motion and keyboard focus remains visible.

Reference implementation: `SwitcherProfiles.swift`, `SwitcherHistory.swift`,
`SwitcherCycleSession.swift`, `PaletteSearch.swift`, `RadialMenuViewportState.swift`,
`ProductionSwitcherVisuals.swift`, and `ProductionSwitcherWindowController.swift`.

Validation: focused behavior tests, production-build browser interactions on desktop
and narrow layouts, keyboard escape/focus, and reduced-motion checks. This evidence
does not substitute for native packaged-app or physical-device acceptance.

## Local validation (2026-10-12)

- PASS: six model regressions; canonical unit groups 90 + 14 tests, plus 27 licensing route tests. Three unrelated PostgreSQL licensing-store tests were skipped because no disposable database was configured.
- PASS: typecheck, production webpack build, SEO, API security, analytics privacy, and diff check.
- PASS: local Chrome at 1440, 390 and 320 pixels; activation, MRU, action scope, title search, Enter, Escape/focus recovery, closed-state guard, arrows, Tab movement, reflow and reduced motion. No browser exceptions. Mutating network requests blocked; analytics declined.
- Corrected radial title overflow at narrow widths; full target names remain in accessible labels and selected-target text.
- Production deployment and hosted CI are pending. Native acceptance is outside this website-only change.
