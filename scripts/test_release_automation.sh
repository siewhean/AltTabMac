#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_DIR="$(mktemp -d /tmp/cmdtab-release-tests.XXXXXX)"
trap 'rm -rf "${TMP_DIR}"' EXIT

fail() {
    echo "$1" >&2
    exit 1
}

for script in \
    "${ROOT_DIR}/build.sh" \
    "${ROOT_DIR}/scripts/release_metadata.sh" \
    "${ROOT_DIR}/scripts/build_release_dmg.sh" \
    "${ROOT_DIR}/scripts/release_notarization_checklist.sh" \
    "${ROOT_DIR}/scripts/verify_release_artifacts.sh"; do
    bash -n "${script}"
done

if grep -n -- '--deep' \
    "${ROOT_DIR}/build.sh" \
    "${ROOT_DIR}/scripts/build_release_dmg.sh" \
    "${ROOT_DIR}/scripts/verify_release_artifacts.sh" >/dev/null; then
    fail "Release automation must not use recursive codesigning"
fi

if grep -n '^ICON_ICNS=.*Resources/' "${ROOT_DIR}/build.sh" >/dev/null; then
    fail "Generated icons must not be written into tracked Resources"
fi

METADATA="$({
    ROOT_DIR="${ROOT_DIR}"
    # shellcheck source=release_metadata.sh
    source "${ROOT_DIR}/scripts/release_metadata.sh"
    printf '%s|%s|%s|%s|%s\n' \
        "${CMDTAB_VERSION}" "${CMDTAB_BUILD_NUMBER}" "${CMDTAB_BUNDLE_ID}" \
        "${CMDTAB_RELEASE_TAG}" "${CMDTAB_DMG_BASENAME}"
})"
EXPECTED_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "${ROOT_DIR}/Resources/Info.plist")"
EXPECTED_BUILD="$(plutil -extract CFBundleVersion raw -o - "${ROOT_DIR}/Resources/Info.plist")"
EXPECTED_BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw -o - "${ROOT_DIR}/Resources/Info.plist")"
EXPECTED_APP_NAME="$(plutil -extract CFBundleName raw -o - "${ROOT_DIR}/Resources/Info.plist")"
EXPECTED_METADATA="${EXPECTED_VERSION}|${EXPECTED_BUILD}|${EXPECTED_BUNDLE_ID}|v${EXPECTED_VERSION}|${EXPECTED_APP_NAME}-${EXPECTED_VERSION}-universal.dmg"
[ "${METADATA}" = "${EXPECTED_METADATA}" ] \
    || fail "Environment metadata overrides are not canonical: ${METADATA}"

if ROOT_DIR="${ROOT_DIR}" CMDTAB_VERSION="9.8.7" bash -c \
    'source "$ROOT_DIR/scripts/release_metadata.sh"; validate_release_metadata_against_source'; then
    fail "Production metadata validation must reject values outside the tagged source plist"
fi

grep -Fq 'assert_clean_source' "${ROOT_DIR}/scripts/build_release_dmg.sh" \
    || fail "Release build must reassert immutable source state"
grep -Fq 'certificateSha256Fingerprint' "${ROOT_DIR}/scripts/build_release_dmg.sh" \
    || fail "Release receipt must record certificate fingerprint"
grep -Fq 'certificateExpiresAt' "${ROOT_DIR}/scripts/build_release_dmg.sh" \
    || fail "Release receipt must record certificate expiry"
for script in \
    "${ROOT_DIR}/scripts/build_release_dmg.sh" \
    "${ROOT_DIR}/scripts/release_notarization_checklist.sh"; do
    grep -Fq 'organizationalUnitName' "${script}" \
        || fail "Release signing must validate the certificate TeamIdentifier cryptographically"
    if grep -Fq 'does not contain CMDTAB_TEAM_ID' "${script}"; then
        fail "Release signing must not infer TeamIdentifier from the certificate display name"
    fi
done
grep -Fq 'app-notarization.raw.json' "${ROOT_DIR}/scripts/verify_release_artifacts.sh" \
    || fail "Post-build verification must require raw notarization evidence"
grep -Fq 'hdiutil attach' "${ROOT_DIR}/scripts/verify_release_artifacts.sh" \
    || fail "Post-build verification must inspect the app embedded in the DMG"
grep -Fq -- "-name '*.bundle'" "${ROOT_DIR}/scripts/build_release_dmg.sh" \
    || fail "Leaf-first signing must include nested bundle containers"

if CMDTAB_BUILD_SCRATCH=/ "${ROOT_DIR}/build.sh" >"${TMP_DIR}/unsafe-scratch.log" 2>&1; then
    fail "Build must reject an unsafe scratch directory"
fi
if CMDTAB_APP_BUNDLE=/ "${ROOT_DIR}/build.sh" >"${TMP_DIR}/unsafe-app.log" 2>&1; then
    fail "Build must reject an unsafe app output directory"
fi
if CMDTAB_BUILD_SCRATCH=/tmp/../ "${ROOT_DIR}/build.sh" >"${TMP_DIR}/traversal-scratch.log" 2>&1; then
    fail "Build must reject a scratch path that traverses outside /tmp"
fi
grep -Fq 'must not end in a traversal component' "${TMP_DIR}/traversal-scratch.log" \
    || fail "Traversal scratch path was not rejected before deletion"
if CMDTAB_APP_BUNDLE=/tmp/../../Users/Shared/CmdTab.app \
    "${ROOT_DIR}/build.sh" >"${TMP_DIR}/traversal-app.log" 2>&1; then
    fail "Build must reject an app path that traverses outside /tmp"
fi

TRUSTED_SHA="0123456789abcdef0123456789abcdef01234567"
cat >"${TMP_DIR}/trusted-run.json" <<JSON
{"path":".github/workflows/cmdtab-prepublication-evidence.yml","status":"completed","conclusion":"success","head_sha":"${TRUSTED_SHA}","event":"workflow_dispatch"}
JSON
"${ROOT_DIR}/scripts/verify_workflow_run_provenance.mjs" \
    "${TMP_DIR}/trusted-run.json" ".github/workflows/cmdtab-prepublication-evidence.yml" "${TRUSTED_SHA}"

cat >"${TMP_DIR}/substituted-run.json" <<JSON
{"path":".github/workflows/security.yml","status":"completed","conclusion":"success","head_sha":"${TRUSTED_SHA}","event":"workflow_dispatch"}
JSON
if "${ROOT_DIR}/scripts/verify_workflow_run_provenance.mjs" \
    "${TMP_DIR}/substituted-run.json" ".github/workflows/cmdtab-prepublication-evidence.yml" "${TRUSTED_SHA}" \
    >"${TMP_DIR}/substituted-run.log" 2>&1; then
    fail "Workflow provenance must reject a same-repository artifact from the wrong producer"
fi
grep -Fq 'workflow path' "${TMP_DIR}/substituted-run.log" \
    || fail "Wrong-workflow substitution did not fail for the expected reason"

echo "Release automation regression checks passed"
