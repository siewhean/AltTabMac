#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE="${ROOT_DIR}/Tests/Fixtures/WindowProbe/main.swift"
OUTPUT="${CMDTAB_WINDOWPROBE_OUTPUT:-${ROOT_DIR}/dist/fixtures/WindowProbe}"
SCRATCH="${CMDTAB_WINDOWPROBE_SCRATCH:-$(mktemp -d /tmp/cmdtab-windowprobe.XXXXXX)}"

cleanup() {
  if [[ "${CMDTAB_KEEP_WINDOWPROBE_SCRATCH:-0}" != "1" ]]; then
    rm -rf "${SCRATCH}"
  fi
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "WindowProbe must be built on macOS." >&2
  exit 1
fi

for tool in swiftc shasum; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "Missing required tool: ${tool}" >&2
    exit 1
  }
done

[[ -f "${SOURCE}" ]] || {
  echo "Missing fixture source: ${SOURCE}" >&2
  exit 1
}

mkdir -p "${SCRATCH}" "$(dirname "${OUTPUT}")"
swiftc \
  -O \
  -framework AppKit \
  -framework ApplicationServices \
  -framework CoreGraphics \
  -framework Foundation \
  -Xlinker -reproducible \
  "${SOURCE}" \
  -o "${SCRATCH}/WindowProbe"

install -m 0755 "${SCRATCH}/WindowProbe" "${OUTPUT}"
shasum -a 256 "${OUTPUT}" > "${OUTPUT}.sha256"

printf 'Packaged exact-window probe: %s\n' "${OUTPUT}"
printf 'Usage: %q net.cmdtab.fixture.WindowLab\n' "${OUTPUT}"
printf 'Terminal must have Accessibility permission for focusedWindowID/mainWindowID.\n'
