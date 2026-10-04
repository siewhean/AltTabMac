#!/usr/bin/env python3
"""Mutation regressions for the callback-safe authorization source gate."""

import unittest
from pathlib import Path

from hotkey_source_contract import verify_event_tap_authorization

ROOT = Path(__file__).resolve().parents[2]
HOTKEYS = (ROOT / "Sources/CmdTab/ProfileHotkeyManager.swift").read_text()
LICENSING = (ROOT / "Sources/CmdTab/LicensingController.swift").read_text()


class HotkeySourceContractTests(unittest.TestCase):
    def test_production_snapshot_contract_passes(self):
        verify_event_tap_authorization(HOTKEYS, LICENSING)

    def test_each_callback_must_guard_authorization(self):
        for occurrence in (1, 2):
            with self.subTest(occurrence=occurrence):
                literal = "guard shouldHandleShortcut else"
                index = -1
                for _ in range(occurrence):
                    index = HOTKEYS.index(literal, index + 1)
                mutated = HOTKEYS[:index] + "guard true else" + HOTKEYS[index + len(literal):]
                with self.assertRaises(ValueError):
                    verify_event_tap_authorization(mutated, LICENSING)

    def test_sync_refresh_cannot_replace_snapshot(self):
        with self.assertRaises(ValueError):
            verify_event_tap_authorization(HOTKEYS.replace("shouldHandleEventTapShortcut()", "shouldHandleCustomSwitcherShortcut()"), LICENSING)

    def test_snapshot_rejects_missing_safety_guards(self):
        for literal in (
            "!BoundedKeychainReadRegistry.hasPendingReads,",
            "age < Self.shortcutMaximumValidationAge,",
            "now.addingTimeInterval(Self.clockRollbackTolerance) >= validatedAt",
            "return now < endsAt",
            "case .unregistered, .expired:",
        ):
            with self.subTest(literal=literal), self.assertRaises(ValueError):
                verify_event_tap_authorization(HOTKEYS, LICENSING.replace(literal, "/* removed */"))

    def test_snapshot_rejects_inline_security_work(self):
        for call in ("refreshStatus()", "licenseStore.loadLicenseKey()", "secureTrialClockStore.saveLastSeenDate(now)"):
            with self.subTest(call=call), self.assertRaises(ValueError):
                verify_event_tap_authorization(HOTKEYS, LICENSING.replace("func shouldHandleEventTapShortcut() -> Bool {", "func shouldHandleEventTapShortcut() -> Bool {\n        " + call))

    def test_denied_snapshot_states_cannot_grant_access(self):
        with self.assertRaises(ValueError):
            verify_event_tap_authorization(
                HOTKEYS,
                LICENSING.replace(
                    "case .unregistered, .expired:\n            return false",
                    "case .unregistered, .expired:\n            return true",
                ),
            )


if __name__ == "__main__":
    unittest.main()
