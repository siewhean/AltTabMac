#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cat >&2 <<'MESSAGE'
The legacy CmdTab DMG builder is intentionally disabled.

It previously allowed release metadata overrides and performed Developer ID signing,
DMG signing, notarization, and stapling outside the reviewed ReleaseConfig and QA
gates. Using that path could produce a distributable artifact whose bundle identity,
version, entitlements, or evidence diverged from the source repository.

Phase 1 local QA:
  ./scripts/release/run-phase1-qa.sh

Local ad-hoc bundle only:
  ./scripts/release/package-app.sh

Developer ID signing, notarization, stapling, Gatekeeper assessment, and the final
DMG pipeline will be implemented and re-enabled in Phase 2 after the Phase 1 macOS
gate passes and protected Apple credentials are available.
MESSAGE

printf '\nRepository: %s\n' "${ROOT_DIR}" >&2
exit 2
