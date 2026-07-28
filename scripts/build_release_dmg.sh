#!/usr/bin/env bash
# Compatibility wrapper for the credential-gated notarized release pipeline.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${ROOT_DIR}/scripts/release/build-notarized-dmg.sh" "$@"
