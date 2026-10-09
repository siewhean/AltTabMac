# Private-capability canary procedure

This is a physical release gate for the exact signed candidate. It verifies the
degradation boundary for the AX window-ID bridge, SkyLight exact focus, and
SkyLight capture on **each supported macOS major version**. A receipt validated
by the repository script is only structurally valid and candidate-bound; it is
not an acceptance verdict and it must not be reported as CI success.

The canonical receipt shape is
[`private-capability-canary.schema.json`](private-capability-canary.schema.json).
It contains no titles, document paths, account names, raw screenshots, private
keys, or Apple credentials.

## Required environment

Run once on an authorized physical Mac running macOS 14, and separately on an
authorized physical Mac running macOS 15. Repeat on Apple Silicon and Intel as
required by the release matrix; a result on one OS or architecture never proves
another. Use a clean, isolated account and a clean checkout of the exact
candidate SHA. Install only the exact timestamped Developer ID candidate being
tested. Grant Accessibility and Screen Recording to CmdTab and the fixture only
when the canary needs them. Do not use a local ad-hoc package as a substitute.

Use two clearly distinct fixture windows from WindowLab (for example, its two
top-level windows after opening a second fixture instance). Do not record their
titles or raw identifiers in the receipt. Keep the terminal log and any local
diagnostics support report in the restricted release evidence location; redact
or retain separately if it could contain user data.

## Procedure

1. Record the clean checkout SHA, branch, and hash of
   `release/ReleaseConfig.json`. Confirm the app bundle identifier, marketing
   version, and build number from the signed candidate's `Contents/Info.plist`.
   Compute the SHA-256 and byte count of the **entire `.app` bundle archive**
   retained for release evidence (not just its executable). This is the
   `artifact` bound by the receipt.
2. Start CmdTab and the two fixture windows. Invoke CmdTab and select each
   sibling in both directions at least once. For each selection, independently
   observe the focused window using Accessibility. Increment
   `exactVerifiedCount` only when the selected fixture window is the focused
   window. Any application fallback, target disappearance, permission failure,
   or inability to verify belongs in `nonExactOutcomeCount`. If a different
   sibling became focused, stop: record `wrongSiblingCount: 1`, preserve the
   supporting diagnostics, and mark the receipt `blocked`.
3. Check the AX window-ID bridge against the same two fixture windows. If it
   round-trips each fixture to its own exact WindowServer identity, record
   `available` and `exact_id_round_trip`. If the bridge is unavailable or
   cannot resolve identity, record `degraded`, `unavailable`, or `failed` with
   a concise reason and `identity_unavailable`; do not remove either known Core
   Graphics fixture from the switcher to make the observation look successful.
4. Inspect the two preview tiles. Count a preview as correct only when it shows
   its own fixture. A placeholder labelled unavailable is permitted and must be
   counted in `truthfullyUnavailableCount`; a blank, stale, or sibling preview
   is never permitted. On a stale/cross-window preview, stop and record a
   nonzero `staleOrCrossWindowPreviewCount` in a `blocked` receipt.
5. Record the three capability states and reason only when state is not
   `available`. Include only aggregate fixture counts and outcome counters. Set
   both `operatorAcknowledgement.authorizedMac` and
   `operatorAcknowledgement.noSecretsIncluded` to `true` only after checking
   the JSON contains no credentials or user data.
6. Validate the retained receipt while the candidate bundle and clean checkout
   are still available:

   ```bash
     python3 scripts/release/validate-private-capability-canary.py \
     /restricted/evidence/private-capability-macos-14.json \
     --candidate <40-lowercase-source-sha> \
     --branch <candidate-branch> \
     --artifact /restricted/evidence/CmdTab.app.zip \
     --bundle /Applications/CmdTab.app \
     --require-current-checkout
   ```

   The validator compares the recorded candidate SHA, branch, release-config
   hash, artifact byte count and SHA-256, then reads the separately supplied
   installed `.app` bundle's `Contents/Info.plist` to confirm bundle metadata.
   Supply the same retained archive path that was hashed in the receipt and the
   installed bundle that was actually observed. A nonzero exit means the
   receipt cannot be used.

7. Retain one receipt and its restricted evidence per macOS major version. Add
   the candidate SHA, artifact SHA-256, host major version, architecture, and
   outcome to the release matrix. Do not change the private-capability or
   physical-completeness row to PASS until a release reviewer has evaluated
   both successful physical receipts and all other release gates.

A `blocked` receipt is valid retained failure evidence when it records a wrong
sibling or stale/cross-window preview. An `observed` receipt with either count
nonzero is rejected; validation never turns a blocked receipt into acceptance.

## Receipt example

Use this only as a redacted format example. Values must be produced on the
authorized Mac for the candidate being assessed.

```json
{
  "schemaVersion": 1,
  "receiptKind": "cmdtab.private-capability-canary",
  "receiptState": "observed",
  "source": {
    "sha": "<40 lowercase source SHA>",
    "branch": "main",
    "clean": true,
    "releaseConfigSHA256": "<64 lowercase SHA-256>"
  },
  "artifact": {
    "path": "/restricted/evidence/CmdTab.app.zip",
    "sha256": "<64 lowercase SHA-256>",
    "bytes": 123456,
    "bundleIdentifier": "net.cmdtab.CmdTab",
    "marketingVersion": "1.0.0",
    "buildNumber": "1"
  },
  "host": { "productVersion": "14.7.1", "majorVersion": 14, "architecture": "arm64" },
  "recordedAt": "2026-09-09T00:00:00Z",
  "operatorAcknowledgement": { "authorizedMac": true, "noSecretsIncluded": true },
  "capabilities": {
    "axWindowIDBridge": {
      "state": "available", "failureReason": null,
      "fixtureWindowCount": 2, "roundTripResult": "exact_id_round_trip"
    },
    "skyLightExactFocus": {
      "state": "available", "failureReason": null,
      "iterations": 2, "exactVerifiedCount": 2,
      "nonExactOutcomeCount": 0, "wrongSiblingCount": 0
    },
    "skyLightCapture": {
      "state": "available", "failureReason": null,
      "fixtureWindowCount": 2, "correctPreviewCount": 2,
      "truthfullyUnavailableCount": 0, "staleOrCrossWindowPreviewCount": 0
    }
  }
}
```

## Hosted CI boundary

Hosted CI runs only
`scripts/release/test-private-capability-canary.py`, which checks the schema
and validator's fail-closed rules. It does not run private APIs, grant macOS
permissions, open fixtures, observe a physical desktop, or accept the canary.
