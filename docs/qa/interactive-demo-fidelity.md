# Interactive demo fidelity

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
- Palette search matches application names and window titles using the native
  whitespace-insensitive fuzzy ranking, with stable ordering for equal scores.
- Grid navigation follows columns vertically. The demo contains eight sample
  windows, matching the native radial view's maximum visible slots. Larger native
  inventories use a rotating viewport; that scenario is not simulated here.
- Minimize preserves a window; hide affects an app's windows; close removes one
  window; quit removes all windows of that app. These operations are simulated.
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
