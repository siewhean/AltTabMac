# Todo

## 2026-03-27 — Reliable 100ms `⌘Tab` Hold-to-Show

- [x] Refactor `HotkeyManager` pending state into an explicit trigger helper/state model.
- [x] Lock hidden `⌘Tab` reveal timing to the first keydown while keeping `⌥Tab` on its legacy repeated-keydown path.
- [x] Clear pending hotkey trigger state for `Esc`, `Return`, and click commits so modifier release cannot double-activate.
- [x] Add focused trigger-state tests and verify the package test suite passes.
- [x] Update `README.md` and record review notes for the completed fix.

## Review

- `swift test --scratch-path /tmp/AltTabMac-test` passed with 38 tests.
- Follow-up fix anchored hidden `⌘Tab` timing to the event tap's original `CGEvent` timestamp instead of a later main-queue uptime sample.
- Manual hotkey QA on a live macOS desktop is still pending.
