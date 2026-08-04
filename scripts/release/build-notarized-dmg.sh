#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_TOOL="${ROOT_DIR}/scripts/release/release_config.py"
OUTPUT_DIR="${CMDTAB_RELEASE_OUTPUT_DIR:-${ROOT_DIR}/dist/release}"

usage() {
  echo "Usage: $0 [--preflight] [--beta x.y.z-beta.N]" >&2
}

PREFLIGHT_ONLY=0
BETA_VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --preflight|--dry-run)
      PREFLIGHT_ONLY=1
      shift
      ;;
    --beta)
      BETA_VERSION="${2:-}"
      [[ -n "${BETA_VERSION}" ]] || { usage; exit 2; }
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

for tool in codesign ditto git hdiutil lipo osascript plutil python3 shasum spctl swift xattr xcrun; do
  command -v "${tool}" >/dev/null 2>&1 || { echo "Missing required tool: ${tool}" >&2; exit 1; }
done
python3 "${CONFIG_TOOL}" validate >/dev/null
python3 "${CONFIG_TOOL}" verify-repository >/dev/null
if ! git -C "${ROOT_DIR}" diff --quiet ||
   ! git -C "${ROOT_DIR}" diff --cached --quiet ||
   [[ -n "$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=all)" ]]; then
  echo "Notarized releases must be built from a completely clean worktree." >&2
  exit 1
fi

"${ROOT_DIR}/scripts/release/resolve-sparkle-tools.sh" --preflight >/dev/null

VERSION="$(python3 "${CONFIG_TOOL}" get marketingVersion)"
BUILD="$(python3 "${CONFIG_TOOL}" get buildNumber)"
if [[ -n "${BETA_VERSION}" ]]; then
  [[ "${BETA_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+-beta\.[0-9]+$ ]] || {
    echo "Beta notarized builds require --beta x.y.z-beta.N." >&2
    exit 2
  }
  [[ "${BETA_VERSION%-beta.*}" == "${VERSION}" ]] || {
    echo "Beta notarized build version must use ReleaseConfig marketingVersion (${VERSION}) as its x.y.z base." >&2
    exit 1
  }
fi

if [[ "${PREFLIGHT_ONLY}" == "1" ]]; then
  echo "Notarized DMG preflight passed."
  if [[ -n "${BETA_VERSION}" ]]; then
    echo "Validated beta artifact filename: CmdTab-${BETA_VERSION}-${BUILD}.dmg."
  else
    echo "A beta build must supply --beta x.y.z-beta.N before artifact creation."
  fi
  echo "Required secure variables at execution: CMDTAB_SIGNING_IDENTITY, CMDTAB_NOTARY_PROFILE, CMDTAB_SPARKLE_PUBLIC_ED_KEY."
  echo "No signing, notarization, artifact creation, or network request was performed."
  exit 0
fi

SIGNING_IDENTITY="${CMDTAB_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${CMDTAB_NOTARY_PROFILE:-}"
if [[ -z "${SIGNING_IDENTITY}" || -z "${NOTARY_PROFILE}" || -z "${CMDTAB_SPARKLE_PUBLIC_ED_KEY:-}" ]]; then
  echo "Set CMDTAB_SIGNING_IDENTITY, CMDTAB_NOTARY_PROFILE, and CMDTAB_SPARKLE_PUBLIC_ED_KEY." >&2
  exit 2
fi

[[ -n "${BETA_VERSION}" ]] || {
  echo "Notarized public-beta builds require --beta x.y.z-beta.N." >&2
  exit 2
}

VOLUME_NAME="CmdTab ${VERSION}"
APP_PATH="${OUTPUT_DIR}/CmdTab.app"
ZIP_PATH="${OUTPUT_DIR}/CmdTab-${VERSION}-${BUILD}.zip"
DMG_PATH="${OUTPUT_DIR}/CmdTab-${BETA_VERSION}-${BUILD}.dmg"
DMG_RW_PATH="${OUTPUT_DIR}/CmdTab-${VERSION}-${BUILD}-layout.dmg"
EVIDENCE_DIR="${OUTPUT_DIR}/notarization"
DMG_STAGE="$(mktemp -d /tmp/cmdtab-dmg-stage.XXXXXX)"
DMG_MOUNT="$(mktemp -d /tmp/cmdtab-dmg-mount.XXXXXX)"
DMG_DEVICE=""
BACKGROUND_PATH="${DMG_STAGE}/.background/background.png"

cleanup() {
  if [[ -n "${DMG_DEVICE}" ]]; then
    hdiutil detach "${DMG_DEVICE}" -force >/dev/null 2>&1 || true
  fi
  case "${DMG_STAGE}" in
    /tmp/cmdtab-dmg-stage.*) rm -rf "${DMG_STAGE}" ;;
    *) echo "Refusing to remove unexpected DMG staging path: ${DMG_STAGE}" >&2 ;;
  esac
  case "${DMG_MOUNT}" in
    /tmp/cmdtab-dmg-mount.*) rm -rf "${DMG_MOUNT}" ;;
    *) echo "Refusing to remove unexpected DMG mount path: ${DMG_MOUNT}" >&2 ;;
  esac
  rm -f "${DMG_RW_PATH}"
}
trap cleanup EXIT

