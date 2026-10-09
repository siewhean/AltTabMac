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

for tool in python3 plutil codesign lipo xattr otool; do
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
SPARKLE_FRAMEWORK="${APP_PATH}/Contents/Frameworks/Sparkle.framework"

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
[[ -d "${SPARKLE_FRAMEWORK}" ]] || {
  echo "Missing embedded Sparkle.framework" >&2
  exit 1
}

plutil -lint "${INFO_PATH}" >/dev/null
python3 "${CONFIG_TOOL}" verify-info-plist "${INFO_PATH}"

if [[ -n "$(find "${APP_PATH}" -type l ! -path "${SPARKLE_FRAMEWORK}/*" -print -quit)" ]]; then
  echo "App bundle contains a symbolic link outside Sparkle.framework." >&2
  exit 1
fi
SYMLINK_INVENTORY="$(
  while IFS= read -r symlink_path; do
    printf '%s -> %s\n' \
      "${symlink_path#"${SPARKLE_FRAMEWORK}/"}" \
      "$(readlink "${symlink_path}")"
  done < <(find "${SPARKLE_FRAMEWORK}" -type l | LC_ALL=C sort)
)"
EXPECTED_SYMLINK_INVENTORY="$(cat <<'EOF'
Autoupdate -> Versions/Current/Autoupdate
Headers -> Versions/Current/Headers
Modules -> Versions/Current/Modules
PrivateHeaders -> Versions/Current/PrivateHeaders
Resources -> Versions/Current/Resources
Sparkle -> Versions/Current/Sparkle
Updater.app -> Versions/Current/Updater.app
Versions/Current -> B
XPCServices -> Versions/Current/XPCServices
EOF
)"
if [[ "${SYMLINK_INVENTORY}" != "${EXPECTED_SYMLINK_INVENTORY}" ]]; then
  printf 'Unexpected Sparkle symlink inventory:\n%s\n' "${SYMLINK_INVENTORY:-none}" >&2
  exit 1
fi

EXECUTABLE_LIST="$(find "${APP_PATH}/Contents" -type f -perm -111 | LC_ALL=C sort)"
[[ -n "${EXECUTABLE_LIST}" ]] || { echo "App bundle has no executable inventory." >&2; exit 1; }
grep -Fx "${EXECUTABLE_PATH}" <<<"${EXECUTABLE_LIST}" >/dev/null || {
  echo "App executable is missing from the executable inventory." >&2; exit 1;
}
grep -Fx "${SPARKLE_FRAMEWORK}/Versions/B/Autoupdate" <<<"${EXECUTABLE_LIST}" >/dev/null || {
  echo "Sparkle Autoupdate is missing from the executable inventory." >&2; exit 1;
}

SPARKLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  "${SPARKLE_FRAMEWORK}/Versions/B/Resources/Info.plist")"
[[ "${SPARKLE_VERSION}" == "2.9.2" ]] || {
  echo "Expected Sparkle 2.9.2, found ${SPARKLE_VERSION}" >&2
  exit 1
}
LINKED_LIBRARIES="$(otool -L "${EXECUTABLE_PATH}")"
grep -q '@rpath/Sparkle.framework/Versions/B/Sparkle' <<<"${LINKED_LIBRARIES}" || {
  echo "CmdTab does not link to the embedded Sparkle framework through @rpath." >&2
  exit 1
}
LOAD_COMMANDS="$(otool -l "${EXECUTABLE_PATH}")"
grep -q '@executable_path/../Frameworks' <<<"${LOAD_COMMANDS}" || {
  echo "CmdTab is missing the application Frameworks runtime search path." >&2
  exit 1
}
codesign --verify --deep --strict --verbose=2 "${SPARKLE_FRAMEWORK}"

ARCHITECTURES="$(lipo -archs "${EXECUTABLE_PATH}")"
[[ -n "${ARCHITECTURES}" ]] || { echo "Could not determine executable architecture" >&2; exit 1; }
if [[ -n "${CMDTAB_EXPECTED_ARCHITECTURES:-}" ]]; then
  EXPECTED_ARCHITECTURES="$(
    tr ',' '\n' <<<"${CMDTAB_EXPECTED_ARCHITECTURES}" |
      sed '/^$/d' |
      LC_ALL=C sort |
      paste -sd ' ' -
  )"
  while IFS= read -r executable_file; do
    EXECUTABLE_ARCHITECTURES="$(
      lipo -archs "${executable_file}" |
        tr ' ' '\n' |
        sed '/^$/d' |
        LC_ALL=C sort |
        paste -sd ' ' -
    )"
    [[ "${EXECUTABLE_ARCHITECTURES}" == "${EXPECTED_ARCHITECTURES}" ]] || {
      echo "Expected architectures '${EXPECTED_ARCHITECTURES}', found '${EXECUTABLE_ARCHITECTURES}' in ${executable_file}." >&2
      exit 1
    }
  done <<<"${EXECUTABLE_LIST}"
fi

if xattr -p com.apple.quarantine "${APP_PATH}" >/dev/null 2>&1; then
  echo "App bundle unexpectedly carries a quarantine attribute before distribution." >&2
  exit 1
fi

SIGNED_TARGETS=("${SPARKLE_FRAMEWORK}" "${APP_PATH}")
while IFS= read -r executable_file; do
  [[ -n "${executable_file}" ]] && SIGNED_TARGETS+=("${executable_file}")
done <<<"${EXECUTABLE_LIST}"

SIGN_REPORT="$(codesign -d --verbose=4 "${APP_PATH}" 2>&1 || true)"
case "${EXPECTED_SIGNING}" in
  unsigned)
    if codesign -d "${APP_PATH}" >/dev/null 2>&1; then
      echo "Expected unsigned bundle, but a signature is present." >&2
      exit 1
    fi
    ;;
  ad-hoc)
    codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
    grep -q 'Signature=adhoc' <<<"${SIGN_REPORT}" || {
      echo "Expected an ad-hoc signature." >&2
      exit 1
    }
    if grep -q 'Runtime Version=' <<<"${SIGN_REPORT}"; then
      echo "Ad-hoc Sparkle QA bundles must not enable Hardened Runtime; library validation would reject an embedded framework without an Apple-issued Team ID." >&2
      exit 1
    fi
    for signed_target in "${SIGNED_TARGETS[@]}"; do
      NESTED_SIGN_REPORT="$(codesign -d --verbose=4 "${signed_target}" 2>&1)"
      grep -q 'Signature=adhoc' <<<"${NESTED_SIGN_REPORT}" || {
        echo "Expected an ad-hoc signature in ${signed_target}." >&2
        exit 1
      }
      if grep -q 'Runtime Version=' <<<"${NESTED_SIGN_REPORT}"; then
        echo "Ad-hoc nested target unexpectedly enables Hardened Runtime: ${signed_target}." >&2
        exit 1
      fi
    done
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
    APP_TEAM_IDENTIFIER="$(
      awk -F= '/^TeamIdentifier=/{print $2}' <<<"${SIGN_REPORT}"
    )"
    [[ -n "${APP_TEAM_IDENTIFIER}" ]] || {
      echo "Developer ID bundle is missing a TeamIdentifier." >&2
      exit 1
    }
    for signed_target in "${SIGNED_TARGETS[@]}"; do
      NESTED_SIGN_REPORT="$(codesign -d --verbose=4 "${signed_target}" 2>&1)"
      grep -q "TeamIdentifier=${APP_TEAM_IDENTIFIER}" <<<"${NESTED_SIGN_REPORT}" || {
        echo "Signing team mismatch in ${signed_target}." >&2
        exit 1
      }
      grep -q 'Runtime Version=' <<<"${NESTED_SIGN_REPORT}" || {
        echo "Hardened Runtime metadata is missing from ${signed_target}." >&2
        exit 1
      }
      grep -q '^Timestamp=' <<<"${NESTED_SIGN_REPORT}" || {
        echo "Secure timestamp is missing from ${signed_target}." >&2
        exit 1
      }
    done
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
