"""Structural authorization contract for the production event-tap path."""

from __future__ import annotations

import re


def method(source: str, name: str) -> str:
    match = re.search(
        rf"^    (?:private |static |@\w+ )*func {re.escape(name)}\(",
        source,
        re.MULTILINE,
    )
    if not match:
        raise ValueError(f"Missing authorization method: {name}")
    remainder = source[match.end():]
    next_method = re.search(r"^    (?:private |static |@\w+ )*func \w+\(", remainder, re.MULTILINE)
    body = remainder[:next_method.start()] if next_method else remainder
    return re.sub(r"//[^\n]*", "", body)


def verify_event_tap_authorization(hotkeys: str, licensing: str) -> None:
    for name in ("handleKeyDown", "handleAlternateModifierChange"):
        body = method(hotkeys, name)
        if not re.search(
            r"let shouldHandleShortcut = MainActor\.assumeIsolated\s*\{\s*"
            r"LicensingController\.shared\.shouldHandleEventTapShortcut\(\)\s*\}"
            r"\s*guard shouldHandleShortcut else\s*\{",
            body,
        ):
            raise ValueError(f"{name} must guard the validated event-tap snapshot")
        if "shouldHandleCustomSwitcherShortcut" in body:
            raise ValueError(f"{name} must not synchronously refresh licensing")

    snapshot = method(licensing, "shouldHandleEventTapShortcut")
    required = (
        "scheduleShortcutRefresh()",
        "guard !BoundedKeychainReadRegistry.hasPendingReads,",
        "let age, age >= 0, age < Self.shortcutMaximumValidationAge,",
        "let validatedAt = shortcutValidatedAt,",
        "now.addingTimeInterval(Self.clockRollbackTolerance) >= validatedAt else",
        "switch status",
        "case .licensed:",
        "case let .activeTrial(_, endsAt, _):",
        "return now < endsAt",
        "case .unregistered, .expired:",
        "return false",
    )
    for literal in required:
        if literal not in snapshot:
            raise ValueError(f"Event-tap authorization is missing: {literal}")
    if snapshot.index("guard !BoundedKeychainReadRegistry") > snapshot.index("switch status"):
        raise ValueError("Snapshot validity must be guarded before granting access")
    for denied_branch in (
        r">= validatedAt else\s*\{\s*return false\s*\}",
        r"case \.unregistered, \.expired:\s*return false",
    ):
        if not re.search(denied_branch, snapshot):
            raise ValueError("Unknown or invalid authorization must fail closed")
    if "return true" in snapshot[:snapshot.index("switch status")]:
        raise ValueError("Access must not bypass snapshot validation")
    if re.search(r"\b(?:refreshStatus|validate\w*|load\w*|save\w*)\s*\(", snapshot):
        raise ValueError("Event-tap authorization must not refresh or access security stores")
    refresh = method(licensing, "scheduleShortcutRefresh")
    if "DispatchQueue.main.asyncAfter" not in refresh or "self.refreshStatus()" not in refresh:
        raise ValueError("Licensing revalidation must be dispatched asynchronously")
