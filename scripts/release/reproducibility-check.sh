#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PACKAGE_TOOL="${ROOT_DIR}/scripts/release/package-app.sh"
VERIFY_TOOL="${ROOT_DIR}/scripts/release/verify-bundle.sh"
TEMP_ROOT="$(mktemp -d /tmp/cmdtab-reproducibility.XXXXXX)"

cleanup() {
  rm -rf "${TEMP_ROOT}"
}
trap cleanup EXIT

hash_bundle() {
  local app_path="$1"
  local output_path="$2"
  (
    cd "${app_path}"
    find . -type f | LC_ALL=C sort | while IFS= read -r relative; do
      shasum -a 256 "${relative}"
    done
  ) > "${output_path}"
}

FIRST_APP="${TEMP_ROOT}/first/CmdTab.app"
SECOND_APP="${TEMP_ROOT}/second/CmdTab.app"

CMDTAB_OUTPUT_APP="${FIRST_APP}" \
CMDTAB_SKIP_ADHOC_SIGN=1 \
CMDTAB_RELEASE_SCRATCH="${TEMP_ROOT}/first-scratch" \
  "${PACKAGE_TOOL}"

CMDTAB_OUTPUT_APP="${SECOND_APP}" \
CMDTAB_SKIP_ADHOC_SIGN=1 \
CMDTAB_RELEASE_SCRATCH="${TEMP_ROOT}/second-scratch" \
  "${PACKAGE_TOOL}"

"${VERIFY_TOOL}" "${FIRST_APP}" unsigned
"${VERIFY_TOOL}" "${SECOND_APP}" unsigned

hash_bundle "${FIRST_APP}" "${TEMP_ROOT}/first.sha256"
hash_bundle "${SECOND_APP}" "${TEMP_ROOT}/second.sha256"

if ! diff -u "${TEMP_ROOT}/first.sha256" "${TEMP_ROOT}/second.sha256"; then
  echo "Two clean unsigned package builds were not byte-for-byte reproducible." >&2
  exit 1
fi

cmp "${FIRST_APP}/Contents/Info.plist" "${SECOND_APP}/Contents/Info.plist"
cmp "${FIRST_APP}/Contents/MacOS/CmdTab" "${SECOND_APP}/Contents/MacOS/CmdTab"

echo "Two clean unsigned CmdTab.app builds are byte-for-byte reproducible."
