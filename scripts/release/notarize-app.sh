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
    CMDTAB_NOTARY_KEY_PATH
    CMDTAB_NOTARY_ISSUER     Required for team keys; omit for individual keys

This script does not support plaintext Apple ID passwords.
USAGE
}

fail() {
  echo "Notarization failed: $*" >&2
  exit 1
}

if [[ -z "${ZIP_PATH}" || -z "${EVIDENCE_DIR}" ]]; then usage; exit 2; fi
if [[ "$(uname -s)" != "Darwin" ]]; then fail "notarization must run on macOS"; fi
for tool in xcrun python3 shasum; do command -v "${tool}" >/dev/null 2>&1 || fail "missing required tool: ${tool}"; done
[[ -f "${ZIP_PATH}" ]] || fail "ZIP does not exist: ${ZIP_PATH}"
[[ "${ZIP_PATH}" == *.zip ]] || fail "notarization input must be a .zip archive"

PROFILE_MODE=0
API_MODE=0
[[ -n "${KEYCHAIN_PROFILE}" ]] && PROFILE_MODE=1
if [[ -n "${KEY_ID}" || -n "${ISSUER_ID}" || -n "${KEY_PATH}" ]]; then API_MODE=1; fi
if [[ "${PROFILE_MODE}" == "1" && "${API_MODE}" == "1" ]]; then fail "configure either CMDTAB_NOTARY_PROFILE or API-key credentials, not both"; fi
if [[ "${PROFILE_MODE}" == "0" && "${API_MODE}" == "0" ]]; then fail "no notarization credentials were configured"; fi

AUTH_ARGS=()
AUTH_MODE=""
if [[ "${PROFILE_MODE}" == "1" ]]; then
  AUTH_MODE="keychain-profile"
  AUTH_ARGS=(--keychain-profile "${KEYCHAIN_PROFILE}")
else
  [[ -n "${KEY_ID}" ]] || fail "CMDTAB_NOTARY_KEY_ID is required for API-key authentication"
  [[ -n "${KEY_PATH}" ]] || fail "CMDTAB_NOTARY_KEY_PATH is required for API-key authentication"
  [[ -f "${KEY_PATH}" ]] || fail "API key file does not exist: ${KEY_PATH}"
  AUTH_MODE="app-store-connect-api-key"
  AUTH_ARGS=(--key "${KEY_PATH}" --key-id "${KEY_ID}")
  if [[ -n "${ISSUER_ID}" ]]; then AUTH_ARGS+=(--issuer "${ISSUER_ID}"); fi
fi

mkdir -p "${EVIDENCE_DIR}"
RESULT_JSON="${EVIDENCE_DIR}/notary-result.json"
LOG_JSON="${EVIDENCE_DIR}/notary-log.json"
SUBMISSION_ID_PATH="${EVIDENCE_DIR}/submission-id.txt"
AUTH_MODE_PATH="${EVIDENCE_DIR}/authentication-mode.txt"
ZIP_CHECKSUM_PATH="${EVIDENCE_DIR}/submitted-zip.sha256"
TMP_RESULT="$(mktemp "${EVIDENCE_DIR}/notary-result.XXXXXX")"
cleanup() { rm -f "${TMP_RESULT}"; }
trap cleanup EXIT

printf '%s\n' "${AUTH_MODE}" > "${AUTH_MODE_PATH}"
(
  cd "$(dirname "${ZIP_PATH}")"
  shasum -a 256 "$(basename "${ZIP_PATH}")"
) > "${ZIP_CHECKSUM_PATH}"

printf 'Submitting %s to Apple notarization using %s authentication.\n' "${ZIP_PATH}" "${AUTH_MODE}"
xcrun notarytool submit "${ZIP_PATH}" "${AUTH_ARGS[@]}" --wait --output-format json > "${TMP_RESULT}"
mv "${TMP_RESULT}" "${RESULT_JSON}"

SUBMISSION_ID="$(python3 - "${RESULT_JSON}" <<'PY'
import json, sys
from pathlib import Path
print(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")).get("id", ""))
PY
)"
STATUS="$(python3 - "${RESULT_JSON}" <<'PY'
import json, sys
from pathlib import Path
print(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")).get("status", ""))
PY
)"
MESSAGE="$(python3 - "${RESULT_JSON}" <<'PY'
import json, sys
from pathlib import Path
print(str(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")).get("message", "")).replace("\n", " "))
PY
)"

[[ -n "${SUBMISSION_ID}" ]] || fail "notarytool response did not contain a submission ID"
printf '%s\n' "${SUBMISSION_ID}" > "${SUBMISSION_ID_PATH}"

rm -f "${LOG_JSON}"
if ! xcrun notarytool log "${SUBMISSION_ID}" "${AUTH_ARGS[@]}" "${LOG_JSON}"; then
  fail "notarization result was received but the detailed Apple log could not be downloaded"
fi
[[ -s "${LOG_JSON}" ]] || fail "Apple notarization log is empty"

if [[ "${STATUS}" != "Accepted" ]]; then
  printf 'Notarization status: %s\n' "${STATUS:-unknown}" >&2
  [[ -z "${MESSAGE}" ]] || printf 'Apple message: %s\n' "${MESSAGE}" >&2
  fail "Apple did not accept submission ${SUBMISSION_ID}; inspect ${RESULT_JSON} and ${LOG_JSON}"
fi

python3 - "${LOG_JSON}" <<'PY'
import json, sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
issues = data.get("issues") or []
if issues:
    for issue in issues:
        print(f"{issue.get('severity', 'unknown')}: {issue.get('path', 'unknown path')}: {issue.get('message', 'no message')}", file=sys.stderr)
    raise SystemExit("Apple accepted the submission but the notarization log contains issues")
PY

printf 'Notarization accepted with an issue-free log.\n'
printf 'Submission ID: %s\n' "${SUBMISSION_ID}"
printf 'Result: %s\n' "${RESULT_JSON}"
printf 'Log: %s\n' "${LOG_JSON}"
