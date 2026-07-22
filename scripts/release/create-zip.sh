#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-}"
ZIP_PATH="${2:-}"

usage() {
  echo "Usage: create-zip.sh /path/to/CmdTab.app /path/to/CmdTab.zip" >&2
}

fail() {
  echo "ZIP creation failed: $*" >&2
  exit 1
}

if [[ -z "${APP_PATH}" || -z "${ZIP_PATH}" ]]; then
  usage
  exit 2
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "distribution ZIP creation must run on macOS"
fi

for tool in ditto shasum unzip python3; do
  command -v "${tool}" >/dev/null 2>&1 || fail "missing required tool: ${tool}"
done

[[ -d "${APP_PATH}" ]] || fail "app bundle does not exist: ${APP_PATH}"
[[ "$(basename "${APP_PATH}")" == "CmdTab.app" ]] || fail "expected CmdTab.app, got $(basename "${APP_PATH}")"
[[ "${ZIP_PATH}" == *.zip ]] || fail "output path must end in .zip"

APP_REAL="$(python3 - "${APP_PATH}" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
)"
ZIP_PARENT_REAL="$(python3 - "$(dirname "${ZIP_PATH}")" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
)"
case "${ZIP_PARENT_REAL}/" in
  "${APP_REAL}/"*) fail "ZIP output cannot be placed inside the app bundle" ;;
esac

mkdir -p "$(dirname "${ZIP_PATH}")"
rm -f "${ZIP_PATH}" "${ZIP_PATH}.sha256"

# ditto preserves macOS bundle metadata and resource forks in the format expected
# by Apple's notarization service. --keepParent ensures CmdTab.app is the archive root.
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"
unzip -tq "${ZIP_PATH}" >/dev/null
(
  cd "$(dirname "${ZIP_PATH}")"
  shasum -a 256 "$(basename "${ZIP_PATH}")"
) > "${ZIP_PATH}.sha256"

printf 'Created distribution ZIP: %s\n' "${ZIP_PATH}"
printf 'Checksum: %s\n' "${ZIP_PATH}.sha256"
