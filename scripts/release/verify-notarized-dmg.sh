#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DMG_PATH="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi
EXPECTED_VERSION=""
EXPECTED_BUILD=""

usage() {
  echo "Usage: $0 /path/to/notarized-CmdTab.dmg [--expected-version x.y.z] [--expected-build N]" >&2
}

if [[ -z "${DMG_PATH}" || ! -f "${DMG_PATH}" ]]; then
  usage
  exit 2
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --expected-version)
      EXPECTED_VERSION="${2:-}"
      [[ -n "${EXPECTED_VERSION}" ]] || { usage; exit 2; }
      shift 2
      ;;
    --expected-build)
      EXPECTED_BUILD="${2:-}"
      [[ "${EXPECTED_BUILD}" =~ ^[1-9][0-9]*$ ]] || { usage; exit 2; }
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

for tool in codesign hdiutil spctl xcrun; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "Missing required tool: ${tool}" >&2
    exit 1
  }
done

codesign --verify --strict --verbose=2 "${DMG_PATH}"
xcrun stapler validate "${DMG_PATH}"
spctl --assess --type open --context context:primary-signature \
  --verbose=4 "${DMG_PATH}"

MOUNT_ROOT="$(mktemp -d /tmp/cmdtab-verify-dmg.XXXXXX)"
mounted=0
cleanup() {
  if [[ "${mounted}" == "1" ]]; then
    hdiutil detach "${MOUNT_ROOT}" >/dev/null
  fi
  case "${MOUNT_ROOT}" in
    /tmp/cmdtab-verify-dmg.*) rmdir "${MOUNT_ROOT}" 2>/dev/null || true ;;
    *) echo "Refusing to remove unexpected mount path: ${MOUNT_ROOT}" >&2 ;;
  esac
}
trap cleanup EXIT

hdiutil attach -readonly -nobrowse -mountpoint "${MOUNT_ROOT}" \
  "${DMG_PATH}" >/dev/null
mounted=1

APP_PATH="${MOUNT_ROOT}/CmdTab.app"
[[ -d "${APP_PATH}" ]] || {
  echo "DMG does not contain CmdTab.app at its root." >&2
  exit 1
}

"${ROOT_DIR}/scripts/release/verify-bundle.sh" \
  "${APP_PATH}" \
  developer-id
if [[ -n "${EXPECTED_VERSION}" ]]; then
  ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_PATH}/Contents/Info.plist")"
  [[ "${ACTUAL_VERSION}" == "${EXPECTED_VERSION}" ]] || {
    echo "DMG CFBundleShortVersionString (${ACTUAL_VERSION}) does not match expected release version (${EXPECTED_VERSION})." >&2
    exit 1
  }
fi
if [[ -n "${EXPECTED_BUILD}" ]]; then
  ACTUAL_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${APP_PATH}/Contents/Info.plist")"
  [[ "${ACTUAL_BUILD}" == "${EXPECTED_BUILD}" ]] || {
    echo "DMG CFBundleVersion (${ACTUAL_BUILD}) does not match expected release build (${EXPECTED_BUILD})." >&2
    exit 1
  }
fi
xcrun stapler validate "${APP_PATH}"
spctl --assess --type execute --verbose=4 "${APP_PATH}"

printf 'Notarized DMG verification passed: %s\n' "${DMG_PATH}"
