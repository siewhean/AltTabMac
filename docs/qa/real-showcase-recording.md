# CmdTab Real Showcase Recording Gate

The public showcase must use a real screen recording of a packaged CmdTab build.
Fixture renders, browser recreations, AI-generated footage, and synthetic pointer or
keyboard animation are not acceptable substitutes for this gate.

## Accepted build

Before recording, retain:

- the exact source commit SHA;
- the packaged `CmdTab.app` path;
- the SHA-256 of `Contents/MacOS/CmdTab`;
- the output of `codesign --verify --deep --strict`;
- the output of `lipo -archs`;
- an exact-bundle launch result from `scripts/release/smoke-launch-app.sh`.

The recording must show the same packaged build that produced those receipts.

## Capture requirements

- Record the real macOS desktop at 1920×1080 or higher.
- Use QuickTime Player, Screenshot, or another local screen recorder.
- Disable notifications and hide unrelated private content.
- Do not add simulated application windows.
- Keep an unedited source recording alongside every edited clip.
- Use simple cuts and mode labels only; do not obscure the CmdTab interface.

## Required clips

1. **Classic Grid** — open CmdTab, move forward and backward through real windows,
   and activate the exact selected window.
2. **Command Palette** — type a real application or window query, move the
   selection, and activate the result.
3. **Radial Menu** — navigate in both directions and activate a real window.
4. **Quick Actions** — hide, minimise, close, and quit only where the selected
   target supports the action.
5. **Hot Swap** — show accepted immediate Command double-tap, rejected delayed
   double-tap, accepted side-matched Command+Option chord, and rejected Option
   alone.
6. **Minimised window restoration** — restore and focus the exact window.
7. **Preview continuity** — repeatedly open Arc and Telegram previews after a valid
   capture has appeared.

## Evidence directory

Store evidence outside the repository:

```text
~/Documents/CmdTab-showcase/<commit-short-sha>/
├── source/
├── edited/
├── recording-notes.md
├── package-binary.sha256
└── recording-manifest.sha256
```

`recording-notes.md` must identify the commit, package path, macOS version,
hardware architecture, recording resolution, every included clip, and any row
that remains `NOT TESTED`.

## Acceptance

A clip is accepted only when a reviewer can distinguish the genuine packaged app
from the website demo and can trace it to the recorded package SHA. Unsupported
hardware or unavailable permissions remain `NOT TESTED`; they are never inferred
from source or unit tests.
