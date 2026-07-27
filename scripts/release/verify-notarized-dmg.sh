#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DMG_PATH="${1:-}"

if [[ -z "${DMG_PATH}" || ! -f "${DMG_PATH}" ]]; then
  echo "Usage: $0 /path/to/notarized-CmdTab.dmg" >&2
  exit 2
fi

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
xcrun stapler validate "${APP_PATH}"
spctl --assess --type execute --verbose=4 "${APP_PATH}"

printf 'Notarized DMG verification passed: %s\n' "${DMG_PATH}"
