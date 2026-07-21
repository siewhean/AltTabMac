#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=release_metadata.sh
source "${ROOT_DIR}/scripts/release_metadata.sh"

MODE="local"
OUTPUT_DIR="${CMDTAB_RELEASE_DIR:-${ROOT_DIR}/dist}"
APP_BUNDLE="${CMDTAB_APP_BUNDLE:-${ROOT_DIR}/${CMDTAB_APP_NAME}.app}"
DMG_PATH="${OUTPUT_DIR}/${CMDTAB_DMG_BASENAME}"
RECEIPT_PATH="${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-release-receipt.json"
EVIDENCE_DIR="${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-evidence"

usage() {
    echo "Usage: $0 [--local-app|--release] [--app PATH] [--output-dir PATH]" >&2
}

fail() {
    echo "$1" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --local-app) MODE="local" ;;
        --release) MODE="release" ;;
        --app)
            [ "$#" -ge 2 ] || { usage; exit 2; }
            APP_BUNDLE="$2"
            shift
            ;;
        --output-dir)
            [ "$#" -ge 2 ] || { usage; exit 2; }
            OUTPUT_DIR="$2"
            DMG_PATH="${OUTPUT_DIR}/${CMDTAB_DMG_BASENAME}"
            RECEIPT_PATH="${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-release-receipt.json"
            EVIDENCE_DIR="${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-evidence"
            shift
            ;;
        -h|--help) usage; exit 0 ;;
        *) usage; fail "Unknown argument: $1" ;;
    esac
    shift
done

if [ "${MODE}" = "release" ]; then
    validate_release_metadata_against_source \
        || fail "Release metadata must match the tracked Info.plist and canonical tag/filename"
fi

APP_PLIST="${APP_BUNDLE}/Contents/Info.plist"
APP_EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/${CMDTAB_APP_NAME}"

require_tool() {
    command -v "$1" >/dev/null 2>&1 || fail "Missing required tool: $1"
}

expect_plist_value() {
    local key="$1"
    local expected="$2"
    local actual
    actual="$(release_plist_value "${key}" "${APP_PLIST}")"
    [ "${actual}" = "${expected}" ] || fail "${key} mismatch: expected ${expected}, found ${actual}"
}

verify_architectures_and_minos() {
    local architectures sorted architecture minos
    architectures="$(lipo -archs "${APP_EXECUTABLE}")"
    sorted="$(printf '%s\n' "${architectures}" | tr ' ' '\n' | sort | tr '\n' ' ')"
    [ "${sorted}" = "arm64 x86_64 " ] || fail "Expected exactly arm64+x86_64, found: ${architectures}"

    for architecture in arm64 x86_64; do
        minos="$(xcrun vtool -show-build -arch "${architecture}" "${APP_EXECUTABLE}" \
            | awk '$1 == "minos" { print $2; exit }')"
        [ -n "${minos}" ] || fail "Missing LC_BUILD_VERSION minos for ${architecture}"
        [ "${minos}" = "${CMDTAB_MIN_MACOS_VERSION}" ] \
            || fail "${architecture} minos mismatch: expected ${CMDTAB_MIN_MACOS_VERSION}, found ${minos}"
        echo "${architecture} minos: ${minos}"
    done
}

verify_nested_code() {
    local code_path
    while IFS= read -r code_path; do
        file "${code_path}" | grep -q 'Mach-O' || continue
        codesign --verify --strict --verbose=2 "${code_path}"
    done < <(find "${APP_BUNDLE}/Contents" -depth -type f -print)

    while IFS= read -r code_path; do
        codesign --verify --strict --verbose=2 "${code_path}"
    done < <(find "${APP_BUNDLE}/Contents" -depth -type d \( \
        -name '*.framework' -o -name '*.xpc' -o -name '*.appex' -o \
        -name '*.plugin' -o -name '*.app' -o -name '*.bundle' \
    \) -print)
}

certificate_fingerprint() {
    local signed_path="$1"
    local certificate_dir certificate_path fingerprint
    certificate_dir="$(mktemp -d /tmp/cmdtab-certificates.XXXXXX)"
    (
        cd "${certificate_dir}"
        codesign -d --extract-certificates "${signed_path}" >/dev/null 2>&1
    ) || { rm -rf "${certificate_dir}"; fail "Unable to extract signing certificate from ${signed_path}"; }
    certificate_path="${certificate_dir}/codesign0"
    [ -s "${certificate_path}" ] \
        || { rm -rf "${certificate_dir}"; fail "Missing leaf signing certificate for ${signed_path}"; }
    fingerprint="$(openssl x509 -inform DER -in "${certificate_path}" -fingerprint -sha256 -noout | cut -d= -f2)"
    rm -rf "${certificate_dir}"
    printf '%s\n' "${fingerprint}"
}

