#!/usr/bin/env python3
"""
Exact, dependency-free model checks for the reviewed CmdTab switcher logic.

This captures the pre-fix behavior that motivated the regression suite:
1. exact-identity MRU ordering with the current identity moved to the end;
2. initial selection skipping every item that shares the current PID;
3. final-phase membership dropping previewless candidates while fallback apps
   are suppressed by all candidates.

It does not simulate macOS, AppKit, Accessibility, or real activation.
"""

from itertools import product
import json

ITEMS = [
    ("A1", "A"),
    ("A2", "A"),
    ("B1", "B"),
    ("B2", "B"),
    ("C1", "C"),
]
RAW_ORDER = [identity for identity, _ in ITEMS]
PID = dict(ITEMS)


def history_after(sequence):
    history = []
    for identity in sequence:
        if identity in history:
            history.remove(identity)
        history.insert(0, identity)
    return history


def ordered_items(sequence):
    history = history_after(sequence)
    current = sequence[-1]
    ranked = sorted(
        enumerate(RAW_ORDER),
        key=lambda pair: (
            history.index(pair[1]) if pair[1] in history else 10**9,
            pair[0],
        ),
    )
    result = [identity for _, identity in ranked]
    result.remove(current)
    result.append(current)
    return result, history, current


def current_forward_selection(ordered, current):
    if len(ordered) <= 1:
        return 0
    current_pid = PID[current]
    for index, identity in enumerate(ordered):
        if PID[identity] != current_pid:
            return index
    return 0


def strict_forward_selection(ordered, current):
    # Once current has been moved to the end, strict global MRU selects index 0.
    return 0


def run_mru_check(max_sequence_length=6):
    meaningful = 0
    mismatches = 0
    examples = []

    for length in range(1, max_sequence_length + 1):
        for sequence in product(RAW_ORDER, repeat=length):
            ordered, history, current = ordered_items(sequence)

            # Avoid judging the relative order of never-focused windows.
            if ordered[0] not in history:
                continue

            meaningful += 1
            actual_index = current_forward_selection(ordered, current)
            expected_index = strict_forward_selection(ordered, current)
            if actual_index != expected_index:
                mismatches += 1
                if len(examples) < 10:
                    examples.append(
                        {
                            "activation_sequence": list(sequence),
                            "history": history,
                            "ordered_tiles": ordered,
                            "strict_selection": ordered[expected_index],
                            "current_selection": ordered[actual_index],
                        }
                    )

    return {
        "window_universe": RAW_ORDER,
        "max_sequence_length": max_sequence_length,
        "meaningful_sequences_checked": meaningful,
        "strict_mru_selection_mismatches": mismatches,
        "mismatch_rate": mismatches / meaningful if meaningful else 0,
        "examples": examples,
    }


def run_preview_check(max_apps=6):
    configurations = 0
    failures = 0
    examples = []

    for app_count in range(1, max_apps + 1):
        apps = [f"App{index}" for index in range(1, app_count + 1)]
        for success_bits in product([False, True], repeat=app_count):
            configurations += 1

            emitted_window_apps = {
                app for app, success in zip(apps, success_bits) if success
            }
            candidate_apps = set(apps)
            fallback_apps = {app for app in apps if app not in candidate_apps}
            visible_apps = emitted_window_apps | fallback_apps

            if visible_apps != set(apps):
                failures += 1
                if len(examples) < 10:
                    examples.append(
                        {
                            "apps": apps,
                            "preview_success": dict(zip(apps, success_bits)),
                            "visible_apps": sorted(visible_apps),
                            "missing_apps": sorted(set(apps) - visible_apps),
                        }
                    )

    return {
        "app_counts": [1, max_apps],
        "preview_success_configurations_checked": configurations,
        "completeness_failures": failures,
        "failure_rate": failures / configurations if configurations else 0,
        "examples": examples,
    }


if __name__ == "__main__":
    result = {
        "mru_selection": run_mru_check(),
        "preview_completeness": run_preview_check(),
    }
    print(json.dumps(result, indent=2))
