#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-}"
IDENTITY="${2:-}"
ENTITLEMENTS_PATH="${3:-}"
TIMESTAMP_MODE="${4:-timestamp}"

if [[ -z "${APP_PATH}" || -z "${IDENTITY}" || -z "${ENTITLEMENTS_PATH}" ]]; then
  echo "Usage: $0 /path/to/CmdTab.app identity /path/to/entitlements [timestamp|none]" >&2
  exit 2
fi
[[ -d "${APP_PATH}" ]] || { echo "Missing app bundle: ${APP_PATH}" >&2; exit 1; }
[[ -f "${ENTITLEMENTS_PATH}" ]] || { echo "Missing entitlements: ${ENTITLEMENTS_PATH}" >&2; exit 1; }

case "${TIMESTAMP_MODE}" in
  timestamp) TIMESTAMP_ARGUMENT=(--timestamp) ;;
  none) TIMESTAMP_ARGUMENT=(--timestamp=none) ;;
  *) echo "Timestamp mode must be timestamp or none" >&2; exit 2 ;;
esac

# Library Validation is enabled by Hardened Runtime and requires embedded code to
# share the host app's Apple-issued Team ID. An ad-hoc identity has no stable Team
# ID, so a runtime-signed local QA app cannot load the embedded Sparkle framework
# on current macOS. Keep Hardened Runtime mandatory for real Developer ID builds,
# but omit it for ad-hoc QA packages instead of weakening the app with the Disable
# Library Validation entitlement.
SIGNING_OPTIONS=()
if [[ "${IDENTITY}" != "-" ]]; then
  SIGNING_OPTIONS+=(--options runtime)
fi

SPARKLE_FRAMEWORK="${APP_PATH}/Contents/Frameworks/Sparkle.framework"
[[ -d "${SPARKLE_FRAMEWORK}" ]] || {
  echo "Missing embedded Sparkle.framework" >&2
  exit 1
}

sign_nested() {
  local target="$1"
  local preserve_entitlements="${2:-0}"
  local arguments=(
    --force
    --sign "${IDENTITY}"
    "${SIGNING_OPTIONS[@]}"
    "${TIMESTAMP_ARGUMENT[@]}"
  )
  if [[ "${preserve_entitlements}" == "1" ]]; then
    arguments+=(--preserve-metadata=entitlements)
  fi
  codesign "${arguments[@]}" "${target}"
}

# Sparkle's documented manual distribution order. Do not use --deep for signing:
# each nested service keeps only its own reviewed metadata.
sign_nested "${SPARKLE_FRAMEWORK}/Versions/B/XPCServices/Installer.xpc"
sign_nested "${SPARKLE_FRAMEWORK}/Versions/B/XPCServices/Downloader.xpc" 1
sign_nested "${SPARKLE_FRAMEWORK}/Versions/B/Autoupdate"
sign_nested "${SPARKLE_FRAMEWORK}/Versions/B/Updater.app"
sign_nested "${SPARKLE_FRAMEWORK}"

APP_SIGNING_ARGUMENTS=(
  --force
  --sign "${IDENTITY}"
  "${SIGNING_OPTIONS[@]}"
  "${TIMESTAMP_ARGUMENT[@]}"
  --entitlements "${ENTITLEMENTS_PATH}"
)
codesign "${APP_SIGNING_ARGUMENTS[@]}" "${APP_PATH}"

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
