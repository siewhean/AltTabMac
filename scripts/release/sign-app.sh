#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_TOOL="${ROOT_DIR}/scripts/release/release_config.py"
VERIFY_TOOL="${ROOT_DIR}/scripts/release/verify-bundle.sh"
INPUT_APP="${1:-}"
OUTPUT_APP="${2:-}"
SIGNING_IDENTITY="${CMDTAB_DEVELOPER_IDENTITY:-}"
EXPECTED_TEAM_ID="${CMDTAB_TEAM_ID:-}"
ENTITLEMENTS_PATH="${CMDTAB_DISTRIBUTION_ENTITLEMENTS:-${ROOT_DIR}/release/CmdTab.entitlements}"
INPUT_SIGNING="${CMDTAB_INPUT_SIGNING:-unsigned}"

usage() {
  cat >&2 <<'USAGE'
Usage: sign-app.sh /path/to/unsigned/CmdTab.app /path/to/signed/CmdTab.app

Required environment:
  CMDTAB_DEVELOPER_IDENTITY  Exact Developer ID Application certificate name
  CMDTAB_TEAM_ID             Expected Apple Developer Team ID

Optional environment:
  CMDTAB_DISTRIBUTION_ENTITLEMENTS  Reviewed entitlement plist
  CMDTAB_INPUT_SIGNING              unsigned (default) or ad-hoc
USAGE
}

fail() {
  echo "Developer ID signing failed: $*" >&2
  exit 1
}

if [[ -z "${INPUT_APP}" || -z "${OUTPUT_APP}" ]]; then
  usage
  exit 2
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "signing must run on macOS"
fi

for tool in codesign security ditto plutil python3; do
  command -v "${tool}" >/dev/null 2>&1 || fail "missing required tool: ${tool}"
done

[[ -d "${INPUT_APP}" ]] || fail "input app does not exist: ${INPUT_APP}"
[[ -n "${SIGNING_IDENTITY}" ]] || fail "CMDTAB_DEVELOPER_IDENTITY is required"
[[ -n "${EXPECTED_TEAM_ID}" ]] || fail "CMDTAB_TEAM_ID is required"
[[ "${SIGNING_IDENTITY}" != "-" ]] || fail "ad-hoc identity is not valid for Phase 2"
[[ -f "${ENTITLEMENTS_PATH}" ]] || fail "entitlements file does not exist: ${ENTITLEMENTS_PATH}"
plutil -lint "${ENTITLEMENTS_PATH}" >/dev/null

case "${INPUT_SIGNING}" in
  unsigned|ad-hoc) ;;
  *) fail "CMDTAB_INPUT_SIGNING must be unsigned or ad-hoc" ;;
esac

INPUT_REAL="$(python3 - "${INPUT_APP}" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
)"
OUTPUT_REAL="$(python3 - "${OUTPUT_APP}" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
)"
[[ "${INPUT_REAL}" != "${OUTPUT_REAL}" ]] || fail "input and output paths must differ"

python3 "${CONFIG_TOOL}" verify-repository
"${VERIFY_TOOL}" "${INPUT_APP}" "${INPUT_SIGNING}"

IDENTITIES="$(security find-identity -v -p codesigning 2>&1 || true)"
grep -Fq "\"${SIGNING_IDENTITY}\"" <<<"${IDENTITIES}" || {
  printf '%s\n' "${IDENTITIES}" >&2
  fail "the requested signing identity is not available in the active keychain search list"
}

rm -rf "${OUTPUT_APP}"
mkdir -p "$(dirname "${OUTPUT_APP}")"
ditto "${INPUT_APP}" "${OUTPUT_APP}"
xattr -cr "${OUTPUT_APP}" 2>/dev/null || true

EXECUTABLE_NAME="$(python3 "${CONFIG_TOOL}" get executableName)"
MAIN_EXECUTABLE="${OUTPUT_APP}/Contents/MacOS/${EXECUTABLE_NAME}"

# Remove any inherited bundle or linker-generated ad-hoc signatures from the copy.
if codesign -d "${OUTPUT_APP}" >/dev/null 2>&1; then
  codesign --remove-signature "${OUTPUT_APP}" || true
fi
if codesign -d "${MAIN_EXECUTABLE}" >/dev/null 2>&1; then
  codesign --remove-signature "${MAIN_EXECUTABLE}" || true
fi

sign_nested_code() {
  local code_path="$1"
  codesign \
    --force \
    --sign "${SIGNING_IDENTITY}" \
    --options runtime \
    --timestamp \
    --generate-entitlement-der \
    "${code_path}"
}

# Sign nested bundles and standalone nested executables deepest-first. The current
# bundle has none, but this keeps future helpers/frameworks from being signed only
# through an unsafe blanket --deep operation.
while IFS= read -r code_path; do
  [[ -n "${code_path}" ]] || continue
  [[ "${code_path}" != "${MAIN_EXECUTABLE}" ]] || continue
  sign_nested_code "${code_path}"
done < <(
  find "${OUTPUT_APP}/Contents" -depth \
    \( -type d \( -name '*.framework' -o -name '*.xpc' -o -name '*.appex' -o -name '*.app' \) \
       -o -type f -perm -111 \) \
    -print | LC_ALL=C sort -r
)

codesign \
  --force \
  --sign "${SIGNING_IDENTITY}" \
  --options runtime \
  --timestamp \
  --generate-entitlement-der \
  --entitlements "${ENTITLEMENTS_PATH}" \
  "${OUTPUT_APP}"

CMDTAB_EXPECTED_DEVELOPER_IDENTITY="${SIGNING_IDENTITY}" \
CMDTAB_EXPECTED_TEAM_ID="${EXPECTED_TEAM_ID}" \
  "${VERIFY_TOOL}" "${OUTPUT_APP}" developer-id

SIGN_REPORT="$(codesign -d --verbose=4 "${OUTPUT_APP}" 2>&1)"
grep -Fq "Authority=${SIGNING_IDENTITY}" <<<"${SIGN_REPORT}" || fail "signed authority does not match the requested identity"
grep -Fq "TeamIdentifier=${EXPECTED_TEAM_ID}" <<<"${SIGN_REPORT}" || fail "signed TeamIdentifier does not match CMDTAB_TEAM_ID"
grep -Fq 'Runtime Version=' <<<"${SIGN_REPORT}" || fail "Hardened Runtime metadata is missing"
grep -Fq 'Timestamp=' <<<"${SIGN_REPORT}" || fail "secure timestamp is missing"

printf 'Developer ID signed app: %s\n' "${OUTPUT_APP}"
printf 'Signing identity: %s\n' "${SIGNING_IDENTITY}"
printf 'Team ID: %s\n' "${EXPECTED_TEAM_ID}"
