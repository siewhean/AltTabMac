#!/usr/bin/env bash
# Build a universal CmdTab.app suitable for local validation or release re-signing.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "${ROOT_DIR}"

# shellcheck source=scripts/release_metadata.sh
source "${ROOT_DIR}/scripts/release_metadata.sh"

APP_NAME="${CMDTAB_APP_NAME}"
SCRATCH="${CMDTAB_BUILD_SCRATCH:-/tmp/CmdTab_build}"
APP_BUNDLE="${CMDTAB_APP_BUNDLE:-${ROOT_DIR}/${APP_NAME}.app}"
CONTENTS="${APP_BUNDLE}/Contents"
INFO_PLIST="${CMDTAB_SOURCE_PLIST}"
ENTITLEMENTS_FILE="${ROOT_DIR}/Resources/CmdTab.entitlements"
ICON_SOURCE="${ROOT_DIR}/Resources/${APP_NAME}.png"
ICONSET_DIR="${SCRATCH}/${APP_NAME}.iconset"
ICON_ICNS="${SCRATCH}/${APP_NAME}.icns"
LOCAL_TEAM_ID="${CMDTAB_LOCAL_TEAM_ID:-T6CDNA9H92}"

fail() {
    echo "$1" >&2
    exit 1
}

validate_output_paths() {
    local scratch_parent app_parent scratch_name app_name canonical_scratch canonical_app
    scratch_name="$(basename "${SCRATCH}")"
    app_name="$(basename "${APP_BUNDLE}")"
    case "${scratch_name}" in
        .|..) fail "CMDTAB_BUILD_SCRATCH must not end in a traversal component" ;;
    esac
    scratch_parent="$(cd -P "$(dirname "${SCRATCH}")" 2>/dev/null && pwd)" \
        || fail "CMDTAB_BUILD_SCRATCH parent must already exist"
    app_parent="$(cd -P "$(dirname "${APP_BUNDLE}")" 2>/dev/null && pwd)" \
        || fail "CMDTAB_APP_BUNDLE parent must already exist"
    canonical_scratch="${scratch_parent}/${scratch_name}"
    canonical_app="${app_parent}/${app_name}"

    case "${canonical_scratch}" in
        /private/tmp/?*) ;;
        *) fail "CMDTAB_BUILD_SCRATCH must resolve to a non-root path below /private/tmp" ;;
    esac
    case "${canonical_app}" in
        "${ROOT_DIR}/${APP_NAME}.app"|/private/tmp/*/"${APP_NAME}.app") ;;
        *) fail "CMDTAB_APP_BUNDLE must resolve to the repo app or a CmdTab.app below /private/tmp" ;;
    esac
    SCRATCH="${canonical_scratch}"
    APP_BUNDLE="${canonical_app}"
    CONTENTS="${APP_BUNDLE}/Contents"
}

require_tool() {
    command -v "$1" >/dev/null 2>&1 || fail "Missing required tool: $1"
}

set_plist_metadata() {
    local plist="$1"
    plutil -replace CFBundleName -string "${APP_NAME}" "${plist}"
    plutil -replace CFBundleDisplayName -string "${APP_NAME}" "${plist}"
    plutil -replace CFBundleExecutable -string "${APP_NAME}" "${plist}"
    plutil -replace CFBundleIdentifier -string "${CMDTAB_BUNDLE_ID}" "${plist}"
    plutil -replace CFBundleShortVersionString -string "${CMDTAB_VERSION}" "${plist}"
    plutil -replace CFBundleVersion -string "${CMDTAB_BUILD_NUMBER}" "${plist}"
    plutil -replace LSMinimumSystemVersion -string "${CMDTAB_MIN_MACOS_VERSION}" "${plist}"
}

generate_app_icon() {
    [ -f "${ICON_SOURCE}" ] || return 0

    rm -rf "${ICONSET_DIR}" "${ICON_ICNS}"
    mkdir -p "${ICONSET_DIR}"
    sips -z 16 16 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
    sips -z 32 32 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
    sips -z 64 64 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
    sips -z 256 256 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
    sips -z 512 512 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
    cp "${ICON_SOURCE}" "${ICONSET_DIR}/icon_512x512@2x.png"
    iconutil -c icns "${ICONSET_DIR}" -o "${ICON_ICNS}"
}

build_architecture() {
    local architecture="$1"
    local architecture_scratch="${SCRATCH}/${architecture}"
    swift build -c release --arch "${architecture}" --disable-index-store --jobs 1 \
        -Xswiftc -gnone --scratch-path "${architecture_scratch}" >&2
    swift build -c release --arch "${architecture}" --disable-index-store --jobs 1 \
        -Xswiftc -gnone --scratch-path "${architecture_scratch}" --show-bin-path
}

resolve_local_signing_identity() {
    if [ -n "${CMDTAB_LOCAL_SIGNING_IDENTITY:-}" ]; then
        printf '%s\n' "${CMDTAB_LOCAL_SIGNING_IDENTITY}"
        return
    fi

    local identity
    identity="$(security find-identity -v -p codesigning 2>/dev/null \
        | awk -v team="(${LOCAL_TEAM_ID})" '$0 ~ /Apple Development:/ && index($0, team) { print $2 }' \
        | head -n 1)"
    printf '%s\n' "${identity:--}"
}

sign_nested_code() {
    local identity="$1"
    local code_path

    while IFS= read -r code_path; do
        [ "${code_path}" = "${CONTENTS}/MacOS/${APP_NAME}" ] && continue
        file "${code_path}" | grep -q 'Mach-O' || continue
        codesign --sign "${identity}" --force --options runtime "${code_path}"
    done < <(find "${CONTENTS}" -depth -type f -print)

    while IFS= read -r code_path; do
        codesign --sign "${identity}" --force --options runtime "${code_path}"
    done < <(find "${CONTENTS}" -depth -type d \( \
        -name '*.framework' -o -name '*.xpc' -o -name '*.appex' -o \
        -name '*.plugin' -o -name '*.app' -o -name '*.bundle' \
    \) -print)
}

for tool in swift lipo codesign file find sips iconutil xattr security awk plutil sort tr dirname basename; do
    require_tool "${tool}"
done
[ -f "${ENTITLEMENTS_FILE}" ] || fail "Missing ${ENTITLEMENTS_FILE}"
validate_output_paths

echo "Building ${APP_NAME} ${CMDTAB_VERSION} (${CMDTAB_BUILD_NUMBER}) for arm64 and x86_64..."
rm -rf "${SCRATCH}"
generate_app_icon
ARM64_BIN_DIR="$(build_architecture arm64)"
X86_64_BIN_DIR="$(build_architecture x86_64)"
[ -f "${ARM64_BIN_DIR}/${APP_NAME}" ] || fail "Missing arm64 binary"
[ -f "${X86_64_BIN_DIR}/${APP_NAME}" ] || fail "Missing x86_64 binary"

echo "Packaging ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources"
lipo -create \
    "${ARM64_BIN_DIR}/${APP_NAME}" \
    "${X86_64_BIN_DIR}/${APP_NAME}" \
    -output "${CONTENTS}/MacOS/${APP_NAME}"
cp "${INFO_PLIST}" "${CONTENTS}/Info.plist"
set_plist_metadata "${CONTENTS}/Info.plist"
[ ! -f "${ICON_ICNS}" ] || cp "${ICON_ICNS}" "${CONTENTS}/Resources/${APP_NAME}.icns"
[ ! -f "${ICON_SOURCE}" ] || cp "${ICON_SOURCE}" "${CONTENTS}/Resources/${APP_NAME}.png"
chmod +x "${CONTENTS}/MacOS/${APP_NAME}"
xattr -cr "${APP_BUNDLE}" 2>/dev/null || true

ARCHITECTURES="$(lipo -archs "${CONTENTS}/MacOS/${APP_NAME}")"
[ "$(printf '%s\n' "${ARCHITECTURES}" | tr ' ' '\n' | sort | tr '\n' ' ')" = "arm64 x86_64 " ] \
    || fail "Universal binary validation failed: ${ARCHITECTURES}"

LOCAL_SIGNING_IDENTITY="$(resolve_local_signing_identity)"
if [ "${LOCAL_SIGNING_IDENTITY}" = '-' ]; then
    echo "Warning: no Apple Development identity found; ad-hoc rebuilds may require macOS permissions again." >&2
else
    echo "Signing local build with ${LOCAL_SIGNING_IDENTITY}"
fi

# Sign every nested Mach-O leaf before code containers and the app root.
sign_nested_code "${LOCAL_SIGNING_IDENTITY}"
codesign --sign "${LOCAL_SIGNING_IDENTITY}" --force --options runtime \
    --entitlements "${ENTITLEMENTS_FILE}" \
    "${APP_BUNDLE}"
codesign --verify --strict --verbose=2 "${APP_BUNDLE}"

echo "Built ${APP_BUNDLE} (${ARCHITECTURES})"
