#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_DIR="${CMDTAB_PHASE1_EVIDENCE_DIR:-${ROOT_DIR}/dist/phase1-evidence}"
TEMP_ROOT="$(mktemp -d /tmp/cmdtab-phase1-qa.XXXXXX)"
APP_PATH="${ROOT_DIR}/dist/CmdTab.app"
LOG_PATH="${EVIDENCE_DIR}/commands.log"

cleanup() {
  rm -rf "${TEMP_ROOT}"
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Phase 1 QA must run on macOS." >&2
  exit 1
fi

for tool in python3 swift codesign lipo plutil shasum git; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "Missing required tool: ${tool}" >&2
    exit 1
  }
done

rm -rf "${EVIDENCE_DIR}"
mkdir -p "${EVIDENCE_DIR}"

exec > >(tee "${LOG_PATH}") 2>&1

echo "CmdTab Phase 1 local QA"
echo "commit=$(git -C "${ROOT_DIR}" rev-parse HEAD)"
echo "macos=$(sw_vers -productVersion)"
echo "architecture=$(uname -m)"
echo "swift=$(swift --version | head -n 1)"
date -u '+utc=%Y-%m-%dT%H:%M:%SZ'

echo
echo "== Repository identity contract =="
python3 "${ROOT_DIR}/scripts/release/release_config.py" verify-repository

echo
echo "== Bundle migration tests =="
swift test \
  --package-path "${ROOT_DIR}" \
  --scratch-path "${TEMP_ROOT}/migration-tests" \
  --filter BundleIdentityMigrationTests

echo
echo "== Full Swift package suite =="
swift test \
  --package-path "${ROOT_DIR}" \
  --scratch-path "${TEMP_ROOT}/full-tests"

echo
echo "== Package ad-hoc local QA bundle =="
CMDTAB_OUTPUT_APP="${APP_PATH}" \
CMDTAB_RELEASE_SCRATCH="${TEMP_ROOT}/package" \
  "${ROOT_DIR}/scripts/release/package-app.sh"

echo
echo "== Verify packaged bundle =="
"${ROOT_DIR}/scripts/release/verify-bundle.sh" "${APP_PATH}" ad-hoc

echo
echo "== Two-build reproducibility =="
"${ROOT_DIR}/scripts/release/reproducibility-check.sh"

echo
echo "== Artifact inspection =="
plutil -p "${APP_PATH}/Contents/Info.plist"
codesign -d --verbose=4 --entitlements :- "${APP_PATH}" 2>&1
lipo -archs "${APP_PATH}/Contents/MacOS/CmdTab"

cp "${ROOT_DIR}/dist/CmdTab.manifest.json" "${EVIDENCE_DIR}/bundle-manifest.json"
cp "${ROOT_DIR}/dist/CmdTab.sha256" "${EVIDENCE_DIR}/checksums.txt"
git -C "${ROOT_DIR}" rev-parse HEAD > "${EVIDENCE_DIR}/commit.txt"
sw_vers > "${EVIDENCE_DIR}/macos.txt"
swift --version > "${EVIDENCE_DIR}/swift-version.txt"

cat > "${EVIDENCE_DIR}/manual-checks.md" <<'CHECKLIST'
# Phase 1 manual checks

The automated local checks passed. The following observations still require a person:

- [ ] Launch `dist/CmdTab.app` successfully.
- [ ] CmdTab appears in the menu bar.
- [ ] CmdTab does not appear in the Dock.
- [ ] CmdTab does not appear in the native Command-Tab switcher.
- [ ] Settings opens from the menu-bar item.
- [ ] An existing beta profile retains supported preferences, install ID, trial/license state, and search memory.
- [ ] Accessibility re-grant guidance is clear if macOS treats the new bundle identifier as a new app.
- [ ] Screen Recording re-grant guidance is clear if macOS treats the new bundle identifier as a new app.
- [ ] The app can be quit deliberately from its own UI.
CHECKLIST

echo
echo "Phase 1 automated local QA passed."
echo "Evidence: ${EVIDENCE_DIR}"
echo "Manual observations remain in ${EVIDENCE_DIR}/manual-checks.md"
