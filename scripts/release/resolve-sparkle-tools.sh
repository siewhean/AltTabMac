#!/usr/bin/env bash
set -euo pipefail

# Resolve the Sparkle release utilities from the exact SwiftPM dependency graph
# used by CmdTab.  Do not use a developer's repository-local .build directory:
# release builds deliberately use isolated scratch directories.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="resolve"
SCRATCH_PATH=""

usage() {
  echo "Usage: $0 [--preflight] [--scratch-path /absolute/path]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --preflight)
      MODE="preflight"
      shift
      ;;
    --scratch-path)
      SCRATCH_PATH="${2:-}"
      [[ -n "${SCRATCH_PATH}" ]] || { usage; exit 2; }
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

GENERATE_APPCAST_OVERRIDE="${CMDTAB_GENERATE_APPCAST:-}"
SIGN_UPDATE_OVERRIDE="${CMDTAB_SIGN_UPDATE:-}"
if [[ -n "${GENERATE_APPCAST_OVERRIDE}" || -n "${SIGN_UPDATE_OVERRIDE}" ]]; then
  [[ -n "${GENERATE_APPCAST_OVERRIDE}" && -n "${SIGN_UPDATE_OVERRIDE}" ]] || {
    echo "CMDTAB_GENERATE_APPCAST and CMDTAB_SIGN_UPDATE must be supplied together." >&2
    exit 2
  }
  [[ -x "${GENERATE_APPCAST_OVERRIDE}" ]] || {
    echo "CMDTAB_GENERATE_APPCAST is not executable." >&2
    exit 1
  }
  [[ -x "${SIGN_UPDATE_OVERRIDE}" ]] || {
    echo "CMDTAB_SIGN_UPDATE is not executable." >&2
    exit 1
  }
  if [[ "${MODE}" == "preflight" ]]; then
    echo "Sparkle tool preflight passed with explicit executable overrides."
    exit 0
  fi
  printf '%s\n%s\n' "${GENERATE_APPCAST_OVERRIDE}" "${SIGN_UPDATE_OVERRIDE}"
  exit 0
fi

for tool in swift python3; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "Missing required tool: ${tool}" >&2
    exit 1
  }
done
python3 "${ROOT_DIR}/scripts/release/release_config.py" validate >/dev/null

if [[ "${MODE}" == "preflight" ]]; then
  echo "Sparkle tool preflight passed; tools will be resolved from an isolated SwiftPM scratch path."
  exit 0
fi

[[ -n "${SCRATCH_PATH}" ]] || {
  echo "Sparkle tool resolution requires an explicit isolated --scratch-path." >&2
  exit 2
}

swift build \
  --package-path "${ROOT_DIR}" \
  --configuration release \
  --scratch-path "${SCRATCH_PATH}" \
  --triple arm64-apple-macosx13.0 \
  -Xswiftc -gnone >&2

GENERATE_APPCAST="${SCRATCH_PATH}/artifacts/sparkle/Sparkle/bin/generate_appcast"
SIGN_UPDATE="${SCRATCH_PATH}/artifacts/sparkle/Sparkle/bin/sign_update"
[[ -x "${GENERATE_APPCAST}" ]] || {
  echo "SwiftPM did not provision Sparkle generate_appcast in the isolated scratch path." >&2
  exit 1
}
[[ -x "${SIGN_UPDATE}" ]] || {
  echo "SwiftPM did not provision Sparkle sign_update in the isolated scratch path." >&2
  exit 1
}

printf '%s\n%s\n' "${GENERATE_APPCAST}" "${SIGN_UPDATE}"
