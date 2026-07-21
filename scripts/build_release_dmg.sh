#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=release_metadata.sh
source "${ROOT_DIR}/scripts/release_metadata.sh"
validate_release_metadata_against_source \
    || { echo "Release metadata must match the tracked Info.plist and canonical tag/filename" >&2; exit 1; }

APP_BUNDLE="${ROOT_DIR}/${CMDTAB_APP_NAME}.app"
APP_PLIST="${APP_BUNDLE}/Contents/Info.plist"
APP_EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/${CMDTAB_APP_NAME}"
ENTITLEMENTS_PATH="${ROOT_DIR}/Resources/CmdTab.entitlements"
DEVELOPER_ID="${CMDTAB_DEVELOPER_ID:-}"
TEAM_ID="${CMDTAB_TEAM_ID:-}"
NOTARY_PROFILE="${CMDTAB_NOTARY_PROFILE:-}"
OUTPUT_DIR="${CMDTAB_RELEASE_DIR:-${ROOT_DIR}/dist}"
DMG_PATH="${OUTPUT_DIR}/${CMDTAB_DMG_BASENAME}"
RECEIPT_PATH="${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-release-receipt.json"
EVIDENCE_DIR="${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-evidence"
DMG_STAGE_DIR="$(mktemp -d /tmp/cmdtab-dmg-stage.XXXXXX)"
APP_ARCHIVE="${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-notarization.zip"

cleanup() {
    rm -rf "${DMG_STAGE_DIR}" "${APP_ARCHIVE}"
}
trap cleanup EXIT

fail() {
    echo "$1" >&2
    exit 1
}

require_tool() {
    command -v "$1" >/dev/null 2>&1 || fail "Missing required tool: $1"
}

assert_clean_source() {
    [ "$(git -C "${ROOT_DIR}" rev-parse HEAD)" = "${SOURCE_COMMIT}" ] \
        || fail "HEAD changed during release build"
    [ "$(git -C "${ROOT_DIR}" rev-list -n 1 "${CMDTAB_RELEASE_TAG}" 2>/dev/null || true)" = "${SOURCE_COMMIT}" ] \
        || fail "Release tag ${CMDTAB_RELEASE_TAG} moved during the release build"
    [ -z "$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=all)" ] \
        || fail "Release build changed the source worktree"
}

record_command() {
    local name="$1"
    shift
    "$@" >"${EVIDENCE_DIR}/${name}.txt" 2>&1 || {
        cat "${EVIDENCE_DIR}/${name}.txt" >&2
        fail "Verification command failed: ${name}"
    }
    cat "${EVIDENCE_DIR}/${name}.txt"
}

write_evidence_checksums() {
    (
        cd "${EVIDENCE_DIR}"
        find . -type f ! -name evidence.sha256 -print \
            | LC_ALL=C sort \
            | while IFS= read -r evidence_file; do
                shasum -a 256 "${evidence_file}"
            done >evidence.sha256
        shasum -a 256 -c evidence.sha256 >/dev/null
    )
}

sign_nested_code() {
    local code_path
    while IFS= read -r code_path; do
        [ "${code_path}" = "${APP_EXECUTABLE}" ] && continue
        file "${code_path}" | grep -q 'Mach-O' || continue
        codesign --sign "${DEVELOPER_ID}" --force --options runtime --timestamp "${code_path}"
    done < <(find "${APP_BUNDLE}/Contents" -depth -type f -print)

    while IFS= read -r code_path; do
        codesign --sign "${DEVELOPER_ID}" --force --options runtime --timestamp "${code_path}"
    done < <(find "${APP_BUNDLE}/Contents" -depth -type d \( \
        -name '*.framework' -o -name '*.xpc' -o -name '*.appex' -o \
        -name '*.plugin' -o -name '*.app' -o -name '*.bundle' \
    \) -print)
}

submit_for_notarization() {
    local artifact="$1"
    local prefix="$2"
    local raw_path="${EVIDENCE_DIR}/${prefix}-notarization.raw.json"
    local sanitized_path="${EVIDENCE_DIR}/${prefix}-notarization.sanitized.json"
    local status submission_id

    xcrun notarytool submit "${artifact}" \
        --keychain-profile "${NOTARY_PROFILE}" \
        --wait --output-format json >"${raw_path}" \
        || fail "${prefix} notarization submission failed; raw response: ${raw_path}"
    status="$(plutil -extract status raw -o - "${raw_path}")" \
        || fail "${prefix} notarization result is missing status"
    submission_id="$(plutil -extract id raw -o - "${raw_path}")" \
        || fail "${prefix} notarization result is missing submission ID"
    plutil -create xml1 "${sanitized_path}"
    plutil -insert id -string "${submission_id}" "${sanitized_path}"
    plutil -insert status -string "${status}" "${sanitized_path}"
    plutil -convert json "${sanitized_path}"
    [ "${status}" = "Accepted" ] || fail "${prefix} notarization was not accepted: ${status}"
    [ -n "${submission_id}" ] || fail "${prefix} notarization did not return a submission ID"
    printf '%s\n' "${submission_id}"
}