mkdir -p "${OUTPUT_DIR}" "${EVIDENCE_DIR}"
rm -f "${ZIP_PATH}" "${DMG_PATH}" "${DMG_PATH}.sha256" "${DMG_RW_PATH}"

CMDTAB_OUTPUT_APP="${APP_PATH}" \
CMDTAB_SIGNING_IDENTITY="${SIGNING_IDENTITY}" \
CMDTAB_SPARKLE_PUBLIC_ED_KEY="${CMDTAB_SPARKLE_PUBLIC_ED_KEY}" \
CMDTAB_BUILD_ARCHITECTURES="arm64" \
CMDTAB_EXPECTED_ARCHITECTURES="arm64" \
  "${ROOT_DIR}/scripts/release/package-app.sh"

# Notarize and staple the application before sealing it into the user-facing DMG.
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"
xcrun notarytool submit "${ZIP_PATH}" \
  --keychain-profile "${NOTARY_PROFILE}" \
  --wait \
  --output-format json |
  tee "${EVIDENCE_DIR}/app-notary.json"
python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); assert data.get("status") == "Accepted", data' \
  "${EVIDENCE_DIR}/app-notary.json"
xcrun stapler staple "${APP_PATH}"
xcrun stapler validate "${APP_PATH}"

# Build a deterministic Finder-facing drag-to-Applications layout. The background
# is generated from source so release assembly does not depend on an unreviewed
# binary design asset.
ditto "${APP_PATH}" "${DMG_STAGE}/CmdTab.app"
ln -s /Applications "${DMG_STAGE}/Applications"
swift "${ROOT_DIR}/scripts/release/render-dmg-background.swift" "${BACKGROUND_PATH}"
[[ -s "${BACKGROUND_PATH}" ]] || {
  echo "DMG background was not generated." >&2
  exit 1
}

hdiutil create \
  -volname "${VOLUME_NAME}" \
  -srcfolder "${DMG_STAGE}" \
  -format UDRW \
  -fs HFS+ \
  -ov \
  "${DMG_RW_PATH}"

ATTACH_OUTPUT="$(
  hdiutil attach "${DMG_RW_PATH}" \
    -readwrite \
    -noverify \
    -noautoopen \
    -mountpoint "${DMG_MOUNT}"
)"
DMG_DEVICE="$(awk '/^\/dev\// { print $1; exit }' <<<"${ATTACH_OUTPUT}")"
[[ -n "${DMG_DEVICE}" ]] || {
  echo "Could not determine the mounted DMG device." >&2
  printf '%s\n' "${ATTACH_OUTPUT}" >&2
  exit 1
}
[[ -d "${DMG_MOUNT}/CmdTab.app" && -L "${DMG_MOUNT}/Applications" ]] || {
  echo "Mounted DMG is missing its application or Applications link." >&2
  exit 1
}

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "${VOLUME_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set pathbar visible of container window to false
    set sidebar width of container window to 0
    set bounds of container window to {100, 100, 760, 520}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 112
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.png"
    set position of item "CmdTab.app" of container window to {180, 220}
    set position of item "Applications" of container window to {480, 220}
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "${DMG_DEVICE}"
DMG_DEVICE=""

hdiutil convert "${DMG_RW_PATH}" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  -o "${DMG_PATH}"
[[ -s "${DMG_PATH}" ]] || {
  echo "Compressed DMG was not created." >&2
  exit 1
}

codesign --force --sign "${SIGNING_IDENTITY}" --timestamp "${DMG_PATH}"
xcrun notarytool submit "${DMG_PATH}" \
  --keychain-profile "${NOTARY_PROFILE}" \
  --wait \
  --output-format json |
  tee "${EVIDENCE_DIR}/dmg-notary.json"
python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); assert data.get("status") == "Accepted", data' \
  "${EVIDENCE_DIR}/dmg-notary.json"
xcrun stapler staple "${DMG_PATH}"
xcrun stapler validate "${DMG_PATH}"

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
spctl --assess --type execute --verbose=4 "${APP_PATH}" 2>&1 |
  tee "${EVIDENCE_DIR}/gatekeeper-app.txt"
spctl --assess --type open --context context:primary-signature --verbose=4 "${DMG_PATH}" 2>&1 |
  tee "${EVIDENCE_DIR}/gatekeeper-dmg.txt"
shasum -a 256 "${DMG_PATH}" > "${DMG_PATH}.sha256"

printf 'Notarized app: %s\n' "${APP_PATH}"
printf 'Notarized DMG: %s\n' "${DMG_PATH}"
printf 'DMG volume: %s\n' "${VOLUME_NAME}"
printf 'Evidence: %s\n' "${EVIDENCE_DIR}"
