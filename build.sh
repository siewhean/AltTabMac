#!/usr/bin/env bash
# Compatibility wrapper for the deterministic Phase 1 packaging pipeline.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CMDTAB_OUTPUT_APP="${ROOT_DIR}/CmdTab.app" \
  "${ROOT_DIR}/scripts/release/package-app.sh"

echo
printf 'Local QA bundle: %s\n' "${ROOT_DIR}/CmdTab.app"
echo "This bundle is ad-hoc signed for local testing only."
echo "Developer ID signing and notarization are separate Phase 2 gates."
