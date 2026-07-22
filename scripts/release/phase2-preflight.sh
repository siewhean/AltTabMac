#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_VERIFY_TOOL="${ROOT_DIR}/scripts/release/verify-phase2-source.py"
SIGNING_IDENTITY="${CMDTAB_DEVELOPER_IDENTITY:-}"
EXPECTED_TEAM_ID="${CMDTAB_TEAM_ID:-}"
KEYCHAIN_PROFILE="${CMDTAB_NOTARY_PROFILE:-}"
KEY_ID="${CMDTAB_NOTARY_KEY_ID:-}"
ISSUER_ID="${CMDTAB_NOTARY_ISSUER:-}"
KEY_PATH="${CMDTAB_NOTARY_KEY_PATH:-}"
TEMP_ROOT="$(mktemp -d /tmp/cmdtab-phase2-preflight.XXXXXX)"

usage() {
  cat >&2 <<'USAGE'
Usage: phase2-preflight.sh

Required environment:
  CMDTAB_DEVELOPER_IDENTITY  Exact Developer ID Application certificate name
  CMDTAB_TEAM_ID             Expected 10-character Apple Developer Team ID

Choose exactly one notarization authentication mode:

  Keychain profile:
    CMDTAB_NOTARY_PROFILE

  App Store Connect API key:
    CMDTAB_NOTARY_KEY_ID
    CMDTAB_NOTARY_ISSUER
    CMDTAB_NOTARY_KEY_PATH

This command does not build, sign, submit, staple, or publish an artifact.
USAGE
}

fail() {
  echo "Phase 2 preflight failed: $*" >&2
  exit 1
}

cleanup() {
  rm -rf "${TEMP_ROOT}"
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "preflight must run on macOS"
fi

for tool in security xcrun python3 sed wc tr; do
  command -v "${tool}" >/dev/null 2>&1 || fail "missing required tool: ${tool}"
done

[[ -n "${SIGNING_IDENTITY}" ]] || {
  usage
  fail "CMDTAB_DEVELOPER_IDENTITY is required"
}
[[ -n "${EXPECTED_TEAM_ID}" ]] || {
  usage
  fail "CMDTAB_TEAM_ID is required"
}
[[ "${EXPECTED_TEAM_ID}" =~ ^[A-Z0-9]{10}$ ]] || fail "CMDTAB_TEAM_ID must be a 10-character uppercase alphanumeric Team ID"
[[ "${SIGNING_IDENTITY}" == Developer\ ID\ Application:* ]] || fail "CMDTAB_DEVELOPER_IDENTITY must name a Developer ID Application certificate"
[[ "${SIGNING_IDENTITY}" == *"(${EXPECTED_TEAM_ID})"* ]] || fail "signing identity does not contain the expected Team ID"

python3 "${SOURCE_VERIFY_TOOL}"

IDENTITIES="$(security find-identity -v -p codesigning 2>&1 || true)"
MATCHING_IDENTITIES="$(printf '%s\n' "${IDENTITIES}" | grep -F "\"${SIGNING_IDENTITY}\"" || true)"
MATCH_COUNT="$(printf '%s\n' "${MATCHING_IDENTITIES}" | sed '/^$/d' | wc -l | tr -d '[:space:]')"
if [[ "${MATCH_COUNT}" == "0" ]]; then
  printf '%s\n' "${IDENTITIES}" >&2
  fail "the requested Developer ID identity is not available in the active keychain search list"
fi
if [[ "${MATCH_COUNT}" != "1" ]]; then
  printf '%s\n' "${IDENTITIES}" >&2
  fail "the requested Developer ID identity is ambiguous; expected one match, found ${MATCH_COUNT}"
fi

PROFILE_MODE=0
API_MODE=0
[[ -n "${KEYCHAIN_PROFILE}" ]] && PROFILE_MODE=1
if [[ -n "${KEY_ID}" || -n "${ISSUER_ID}" || -n "${KEY_PATH}" ]]; then
  API_MODE=1
fi

if [[ "${PROFILE_MODE}" == "1" && "${API_MODE}" == "1" ]]; then
  fail "configure either CMDTAB_NOTARY_PROFILE or API-key credentials, not both"
fi
if [[ "${PROFILE_MODE}" == "0" && "${API_MODE}" == "0" ]]; then
  usage
  fail "no notarization credentials were configured"
fi

AUTH_ARGS=()
AUTH_MODE=""
if [[ "${PROFILE_MODE}" == "1" ]]; then
  AUTH_MODE="keychain-profile"
  AUTH_ARGS=(--keychain-profile "${KEYCHAIN_PROFILE}")
else
  [[ -n "${KEY_ID}" ]] || fail "CMDTAB_NOTARY_KEY_ID is required for API-key authentication"
  [[ -n "${ISSUER_ID}" ]] || fail "CMDTAB_NOTARY_ISSUER is required for API-key authentication"
  [[ -n "${KEY_PATH}" ]] || fail "CMDTAB_NOTARY_KEY_PATH is required for API-key authentication"
  [[ -f "${KEY_PATH}" ]] || fail "API key file does not exist: ${KEY_PATH}"
  AUTH_MODE="app-store-connect-api-key"
  AUTH_ARGS=(--key "${KEY_PATH}" --key-id "${KEY_ID}" --issuer "${ISSUER_ID}")

  python3 - "${KEY_PATH}" <<'PY'
import stat
import sys
from pathlib import Path

path = Path(sys.argv[1])
mode = stat.S_IMODE(path.stat().st_mode)
if mode & 0o077:
    raise SystemExit(
        f"App Store Connect API key permissions are too broad: {oct(mode)}; "
        "use chmod 600"
    )
PY
fi

HISTORY_JSON="${TEMP_ROOT}/notary-history.json"
printf 'Validating Apple notarization authentication using %s mode.\n' "${AUTH_MODE}"
xcrun notarytool history \
  "${AUTH_ARGS[@]}" \
  --output-format json > "${HISTORY_JSON}"

python3 - "${HISTORY_JSON}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
if not isinstance(data, dict):
    raise SystemExit("notarytool history did not return a JSON object")
# An account with no previous submissions is valid. Authentication success and a
# parseable response are the preflight boundary; no submission is created here.
PY

printf 'Phase 2 preflight passed.\n'
printf 'Signing identity: %s\n' "${SIGNING_IDENTITY}"
printf 'Team ID: %s\n' "${EXPECTED_TEAM_ID}"
printf 'Notarization authentication: %s\n' "${AUTH_MODE}"
printf 'No artifact was built or submitted.\n'
