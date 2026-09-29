# macOS performance evidence

The repository-owned harness measures the packaged app on a real Mac. It does
not substitute model timings, unit-test timings, or generated sample data when
macOS permissions or observable UI behavior are unavailable.

## Run modes

Build and validate the smoke harness:

```bash
scripts/performance/run-performance-evidence.sh --mode readiness
```

Run the release gate from a clean committed checkout:

```bash
scripts/performance/run-performance-evidence.sh \
  --mode acceptance \
  --skip-build \
  --cmdtab-app /absolute/path/to/signed/CmdTab.app \
  --output-dir /absolute/evidence/directory
```

The acceptance run binds an explicitly supplied timestamped Hardened Runtime
Developer ID candidate to the current clean source SHA, builds the deterministic
WindowLab and PerformanceProbe fixtures, and executes:

- 100 switcher sessions with 10 fixture windows;
- 100 switcher sessions with 25 fixture windows;
- 100 switcher sessions with 50 fixture windows;
- a separate 1,000-session soak with 50 fixture windows.

Terminal, PerformanceProbe, CmdTab, and WindowLab must be allowed to exercise
Accessibility and Screen Recording as macOS requires. A blocked raw result
contains only typed prerequisite interruptions; it never substitutes an
excluded or fabricated timing sample. Codes cover Accessibility, Screen
Recording, fixture-count mismatch, candidate launch/frontmost mismatch, Secure
Input when independently observed, event-tap/HID rejection when proven,
timeouts, capture failure, and CmdTab termination/unresponsiveness. The probe
cannot introspect foreign Secure Input or an event tap, so it records those
limits explicitly rather than guessing their cause.

The probe terminates any running process with the candidate's bundle identifier
before launch, then verifies that macOS launched the exact supplied bundle path.
Save work that depends on a development CmdTab process before starting the run.

## Evidence contract

`manifest.json` binds every raw JSON file to:

- the full Git source SHA and clean/dirty source state;
- SHA-256 values for the exact CmdTab and WindowLab executables;
- host macOS version and architecture;
- the raw-file SHA-256;
- the run kind, fixture-window count, and session count.

Each session records shortcut-to-overlay reveal latency, externally visible
selection-change latency, observation screenshot duration, CmdTab CPU time,
resident memory, shortcut responsiveness, preview observation integrity,
fixture-application frontmost verification, and CmdTab liveness. The soak
manifest totals activation outcomes, missed overlay/shortcut attempts, preview
integrity failures, interrupted/crashed sessions, and bounded-memory signals.
Observation screenshot duration measures the probe's ScreenCaptureKit readback
used to detect UI changes; it does not claim to measure CmdTab's internal
preview or backdrop capture work.
Event-tap state is explicitly an external behavioral proxy: the harness can
prove that the shortcut produced the overlay, but it cannot introspect another
process's event-tap `CFMachPort`.

The evaluator reports p50/p95 reveal, selection, observation capture, and per-session CPU,
two-second settled idle CPU, warmed RSS growth, RSS regression slope, strictly
monotonic RSS growth, failed sessions, and unresponsive shortcut sessions.
Thresholds live in
`scripts/performance/evaluate-performance-evidence.py` and are sealed into the
manifest:

- warm reveal p50 at most 80 ms;
- warm reveal p95 at most 150 ms;
- externally observed selection p95 at most 600 ms;
- observation-window capture p95 at most 500 ms;
- per-session CmdTab CPU p95 at most 100 ms;
- settled idle CPU at most 1%;
- warmed RSS growth at most 32 MiB;
- warmed RSS slope at most 64 KiB per session;
- no strictly monotonic warmed RSS increase;
- no failed or shortcut-unresponsive session.

`readiness` can only produce `ready`, never `accepted`. Only the exact full
matrix from a clean checkout can produce `accepted`. That result applies to the
recorded host and artifact only; Apple Silicon and Intel evidence must be run
and retained separately, and neither result proves notarization, Gatekeeper, or
update behavior.

## Authorized-Mac release procedures

These procedures are physical release gates, not hosted-CI checks. Retain the
raw JSON, manifest, candidate SHA-256, source SHA, macOS version, architecture,
permission state, and terminal log for every run.

1. On a clean Apple Silicon checkout and separately on a clean Intel checkout,
   package the exact signed candidate, install it in an isolated account, grant
   Accessibility and Screen Recording, note the observed Secure Input state,
   then run the acceptance command. Preserve all 10/25/50-window and 1,000
   session soak samples; do not delete interrupted samples.
2. With VoiceOver enabled, exercise Command Palette search, result navigation,
   selection, cancel, and announcements. Record the macOS/VoiceOver version
   and any input, focus, or announcement failure.
3. Repeat exact-window activation with current, visible, and all-Spaces scope;
   include a second display and an off-Space target. Retain the selected and
   actual frontmost window identity with each manual result.
4. On a separate clean account, install the notarized candidate through the
   normal DMG path and retain Gatekeeper evidence. Then perform a real signed
   beta N→N+1 update from `releases/beta/appcast.xml`; retain both artifacts,
   appcast, updater logs, and persisted-settings result.

No deterministic CI result, local readiness run, or single architecture run
can satisfy these physical acceptance gates.
