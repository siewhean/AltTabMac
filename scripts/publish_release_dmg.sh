#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
VERCEL_BIN="${CMDTAB_VERCEL_BIN:-vercel}"
CURL_BIN="${CMDTAB_CURL_BIN:-curl}"
# shellcheck source=release_metadata.sh
source "${ROOT_DIR}/scripts/release_metadata.sh"

fail() {
    echo "$1" >&2
    exit 1
}

[ -n "${BLOB_READ_WRITE_TOKEN:-}" ] || fail "BLOB_READ_WRITE_TOKEN is required"
command -v "${VERCEL_BIN}" >/dev/null 2>&1 || fail "Vercel CLI is unavailable"
command -v "${CURL_BIN}" >/dev/null 2>&1 || fail "curl is unavailable"
validate_release_metadata_against_source \
    || fail "Release metadata must match the tracked Info.plist"

SOURCE_COMMIT="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
[ -z "$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=all)" ] \
    || fail "DMG publishing requires a clean source tree"
[ "$(git -C "${ROOT_DIR}" rev-list -n 1 "${CMDTAB_RELEASE_TAG}" 2>/dev/null || true)" = \
    "${SOURCE_COMMIT}" ] || fail "${CMDTAB_RELEASE_TAG} must point to HEAD"

OUTPUT_DIR="${CMDTAB_RELEASE_DIR:-${ROOT_DIR}/dist}"
DMG_PATH="${OUTPUT_DIR}/${CMDTAB_DMG_BASENAME}"
[ -f "${DMG_PATH}" ] || fail "Missing release DMG: ${DMG_PATH}"
AGGREGATE_PATH="${CMDTAB_PRODUCTION_EVIDENCE:-${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-production-evidence.json}"
AGGREGATE_CHECKSUM_PATH="${CMDTAB_PRODUCTION_EVIDENCE_CHECKSUM:-${AGGREGATE_PATH}.sha256}"
[ -s "${AGGREGATE_PATH}" ] || fail "Missing final production evidence aggregate: ${AGGREGATE_PATH}"
[ -s "${AGGREGATE_CHECKSUM_PATH}" ] || fail "Missing production evidence checksum: ${AGGREGATE_CHECKSUM_PATH}"
(cd "$(dirname "${AGGREGATE_PATH}")" && shasum -a 256 -c "$(basename "${AGGREGATE_CHECKSUM_PATH}")") >/dev/null \
    || fail "Production evidence aggregate checksum verification failed"
EXPECTED_COMMIT="${SOURCE_COMMIT}" EXPECTED_TAG="${CMDTAB_RELEASE_TAG}" \
EXPECTED_APP_RECEIPT="${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-release-receipt.json" \
EXPECTED_SMOKE_RECEIPT="${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-preview-smoke.json" \
EXPECTED_STAGING_RECEIPT="${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-production-staging-deployment.json" node -e '
const { createHash } = require("node:crypto");
const { readFileSync } = require("node:fs");
const { basename, dirname, join } = require("node:path");
const receipt = require(process.argv[1]);
const files = new Set((receipt.evidence ?? []).map((entry) => entry.file));
if (receipt.ok !== true || receipt.generator !== "scripts/aggregate_release_evidence.sh" ||
    receipt.releasePhase !== "pre-publication" || receipt.sourceCommit !== process.env.EXPECTED_COMMIT ||
    receipt.releaseTag !== process.env.EXPECTED_TAG ||
    !files.has(process.env.EXPECTED_APP_RECEIPT) || !files.has(process.env.EXPECTED_SMOKE_RECEIPT) ||
    !files.has(process.env.EXPECTED_STAGING_RECEIPT)) process.exit(1);
