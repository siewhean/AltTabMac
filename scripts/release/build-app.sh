#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_TOOL="${ROOT_DIR}/scripts/release/release_config.py"
SCRATCH_PATH="${CMDTAB_BUILD_SCRATCH:-}"
LINKER_REPRODUCIBILITY="${CMDTAB_LINKER_REPRODUCIBILITY:-1}"
BUILD_JOBS="${CMDTAB_BUILD_JOBS:-}"
BUILD_ARCHITECTURES="${CMDTAB_BUILD_ARCHITECTURES:-}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "CmdTab must be built on macOS." >&2
  exit 1
fi

for tool in swift python3 ditto lipo; do
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

if [[ -n "${BUILD_JOBS}" ]]; then
  [[ "${BUILD_JOBS}" =~ ^[1-9][0-9]*$ ]] || {
    echo "CMDTAB_BUILD_JOBS must be a positive integer." >&2
    exit 2
  }
fi

if [[ -n "${BUILD_ARCHITECTURES}" ]]; then
  [[ "${BUILD_ARCHITECTURES}" == "arm64" ]] || {
    echo "CMDTAB_BUILD_ARCHITECTURES must be arm64 when set." >&2
    exit 2
  }
fi

case "${LINKER_REPRODUCIBILITY}" in
  1)
    # SwiftPM CLI builds do not reliably inherit Xcode's
    # LD_DETERMINISTIC_MODE setting. Keep a valid LC_UUID, but require ld to
    # derive all linker-generated metadata deterministically from the inputs.
    ;;
  0)
    ;;
  *)
    echo "CMDTAB_LINKER_REPRODUCIBILITY must be 0 or 1." >&2
    exit 2
    ;;
esac

build_product() {
  local product_scratch="$1"
  local target_triple="${2:-}"
  local build_arguments=(
    --package-path "${ROOT_DIR}"
    --configuration release
    --scratch-path "${product_scratch}"
  )
  if [[ -n "${BUILD_JOBS}" ]]; then
    build_arguments+=(--jobs "${BUILD_JOBS}")
  fi
  if [[ -n "${target_triple}" ]]; then
    build_arguments+=(--triple "${target_triple}")
  fi
  build_arguments+=(
    -Xlinker -rpath
    -Xlinker "@executable_path/../Frameworks"
    # SwiftPM release builds otherwise embed absolute scratch paths in DWARF.
    # Distribution artifacts keep external dSYMs private; omit inline debug data
    # so clean scratch directories yield the same customer artifact.
    -Xswiftc -gnone
  )
  if [[ "${LINKER_REPRODUCIBILITY}" == "1" ]]; then
    # SwiftPM CLI builds do not reliably inherit Xcode's
    # LD_DETERMINISTIC_MODE setting. Keep a valid LC_UUID, but require ld to
    # derive all linker-generated metadata deterministically from the inputs.
    build_arguments+=( -Xlinker -reproducible )
  fi

  swift build "${build_arguments[@]}" >&2
  local binary_directory
  binary_directory="$(swift build "${build_arguments[@]}" --show-bin-path)"
  local product_binary="${binary_directory}/${APP_NAME}"
  [[ -f "${product_binary}" && -x "${product_binary}" ]] || {
    echo "Release executable was not created at ${product_binary}" >&2
    exit 1
  }
  printf '%s\n' "${product_binary}"
}

printf 'Building %s in %s (deterministic-linker=%s jobs=%s architectures=%s)\n' \
  "${APP_NAME}" \
  "${SCRATCH_PATH}" \
  "${LINKER_REPRODUCIBILITY}" \
  "${BUILD_JOBS:-default}" \
  "${BUILD_ARCHITECTURES:-host}" >&2
if [[ "${BUILD_ARCHITECTURES}" == "arm64" ]]; then
  BINARY_PATH="$(build_product "${SCRATCH_PATH}/arm64" "arm64-apple-macosx13.0")"
else
  BINARY_PATH="$(build_product "${SCRATCH_PATH}")"
fi

printf '%s\n' "${BINARY_PATH}"
