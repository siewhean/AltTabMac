#!/usr/bin/env bash
set -euo pipefail

ZIP_PATH="${1:-}"
EVIDENCE_DIR="${2:-}"
KEYCHAIN_PROFILE="${CMDTAB_NOTARY_PROFILE:-}"
KEY_ID="${CMDTAB_NOTARY_KEY_ID:-}"
ISSUER_ID="${CMDTAB_NOTARY_ISSUER:-}"
KEY_PATH="${CMDTAB_NOTARY_KEY_PATH:-}"

usage() {
  cat >&2 <<'USAGE'
Usage: notarize-app.sh /path/to/CmdTab.zip /path/to/evidence-directory

Choose exactly one authentication mode:

  Keychain profile:
    CMDTAB_NOTARY_PROFILE

  App Store Connect API key:
    CMDTAB_NOTARY_KEY_ID
    CMDTAB_NOTARY_ISSUER
    CMDTAB_NOTARY_KEY_PATH

This script does not support plaintext Apple ID passwords.
USAGE
}

fail() {
  echo "Notarization failed: $*" >&2
  exit 1
}

if [[ -z "${ZIP_PATH}" || -z "${EVIDENCE_DIR}" ]]; then
  usage
  exit 2
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "notarization must run on macOS"
fi

for tool in xcrun python3 shasum; do
  command -v "${tool}" >/dev/null 2>&1 || fail "missing required tool: ${tool}"
done

[[ -f "${ZIP_PATH}" ]] || fail "ZIP does not exist: ${ZIP_PATH}"
[[ "${ZIP_PATH}" == *.zip ]] || fail "notarization input must be a .zip archive"

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
fi

mkdir -p "${EVIDENCE_DIR}"
RESULT_JSON="${EVIDENCE_DIR}/notary-result.json"
LOG_JSON="${EVIDENCE_DIR}/notary-log.json"
SUBMISSION_ID_PATH="${EVIDENCE_DIR}/submission-id.txt"
AUTH_MODE_PATH="${EVIDENCE_DIR}/authentication-mode.txt"
ZIP_CHECKSUM_PATH="${EVIDENCE_DIR}/submitted-zip.sha256"
TMP_RESULT="$(mktemp "${EVIDENCE_DIR}/notary-result.XXXXXX")"

cleanup() {
  rm -f "${TMP_RESULT}"
}
trap cleanup EXIT

printf '%s\n' "${AUTH_MODE}" > "${AUTH_MODE_PATH}"
shasum -a 256 "${ZIP_PATH}" > "${ZIP_CHECKSUM_PATH}"

# Keep credentials out of command logs: only the authentication mode is printed.
printf 'Submitting %s to Apple notarization using %s authentication.\n' \
  "${ZIP_PATH}" "${AUTH_MODE}"

xcrun notarytool submit \
  "${ZIP_PATH}" \
  "${AUTH_ARGS[@]}" \
  --wait \
  --output-format json > "${TMP_RESULT}"

mv "${TMP_RESULT}" "${RESULT_JSON}"

readarray -t RESULT_FIELDS < <(
  python3 - "${RESULT_JSON}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
print(data.get("id", ""))
print(data.get("status", ""))
print(data.get("message", ""))
PY
)

SUBMISSION_ID="${RESULT_FIELDS[0]:-}"
STATUS="${RESULT_FIELDS[1]:-}"
MESSAGE="${RESULT_FIELDS[2]:-}"

[[ -n "${SUBMISSION_ID}" ]] || fail "notarytool response did not contain a submission ID"
printf '%s\n' "${SUBMISSION_ID}" > "${SUBMISSION_ID_PATH}"

# Persist Apple's full log for both accepted and rejected submissions.
if ! xcrun notarytool log "${SUBMISSION_ID}" "${AUTH_ARGS[@]}" > "${LOG_JSON}"; then
  echo "Warning: notarization result was received but the detailed log could not be downloaded." >&2
fi

if [[ "${STATUS}" != "Accepted" ]]; then
  printf 'Notarization status: %s\n' "${STATUS:-unknown}" >&2
  [[ -z "${MESSAGE}" ]] || printf 'Apple message: %s\n' "${MESSAGE}" >&2
  fail "Apple did not accept submission ${SUBMISSION_ID}; inspect ${RESULT_JSON} and ${LOG_JSON}"
fi

printf 'Notarization accepted.\n'
printf 'Submission ID: %s\n' "${SUBMISSION_ID}"
printf 'Result: %s\n' "${RESULT_JSON}"
printf 'Log: %s\n' "${LOG_JSON}"
