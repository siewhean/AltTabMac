#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
usage() {
  echo "Usage: $0 [--beta x.y.z-beta.N] CmdTab.dmg immutable-dmg-url 40-char-source-sha output-dir [previous-{stable,beta}.json]" >&2
}

BETA_VERSION=""
case "${1:-}" in
  --beta)
    BETA_VERSION="${2:-}"
    if [[ -z "${BETA_VERSION}" ]]; then
      usage
      exit 2
    fi
    shift 2
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  --*)
    usage
    exit 2
    ;;
esac

DMG_PATH="${1:-}"
DMG_URL="${2:-}"
SOURCE_SHA="${3:-}"
OUTPUT_DIR="${4:-}"
PREVIOUS_MANIFEST="${5:-}"

if [[ -z "${DMG_PATH}" || -z "${DMG_URL}" || -z "${SOURCE_SHA}" || -z "${OUTPUT_DIR}" ]]; then
  usage
  exit 2
fi

CHANNEL="stable"
MANIFEST_NAME="stable.json"
APPCAST_NAME="appcast.xml"
if [[ -n "${BETA_VERSION}" ]]; then
  [[ "${BETA_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+-beta\.[0-9]+$ ]] || {
    echo "Beta publication requires --beta x.y.z-beta.N." >&2
    exit 2
  }
  CHANNEL="beta"
  MANIFEST_NAME="beta.json"
  APPCAST_NAME="beta-appcast.xml"
fi

CONFIG_VERSION="$(python3 "${ROOT_DIR}/scripts/release/release_config.py" get marketingVersion)"
if [[ "${CHANNEL}" == "beta" ]]; then
  BETA_BASE_VERSION="${BETA_VERSION%-beta.*}"
  [[ "${BETA_BASE_VERSION}" == "${CONFIG_VERSION}" ]] || {
    echo "Beta publication version must use ReleaseConfig marketingVersion (${CONFIG_VERSION}) as its x.y.z base." >&2
    exit 1
  }
  CONFIG_BUILD="$(python3 "${ROOT_DIR}/scripts/release/release_config.py" get buildNumber)"
  EXPECTED_DMG_NAME="CmdTab-${BETA_VERSION}-${CONFIG_BUILD}.dmg"
  [[ "$(basename "${DMG_PATH}")" == "${EXPECTED_DMG_NAME}" ]] || {
    echo "Beta publication DMG must be named ${EXPECTED_DMG_NAME}." >&2
    exit 1
  }
fi

if [[ "${CMDTAB_ALLOW_TEST_SOURCE_SHA:-0}" != "1" ]]; then
  CURRENT_SHA="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
  [[ "${SOURCE_SHA}" == "${CURRENT_SHA}" ]] || {
    echo "Source SHA must match the checked-out release commit." >&2
    exit 1
  }
  if ! git -C "${ROOT_DIR}" diff --quiet ||
     ! git -C "${ROOT_DIR}" diff --cached --quiet ||
     [[ -n "$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=all)" ]]; then
    echo "Publication metadata must be prepared from a completely clean worktree." >&2
    exit 1
  fi
fi

MANIFEST_PATH="${OUTPUT_DIR}/${MANIFEST_NAME}"
APPCAST_PATH="${OUTPUT_DIR}/${APPCAST_NAME}"
CREATE_ARGUMENTS=(
  create
  --dmg "${DMG_PATH}"
  --dmg-url "${DMG_URL}"
  --source-sha "${SOURCE_SHA}"
  --output "${MANIFEST_PATH}"
)
if [[ "${CHANNEL}" == "beta" ]]; then
  CREATE_ARGUMENTS+=(--channel beta --version "${BETA_VERSION}")
fi
if [[ -n "${PREVIOUS_MANIFEST}" ]]; then
  CREATE_ARGUMENTS+=(--previous "${PREVIOUS_MANIFEST}")
fi

mkdir -p "${OUTPUT_DIR}"
python3 "${ROOT_DIR}/scripts/release/release_manifest.py" "${CREATE_ARGUMENTS[@]}"

# Appcast generation is deliberately last: callers must upload the immutable
# DMG and channel-specific manifest before promoting this final feed file.
"${ROOT_DIR}/scripts/release/generate-signed-appcast.sh" \
  "${DMG_PATH}" \
  "${MANIFEST_PATH}" \
  "${APPCAST_PATH}"

printf 'Publication candidate prepared. Upload in this order:\n'
printf '  1. %s\n' "${DMG_PATH}"
printf '  2. %s\n' "${MANIFEST_PATH}"
printf '  3. %s (last)\n' "${APPCAST_PATH}"