for tool in plutil lipo codesign xcrun awk sort tr file find; do
    require_tool "${tool}"
done
[ -d "${APP_BUNDLE}" ] || fail "Missing app bundle: ${APP_BUNDLE}"
[ -f "${APP_EXECUTABLE}" ] || fail "Missing app executable: ${APP_EXECUTABLE}"
expect_plist_value CFBundleName "${CMDTAB_APP_NAME}"
expect_plist_value CFBundleExecutable "${CMDTAB_APP_NAME}"
expect_plist_value CFBundleIdentifier "${CMDTAB_BUNDLE_ID}"
expect_plist_value CFBundleShortVersionString "${CMDTAB_VERSION}"
expect_plist_value CFBundleVersion "${CMDTAB_BUILD_NUMBER}"
expect_plist_value LSMinimumSystemVersion "${CMDTAB_MIN_MACOS_VERSION}"
verify_architectures_and_minos
codesign --verify --strict --verbose=2 "${APP_BUNDLE}"
verify_nested_code

if [ "${MODE}" = "local" ]; then
    echo "Local app verification passed: ${APP_BUNDLE}"
    exit 0
fi

for tool in shasum spctl git basename hdiutil mktemp openssl cut readlink; do
    require_tool "${tool}"
done
[ -f "${DMG_PATH}" ] || fail "Missing release DMG: ${DMG_PATH}"
[ -f "${DMG_PATH}.sha256" ] || fail "Missing checksum file: ${DMG_PATH}.sha256"
[ -f "${RECEIPT_PATH}" ] || fail "Missing release receipt: ${RECEIPT_PATH}"
[ -d "${EVIDENCE_DIR}" ] || fail "Missing release evidence directory: ${EVIDENCE_DIR}"
[ -s "${EVIDENCE_DIR}/evidence.sha256" ] || fail "Missing evidence checksum manifest"

(cd "${OUTPUT_DIR}" && shasum -a 256 -c "$(basename "${DMG_PATH}.sha256")")
(cd "${EVIDENCE_DIR}" && shasum -a 256 -c evidence.sha256)
expect_receipt() {
    local key="$1"
    local expected="$2"
    local actual
    actual="$(plutil -extract "${key}" raw -o - "${RECEIPT_PATH}")"
    [ "${actual}" = "${expected}" ] || fail "Receipt ${key} mismatch: expected ${expected}, found ${actual}"
}

expect_receipt artifact "${CMDTAB_DMG_BASENAME}"
expect_receipt version "${CMDTAB_VERSION}"
expect_receipt build "${CMDTAB_BUILD_NUMBER}"
expect_receipt bundleIdentifier "${CMDTAB_BUNDLE_ID}"
expect_receipt minimumMacOSVersion "${CMDTAB_MIN_MACOS_VERSION}"
expect_receipt releaseTag "${CMDTAB_RELEASE_TAG}"
expect_receipt sourceCommit "$(git -C "${ROOT_DIR}" rev-parse HEAD)"
[ "$(git -C "${ROOT_DIR}" rev-list -n 1 "${CMDTAB_RELEASE_TAG}" 2>/dev/null || true)" = \
    "$(git -C "${ROOT_DIR}" rev-parse HEAD)" ] \
    || fail "Release tag ${CMDTAB_RELEASE_TAG} does not point to the verified source commit"
expect_receipt sha256 "$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')"
expect_receipt notarizationStatus Accepted

CERTIFICATE_RECEIPT="${EVIDENCE_DIR}/certificate.json"
expect_receipt developerId "$(plutil -extract commonName raw -o - "${CERTIFICATE_RECEIPT}")"
expect_receipt teamIdentifier "$(plutil -extract teamIdentifier raw -o - "${CERTIFICATE_RECEIPT}")"
expect_receipt certificateSha256Fingerprint "$(plutil -extract sha256Fingerprint raw -o - "${CERTIFICATE_RECEIPT}")"
expect_receipt certificateExpiresAt "$(plutil -extract expiresAt raw -o - "${CERTIFICATE_RECEIPT}")"
SIGNED_TEAM_ID="$(codesign -d --verbose=4 "${APP_BUNDLE}" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2; exit}')"
SIGNED_AUTHORITY="$(codesign -d --verbose=4 "${APP_BUNDLE}" 2>&1 | awk -F= '/^Authority=Developer ID Application:/{print $2; exit}')"
expect_receipt teamIdentifier "${SIGNED_TEAM_ID}"
expect_receipt developerId "${SIGNED_AUTHORITY}"
expect_receipt certificateSha256Fingerprint "$(certificate_fingerprint "${APP_BUNDLE}")"

