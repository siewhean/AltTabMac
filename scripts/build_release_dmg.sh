#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="CmdTab"
APP_BUNDLE="${ROOT_DIR}/${APP_NAME}.app"
APP_PLIST="${APP_BUNDLE}/Contents/Info.plist"
ENTITLEMENTS_PATH="${ROOT_DIR}/Resources/CmdTab.entitlements"
PLIST_BUDDY="/usr/libexec/PlistBuddy"

DEVELOPER_ID="${CMDTAB_DEVELOPER_ID:-}"
NOTARY_PROFILE="${CMDTAB_NOTARY_PROFILE:-}"
BUNDLE_ID_OVERRIDE="${CMDTAB_BUNDLE_ID:-}"
VERSION_OVERRIDE="${CMDTAB_VERSION:-}"
BUILD_OVERRIDE="${CMDTAB_BUILD_NUMBER:-}"
VOLNAME="${CMDTAB_DMG_VOLNAME:-CmdTab}"
OUTPUT_DIR="${CMDTAB_RELEASE_DIR:-${ROOT_DIR}/dist}"
DMG_BASENAME="${CMDTAB_DMG_NAME:-CmdTab-trial}"
DMG_PATH="${OUTPUT_DIR}/${DMG_BASENAME}.dmg"
STAGE_DIR="$(mktemp -d /tmp/cmdtab-dmg-stage.XXXXXX)"

cleanup() {
  rm -rf "${STAGE_DIR}"
}
trap cleanup EXIT

section() {
  printf '\n== %s ==\n' "$1"
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1" >&2
    exit 1
  fi
}

require_env() {
  local name="$1"
  local value="$2"
  if [[ -z "${value}" ]]; then
    echo "Missing required environment variable: ${name}" >&2
    exit 1
  fi
}

plist_set() {
  local key="$1"
  local value="$2"

  if [[ -z "${value}" ]]; then
    return
  fi

  if "${PLIST_BUDDY}" -c "Print :${key}" "${APP_PLIST}" >/dev/null 2>&1; then
    "${PLIST_BUDDY}" -c "Set :${key} ${value}" "${APP_PLIST}"
  else
    "${PLIST_BUDDY}" -c "Add :${key} string ${value}" "${APP_PLIST}"
  fi
}

section "CmdTab release DMG build"
echo "Repo: ${ROOT_DIR}"
echo "Output directory: ${OUTPUT_DIR}"

section "Tooling checks"
for tool in swift codesign xcrun ditto spctl hdiutil shasum; do
  require_tool "${tool}"
  echo "Found ${tool}"
done

if [[ ! -x "${PLIST_BUDDY}" ]]; then
  echo "Missing required tool: ${PLIST_BUDDY}" >&2
  exit 1
fi
echo "Found ${PLIST_BUDDY}"

section "Credential checks"
require_env "CMDTAB_DEVELOPER_ID" "${DEVELOPER_ID}"
require_env "CMDTAB_NOTARY_PROFILE" "${NOTARY_PROFILE}"
echo "Developer ID identity configured: ${DEVELOPER_ID}"
echo "Notary profile configured: ${NOTARY_PROFILE}"

section "Step 1: Build app bundle"
"${ROOT_DIR}/build.sh"

if [[ ! -d "${APP_BUNDLE}" ]]; then
  echo "Expected app bundle was not created: ${APP_BUNDLE}" >&2
  exit 1
fi

section "Step 2: Apply release metadata"
plist_set "CFBundleIdentifier" "${BUNDLE_ID_OVERRIDE}"
plist_set "CFBundleShortVersionString" "${VERSION_OVERRIDE}"
plist_set "CFBundleVersion" "${BUILD_OVERRIDE}"
plutil -p "${APP_PLIST}" | sed -n '1,40p'

section "Step 3: Sign app bundle"
codesign --force --deep --options runtime --timestamp \
  --entitlements "${ENTITLEMENTS_PATH}" \
  --sign "${DEVELOPER_ID}" \
  "${APP_BUNDLE}"

codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"
spctl --assess --type execute --verbose=4 "${APP_BUNDLE}" || true

section "Step 4: Create DMG staging folder"
mkdir -p "${OUTPUT_DIR}"
cp -R "${APP_BUNDLE}" "${STAGE_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGE_DIR}/Applications"
rm -f "${DMG_PATH}"

section "Step 5: Build DMG"
hdiutil create \
  -volname "${VOLNAME}" \
  -srcfolder "${STAGE_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

section "Step 6: Sign DMG"
codesign --force --timestamp --sign "${DEVELOPER_ID}" "${DMG_PATH}"
codesign --verify --verbose=2 "${DMG_PATH}"

section "Step 7: Notarize DMG"
xcrun notarytool submit "${DMG_PATH}" \
  --keychain-profile "${NOTARY_PROFILE}" \
  --wait

section "Step 8: Staple and verify"
xcrun stapler staple "${DMG_PATH}"
spctl --assess --type open --verbose=4 "${DMG_PATH}" || true

section "Step 9: Checksums"
shasum -a 256 "${DMG_PATH}"

section "Done"
echo "DMG ready: ${DMG_PATH}"
echo "Upload this file and use its public URL as NEXT_PUBLIC_TRIAL_URL"
