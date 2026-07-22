#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_TOOL="${ROOT_DIR}/scripts/release/release_config.py"
BUILD_TOOL="${ROOT_DIR}/scripts/release/build-app.sh"
VERIFY_TOOL="${ROOT_DIR}/scripts/release/verify-bundle.sh"
MANIFEST_TOOL="${ROOT_DIR}/scripts/release/write-bundle-manifest.py"
OUTPUT_APP="${CMDTAB_OUTPUT_APP:-${ROOT_DIR}/dist/CmdTab.app}"
SKIP_SIGN="${CMDTAB_SKIP_ADHOC_SIGN:-0}"
KEEP_SCRATCH="${CMDTAB_KEEP_RELEASE_SCRATCH:-0}"
SCRATCH_ROOT="${CMDTAB_RELEASE_SCRATCH:-$(mktemp -d /tmp/cmdtab-package.XXXXXX)}"
STAGE_APP="${SCRATCH_ROOT}/CmdTab.app"

cleanup() {
  if [[ "${KEEP_SCRATCH}" != "1" ]]; then
    rm -rf "${SCRATCH_ROOT}"
  else
    echo "Kept release scratch at ${SCRATCH_ROOT}" >&2
  fi
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "CmdTab packaging must run on macOS." >&2
  exit 1
fi

for tool in python3 plutil codesign xattr shasum; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "Missing required tool: ${tool}" >&2
    exit 1
  }
done

python3 "${CONFIG_TOOL}" verify-repository

APP_NAME="$(python3 "${CONFIG_TOOL}" get appName)"
EXECUTABLE_NAME="$(python3 "${CONFIG_TOOL}" get executableName)"
ICON_FILE="$(python3 "${CONFIG_TOOL}" get iconFile)"
BUILD_SCRATCH="${SCRATCH_ROOT}/swift-build"
BINARY_PATH="$(CMDTAB_BUILD_SCRATCH="${BUILD_SCRATCH}" "${BUILD_TOOL}")"

rm -rf "${STAGE_APP}"
mkdir -p "${STAGE_APP}/Contents/MacOS" "${STAGE_APP}/Contents/Resources"

install -m 0755 "${BINARY_PATH}" "${STAGE_APP}/Contents/MacOS/${EXECUTABLE_NAME}"
python3 "${CONFIG_TOOL}" render-info-plist "${STAGE_APP}/Contents/Info.plist"
install -m 0644 "${ROOT_DIR}/Resources/${ICON_FILE}.icns" "${STAGE_APP}/Contents/Resources/${ICON_FILE}.icns"
if [[ -f "${ROOT_DIR}/Resources/${ICON_FILE}.png" ]]; then
  install -m 0644 "${ROOT_DIR}/Resources/${ICON_FILE}.png" "${STAGE_APP}/Contents/Resources/${ICON_FILE}.png"
fi

find "${STAGE_APP}" -type d -exec chmod 0755 {} +
find "${STAGE_APP}" -type f ! -path "*/Contents/MacOS/${EXECUTABLE_NAME}" -exec chmod 0644 {} +
chmod 0755 "${STAGE_APP}/Contents/MacOS/${EXECUTABLE_NAME}"
xattr -cr "${STAGE_APP}" 2>/dev/null || true

if [[ -n "$(find "${STAGE_APP}" -type l -print -quit)" ]]; then
  echo "Packaged app contains an unexpected symbolic link." >&2
  exit 1
fi

if [[ "${SKIP_SIGN}" == "1" ]]; then
  # Apple Silicon linkers may add an ad-hoc signature to a Mach-O executable even
  # when the bundle itself has not been signed. Strip that generated signature
  # from the staged copy so the reproducibility path is genuinely unsigned.
  if codesign -d "${STAGE_APP}/Contents/MacOS/${EXECUTABLE_NAME}" >/dev/null 2>&1; then
    codesign --remove-signature "${STAGE_APP}/Contents/MacOS/${EXECUTABLE_NAME}"
  fi
  EXPECTED_SIGNING="unsigned"
else
  plutil -lint "${ROOT_DIR}/Resources/CmdTab.entitlements" >/dev/null
  codesign \
    --force \
    --sign - \
    --timestamp=none \
    --options runtime \
    --entitlements "${ROOT_DIR}/Resources/CmdTab.entitlements" \
    "${STAGE_APP}"
  EXPECTED_SIGNING="ad-hoc"
fi

"${VERIFY_TOOL}" "${STAGE_APP}" "${EXPECTED_SIGNING}"

mkdir -p "$(dirname "${OUTPUT_APP}")"
rm -rf "${OUTPUT_APP}"
mv "${STAGE_APP}" "${OUTPUT_APP}"

ARTIFACT_BASE="${OUTPUT_APP%.app}"
MANIFEST_PATH="${ARTIFACT_BASE}.manifest.json"
CHECKSUM_PATH="${ARTIFACT_BASE}.sha256"
python3 "${MANIFEST_TOOL}" "${OUTPUT_APP}" "${MANIFEST_PATH}" >/dev/null
(
  cd "$(dirname "${OUTPUT_APP}")"
  shasum -a 256 "$(basename "${OUTPUT_APP}")/Contents/Info.plist" \
    "$(basename "${OUTPUT_APP}")/Contents/MacOS/${EXECUTABLE_NAME}" \
    "$(basename "${OUTPUT_APP}")/Contents/Resources/${ICON_FILE}.icns"
) > "${CHECKSUM_PATH}"

printf 'Packaged %s\n' "${OUTPUT_APP}"
printf 'Manifest %s\n' "${MANIFEST_PATH}"
printf 'Checksums %s\n' "${CHECKSUM_PATH}"