for tool in swift lipo codesign xcrun ditto spctl hdiutil shasum plutil security \
    file find awk git grep openssl cut tr sort; do
    require_tool "${tool}"
done
[ -f "${ENTITLEMENTS_PATH}" ] || fail "Missing release entitlements: ${ENTITLEMENTS_PATH}"
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
SIGNING_IDENTITY_HASH="$(printf '%s\n' "${IDENTITY_MATCHES}" | awk '{print $2}')"

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
CERTIFICATE_FINGERPRINT="$(printf '%s\n' "${CERTIFICATE_PEM}" | openssl x509 -fingerprint -sha256 -noout | cut -d= -f2)"
CERTIFICATE_EXPIRY="$(printf '%s\n' "${CERTIFICATE_PEM}" | openssl x509 -enddate -noout | cut -d= -f2-)"
CERTIFICATE_SHA1="$(printf '%s\n' "${CERTIFICATE_PEM}" | openssl x509 -fingerprint -sha1 -noout | cut -d= -f2 | tr -d ':')"
[ "${CERTIFICATE_SHA1}" = "${SIGNING_IDENTITY_HASH}" ] \
    || fail "Resolved identity does not match the Developer ID certificate"

xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null \
    || fail "Notary profile validation failed: ${NOTARY_PROFILE}"
[ -z "$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=all)" ] \
    || fail "Release worktree must be clean"
SOURCE_COMMIT="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
git -C "${ROOT_DIR}" tag --points-at HEAD | grep -Fxq "${CMDTAB_RELEASE_TAG}" \
    || fail "HEAD must be tagged ${CMDTAB_RELEASE_TAG}"
assert_clean_source

mkdir -p "${OUTPUT_DIR}"
rm -rf "${EVIDENCE_DIR}"
mkdir -p "${EVIDENCE_DIR}"
CERTIFICATE_RECEIPT="${EVIDENCE_DIR}/certificate.json"
plutil -create xml1 "${CERTIFICATE_RECEIPT}"
plutil -insert commonName -string "${DEVELOPER_ID}" "${CERTIFICATE_RECEIPT}"
plutil -insert teamIdentifier -string "${TEAM_ID}" "${CERTIFICATE_RECEIPT}"
plutil -insert sha256Fingerprint -string "${CERTIFICATE_FINGERPRINT}" "${CERTIFICATE_RECEIPT}"
plutil -insert expiresAt -string "${CERTIFICATE_EXPIRY}" "${CERTIFICATE_RECEIPT}"
plutil -convert json "${CERTIFICATE_RECEIPT}"

echo "== Build immutable source ${SOURCE_COMMIT} =="
CMDTAB_APP_BUNDLE="${APP_BUNDLE}" "${ROOT_DIR}/build.sh"
assert_clean_source
"${ROOT_DIR}/scripts/verify_release_artifacts.sh" --local-app --app "${APP_BUNDLE}" \
    >"${EVIDENCE_DIR}/architectures-and-minos.txt" 2>&1
cat "${EVIDENCE_DIR}/architectures-and-minos.txt"

echo "== Leaf-first Developer ID signing =="
DEVELOPER_ID="${SIGNING_IDENTITY_HASH}"
sign_nested_code
codesign --sign "${DEVELOPER_ID}" --force --options runtime --timestamp \
    --entitlements "${ENTITLEMENTS_PATH}" "${APP_BUNDLE}"
record_command app-codesign-verify codesign --verify --strict --verbose=4 "${APP_BUNDLE}"
SIGNED_TEAM_ID="$(codesign -d --verbose=4 "${APP_BUNDLE}" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2}')"
[ "${SIGNED_TEAM_ID}" = "${TEAM_ID}" ] || fail "Signed app TeamIdentifier mismatch: ${SIGNED_TEAM_ID:-missing}"

echo "== App notarization =="
ditto -c -k --keepParent "${APP_BUNDLE}" "${APP_ARCHIVE}"
APP_NOTARY_SUBMISSION_ID="$(submit_for_notarization "${APP_ARCHIVE}" app)"
xcrun stapler staple "${APP_BUNDLE}"
record_command app-stapler-validate xcrun stapler validate "${APP_BUNDLE}"
record_command app-gatekeeper spctl --assess --type execute --verbose=4 "${APP_BUNDLE}"

