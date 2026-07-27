#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_TOOL="${ROOT_DIR}/scripts/release/release_config.py"
OUTPUT_DIR="${CMDTAB_RELEASE_OUTPUT_DIR:-${ROOT_DIR}/dist/release}"
SIGNING_IDENTITY="${CMDTAB_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${CMDTAB_NOTARY_PROFILE:-}"

if [[ -z "${SIGNING_IDENTITY}" || -z "${NOTARY_PROFILE}" || -z "${CMDTAB_SPARKLE_PUBLIC_ED_KEY:-}" ]]; then
  echo "Set CMDTAB_SIGNING_IDENTITY, CMDTAB_NOTARY_PROFILE, and CMDTAB_SPARKLE_PUBLIC_ED_KEY." >&2
  exit 2
fi
for tool in codesign ditto hdiutil python3 spctl xcrun; do
  command -v "${tool}" >/dev/null 2>&1 || { echo "Missing required tool: ${tool}" >&2; exit 1; }
done
if ! git -C "${ROOT_DIR}" diff --quiet ||
   ! git -C "${ROOT_DIR}" diff --cached --quiet ||
   [[ -n "$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=all)" ]]; then
  echo "Notarized releases must be built from a completely clean worktree." >&2
  exit 1
fi

VERSION="$(python3 "${CONFIG_TOOL}" get marketingVersion)"
BUILD="$(python3 "${CONFIG_TOOL}" get buildNumber)"
APP_PATH="${OUTPUT_DIR}/CmdTab.app"
ZIP_PATH="${OUTPUT_DIR}/CmdTab-${VERSION}-${BUILD}.zip"
DMG_PATH="${OUTPUT_DIR}/CmdTab-${VERSION}-${BUILD}.dmg"
EVIDENCE_DIR="${OUTPUT_DIR}/notarization"
DMG_STAGE="$(mktemp -d /tmp/cmdtab-dmg-stage.XXXXXX)"

cleanup() {
  case "${DMG_STAGE}" in
    /tmp/cmdtab-dmg-stage.*) rm -rf "${DMG_STAGE}" ;;
    *) echo "Refusing to remove unexpected DMG staging path: ${DMG_STAGE}" >&2 ;;
  esac
}
trap cleanup EXIT

mkdir -p "${OUTPUT_DIR}" "${EVIDENCE_DIR}"
CMDTAB_OUTPUT_APP="${APP_PATH}" \
CMDTAB_SIGNING_IDENTITY="${SIGNING_IDENTITY}" \
CMDTAB_SPARKLE_PUBLIC_ED_KEY="${CMDTAB_SPARKLE_PUBLIC_ED_KEY}" \
CMDTAB_BUILD_ARCHITECTURES="arm64,x86_64" \
CMDTAB_EXPECTED_ARCHITECTURES="arm64,x86_64" \
  "${ROOT_DIR}/scripts/release/package-app.sh"

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

ditto "${APP_PATH}" "${DMG_STAGE}/CmdTab.app"
ln -s /Applications "${DMG_STAGE}/Applications"
hdiutil create \
  -volname "CmdTab" \
  -srcfolder "${DMG_STAGE}" \
  -format UDZO \
  -ov \
  "${DMG_PATH}"
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
printf 'Evidence: %s\n' "${EVIDENCE_DIR}"
