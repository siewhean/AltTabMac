#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PACKAGE_TOOL="${ROOT_DIR}/scripts/release/package-app.sh"
VERIFY_TOOL="${ROOT_DIR}/scripts/release/verify-bundle.sh"
TEMP_ROOT="$(mktemp -d /tmp/cmdtab-reproducibility.XXXXXX)"
CANONICAL_SCRATCH="${TEMP_ROOT}/canonical-scratch"

cleanup() {
  rm -rf "${TEMP_ROOT}"
}
trap cleanup EXIT

for tool in cmp diff shasum; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "Missing required tool: ${tool}" >&2
    exit 1
  }
done

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

build_clean_bundle() {
  local output_app="$1"

  # SwiftPM and the linker may embed the absolute scratch/module path in Mach-O
  # metadata. A reproducibility comparison must therefore hold the build inputs
  # and build path constant while still deleting all prior build output.
  rm -rf "${CANONICAL_SCRATCH}"
  mkdir -p "${CANONICAL_SCRATCH}"

  CMDTAB_OUTPUT_APP="${output_app}" \
  CMDTAB_SKIP_ADHOC_SIGN=1 \
  CMDTAB_RELEASE_SCRATCH="${CANONICAL_SCRATCH}" \
    "${PACKAGE_TOOL}"
}

print_binary_diagnostics() {
  local first_binary="$1"
  local second_binary="$2"

  echo >&2
  echo "Mach-O reproducibility diagnostics:" >&2
  if command -v dwarfdump >/dev/null 2>&1; then
    echo "first UUID:" >&2
    dwarfdump --uuid "${first_binary}" >&2 || true
    echo "second UUID:" >&2
    dwarfdump --uuid "${second_binary}" >&2 || true
  fi

  echo "first differing byte offsets (decimal byte values):" >&2
  cmp -l "${first_binary}" "${second_binary}" 2>/dev/null | head -n 20 >&2 || true
}

FIRST_APP="${TEMP_ROOT}/first/CmdTab.app"
SECOND_APP="${TEMP_ROOT}/second/CmdTab.app"
FIRST_BINARY="${FIRST_APP}/Contents/MacOS/CmdTab"
SECOND_BINARY="${SECOND_APP}/Contents/MacOS/CmdTab"

build_clean_bundle "${FIRST_APP}"
build_clean_bundle "${SECOND_APP}"

"${VERIFY_TOOL}" "${FIRST_APP}" unsigned
"${VERIFY_TOOL}" "${SECOND_APP}" unsigned

hash_bundle "${FIRST_APP}" "${TEMP_ROOT}/first.sha256"
hash_bundle "${SECOND_APP}" "${TEMP_ROOT}/second.sha256"

if ! diff -u "${TEMP_ROOT}/first.sha256" "${TEMP_ROOT}/second.sha256"; then
  print_binary_diagnostics "${FIRST_BINARY}" "${SECOND_BINARY}"
  echo "Two clean unsigned package builds from the same canonical build path were not byte-for-byte reproducible." >&2
  exit 1
fi

cmp "${FIRST_APP}/Contents/Info.plist" "${SECOND_APP}/Contents/Info.plist"
cmp "${FIRST_BINARY}" "${SECOND_BINARY}"

echo "Two clean unsigned CmdTab.app builds from the same canonical build path are byte-for-byte reproducible."