echo "== DMG creation and notarization =="
mkdir -p "${DMG_STAGE_DIR}/payload"
ditto "${APP_BUNDLE}" "${DMG_STAGE_DIR}/payload/${CMDTAB_APP_NAME}.app"
ln -s /Applications "${DMG_STAGE_DIR}/payload/Applications"
rm -f "${DMG_PATH}" "${DMG_PATH}.sha256"
hdiutil create -volname "${CMDTAB_APP_NAME} ${CMDTAB_VERSION}" \
    -srcfolder "${DMG_STAGE_DIR}/payload" -ov -format UDZO "${DMG_PATH}"
codesign --force --timestamp --sign "${DEVELOPER_ID}" "${DMG_PATH}"
record_command dmg-codesign-verify codesign --verify --strict --verbose=4 "${DMG_PATH}"
DMG_NOTARY_SUBMISSION_ID="$(submit_for_notarization "${DMG_PATH}" dmg)"
xcrun stapler staple "${DMG_PATH}"
record_command dmg-stapler-validate xcrun stapler validate "${DMG_PATH}"
record_command dmg-gatekeeper spctl --assess --type open --context context:primary-signature --verbose=4 "${DMG_PATH}"

DMG_SHA256="$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')"
printf '%s  %s\n' "${DMG_SHA256}" "${CMDTAB_DMG_BASENAME}" >"${DMG_PATH}.sha256"
(cd "${OUTPUT_DIR}" && shasum -a 256 -c "$(basename "${DMG_PATH}.sha256")") \
    >"${EVIDENCE_DIR}/checksum-verify.txt" 2>&1
cat "${EVIDENCE_DIR}/checksum-verify.txt"

ARCHITECTURES="$(lipo -archs "${APP_EXECUTABLE}")"
plutil -create xml1 "${RECEIPT_PATH}"
plutil -insert schemaVersion -integer 2 "${RECEIPT_PATH}"
plutil -insert artifact -string "${CMDTAB_DMG_BASENAME}" "${RECEIPT_PATH}"
plutil -insert version -string "${CMDTAB_VERSION}" "${RECEIPT_PATH}"
plutil -insert build -string "${CMDTAB_BUILD_NUMBER}" "${RECEIPT_PATH}"
plutil -insert bundleIdentifier -string "${CMDTAB_BUNDLE_ID}" "${RECEIPT_PATH}"
plutil -insert minimumMacOSVersion -string "${CMDTAB_MIN_MACOS_VERSION}" "${RECEIPT_PATH}"
plutil -insert sourceCommit -string "${SOURCE_COMMIT}" "${RECEIPT_PATH}"
plutil -insert releaseTag -string "${CMDTAB_RELEASE_TAG}" "${RECEIPT_PATH}"
plutil -insert developerId -string "${CMDTAB_DEVELOPER_ID}" "${RECEIPT_PATH}"
plutil -insert certificateSha256Fingerprint -string "${CERTIFICATE_FINGERPRINT}" "${RECEIPT_PATH}"
plutil -insert certificateExpiresAt -string "${CERTIFICATE_EXPIRY}" "${RECEIPT_PATH}"
plutil -insert teamIdentifier -string "${SIGNED_TEAM_ID}" "${RECEIPT_PATH}"
plutil -insert detectedArchitectures -string "${ARCHITECTURES}" "${RECEIPT_PATH}"
plutil -insert sha256 -string "${DMG_SHA256}" "${RECEIPT_PATH}"
plutil -insert notarizationSubmissionIds -dictionary "${RECEIPT_PATH}"
plutil -insert notarizationSubmissionIds.app -string "${APP_NOTARY_SUBMISSION_ID}" "${RECEIPT_PATH}"
plutil -insert notarizationSubmissionIds.dmg -string "${DMG_NOTARY_SUBMISSION_ID}" "${RECEIPT_PATH}"
plutil -insert notarizationStatus -string Accepted "${RECEIPT_PATH}"
plutil -insert evidenceCreatedAt -string "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "${RECEIPT_PATH}"
plutil -convert json "${RECEIPT_PATH}"

assert_clean_source
write_evidence_checksums
"${ROOT_DIR}/scripts/verify_release_artifacts.sh" --release --output-dir "${OUTPUT_DIR}" \
    >"${EVIDENCE_DIR}/post-build-verification.txt" 2>&1
cat "${EVIDENCE_DIR}/post-build-verification.txt"
write_evidence_checksums
"${ROOT_DIR}/scripts/verify_release_artifacts.sh" --release --output-dir "${OUTPUT_DIR}"
assert_clean_source

echo "Release ready: ${DMG_PATH}"
echo "Release receipt: ${RECEIPT_PATH}"
echo "Release evidence: ${EVIDENCE_DIR}"