RECEIPT_ARCHITECTURES="$(plutil -extract detectedArchitectures raw -o - "${RECEIPT_PATH}")"
[ "$(printf '%s\n' "${RECEIPT_ARCHITECTURES}" | tr ' ' '\n' | sort | tr '\n' ' ')" = "arm64 x86_64 " ] \
    || fail "Receipt architectures are not exactly arm64+x86_64: ${RECEIPT_ARCHITECTURES}"
for prefix in app dmg; do
    SANITIZED_NOTARY="${EVIDENCE_DIR}/${prefix}-notarization.sanitized.json"
    RAW_NOTARY="${EVIDENCE_DIR}/${prefix}-notarization.raw.json"
    [ "$(plutil -extract status raw -o - "${SANITIZED_NOTARY}")" = "Accepted" ] \
        || fail "${prefix} sanitized notarization status is not Accepted"
    [ "$(plutil -extract status raw -o - "${RAW_NOTARY}")" = "Accepted" ] \
        || fail "${prefix} raw notarization status is not Accepted"
    [ "$(plutil -extract id raw -o - "${SANITIZED_NOTARY}")" = \
        "$(plutil -extract "notarizationSubmissionIds.${prefix}" raw -o - "${RECEIPT_PATH}")" ] \
        || fail "${prefix} notarization submission ID does not match the receipt"
    [ "$(plutil -extract id raw -o - "${RAW_NOTARY}")" = \
        "$(plutil -extract "notarizationSubmissionIds.${prefix}" raw -o - "${RECEIPT_PATH}")" ] \
        || fail "${prefix} raw notarization submission ID does not match the receipt"
done

for evidence_file in \
    certificate.json \
    app-notarization.raw.json \
    app-notarization.sanitized.json \
    dmg-notarization.raw.json \
    dmg-notarization.sanitized.json \
    app-codesign-verify.txt \
    app-stapler-validate.txt \
    app-gatekeeper.txt \
    dmg-codesign-verify.txt \
    dmg-stapler-validate.txt \
    dmg-gatekeeper.txt \
    architectures-and-minos.txt \
    checksum-verify.txt; do
    [ -s "${EVIDENCE_DIR}/${evidence_file}" ] || fail "Missing release evidence: ${evidence_file}"
done

xcrun stapler validate "${APP_BUNDLE}"
xcrun stapler validate "${DMG_PATH}"
spctl --assess --type execute --verbose=4 "${APP_BUNDLE}"
spctl --assess --type open --context context:primary-signature --verbose=4 "${DMG_PATH}"

DMG_TEAM_ID="$(codesign -d --verbose=4 "${DMG_PATH}" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2; exit}')"
[ "${DMG_TEAM_ID}" = "${SIGNED_TEAM_ID}" ] || fail "DMG and app TeamIdentifier values differ"
[ "$(certificate_fingerprint "${DMG_PATH}")" = "$(certificate_fingerprint "${APP_BUNDLE}")" ] \
    || fail "DMG and app signing certificate fingerprints differ"

MOUNT_DIR="$(mktemp -d /tmp/cmdtab-release-mount.XXXXXX)"
cleanup_mount() {
    hdiutil detach "${MOUNT_DIR}" -quiet >/dev/null 2>&1 || true
    rm -rf "${MOUNT_DIR}"
}
trap cleanup_mount EXIT
hdiutil attach "${DMG_PATH}" -readonly -nobrowse -mountpoint "${MOUNT_DIR}" >/dev/null
EMBEDDED_APP="${MOUNT_DIR}/${CMDTAB_APP_NAME}.app"
[ -d "${EMBEDDED_APP}" ] || fail "DMG does not contain ${CMDTAB_APP_NAME}.app"
[ -L "${MOUNT_DIR}/Applications" ] || fail "DMG does not contain the Applications symlink"
[ "$(readlink "${MOUNT_DIR}/Applications")" = "/Applications" ] \
    || fail "DMG Applications symlink has the wrong destination"
CMDTAB_APP_BUNDLE="${EMBEDDED_APP}" "${ROOT_DIR}/scripts/verify_release_artifacts.sh" \
    --local-app --app "${EMBEDDED_APP}"
xcrun stapler validate "${EMBEDDED_APP}"
cleanup_mount
trap - EXIT
echo "Release verification passed: ${DMG_PATH}"
