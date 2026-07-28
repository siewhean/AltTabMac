#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DMG_PATH="${1:-}"
MANIFEST_PATH="${2:-}"
OUTPUT_PATH="${3:-}"
KEY_ACCOUNT="${CMDTAB_SPARKLE_KEY_ACCOUNT:-ed25519}"

if [[ -z "${DMG_PATH}" || -z "${MANIFEST_PATH}" || -z "${OUTPUT_PATH}" ]]; then
  echo "Usage: $0 /path/to/CmdTab.dmg /path/to/stable.json /path/to/appcast.xml" >&2
  exit 2
fi

"${ROOT_DIR}/scripts/release/verify-notarized-dmg.sh" "${DMG_PATH}"

python3 "${ROOT_DIR}/scripts/release/release_manifest.py" \
  validate "${MANIFEST_PATH}" --artifact "${DMG_PATH}"

GENERATE_APPCAST="${CMDTAB_GENERATE_APPCAST:-${ROOT_DIR}/.build/artifacts/sparkle/Sparkle/bin/generate_appcast}"
SIGN_UPDATE="${CMDTAB_SIGN_UPDATE:-${ROOT_DIR}/.build/artifacts/sparkle/Sparkle/bin/sign_update}"
[[ -x "${GENERATE_APPCAST}" ]] || { echo "Missing Sparkle generate_appcast tool" >&2; exit 1; }
[[ -x "${SIGN_UPDATE}" ]] || { echo "Missing Sparkle sign_update tool" >&2; exit 1; }

TEMP_ROOT="$(mktemp -d /tmp/cmdtab-appcast.XXXXXX)"
cleanup() {
  case "${TEMP_ROOT}" in
    /tmp/cmdtab-appcast.*) rm -rf "${TEMP_ROOT}" ;;
    *) echo "Refusing to remove unexpected temporary path: ${TEMP_ROOT}" >&2 ;;
  esac
}
trap cleanup EXIT

DMG_NAME="$(python3 -c 'import json,sys,urllib.parse; print(urllib.parse.urlparse(json.load(open(sys.argv[1]))["dmgURL"]).path.rsplit("/",1)[-1])' "${MANIFEST_PATH}")"
DOWNLOAD_PREFIX="$(python3 -c 'import json,sys; value=json.load(open(sys.argv[1]))["dmgURL"]; print(value.rsplit("/",1)[0] + "/")' "${MANIFEST_PATH}")"
BUILD_NUMBER="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["build"])' "${MANIFEST_PATH}")"
cp "${DMG_PATH}" "${TEMP_ROOT}/${DMG_NAME}"

GENERATE_ARGUMENTS=(
  -o "${TEMP_ROOT}/$(basename "${OUTPUT_PATH}")"
  --download-url-prefix "${DOWNLOAD_PREFIX}"
  --versions "${BUILD_NUMBER}"
  --maximum-deltas 0
  --maximum-versions 3
  "${TEMP_ROOT}"
)

if [[ -n "${CMDTAB_SPARKLE_PRIVATE_ED_KEY:-}" ]]; then
  printf '%s' "${CMDTAB_SPARKLE_PRIVATE_ED_KEY}" |
    "${GENERATE_APPCAST}" --ed-key-file - "${GENERATE_ARGUMENTS[@]}"
  printf '%s' "${CMDTAB_SPARKLE_PRIVATE_ED_KEY}" |
    "${SIGN_UPDATE}" --verify --ed-key-file - "${TEMP_ROOT}/$(basename "${OUTPUT_PATH}")"
else
  "${GENERATE_APPCAST}" --account "${KEY_ACCOUNT}" "${GENERATE_ARGUMENTS[@]}"
  "${SIGN_UPDATE}" --verify --account "${KEY_ACCOUNT}" "${TEMP_ROOT}/$(basename "${OUTPUT_PATH}")"
fi

python3 "${ROOT_DIR}/scripts/release/validate-appcast.py" \
  "${TEMP_ROOT}/$(basename "${OUTPUT_PATH}")" \
  "${MANIFEST_PATH}"

mkdir -p "$(dirname "${OUTPUT_PATH}")"
install -m 0644 "${TEMP_ROOT}/$(basename "${OUTPUT_PATH}")" "${OUTPUT_PATH}"
printf 'Signed appcast: %s\n' "${OUTPUT_PATH}"
