#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'CmdTab signed-release preflight\n'
printf 'Repository: %s\n\n' "${ROOT_DIR}"

missing=0
for tool in codesign ditto hdiutil python3 spctl swift xcrun; do
  if command -v "${tool}" >/dev/null 2>&1; then
    printf 'PASS tool: %s\n' "${tool}"
  else
    printf 'FAIL tool: %s\n' "${tool}"
    missing=1
  fi
done

for variable_name in \
  CMDTAB_SIGNING_IDENTITY \
  CMDTAB_NOTARY_PROFILE \
  CMDTAB_SPARKLE_PUBLIC_ED_KEY; do
  if [[ -n "${!variable_name:-}" ]]; then
    printf 'PASS variable: %s is set\n' "${variable_name}"
  else
    printf 'FAIL variable: %s is not set\n' "${variable_name}"
    missing=1
  fi
done

python3 "${ROOT_DIR}/scripts/release/release_config.py" verify-repository

if [[ "${missing}" != "0" ]]; then
  printf '\nRelease credentials or tools are incomplete. No notarization was attempted.\n' >&2
  exit 2
fi

cat <<'MESSAGE'

Preflight passed. Build, leaf-first sign, notarize, staple, and assess with:
  ./scripts/build_release_dmg.sh

Then follow:
  docs/release/signed-update-runbook.md

This preflight is not notarization, Gatekeeper, or clean-hardware evidence.
MESSAGE
