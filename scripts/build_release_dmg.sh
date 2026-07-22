#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cat >&2 <<'MESSAGE'
The legacy CmdTab DMG builder remains intentionally disabled.

It previously allowed release metadata overrides and performed Developer ID signing,
DMG signing, notarization, and stapling outside the reviewed ReleaseConfig and QA
gates. Re-enabling that implementation could produce a distributable artifact whose
bundle identity, version, entitlements, signing identity, or evidence diverged from
the source repository.

Phase 1 local QA:
  ./scripts/release/run-phase1-qa.sh

Phase 2 signed/notarized/stapled ZIP:
  ./scripts/release/run-phase2-qa.sh

The reviewed Phase 2 pipeline preserves a deterministic unsigned input, signs a copied
bundle, submits a notarization-safe ZIP, staples the app, recreates the final ZIP, and
verifies strict codesign, entitlements, Gatekeeper, archive extraction, and checksums.

A DMG may be added later only as a thin container around the already accepted signed
and stapled app. It must not create a second signing or metadata source of truth.
MESSAGE

printf '\nRepository: %s\n' "${ROOT_DIR}" >&2
exit 2
