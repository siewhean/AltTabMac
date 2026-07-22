#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY_BUNDLE_TOOL="${ROOT_DIR}/scripts/release/verify-bundle.sh"
EXPECTED_ENTITLEMENTS="${CMDTAB_DISTRIBUTION_ENTITLEMENTS:-${ROOT_DIR}/release/CmdTab.entitlements}"
EXPECTED_IDENTITY="${CMDTAB_DEVELOPER_IDENTITY:-}"
EXPECTED_TEAM_ID="${CMDTAB_TEAM_ID:-}"
APP_PATH="${1:-}"
ZIP_PATH="${2:-}"
TEMP_ROOT="$(mktemp -d /tmp/cmdtab-distribution-verify.XXXXXX)"

usage() {
  cat >&2 <<'USAGE'
Usage: verify-distribution.sh /path/to/stapled/CmdTab.app [/path/to/CmdTab.zip]

Required environment:
  CMDTAB_DEVELOPER_IDENTITY
  CMDTAB_TEAM_ID
USAGE
}

fail() {
  echo "Distribution verification failed: $*" >&2
  exit 1
}

cleanup() {
  rm -rf "${TEMP_ROOT}"
}
trap cleanup EXIT

if [[ -z "${APP_PATH}" ]]; then
  usage
  exit 2
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "distribution verification must run on macOS"
fi

for tool in codesign spctl xcrun plutil python3 ditto unzip shasum; do
  command -v "${tool}" >/dev/null 2>&1 || fail "missing required tool: ${tool}"
done

[[ -d "${APP_PATH}" ]] || fail "app bundle does not exist: ${APP_PATH}"
[[ -f "${EXPECTED_ENTITLEMENTS}" ]] || fail "expected entitlement plist does not exist: ${EXPECTED_ENTITLEMENTS}"
[[ -n "${EXPECTED_IDENTITY}" ]] || fail "CMDTAB_DEVELOPER_IDENTITY is required"
[[ -n "${EXPECTED_TEAM_ID}" ]] || fail "CMDTAB_TEAM_ID is required"
plutil -lint "${EXPECTED_ENTITLEMENTS}" >/dev/null

verify_one_app() {
  local candidate="$1"
  local label="$2"
  local report
  local actual_entitlements="${TEMP_ROOT}/${label}-entitlements.plist"
  local entitlement_stderr="${TEMP_ROOT}/${label}-entitlements.stderr"

  CMDTAB_EXPECTED_DEVELOPER_IDENTITY="${EXPECTED_IDENTITY}" \
  CMDTAB_EXPECTED_TEAM_ID="${EXPECTED_TEAM_ID}" \
    "${VERIFY_BUNDLE_TOOL}" "${candidate}" developer-id

  codesign --verify --deep --strict --verbose=2 "${candidate}"
  report="$(codesign -d --verbose=4 "${candidate}" 2>&1)"

  grep -Fq "Authority=${EXPECTED_IDENTITY}" <<<"${report}" || fail "${label}: Developer ID authority does not match"
  grep -Fq "TeamIdentifier=${EXPECTED_TEAM_ID}" <<<"${report}" || fail "${label}: TeamIdentifier does not match"
  grep -Fq 'Runtime Version=' <<<"${report}" || fail "${label}: Hardened Runtime metadata is missing"
  grep -Fq 'Timestamp=' <<<"${report}" || fail "${label}: secure timestamp is missing"

  codesign -d --entitlements - "${candidate}" >"${actual_entitlements}" 2>"${entitlement_stderr}" || {
    cat "${entitlement_stderr}" >&2
    fail "${label}: unable to read embedded entitlements"
  }
  plutil -lint "${actual_entitlements}" >/dev/null || {
    cat "${entitlement_stderr}" >&2
    fail "${label}: embedded entitlements are not a valid plist"
  }

  python3 - "${EXPECTED_ENTITLEMENTS}" "${actual_entitlements}" <<'PY'
import plistlib
import sys
from pathlib import Path

expected_path = Path(sys.argv[1])
actual_path = Path(sys.argv[2])
with expected_path.open("rb") as handle:
    expected = plistlib.load(handle)
with actual_path.open("rb") as handle:
    actual = plistlib.load(handle)
if actual != expected:
    raise SystemExit(f"embedded entitlements differ: expected={expected!r} actual={actual!r}")
PY

  xcrun stapler validate -v "${candidate}"
  spctl --assess --type execute --verbose=4 "${candidate}"
  printf 'Verified %s: %s\n' "${label}" "${candidate}"
}

verify_one_app "${APP_PATH}" "stapled-app"

if [[ -n "${ZIP_PATH}" ]]; then
  [[ -f "${ZIP_PATH}" ]] || fail "distribution ZIP does not exist: ${ZIP_PATH}"
  [[ "${ZIP_PATH}" == *.zip ]] || fail "distribution archive must end in .zip"
  unzip -tq "${ZIP_PATH}" >/dev/null

  if [[ -f "${ZIP_PATH}.sha256" ]]; then
    (
      cd "$(dirname "${ZIP_PATH}")"
      shasum -a 256 -c "$(basename "${ZIP_PATH}.sha256")"
    )
  fi

  EXTRACT_DIR="${TEMP_ROOT}/zip-extract"
  mkdir -p "${EXTRACT_DIR}"
  ditto -x -k "${ZIP_PATH}" "${EXTRACT_DIR}"
  EXTRACTED_APP="${EXTRACT_DIR}/CmdTab.app"
  [[ -d "${EXTRACTED_APP}" ]] || fail "ZIP does not contain CmdTab.app at its root"
  verify_one_app "${EXTRACTED_APP}" "zip-extracted-app"
fi

printf 'Developer ID distribution verification passed.\n'
