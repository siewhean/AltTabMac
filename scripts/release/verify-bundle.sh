#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_TOOL="${ROOT_DIR}/scripts/release/release_config.py"
APP_PATH="${1:-}"
EXPECTED_SIGNING="${2:-ad-hoc}"

if [[ -z "${APP_PATH}" ]]; then
  echo "Usage: $0 /path/to/CmdTab.app [ad-hoc|unsigned|developer-id|any]" >&2
  exit 2
fi
if [[ ! -d "${APP_PATH}" ]]; then
  echo "App bundle does not exist: ${APP_PATH}" >&2
  exit 1
fi
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Bundle verification must run on macOS." >&2
  exit 1
fi

for tool in python3 plutil codesign lipo xattr; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "Missing required tool: ${tool}" >&2
    exit 1
  }
done

APP_NAME="$(python3 "${CONFIG_TOOL}" get appName)"
EXECUTABLE_NAME="$(python3 "${CONFIG_TOOL}" get executableName)"
ICON_FILE="$(python3 "${CONFIG_TOOL}" get iconFile)"
INFO_PATH="${APP_PATH}/Contents/Info.plist"
EXECUTABLE_PATH="${APP_PATH}/Contents/MacOS/${EXECUTABLE_NAME}"
ICON_PATH="${APP_PATH}/Contents/Resources/${ICON_FILE}.icns"

[[ "$(basename "${APP_PATH}")" == "${APP_NAME}.app" ]] || {
  echo "Unexpected app bundle name: $(basename "${APP_PATH}")" >&2
  exit 1
}
[[ -f "${INFO_PATH}" ]] || { echo "Missing Info.plist" >&2; exit 1; }
[[ -f "${EXECUTABLE_PATH}" && -x "${EXECUTABLE_PATH}" ]] || {
  echo "Missing executable: ${EXECUTABLE_PATH}" >&2
  exit 1
}
[[ -f "${ICON_PATH}" ]] || { echo "Missing app icon: ${ICON_PATH}" >&2; exit 1; }

plutil -lint "${INFO_PATH}" >/dev/null
python3 "${CONFIG_TOOL}" verify-info-plist "${INFO_PATH}"

if [[ -n "$(find "${APP_PATH}" -type l -print -quit)" ]]; then
  echo "App bundle contains symbolic links." >&2
  exit 1
fi

EXECUTABLE_LIST="$(find "${APP_PATH}/Contents" -type f -perm -111 | LC_ALL=C sort)"
EXECUTABLE_COUNT="$(printf '%s\n' "${EXECUTABLE_LIST}" | sed '/^$/d' | wc -l | tr -d '[:space:]')"
if [[ "${EXECUTABLE_COUNT}" != "1" || "${EXECUTABLE_LIST}" != "${EXECUTABLE_PATH}" ]]; then
  printf 'Unexpected executable files in bundle:\n%s\n' "${EXECUTABLE_LIST:-none}" >&2
  exit 1
fi

ARCHITECTURES="$(lipo -archs "${EXECUTABLE_PATH}")"
[[ -n "${ARCHITECTURES}" ]] || { echo "Could not determine executable architecture" >&2; exit 1; }

if xattr -p com.apple.quarantine "${APP_PATH}" >/dev/null 2>&1; then
  echo "App bundle unexpectedly carries a quarantine attribute before distribution." >&2
  exit 1
fi

SIGN_REPORT="$(codesign -d --verbose=4 "${APP_PATH}" 2>&1 || true)"
case "${EXPECTED_SIGNING}" in
  unsigned)
    if codesign -d "${APP_PATH}" >/dev/null 2>&1; then
      echo "Expected unsigned bundle, but a signature is present." >&2
      exit 1
    fi
    ;;
  ad-hoc)
    codesign --verify --strict --verbose=2 "${APP_PATH}"
    grep -q 'Signature=adhoc' <<<"${SIGN_REPORT}" || {
      echo "Expected an ad-hoc signature." >&2
      exit 1
    }
    ;;
  developer-id)
    codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
    grep -q 'Authority=Developer ID Application:' <<<"${SIGN_REPORT}" || {
      echo "Expected a Developer ID Application signature." >&2
      exit 1
    }
    grep -q 'Runtime Version=' <<<"${SIGN_REPORT}" || {
      echo "Developer ID bundle is missing Hardened Runtime metadata." >&2
      exit 1
    }
    ;;
  any)
    ;;
  *)
    echo "Unknown signing expectation: ${EXPECTED_SIGNING}" >&2
    exit 2
    ;;
esac

printf 'Bundle verification passed\n'
printf '  app: %s\n' "${APP_PATH}"
printf '  identifier: %s\n' "$(python3 "${CONFIG_TOOL}" get bundleIdentifier)"
printf '  version: %s (%s)\n' \
  "$(python3 "${CONFIG_TOOL}" get marketingVersion)" \
  "$(python3 "${CONFIG_TOOL}" get buildNumber)"
printf '  architectures: %s\n' "${ARCHITECTURES}"
printf '  signing: %s\n' "${EXPECTED_SIGNING}"
