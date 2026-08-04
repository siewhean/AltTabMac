#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DMG_PATH="${1:-}"
MANIFEST_PATH="${2:-}"
OUTPUT_PATH="${3:-}"
KEY_ACCOUNT="${CMDTAB_SPARKLE_KEY_ACCOUNT:-ed25519}"
TOOL_RESOLVER="${ROOT_DIR}/scripts/release/resolve-sparkle-tools.sh"

if [[ -z "${DMG_PATH}" || -z "${MANIFEST_PATH}" || -z "${OUTPUT_PATH}" ]]; then
  echo "Usage: $0 /path/to/CmdTab.dmg /path/to/{stable,beta}.json /path/to/appcast.xml" >&2
  exit 2
fi

TEMP_ROOT="$(mktemp -d /tmp/cmdtab-appcast.XXXXXX)"
cleanup() {
  case "${TEMP_ROOT}" in
    /tmp/cmdtab-appcast.*) rm -rf "${TEMP_ROOT}" ;;
    *) echo "Refusing to remove unexpected temporary path: ${TEMP_ROOT}" >&2 ;;
  esac
}
trap cleanup EXIT

TOOL_OUTPUT="$("${TOOL_RESOLVER}" --scratch-path "${TEMP_ROOT}/swiftpm-artifacts")"
GENERATE_APPCAST="$(printf '%s\n' "${TOOL_OUTPUT}" | sed -n '1p')"
SIGN_UPDATE="$(printf '%s\n' "${TOOL_OUTPUT}" | sed -n '2p')"
[[ -n "${GENERATE_APPCAST}" && -n "${SIGN_UPDATE}" ]] || {
  echo "Sparkle tool resolver did not return both required utilities." >&2
  exit 1
}

DMG_NAME="$(python3 -c 'import json,sys,urllib.parse; print(urllib.parse.urlparse(json.load(open(sys.argv[1]))["dmgURL"]).path.rsplit("/",1)[-1])' "${MANIFEST_PATH}")"
DOWNLOAD_PREFIX="$(python3 -c 'import json,sys; value=json.load(open(sys.argv[1]))["dmgURL"]; print(value.rsplit("/",1)[0] + "/")' "${MANIFEST_PATH}")"
BUILD_NUMBER="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["build"])' "${MANIFEST_PATH}")"
RELEASE_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "${MANIFEST_PATH}")"
CHANNEL="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["channel"])' "${MANIFEST_PATH}")"
MARKETING_VERSION="${RELEASE_VERSION}"
if [[ "${CHANNEL}" == "beta" ]]; then
  MARKETING_VERSION="${RELEASE_VERSION%-beta.*}"
fi

# Re-check the actual mounted app for direct callers as well as the publication
# wrapper. A signed DMG and a valid manifest are insufficient if their bundle
# version or build identities differ.
"${ROOT_DIR}/scripts/release/verify-notarized-dmg.sh" \
  "${DMG_PATH}" \
  --expected-version "${MARKETING_VERSION}" \
  --expected-build "${BUILD_NUMBER}"

python3 "${ROOT_DIR}/scripts/release/release_manifest.py" \
  validate "${MANIFEST_PATH}" --artifact "${DMG_PATH}"

cp "${DMG_PATH}" "${TEMP_ROOT}/${DMG_NAME}"

GENERATE_ARGUMENTS=(
  -o "${TEMP_ROOT}/$(basename "${OUTPUT_PATH}")"
  --download-url-prefix "${DOWNLOAD_PREFIX}"
  --versions "${BUILD_NUMBER}"
  --maximum-deltas 0
  --maximum-versions 3
  "${TEMP_ROOT}"
)

if [[ "${CHANNEL}" == "beta" ]]; then
  GENERATE_ARGUMENTS+=(--channel beta)
fi

if [[ -n "${CMDTAB_SPARKLE_PRIVATE_ED_KEY:-}" ]]; then
  printf '%s' "${CMDTAB_SPARKLE_PRIVATE_ED_KEY}" |
    "${GENERATE_APPCAST}" --ed-key-file - "${GENERATE_ARGUMENTS[@]}"
  printf '%s' "${CMDTAB_SPARKLE_PRIVATE_ED_KEY}" |
    "${SIGN_UPDATE}" --verify --ed-key-file - "${TEMP_ROOT}/$(basename "${OUTPUT_PATH}")"
else
  "${GENERATE_APPCAST}" --account "${KEY_ACCOUNT}" "${GENERATE_ARGUMENTS[@]}"
  "${SIGN_UPDATE}" --verify --account "${KEY_ACCOUNT}" "${TEMP_ROOT}/$(basename "${OUTPUT_PATH}")"
fi

python3 - "${TEMP_ROOT}/$(basename "${OUTPUT_PATH}")" "${MANIFEST_PATH}" <<'PY'
import json
import sys
import xml.etree.ElementTree as ET

sparkle = "http://www.andymatuschak.org/xml-namespaces/sparkle"
appcast_path, manifest_path = sys.argv[1:]
manifest = json.load(open(manifest_path, encoding="utf-8"))
tree = ET.parse(appcast_path)
for enclosure in tree.findall("./channel/item/enclosure"):
    enclosure.set(f"{{{sparkle}}}sha256", manifest["sha256"])
ET.register_namespace("sparkle", sparkle)
tree.write(appcast_path, encoding="utf-8", xml_declaration=True)
PY

python3 "${ROOT_DIR}/scripts/release/validate-appcast.py" \
  "${TEMP_ROOT}/$(basename "${OUTPUT_PATH}")" \
  "${MANIFEST_PATH}"

mkdir -p "$(dirname "${OUTPUT_PATH}")"
install -m 0644 "${TEMP_ROOT}/$(basename "${OUTPUT_PATH}")" "${OUTPUT_PATH}"
printf 'Signed appcast: %s\n' "${OUTPUT_PATH}"
