#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE="${ROOT_DIR}/Tests/Fixtures/PerformanceProbe/main.swift"
OUTPUT="${CMDTAB_PERFORMANCE_PROBE_OUTPUT:-${ROOT_DIR}/dist/fixtures/PerformanceProbe}"
OWNS_SCRATCH=0
if [[ -n "${CMDTAB_PERFORMANCE_PROBE_SCRATCH:-}" ]]; then
  SCRATCH="${CMDTAB_PERFORMANCE_PROBE_SCRATCH}"
else
  SCRATCH="$(mktemp -d /tmp/cmdtab-performance-probe.XXXXXX)"
  OWNS_SCRATCH=1
fi

cleanup() {
  if [[ "${OWNS_SCRATCH}" == "1" &&
        "${CMDTAB_KEEP_PERFORMANCE_PROBE_SCRATCH:-0}" != "1" ]]; then
    rm -rf "${SCRATCH}"
  fi
}
trap cleanup EXIT

[[ "$(uname -s)" == "Darwin" ]] || {
  echo "PerformanceProbe must be built on macOS." >&2
  exit 1
}

for tool in swiftc shasum; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "Missing required tool: ${tool}" >&2
    exit 1
  }
done

mkdir -p "${SCRATCH}" "$(dirname "${OUTPUT}")"
ARCHITECTURE="$(uname -m)"
swiftc \
  -O \
  -target "${ARCHITECTURE}-apple-macosx13.0" \
  -framework AppKit \
  -framework ApplicationServices \
  -framework CoreGraphics \
  -framework CryptoKit \
  -framework Foundation \
  -framework ScreenCaptureKit \
  -Xlinker -reproducible \
  "${SOURCE}" \
  -o "${SCRATCH}/PerformanceProbe"

install -m 0755 "${SCRATCH}/PerformanceProbe" "${OUTPUT}"
shasum -a 256 "${OUTPUT}" > "${OUTPUT}.sha256"

printf 'Packaged performance probe: %s\n' "${OUTPUT}"
