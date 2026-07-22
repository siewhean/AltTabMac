#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-}"
MAX_ATTEMPTS="${CMDTAB_STAPLE_ATTEMPTS:-5}"
RETRY_DELAY="${CMDTAB_STAPLE_RETRY_DELAY:-15}"

usage() {
  echo "Usage: staple-app.sh /path/to/signed/CmdTab.app" >&2
}

fail() {
  echo "Stapling failed: $*" >&2
  exit 1
}

if [[ -z "${APP_PATH}" ]]; then
  usage
  exit 2
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "stapling must run on macOS"
fi

for tool in xcrun; do
  command -v "${tool}" >/dev/null 2>&1 || fail "missing required tool: ${tool}"
done

[[ -d "${APP_PATH}" ]] || fail "app bundle does not exist: ${APP_PATH}"
[[ "${MAX_ATTEMPTS}" =~ ^[1-9][0-9]*$ ]] || fail "CMDTAB_STAPLE_ATTEMPTS must be a positive integer"
[[ "${RETRY_DELAY}" =~ ^[0-9]+$ ]] || fail "CMDTAB_STAPLE_RETRY_DELAY must be a non-negative integer"

attempt=1
while true; do
  if xcrun stapler staple -v "${APP_PATH}"; then
    break
  fi

  if [[ "${attempt}" -ge "${MAX_ATTEMPTS}" ]]; then
    fail "ticket was not available after ${MAX_ATTEMPTS} attempts"
  fi

  echo "Staple attempt ${attempt} failed; retrying in ${RETRY_DELAY}s." >&2
  sleep "${RETRY_DELAY}"
  attempt=$((attempt + 1))
done

xcrun stapler validate -v "${APP_PATH}"
printf 'Stapled and validated notarization ticket: %s\n' "${APP_PATH}"
