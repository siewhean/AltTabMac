#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE="${ROOT_DIR}/Tests/Fixtures/WindowLab/main.swift"
OUTPUT_APP="${CMDTAB_WINDOWLAB_OUTPUT_APP:-${ROOT_DIR}/dist/fixtures/WindowLab.app}"
SCRATCH="${CMDTAB_WINDOWLAB_SCRATCH:-$(mktemp -d /tmp/cmdtab-windowlab.XXXXXX)}"
BINARY="${SCRATCH}/WindowLab"

cleanup() {
  if [[ "${CMDTAB_KEEP_WINDOWLAB_SCRATCH:-0}" != "1" ]]; then
    rm -rf "${SCRATCH}"
  fi
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "WindowLab must be built on macOS." >&2
  exit 1
fi

for tool in swiftc codesign plutil shasum; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "Missing required tool: ${tool}" >&2
    exit 1
  }
done

[[ -f "${SOURCE}" ]] || {
  echo "Missing fixture source: ${SOURCE}" >&2
  exit 1
}

mkdir -p "${SCRATCH}" "$(dirname "${OUTPUT_APP}")"
swiftc \
  -O \
  -framework AppKit \
  -framework Foundation \
  -Xlinker -reproducible \
  "${SOURCE}" \
  -o "${BINARY}"

rm -rf "${OUTPUT_APP}"
mkdir -p "${OUTPUT_APP}/Contents/MacOS"
install -m 0755 "${BINARY}" "${OUTPUT_APP}/Contents/MacOS/WindowLab"
cat > "${OUTPUT_APP}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key><string>WindowLab</string>
  <key>CFBundleExecutable</key><string>WindowLab</string>
  <key>CFBundleIdentifier</key><string>net.cmdtab.fixture.WindowLab</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>WindowLab</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

plutil -lint "${OUTPUT_APP}/Contents/Info.plist" >/dev/null
find "${OUTPUT_APP}" -type d -exec chmod 0755 {} +
find "${OUTPUT_APP}" -type f ! -path '*/Contents/MacOS/WindowLab' -exec chmod 0644 {} +
codesign --force --sign - --timestamp=none "${OUTPUT_APP}"
codesign --verify --strict --verbose=2 "${OUTPUT_APP}"
(
  cd "$(dirname "${OUTPUT_APP}")"
  shasum -a 256 "$(basename "${OUTPUT_APP}")/Contents/Info.plist" \
    "$(basename "${OUTPUT_APP}")/Contents/MacOS/WindowLab"
) > "${OUTPUT_APP%.app}.sha256"

printf 'Packaged fixture: %s\n' "${OUTPUT_APP}"
printf 'Scenarios: standard minimized duplicate-titles fullscreen floating-panel delayed-focus unresponsive\n'
printf 'Launch example: open %q --args minimized\n' "${OUTPUT_APP}"
