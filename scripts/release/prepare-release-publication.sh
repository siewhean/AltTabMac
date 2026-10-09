#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DMG_PATH="${1:-}"
DMG_URL="${2:-}"
SOURCE_SHA="${3:-}"
OUTPUT_DIR="${4:-}"
PREVIOUS_MANIFEST="${5:-}"
EVIDENCE_RECEIPT="${6:-}"

if [[ -z "${DMG_PATH}" || -z "${DMG_URL}" || -z "${SOURCE_SHA}" || -z "${OUTPUT_DIR}" || -z "${EVIDENCE_RECEIPT}" ]]; then
  echo "Usage: $0 CmdTab.dmg immutable-dmg-url 40-char-source-sha output-dir [previous-channel.json] candidate-evidence.json" >&2
  exit 2
fi

CURRENT_BRANCH="$(git -C "${ROOT_DIR}" branch --show-current)"
python3 "${ROOT_DIR}/scripts/release/candidate-evidence.py" verify \
  --candidate "${SOURCE_SHA}" \
  --branch "${CURRENT_BRANCH}" \
  --artifact "${DMG_PATH}" \
  "${EVIDENCE_RECEIPT}"

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

CHANNEL="$(python3 "${ROOT_DIR}/scripts/release/release_config.py" get updateChannel)"
if [[ "${CHANNEL}" != "beta" && "${CHANNEL}" != "stable" ]]; then
  echo "Development configuration cannot prepare public update publication." >&2
  exit 2
fi
MANIFEST_PATH="${OUTPUT_DIR}/${CHANNEL}.json"
APPCAST_PATH="${OUTPUT_DIR}/appcast.xml"
CREATE_ARGUMENTS=(
  create
  --dmg "${DMG_PATH}"
  --dmg-url "${DMG_URL}"
  --source-sha "${SOURCE_SHA}"
  --output "${MANIFEST_PATH}"
)
if [[ -n "${PREVIOUS_MANIFEST}" ]]; then
  CREATE_ARGUMENTS+=(--previous "${PREVIOUS_MANIFEST}")
fi

mkdir -p "${OUTPUT_DIR}"
python3 "${ROOT_DIR}/scripts/release/release_manifest.py" "${CREATE_ARGUMENTS[@]}"

# Appcast generation is deliberately last: callers must upload the immutable
# DMG and stable manifest before promoting this final feed file.
"${ROOT_DIR}/scripts/release/generate-signed-appcast.sh" \
  "${DMG_PATH}" \
  "${MANIFEST_PATH}" \
  "${APPCAST_PATH}"

printf 'Publication candidate prepared. Upload in this order:\n'
printf '  1. %s\n' "${DMG_PATH}"
printf '  2. %s\n' "${MANIFEST_PATH}"
printf '  3. %s (last)\n' "${APPCAST_PATH}"
