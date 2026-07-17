#!/usr/bin/env python3
"""Apply the final PID-level fallback correction with asserted replacements."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(relative_path: str, old: str, new: str) -> None:
    path = ROOT / relative_path
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(
            f"Expected exactly one match in {relative_path}, found {count}:\n{old}"
        )
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_once(
    "Sources/CmdTab/AppSwitcher.swift",
    """        let representedWindowPIDs = Set(windowItems.compactMap(\\.historyIdentity.ownerPID))
        let representedWindowAppIdentifiers = Set(windowItems.compactMap(\\.sourceAppIdentifier))
        var seenFallbackAppIdentifiers = Set<String>()
        let fallbackHistoryEntries = history.snapshot()
""",
    """        let representedWindowPIDs = Set(windowItems.compactMap(\\.historyIdentity.ownerPID))
        var seenFallbackPIDs = Set<pid_t>()
        let fallbackHistoryEntries = history.snapshot()
""",
)

replace_once(
    "Sources/CmdTab/AppSwitcher.swift",
    """                guard Self.shouldIncludeFallbackApp(
                    processIdentifier: app.processIdentifier,
                    sourceAppIdentifier: sourceAppIdentifier,
                    representedWindowPIDs: representedWindowPIDs,
                    representedWindowAppIdentifiers: representedWindowAppIdentifiers,
                    seenFallbackAppIdentifiers: &seenFallbackAppIdentifiers
                ) else {
""",
    """                guard Self.shouldIncludeFallbackApp(
                    processIdentifier: app.processIdentifier,
                    representedWindowPIDs: representedWindowPIDs,
                    seenFallbackPIDs: &seenFallbackPIDs
                ) else {
""",
)

replace_once(
    "Sources/CmdTab/AppSwitcher.swift",
    """    static func shouldIncludeFallbackApp(
        processIdentifier: pid_t,
        sourceAppIdentifier: String,
        representedWindowPIDs: Set<pid_t>,
        representedWindowAppIdentifiers: Set<String>,
        seenFallbackAppIdentifiers: inout Set<String>
    ) -> Bool {
        guard !representedWindowPIDs.contains(processIdentifier) else { return false }
        guard !representedWindowAppIdentifiers.contains(sourceAppIdentifier) else { return false }
        return seenFallbackAppIdentifiers.insert(sourceAppIdentifier).inserted
    }
""",
    """    static func shouldIncludeFallbackApp(
        processIdentifier: pid_t,
        representedWindowPIDs: Set<pid_t>,
        seenFallbackPIDs: inout Set<pid_t>
    ) -> Bool {
        // A regular running process without an emitted window gets one fallback.
        // Bundle-level deduplication is incorrect because two independent regular
        // processes may legitimately share a bundle identifier.
        guard !representedWindowPIDs.contains(processIdentifier) else { return false }
        return seenFallbackPIDs.insert(processIdentifier).inserted
    }
""",
)

replace_once(
    "Tests/CmdTabTests/AppSwitcherActivationTests.swift",
    """    func testFallbackAppsAreDroppedWhenWindowsAlreadyRepresentThatApp() {
        var seen = Set<String>()

        XCTAssertFalse(
            AppSwitcher.shouldIncludeFallbackApp(
                processIdentifier: 101,
                sourceAppIdentifier: "com.apple.finder",
                representedWindowPIDs: [101],
                representedWindowAppIdentifiers: ["com.apple.finder"],
                seenFallbackAppIdentifiers: &seen
            )
        )
    }

    func testFallbackAppsAreDeduplicatedByApplicationIdentifier() {
        var seen = Set<String>()

        XCTAssertTrue(
            AppSwitcher.shouldIncludeFallbackApp(
                processIdentifier: 101,
                sourceAppIdentifier: "com.apple.finder",
                representedWindowPIDs: [],
                representedWindowAppIdentifiers: [],
                seenFallbackAppIdentifiers: &seen
            )
        )

        XCTAssertFalse(
            AppSwitcher.shouldIncludeFallbackApp(
                processIdentifier: 202,
                sourceAppIdentifier: "com.apple.finder",
                representedWindowPIDs: [],
                representedWindowAppIdentifiers: [],
                seenFallbackAppIdentifiers: &seen
            )
        )
    }
""",
    """    func testFallbackAppIsDroppedWhenTheSameProcessAlreadyHasAWindow() {
        var seen = Set<pid_t>()

        XCTAssertFalse(
            AppSwitcher.shouldIncludeFallbackApp(
                processIdentifier: 101,
                representedWindowPIDs: [101],
                seenFallbackPIDs: &seen
            )
        )
    }

    func testFallbackAppsRemainDistinctForProcessesSharingABundleIdentifier() {
        var seen = Set<pid_t>()

        XCTAssertTrue(
            AppSwitcher.shouldIncludeFallbackApp(
                processIdentifier: 101,
                representedWindowPIDs: [],
                seenFallbackPIDs: &seen
            )
        )

        XCTAssertTrue(
            AppSwitcher.shouldIncludeFallbackApp(
                processIdentifier: 202,
                representedWindowPIDs: [],
                seenFallbackPIDs: &seen
            )
        )

        XCTAssertFalse(
            AppSwitcher.shouldIncludeFallbackApp(
                processIdentifier: 202,
                representedWindowPIDs: [],
                seenFallbackPIDs: &seen
            )
        )
    }
""",
)

print("Applied PID-level fallback repair successfully.")
