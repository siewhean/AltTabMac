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
USE_HARDENED_RUNTIME=0
if [[ "${IDENTITY}" != "-" ]]; then
  USE_HARDENED_RUNTIME=1
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
  )
  if [[ "${USE_HARDENED_RUNTIME}" == "1" ]]; then
    arguments+=(--options runtime)
  fi
  arguments+=("${TIMESTAMP_ARGUMENT[@]}")
  if [[ "${preserve_entitlements}" == "1" ]]; then
    arguments+=(--preserve-metadata=entitlements)
  fi
  codesign "${arguments[@]}" "${target}"
}

# Sign every discovered nested code container leaf-first. Sparkle changes its
# framework layout between releases; deriving the inventory ensures a new helper
# cannot silently escape signing or verification.
NESTED_CONTAINERS="$(
  find "${SPARKLE_FRAMEWORK}/Versions" -type d \( -name '*.xpc' -o -name '*.app' \) -print |
    awk '{ print length($0), $0 }' | LC_ALL=C sort -rn | cut -d' ' -f2-
)"
[[ -n "${NESTED_CONTAINERS}" ]] || {
  echo "Sparkle framework has no nested code containers." >&2
  exit 1
}
while IFS= read -r nested_container; do
  [[ -n "${nested_container}" ]] || continue
  # Downloader currently carries Sparkle's reviewed helper entitlement.
  if [[ "${nested_container}" == */Downloader.xpc ]]; then
    sign_nested "${nested_container}" 1
  else
    sign_nested "${nested_container}"
  fi
done <<<"${NESTED_CONTAINERS}"

AUTUPDATE_PATH="${SPARKLE_FRAMEWORK}/Versions/B/Autoupdate"
[[ -x "${AUTUPDATE_PATH}" ]] || { echo "Missing Sparkle Autoupdate executable." >&2; exit 1; }
sign_nested "${AUTUPDATE_PATH}"
sign_nested "${SPARKLE_FRAMEWORK}"

APP_SIGNING_ARGUMENTS=(
  --force
  --sign "${IDENTITY}"
)
if [[ "${USE_HARDENED_RUNTIME}" == "1" ]]; then
  APP_SIGNING_ARGUMENTS+=(--options runtime)
fi
APP_SIGNING_ARGUMENTS+=(
  "${TIMESTAMP_ARGUMENT[@]}"
  --entitlements "${ENTITLEMENTS_PATH}"
)
codesign "${APP_SIGNING_ARGUMENTS[@]}" "${APP_PATH}"

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
