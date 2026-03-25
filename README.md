# AltTabMac

Last Updated: 2026-03-25
Active Task: Reliability upgrade, settings improvements, Dock behavior changes, and agent context setup.

## Project Summary

AltTabMac is a custom macOS app switcher built with Swift, AppKit, and SwiftUI. It replaces the default switcher with a window-aware overlay, optional browser-tab switching, multiple visual styles, and a settings surface for controlling behavior.

## Current Status

- Agent context entrypoints now exist in `AGENTS.md`, `CLAUDE.md`, and `CODEX.md`, all pointing back to this file.
- Hotkey handling now uses an explicit trigger state model with armed, visible, cancelled, and committed phases so early release aborts cleanly and `Esc` cancels from one path.
- Settings now expose a safe recent browser tab limit, inline appearance previews, and safe System Settings buttons without force-unwrapped URLs.
- The app source is configured to show a Dock icon again, and Dock reopen events now route to Settings instead of the switcher overlay.
- Liquid Glass styling has been made more transparent across Classic Grid, Command Palette, and Radial Menu.
- Automated coverage now includes hotkey trigger-state tests, recent-tab limit tests, and preference clamping tests.

## Active Constraints / Non-Negotiables

- Read this file before planning or coding.
- Update this file whenever task context, progress, decisions, or blockers change.
- Settings interactions must be safe and avoid crash-prone force unwraps.
- Browser tab limits must remain separate from app-window limits.
- Early modifier release before overlay reveal must abort without switching.

## Decisions Already Made

- Canonical shared context file: `README.md`
- Repo instruction entrypoints: `AGENTS.md`, `CLAUDE.md`, `CODEX.md`
- The current single `Primary Shortcut` control stays unless a true duplicate is found.
- Dock presence should be re-enabled and Dock clicks should open Settings.

## Open Issues / Next Steps

- Run manual QA for the live macOS-only behaviors: Dock reopen, nonactivating overlay focus, hotkey suppression, and visual transparency checks.
- Rebuild and launch the app bundle after source changes when validating outside `swift test`.
- Keep this file current whenever the active task or implementation status changes.

## Recent Changes Log

- 2026-03-25: Added the agent context system scaffold and seeded the current AltTabMac project status.
- 2026-03-25: Implemented the hotkey trigger-state refactor, recent browser tab limit, inline style previews, Dock-to-Settings reopen path, more transparent Liquid Glass visuals, and added automated tests for the new behaviors.

## Agent Update Protocol

1. Read `AGENTS.md`.
2. Read this file before planning or coding.
3. Treat this file as the current shared context unless the latest user prompt overrides it.
4. Update `Current Status`, `Decisions Already Made`, `Open Issues / Next Steps`, and `Recent Changes Log` whenever work changes them.
5. Prefer updating existing sections over appending duplicate notes.
