#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_TOOL="${ROOT_DIR}/scripts/release/release_config.py"
SOURCE_VERIFY_TOOL="${ROOT_DIR}/scripts/release/verify-phase2-source.py"
DISTRIBUTION_RECORD_TOOL="${ROOT_DIR}/scripts/release/write-distribution-record.py"
EVIDENCE_DIR="${CMDTAB_PHASE2_EVIDENCE_DIR:-${ROOT_DIR}/dist/phase2-evidence}"
ARTIFACT_DIR="${CMDTAB_PHASE2_ARTIFACT_DIR:-${ROOT_DIR}/dist/phase2}"
TEMP_ROOT="$(mktemp -d /tmp/cmdtab-phase2-qa.XXXXXX)"
LOG_PATH="${EVIDENCE_DIR}/commands.log"
RESULT_PATH="${EVIDENCE_DIR}/result.txt"
MANUAL_PATH="${EVIDENCE_DIR}/manual-checks.md"
UNSIGNED_APP="${TEMP_ROOT}/unsigned/CmdTab.app"
SIGNED_APP="${ARTIFACT_DIR}/CmdTab.app"
NOTARY_ZIP="${TEMP_ROOT}/CmdTab-notarization.zip"
NOTARY_EVIDENCE_DIR="${EVIDENCE_DIR}/notarization"

