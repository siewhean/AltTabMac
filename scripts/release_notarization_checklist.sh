#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=release_metadata.sh
source "${ROOT_DIR}/scripts/release_metadata.sh"
validate_release_metadata_against_source \
    || { echo "Release metadata must match the tracked Info.plist and canonical tag/filename" >&2; exit 1; }

MODE="preflight"
if [ "${1:-}" = "--post-build" ]; then
    MODE="post-build"
    shift
fi
[ "$#" -eq 0 ] || { echo "Usage: $0 [--post-build]" >&2; exit 2; }

fail() {
    echo "$1" >&2
    exit 1
}

require_tool() {
    command -v "$1" >/dev/null 2>&1 || fail "Missing required tool: $1"
}

if [ "${MODE}" = "post-build" ]; then
    exec "${ROOT_DIR}/scripts/verify_release_artifacts.sh" --release \
        --output-dir "${CMDTAB_RELEASE_DIR:-${ROOT_DIR}/dist}"
fi

DEVELOPER_ID="${CMDTAB_DEVELOPER_ID:-}"
TEAM_ID="${CMDTAB_TEAM_ID:-}"
NOTARY_PROFILE="${CMDTAB_NOTARY_PROFILE:-}"

echo "== ${CMDTAB_APP_NAME} ${CMDTAB_VERSION} (${CMDTAB_BUILD_NUMBER}) release preflight =="
for tool in swift lipo codesign xcrun ditto spctl hdiutil shasum plutil security \
    file find git grep openssl awk; do
    require_tool "${tool}"
done
[ -f "${ROOT_DIR}/Resources/CmdTab.entitlements" ] || fail "Missing release entitlements"
[ -n "${DEVELOPER_ID}" ] || fail "Missing required environment variable: CMDTAB_DEVELOPER_ID"
[ -n "${TEAM_ID}" ] || fail "Missing required environment variable: CMDTAB_TEAM_ID"
[ -n "${NOTARY_PROFILE}" ] || fail "Missing required environment variable: CMDTAB_NOTARY_PROFILE"
case "${DEVELOPER_ID}" in
    "Developer ID Application:"*) ;;
    *) fail "CMDTAB_DEVELOPER_ID must name a Developer ID Application certificate" ;;
esac
CODE_SIGNING_IDENTITIES="$(security find-identity -v -p codesigning)"
IDENTITY_MATCHES="$(printf '%s\n' "${CODE_SIGNING_IDENTITIES}" | grep -F "\"${DEVELOPER_ID}\"" || true)"
IDENTITY_MATCH_COUNT="$(printf '%s\n' "${IDENTITY_MATCHES}" | awk 'NF { count++ } END { print count + 0 }')"
[ "${IDENTITY_MATCH_COUNT}" -eq 1 ] \
    || fail "Expected exactly one Developer ID Application identity named: ${DEVELOPER_ID}"
CERTIFICATE_PEM="$(security find-certificate -c "${DEVELOPER_ID}" -p)" \
    || fail "Unable to read Developer ID Application certificate"
printf '%s\n' "${CERTIFICATE_PEM}" | openssl x509 -checkend 0 -noout \
    || fail "Developer ID Application certificate is expired"
CERTIFICATE_TEAM_ID="$(printf '%s\n' "${CERTIFICATE_PEM}" | \
    openssl x509 -subject -nameopt multiline -noout | \
    awk -F= '/^[[:space:]]*organizationalUnitName[[:space:]]*=/{value=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); print value; exit}')"
[ -n "${CERTIFICATE_TEAM_ID}" ] || fail "Developer ID Application certificate has no organizational unit / TeamIdentifier"
[ "${CERTIFICATE_TEAM_ID}" = "${TEAM_ID}" ] \
    || fail "Developer ID Application certificate TeamIdentifier mismatch: ${CERTIFICATE_TEAM_ID}"
xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null \
    || fail "Notary profile validation failed: ${NOTARY_PROFILE}"

[ -z "$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=all)" ] \
    || fail "Release worktree must be clean"
git -C "${ROOT_DIR}" tag --points-at HEAD | grep -Fxq "${CMDTAB_RELEASE_TAG}" \
    || fail "HEAD must be tagged ${CMDTAB_RELEASE_TAG}"

for script in \
    "${ROOT_DIR}/build.sh" \
    "${ROOT_DIR}/scripts/build_release_dmg.sh" \
    "${ROOT_DIR}/scripts/verify_release_artifacts.sh"; do
    if grep -n -- '--deep' "${script}" >/dev/null; then
        fail "Production signing scripts must not use recursive codesigning: ${script}"
    fi
done

if [ -d "${ROOT_DIR}/${CMDTAB_APP_NAME}.app" ]; then
    "${ROOT_DIR}/scripts/verify_release_artifacts.sh" --local-app
fi

echo "Preflight passed. Run scripts/build_release_dmg.sh to create ${CMDTAB_DMG_BASENAME}."
