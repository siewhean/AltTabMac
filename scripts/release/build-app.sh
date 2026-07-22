#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_TOOL="${ROOT_DIR}/scripts/release/release_config.py"
SCRATCH_PATH="${CMDTAB_BUILD_SCRATCH:-}"
LINKER_REPRODUCIBILITY="${CMDTAB_LINKER_REPRODUCIBILITY:-1}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "CmdTab must be built on macOS." >&2
  exit 1
fi

for tool in swift python3; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "Missing required tool: ${tool}" >&2
    exit 1
  }
done

python3 "${CONFIG_TOOL}" validate >/dev/null
APP_NAME="$(python3 "${CONFIG_TOOL}" get appName)"

if [[ -z "${SCRATCH_PATH}" ]]; then
  SCRATCH_PATH="$(mktemp -d /tmp/cmdtab-release-build.XXXXXX)"
fi
mkdir -p "${SCRATCH_PATH}"

BUILD_ARGUMENTS=(
  --package-path "${ROOT_DIR}"
  --configuration release
  --scratch-path "${SCRATCH_PATH}"
)

case "${LINKER_REPRODUCIBILITY}" in
  1)
    # SwiftPM CLI builds do not reliably inherit Xcode's
    # LD_DETERMINISTIC_MODE setting. Keep a valid LC_UUID, but require ld to
    # derive all linker-generated metadata deterministically from the inputs.
    BUILD_ARGUMENTS+=( -Xlinker -reproducible )
    ;;
  0)
    ;;
  *)
    echo "CMDTAB_LINKER_REPRODUCIBILITY must be 0 or 1." >&2
    exit 2
    ;;
esac

printf 'Building %s in %s (deterministic-linker=%s)\n' \
  "${APP_NAME}" "${SCRATCH_PATH}" "${LINKER_REPRODUCIBILITY}" >&2
swift build "${BUILD_ARGUMENTS[@]}" >&2

BIN_DIR="$(swift build \
  --package-path "${ROOT_DIR}" \
  --configuration release \
  --scratch-path "${SCRATCH_PATH}" \
  --show-bin-path)"
BINARY_PATH="${BIN_DIR}/${APP_NAME}"

if [[ ! -f "${BINARY_PATH}" || ! -x "${BINARY_PATH}" ]]; then
  echo "Release executable was not created at ${BINARY_PATH}" >&2
  exit 1
fi

printf '%s\n' "${BINARY_PATH}"
