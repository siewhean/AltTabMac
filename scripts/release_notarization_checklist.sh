#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="CmdTab"
APP_BUNDLE="${ROOT_DIR}/${APP_NAME}.app"
ZIP_PATH="${ROOT_DIR}/${APP_NAME}.zip"
ENTITLEMENTS_PATH="${ROOT_DIR}/Resources/CmdTab.entitlements"

DEVELOPER_ID="${CMDTAB_DEVELOPER_ID:-}"
TEAM_ID="${CMDTAB_TEAM_ID:-}"
NOTARY_PROFILE="${CMDTAB_NOTARY_PROFILE:-}"

function section() {
  printf '\n== %s ==\n' "$1"
}

function require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1"
    exit 1
  fi
}

section "CmdTab release + notarization preflight"
echo "Repo: ${ROOT_DIR}"
echo "App bundle: ${APP_BUNDLE}"

section "Tooling checks"
for tool in swift codesign xcrun ditto spctl; do
  require_tool "$tool"
  echo "Found ${tool}"
done

section "Credential checks"
if [[ -n "${DEVELOPER_ID}" ]]; then
  echo "Developer ID identity configured: ${DEVELOPER_ID}"
else
  echo "CMDTAB_DEVELOPER_ID is not set"
fi

if [[ -n "${TEAM_ID}" ]]; then
  echo "Apple Team ID configured: ${TEAM_ID}"
else
  echo "CMDTAB_TEAM_ID is not set"
fi

if [[ -n "${NOTARY_PROFILE}" ]]; then
  echo "Notary keychain profile configured: ${NOTARY_PROFILE}"
else
  echo "CMDTAB_NOTARY_PROFILE is not set"
fi

section "Step 1: Build the app bundle"
echo "./build.sh"

section "Step 2: Sign with Developer ID"
echo "codesign --force --deep --options runtime \\"
echo "  --entitlements '${ENTITLEMENTS_PATH}' \\"
echo "  --sign \"${DEVELOPER_ID:-Developer ID Application: <Your Name>}\" \\"
echo "  '${APP_BUNDLE}'"

section "Step 3: Verify codesigning"
echo "codesign --verify --deep --strict --verbose=2 '${APP_BUNDLE}'"
echo "spctl --assess --type execute --verbose=4 '${APP_BUNDLE}'"

section "Step 4: Create notarization archive"
echo "rm -f '${ZIP_PATH}'"
echo "ditto -c -k --keepParent '${APP_BUNDLE}' '${ZIP_PATH}'"

section "Step 5: Submit for notarization"
echo "xcrun notarytool submit '${ZIP_PATH}' \\"
echo "  --keychain-profile '${NOTARY_PROFILE:-cmdtab-notary-profile}' \\"
echo "  --wait"

section "Step 6: Staple and re-verify"
echo "xcrun stapler staple '${APP_BUNDLE}'"
echo "spctl --assess --type execute --verbose=4 '${APP_BUNDLE}'"

section "Step 7: Distribution checks"
echo "1. Test install on a clean Mac"
echo "2. Confirm Accessibility permission flow"
echo "3. Confirm Screen Recording permission flow"
echo "4. Test first switch, hot swap, quick actions, and settings"
echo "5. Launch the website checkout/trial links and verify download delivery"

section "Owner environment"
echo "Set these before release:"
echo "  export CMDTAB_DEVELOPER_ID='Developer ID Application: Your Name (TEAMID)'"
echo "  export CMDTAB_TEAM_ID='TEAMID'"
echo "  export CMDTAB_NOTARY_PROFILE='cmdtab-notary-profile'"