for (const entry of receipt.evidence ?? []) {
  if (basename(entry.file) !== entry.file || !/^[0-9a-f]{64}$/.test(entry.sha256 ?? "")) process.exit(1);
  const actual = createHash("sha256").update(readFileSync(join(dirname(process.argv[1]), entry.file))).digest("hex");
  if (actual !== entry.sha256) process.exit(1);
}
' "${AGGREGATE_PATH}" || fail "Production evidence aggregate is incomplete or belongs to another release"
"${CMDTAB_RELEASE_VERIFIER:-${ROOT_DIR}/scripts/verify_release_artifacts.sh}" \
    --release --output-dir "${OUTPUT_DIR}"

TMP_DIR="$(mktemp -d /tmp/cmdtab-blob-publish.XXXXXX)"
chmod 700 "${TMP_DIR}"
cleanup() {
    find "${TMP_DIR}" -type f -exec chmod 600 {} + 2>/dev/null || true
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT INT TERM
UPLOAD_OUTPUT="${TMP_DIR}/upload.txt"
ARTIFACT_SHA256="$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')"

(
    umask 077
    cd "${ROOT_DIR}"
    "${VERCEL_BIN}" blob put "${DMG_PATH}" \
        --access public \
        --pathname "releases/${CMDTAB_VERSION}/${ARTIFACT_SHA256}/${CMDTAB_DMG_BASENAME}" \
        --add-random-suffix false \
        --allow-overwrite false \
        --content-type application/x-apple-diskimage >"${UPLOAD_OUTPUT}"
)
chmod 600 "${UPLOAD_OUTPUT}"
BLOB_URL="$(node -e '
const { readFileSync } = require("node:fs");
const text = readFileSync(process.argv[1], "utf8");
let url = "";
try {
  const value = JSON.parse(text);
  url = value.downloadUrl ?? value.url ?? "";
} catch {
  url = text.match(/https:\/\/[^\s"'\''<>]+/)?.[0] ?? "";
}
if (!/^https:\/\//.test(url)) process.exit(1);
process.stdout.write(url);
' "${UPLOAD_OUTPUT}")" || fail "Vercel Blob did not return a public URL"

AGGREGATE_SHA256="$(shasum -a 256 "${AGGREGATE_PATH}" | awk '{print $1}')"
DOWNLOADED_DMG="${TMP_DIR}/${CMDTAB_DMG_BASENAME}"
"${CURL_BIN}" --fail --silent --show-error --location \
    --retry 5 --retry-all-errors --retry-delay 2 \
    --output "${DOWNLOADED_DMG}" "${BLOB_URL}"
[ "$(shasum -a 256 "${DOWNLOADED_DMG}" | awk '{print $1}')" = "${ARTIFACT_SHA256}" ] \
    || fail "Published Vercel Blob checksum does not match the verified DMG"
RECEIPT_PATH="${CMDTAB_BLOB_RECEIPT:-${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-blob-publication.json}"
RECEIPT_PATH="${RECEIPT_PATH}" SOURCE_COMMIT="${SOURCE_COMMIT}" \
BLOB_URL="${BLOB_URL}" ARTIFACT_SHA256="${ARTIFACT_SHA256}" \
AGGREGATE_SHA256="${AGGREGATE_SHA256}" ARTIFACT="${CMDTAB_DMG_BASENAME}" \
RELEASE_TAG="${CMDTAB_RELEASE_TAG}" node <<'NODE'
const { writeFileSync } = require("node:fs");
const evidenceCreatedAt = new Date().toISOString();
writeFileSync(process.env.RECEIPT_PATH, JSON.stringify({
  version: 1,
  artifact: process.env.ARTIFACT,
  sha256: process.env.ARTIFACT_SHA256,
  sourceCommit: process.env.SOURCE_COMMIT,
  releaseTag: process.env.RELEASE_TAG,
  url: process.env.BLOB_URL,
  productionEvidenceSha256: process.env.AGGREGATE_SHA256,
  publishedAt: evidenceCreatedAt,
  evidenceCreatedAt,
}, null, 2) + "\n", { mode: 0o600 });
NODE
chmod 600 "${RECEIPT_PATH}"
echo "Published verified DMG: ${BLOB_URL}"
echo "Receipt: ${RECEIPT_PATH}"