write_manual_checks() {
  local automated_status="$1"
  cat > "${MANUAL_PATH}" <<CHECKLIST
# Phase 2 manual acceptance checks

**Automated distribution status:** ${automated_status}

Complete these checks against the final ZIP recorded in \`artifact-path.txt\`:

- [ ] Download or transfer the ZIP to a clean, non-development macOS account.
- [ ] Confirm the ZIP checksum matches \`final-artifact.sha256\` and \`distribution-record.json\`.
- [ ] Extract the ZIP and confirm Gatekeeper identifies the expected developer.
- [ ] Launch CmdTab without bypassing Gatekeeper.
- [ ] Confirm CmdTab appears in the menu bar and remains absent from the Dock and native Command-Tab switcher.
- [ ] Grant Accessibility and Screen Recording to the signed CmdTab bundle.
- [ ] Confirm CmdTab intercepts Command-Tab and activates the intended exact window.
- [ ] Confirm live previews, including Arc, appear after Screen Recording permission is granted.
- [ ] Quit and relaunch CmdTab using its own UI.
- [ ] Install a second consecutively signed build with the same identity and confirm macOS privacy grants remain associated with CmdTab.
- [ ] Enable Launch at Login, sign out/in or restart the test account, and confirm the signed app launches once.
- [ ] Exercise a real legacy beta profile and confirm supported preferences, install ID, trial/license state, Keychain license, and search memory migrate without overwriting new-domain values.
- [ ] Confirm uninstall and rollback instructions restore the previous accepted build.
CHECKLIST
}

cleanup() {
  local status=$?
  mkdir -p "${EVIDENCE_DIR}"
  if [[ "${status}" == "0" ]]; then
    printf 'AUTOMATED_PASS\n' > "${RESULT_PATH}"
    write_manual_checks "AUTOMATED_PASS — manual clean-account acceptance remains required"
  else
    printf 'FAIL (exit %s)\n' "${status}" > "${RESULT_PATH}"
    write_manual_checks "FAIL — automated distribution checks stopped before completion"
  fi
  rm -rf "${TEMP_ROOT}"
}
trap cleanup EXIT

fail() { echo "Phase 2 QA failed: $*" >&2; exit 1; }

if [[ "$(uname -s)" != "Darwin" ]]; then fail "Phase 2 QA must run on macOS"; fi
for tool in bash python3 swift codesign security xcrun spctl ditto lipo plutil shasum git; do
  command -v "${tool}" >/dev/null 2>&1 || fail "missing required tool: ${tool}"
done

[[ -n "${CMDTAB_DEVELOPER_IDENTITY:-}" ]] || fail "CMDTAB_DEVELOPER_IDENTITY is required"
[[ -n "${CMDTAB_TEAM_ID:-}" ]] || fail "CMDTAB_TEAM_ID is required"

if [[ -n "${CMDTAB_NOTARY_PROFILE:-}" ]]; then
  if [[ -n "${CMDTAB_NOTARY_KEY_ID:-}${CMDTAB_NOTARY_ISSUER:-}${CMDTAB_NOTARY_KEY_PATH:-}" ]]; then
    fail "configure either CMDTAB_NOTARY_PROFILE or API-key credentials, not both"
  fi
else
  [[ -n "${CMDTAB_NOTARY_KEY_ID:-}" ]] || fail "CMDTAB_NOTARY_PROFILE or CMDTAB_NOTARY_KEY_ID is required"
  [[ -n "${CMDTAB_NOTARY_KEY_PATH:-}" ]] || fail "CMDTAB_NOTARY_KEY_PATH is required for API-key authentication"
fi

rm -rf "${EVIDENCE_DIR}" "${ARTIFACT_DIR}"
mkdir -p "${EVIDENCE_DIR}" "${ARTIFACT_DIR}"
write_manual_checks "PENDING"
exec > >(tee "${LOG_PATH}") 2>&1

COMMIT_SHA="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
VERSION="$(python3 "${CONFIG_TOOL}" get marketingVersion)"
BUILD_NUMBER="$(python3 "${CONFIG_TOOL}" get buildNumber)"

printf 'CmdTab Phase 2 Developer ID distribution QA\n'
printf 'commit=%s\n' "${COMMIT_SHA}"
printf 'version=%s (%s)\n' "${VERSION}" "${BUILD_NUMBER}"
printf 'macos=%s\n' "$(sw_vers -productVersion)"
printf 'architecture=%s\n' "$(uname -m)"
printf 'swift=%s\n' "$(swift --version | head -n 1)"
printf 'signing-identity=%s\n' "${CMDTAB_DEVELOPER_IDENTITY}"
printf 'team-id=%s\n' "${CMDTAB_TEAM_ID}"
if [[ -n "${CMDTAB_NOTARY_PROFILE:-}" ]]; then
  printf 'notary-authentication=keychain-profile\n'
else
  printf 'notary-authentication=app-store-connect-api-key\n'
fi
date -u '+utc=%Y-%m-%dT%H:%M:%SZ'

printf '\n== Phase 2 source contract ==\n'
python3 "${SOURCE_VERIFY_TOOL}"
python3 "${CONFIG_TOOL}" verify-repository

printf '\n== Credential and signing preflight ==\n'
bash "${ROOT_DIR}/scripts/release/phase2-preflight.sh"

printf '\n== Phase 1 regression gate ==\n'
CMDTAB_PHASE1_EVIDENCE_DIR="${EVIDENCE_DIR}/phase1-regression" \
  bash "${ROOT_DIR}/scripts/release/run-phase1-qa.sh"
[[ "$(cat "${EVIDENCE_DIR}/phase1-regression/result.txt")" == "PASS" ]] || fail "Phase 1 regression gate did not pass"

printf '\n== Deterministic unsigned input bundle ==\n'
CMDTAB_OUTPUT_APP="${UNSIGNED_APP}" \
CMDTAB_RELEASE_SCRATCH="${TEMP_ROOT}/unsigned-package" \
CMDTAB_SKIP_ADHOC_SIGN=1 \
  bash "${ROOT_DIR}/scripts/release/package-app.sh"
bash "${ROOT_DIR}/scripts/release/verify-bundle.sh" "${UNSIGNED_APP}" unsigned

UNSIGNED_MANIFEST="${UNSIGNED_APP%.app}.manifest.json"
UNSIGNED_CHECKSUMS="${UNSIGNED_APP%.app}.sha256"
cp "${UNSIGNED_MANIFEST}" "${EVIDENCE_DIR}/unsigned-bundle-manifest.json"
cp "${UNSIGNED_CHECKSUMS}" "${EVIDENCE_DIR}/unsigned-bundle-checksums.txt"

printf '\n== Developer ID signing ==\n'
CMDTAB_INPUT_SIGNING=unsigned \
  bash "${ROOT_DIR}/scripts/release/sign-app.sh" "${UNSIGNED_APP}" "${SIGNED_APP}"

printf '\n== Pre-notarization archive ==\n'
bash "${ROOT_DIR}/scripts/release/create-zip.sh" "${SIGNED_APP}" "${NOTARY_ZIP}"

printf '\n== Apple notarization ==\n'
bash "${ROOT_DIR}/scripts/release/notarize-app.sh" "${NOTARY_ZIP}" "${NOTARY_EVIDENCE_DIR}"

printf '\n== Ticket stapling ==\n'
bash "${ROOT_DIR}/scripts/release/staple-app.sh" "${SIGNED_APP}"

ARCHITECTURES="$(lipo -archs "${SIGNED_APP}/Contents/MacOS/CmdTab" | tr ' ' '-')"
FINAL_ZIP="${ARTIFACT_DIR}/CmdTab-${VERSION}-${ARCHITECTURES}.zip"

printf '\n== Final stapled distribution archive ==\n'
bash "${ROOT_DIR}/scripts/release/create-zip.sh" "${SIGNED_APP}" "${FINAL_ZIP}"

printf '\n== Independent distribution verification ==\n'
bash "${ROOT_DIR}/scripts/release/verify-distribution.sh" "${SIGNED_APP}" "${FINAL_ZIP}"

printf '\n== Evidence capture ==\n'
SIGNED_MANIFEST="${EVIDENCE_DIR}/signed-bundle-manifest.json"
python3 "${ROOT_DIR}/scripts/release/write-bundle-manifest.py" "${SIGNED_APP}" "${SIGNED_MANIFEST}" >/dev/null
cp "${FINAL_ZIP}.sha256" "${EVIDENCE_DIR}/final-artifact.sha256"
printf '%s\n' "${FINAL_ZIP}" > "${EVIDENCE_DIR}/artifact-path.txt"
printf '%s\n' "${COMMIT_SHA}" > "${EVIDENCE_DIR}/commit.txt"
sw_vers > "${EVIDENCE_DIR}/macos.txt"
swift --version > "${EVIDENCE_DIR}/swift-version.txt"
security find-identity -v -p codesigning > "${EVIDENCE_DIR}/available-code-signing-identities.txt"
codesign -d --verbose=4 "${SIGNED_APP}" > /dev/null 2> "${EVIDENCE_DIR}/codesign-report.txt"
codesign -d --entitlements - "${SIGNED_APP}" > "${EVIDENCE_DIR}/embedded-entitlements.plist" 2> "${EVIDENCE_DIR}/embedded-entitlements.stderr"
xcrun stapler validate -v "${SIGNED_APP}" > "${EVIDENCE_DIR}/stapler-validation.txt" 2>&1
spctl --assess --type execute --verbose=4 "${SIGNED_APP}" > "${EVIDENCE_DIR}/gatekeeper-assessment.txt" 2>&1

SUBMISSION_ID="$(cat "${NOTARY_EVIDENCE_DIR}/submission-id.txt")"
python3 "${DISTRIBUTION_RECORD_TOOL}" \
  --release-config "${ROOT_DIR}/release/ReleaseConfig.json" \
  --source-commit "${COMMIT_SHA}" \
  --unsigned-manifest "${EVIDENCE_DIR}/unsigned-bundle-manifest.json" \
  --signed-manifest "${SIGNED_MANIFEST}" \
  --final-artifact "${FINAL_ZIP}" \
  --notary-result "${NOTARY_EVIDENCE_DIR}/notary-result.json" \
  --notary-log "${NOTARY_EVIDENCE_DIR}/notary-log.json" \
  --submission-id "${SUBMISSION_ID}" \
  --signing-identity "${CMDTAB_DEVELOPER_IDENTITY}" \
  --team-id "${CMDTAB_TEAM_ID}" \
  --output "${EVIDENCE_DIR}/distribution-record.json" >/dev/null

printf '\nPhase 2 automated distribution QA passed.\n'
printf 'Final artifact: %s\n' "${FINAL_ZIP}"
printf 'Evidence: %s\n' "${EVIDENCE_DIR}"
printf 'Manual clean-account acceptance remains required: %s\n' "${MANUAL_PATH}"
