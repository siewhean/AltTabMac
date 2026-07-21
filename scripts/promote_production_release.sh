#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
VERCEL_BIN="${CMDTAB_VERCEL_BIN:-vercel}"
CURL_BIN="${CMDTAB_CURL_BIN:-curl}"
# shellcheck source=release_metadata.sh
source "${ROOT_DIR}/scripts/release_metadata.sh"

fail() { echo "$1" >&2; exit 1; }

for variable in VERCEL_TOKEN CMDTAB_VERCEL_PROJECT_ID CMDTAB_VERCEL_ORG_ID \
    CMDTAB_PRODUCTION_HEALTHCHECK_SECRET; do
    [ -n "${!variable:-}" ] || fail "${variable} is required"
done
command -v "${VERCEL_BIN}" >/dev/null 2>&1 || fail "Vercel CLI is unavailable"
command -v "${CURL_BIN}" >/dev/null 2>&1 || fail "curl is unavailable"
validate_release_metadata_against_source || fail "Release metadata is not canonical"
SOURCE_COMMIT="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
[ -z "$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=all)" ] \
    || fail "Production promotion requires a clean source tree"
[ "$(git -C "${ROOT_DIR}" rev-list -n 1 "${CMDTAB_RELEASE_TAG}" 2>/dev/null || true)" = \
    "${SOURCE_COMMIT}" ] || fail "${CMDTAB_RELEASE_TAG} must point to HEAD"

OUTPUT_DIR="${CMDTAB_RELEASE_DIR:-${ROOT_DIR}/dist}"
AGGREGATE_PATH="${CMDTAB_PRODUCTION_EVIDENCE:-${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-production-evidence.json}"
AGGREGATE_CHECKSUM_PATH="${CMDTAB_PRODUCTION_EVIDENCE_CHECKSUM:-${AGGREGATE_PATH}.sha256}"
STAGING_RECEIPT="${CMDTAB_PRODUCTION_STAGING_RECEIPT:-${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-production-staging-deployment.json}"
BLOB_RECEIPT="${CMDTAB_BLOB_RECEIPT:-${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-blob-publication.json}"
for file in "${AGGREGATE_PATH}" "${AGGREGATE_CHECKSUM_PATH}" "${STAGING_RECEIPT}" "${BLOB_RECEIPT}"; do
    [ -s "${file}" ] || fail "Missing public release input: ${file}"
done
(cd "$(dirname "${AGGREGATE_PATH}")" && shasum -a 256 -c "$(basename "${AGGREGATE_CHECKSUM_PATH}")") >/dev/null \
    || fail "Production evidence aggregate checksum verification failed"
AGGREGATE_SHA256="$(shasum -a 256 "${AGGREGATE_PATH}" | awk '{print $1}')"
EXPECTED_COMMIT="${SOURCE_COMMIT}" EXPECTED_TAG="${CMDTAB_RELEASE_TAG}" \
EXPECTED_PROJECT="${CMDTAB_VERCEL_PROJECT_ID}" EXPECTED_AGGREGATE="${AGGREGATE_SHA256}" node -e '
const { createHash } = require("node:crypto");
const { readFileSync } = require("node:fs");
const { basename, dirname, join } = require("node:path");
const aggregate = require(process.argv[1]);
const staging = require(process.argv[2]);
const blob = require(process.argv[3]);
if (aggregate.ok !== true || aggregate.generator !== "scripts/aggregate_release_evidence.sh" ||
    aggregate.releasePhase !== "pre-publication" || aggregate.sourceCommit !== process.env.EXPECTED_COMMIT ||
    aggregate.releaseTag !== process.env.EXPECTED_TAG || staging.sourceCommit !== process.env.EXPECTED_COMMIT ||
    staging.releaseTag !== process.env.EXPECTED_TAG || staging.projectId !== process.env.EXPECTED_PROJECT ||
    staging.environment !== "production" || staging.releasePhase !== "staging" ||
    staging.aliasStatus !== "unaliased" || staging.healthStatus !== "passed" ||
    blob.sourceCommit !== process.env.EXPECTED_COMMIT || blob.releaseTag !== process.env.EXPECTED_TAG ||
    blob.productionEvidenceSha256 !== process.env.EXPECTED_AGGREGATE || !/^https:\/\//.test(blob.url ?? "")) process.exit(1);
for (const entry of aggregate.evidence ?? []) {
  if (basename(entry.file) !== entry.file || !/^[0-9a-f]{64}$/.test(entry.sha256 ?? "")) process.exit(1);
  const actual = createHash("sha256").update(readFileSync(join(dirname(process.argv[1]), entry.file))).digest("hex");
  if (actual !== entry.sha256) process.exit(1);
}
' "${AGGREGATE_PATH}" "${STAGING_RECEIPT}" "${BLOB_RECEIPT}" \
    || fail "Public release inputs are inconsistent"

STAGING_ID="$(node -p 'require(process.argv[1]).deploymentId' "${STAGING_RECEIPT}")"
STAGING_URL="$(node -p 'require(process.argv[1]).deploymentUrl' "${STAGING_RECEIPT}")"
BLOB_URL="$(node -p 'require(process.argv[1]).url' "${BLOB_RECEIPT}")"
CANONICAL_URL="https://cmdtab.net"
CANONICAL_HOST="cmdtab.net"

TMP_DIR="$(mktemp -d /tmp/cmdtab-production-promote.XXXXXX)"
chmod 700 "${TMP_DIR}"
trap 'rm -rf "${TMP_DIR}"' EXIT INT TERM
ALIAS_RESULT="${TMP_DIR}/alias.json"
ALIAS_CONFIG="${TMP_DIR}/alias.curl"
printf 'fail\nsilent\nshow-error\nheader = "Authorization: Bearer %s"\nurl = "https://api.vercel.com/v4/aliases/%s?teamId=%s"\noutput = "%s"\n' \
    "${VERCEL_TOKEN}" "${CANONICAL_HOST}" "${CMDTAB_VERCEL_ORG_ID}" "${ALIAS_RESULT}" >"${ALIAS_CONFIG}"
chmod 600 "${ALIAS_CONFIG}"
"${CURL_BIN}" --config "${ALIAS_CONFIG}"
read -r PREVIOUS_ID PREVIOUS_URL < <(node -e '
const value = require(process.argv[1]);
const id = value.deploymentId ?? value.deployment?.id ?? value.deployment?.uid ?? "";
let url = value.deployment?.url ?? value.deploymentUrl ?? "";
if (url && !url.startsWith("http")) url = `https://${url}`;
if (!id || !url) process.exit(1);
process.stdout.write(`${id} ${url}\n`);
' "${ALIAS_RESULT}") || fail "Unable to resolve the current canonical rollback deployment"
[ "${PREVIOUS_ID}" != "${STAGING_ID}" ] || fail "Staging deployment is already canonical"

ROLLBACK_RECEIPT="${CMDTAB_ROLLBACK_TARGET_RECEIPT:-${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-rollback-target.json}"
ROLLBACK_RECEIPT="${ROLLBACK_RECEIPT}" SOURCE_COMMIT="${SOURCE_COMMIT}" RELEASE_TAG="${CMDTAB_RELEASE_TAG}" \
PREVIOUS_ID="${PREVIOUS_ID}" PREVIOUS_URL="${PREVIOUS_URL}" STAGING_ID="${STAGING_ID}" \
AGGREGATE_SHA256="${AGGREGATE_SHA256}" node <<'NODE'
const { writeFileSync } = require("node:fs");
writeFileSync(process.env.ROLLBACK_RECEIPT, JSON.stringify({
  version: 1, sourceCommit: process.env.SOURCE_COMMIT, releaseTag: process.env.RELEASE_TAG,
  productionEvidenceSha256: process.env.AGGREGATE_SHA256,
  rollbackTarget: { id: process.env.PREVIOUS_ID, url: process.env.PREVIOUS_URL },
  authorizedStagingDeploymentId: process.env.STAGING_ID,
  capturedAt: new Date().toISOString(),
}, null, 2) + "\n", { mode: 0o600 });
NODE
chmod 600 "${ROLLBACK_RECEIPT}"

PROMOTION_ATTEMPTED=false
PROMOTION_SUCCEEDED=false
rollback_on_failure() {
    local status=$?
    trap - EXIT INT TERM
    if [ "${status}" -ne 0 ] && [ "${PROMOTION_ATTEMPTED}" = true ] && \
       [ "${PROMOTION_SUCCEEDED}" != true ]; then
        set +e
        (
            cd "${ROOT_DIR}"
            export VERCEL_PROJECT_ID="${CMDTAB_VERCEL_PROJECT_ID}"
            export VERCEL_ORG_ID="${CMDTAB_VERCEL_ORG_ID}"
            "${VERCEL_BIN}" promote "${PREVIOUS_URL}" --yes --scope "${CMDTAB_VERCEL_ORG_ID}"
        ) >"${TMP_DIR}/rollback.txt" 2>&1
        local rollback_status=$?
        if [ "${rollback_status}" -eq 0 ]; then
            "${CURL_BIN}" --config "${ALIAS_CONFIG}" >/dev/null 2>&1
            rollback_status=$?
        fi
        if [ "${rollback_status}" -eq 0 ]; then
            ROLLBACK_EXPECTED_ID="${PREVIOUS_ID}" node -e '
const value = require(process.argv[1]);
const id = String(value.deploymentId ?? value.deployment?.id ?? value.deployment?.uid ?? "");
if (id !== process.env.ROLLBACK_EXPECTED_ID) process.exit(1);
' "${ALIAS_RESULT}" >/dev/null 2>&1
            rollback_status=$?
        fi
        if [ "${rollback_status}" -eq 0 ]; then
            printf 'fail\nsilent\nshow-error\nheader = "Authorization: Bearer %s"\nurl = "%s/api/health"\noutput = "%s"\n' \
                "${CMDTAB_PRODUCTION_HEALTHCHECK_SECRET}" "${CANONICAL_URL}" \
                "${TMP_DIR}/rollback-health.json" >"${TMP_DIR}/rollback-health.curl"
            "${CURL_BIN}" --config "${TMP_DIR}/rollback-health.curl" >/dev/null 2>&1
            rollback_status=$?
        fi
        if [ "${rollback_status}" -eq 0 ]; then
            node -e '
const result = require(process.argv[1]);
if (result.ok !== true || result.connectivity !== "ok" || result.schema !== "current" || result.staleFulfillment !== false) process.exit(1);
' "${TMP_DIR}/rollback-health.json" >/dev/null 2>&1
            rollback_status=$?
        fi
        set -e
        if [ "${rollback_status}" -eq 0 ]; then
            echo "Promotion failed; restored and health-verified rollback target ${PREVIOUS_ID} (${PREVIOUS_URL})" >&2
        else
            echo "CRITICAL: Promotion failed and automatic rollback failed; use ${ROLLBACK_RECEIPT}" >&2
        fi
    fi
    rm -rf "${TMP_DIR}"
    exit "${status}"
}
trap rollback_on_failure EXIT
trap 'exit 130' INT TERM

PROMOTION_ATTEMPTED=true
(
    cd "${ROOT_DIR}"
    export VERCEL_PROJECT_ID="${CMDTAB_VERCEL_PROJECT_ID}"
    export VERCEL_ORG_ID="${CMDTAB_VERCEL_ORG_ID}"
    "${VERCEL_BIN}" promote "${STAGING_URL}" --yes --scope "${CMDTAB_VERCEL_ORG_ID}" \
        >"${TMP_DIR}/promote.txt"
)

CANONICAL_READY=false
for _ in {1..24}; do
    "${CURL_BIN}" --config "${ALIAS_CONFIG}"
    PROMOTED_CANONICAL_ID="$(node -e '
const value = require(process.argv[1]);
process.stdout.write(String(value.deploymentId ?? value.deployment?.id ?? value.deployment?.uid ?? ""));
' "${ALIAS_RESULT}")"
    if [ "${PROMOTED_CANONICAL_ID}" = "${STAGING_ID}" ]; then
        CANONICAL_READY=true
        break
    fi
    sleep 5
done
[ "${CANONICAL_READY}" = true ] \
    || fail "Canonical alias did not resolve to the authorized staging deployment"

HEALTH_RESULT="${TMP_DIR}/health.json"
HEALTH_CONFIG="${TMP_DIR}/health.curl"
printf 'fail\nsilent\nshow-error\nheader = "Authorization: Bearer %s"\nurl = "%s/api/health"\noutput = "%s"\n' \
    "${CMDTAB_PRODUCTION_HEALTHCHECK_SECRET}" "${CANONICAL_URL}" "${HEALTH_RESULT}" >"${HEALTH_CONFIG}"
chmod 600 "${HEALTH_CONFIG}"
"${CURL_BIN}" --config "${HEALTH_CONFIG}"
node -e '
const result = require(process.argv[1]);
if (result.ok !== true || result.connectivity !== "ok" || result.schema !== "current" ||
    result.staleFulfillment !== false) process.exit(1);
' "${HEALTH_RESULT}" || fail "Canonical Production health failed after promotion"

RECEIPT="${CMDTAB_PUBLIC_RELEASE_RECEIPT:-${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-public-release.json}"
RECEIPT="${RECEIPT}" SOURCE_COMMIT="${SOURCE_COMMIT}" RELEASE_TAG="${CMDTAB_RELEASE_TAG}" \
PROJECT_ID="${CMDTAB_VERCEL_PROJECT_ID}" STAGING_ID="${STAGING_ID}" STAGING_URL="${STAGING_URL}" \
CANONICAL_URL="${CANONICAL_URL}" PREVIOUS_ID="${PREVIOUS_ID}" PREVIOUS_URL="${PREVIOUS_URL}" \
BLOB_URL="${BLOB_URL}" AGGREGATE_SHA256="${AGGREGATE_SHA256}" node <<'NODE'
const { writeFileSync } = require("node:fs");
const evidenceCreatedAt = new Date().toISOString();
writeFileSync(process.env.RECEIPT, JSON.stringify({
  version: 1,
  ok: true,
  sourceCommit: process.env.SOURCE_COMMIT,
  releaseTag: process.env.RELEASE_TAG,
  projectId: process.env.PROJECT_ID,
  productionEvidenceSha256: process.env.AGGREGATE_SHA256,
  blobUrl: process.env.BLOB_URL,
  promotedDeployment: { id: process.env.STAGING_ID, url: process.env.STAGING_URL },
  canonicalUrl: process.env.CANONICAL_URL,
  canonicalHealth: "passed",
  rollbackTarget: { id: process.env.PREVIOUS_ID, url: process.env.PREVIOUS_URL },
  promotedAt: evidenceCreatedAt,
  evidenceCreatedAt,
}, null, 2) + "\n", { mode: 0o600 });
NODE
chmod 600 "${RECEIPT}"
PROMOTION_SUCCEEDED=true
echo "Production release promoted with verified canonical health: ${CANONICAL_URL}"
echo "Rollback target: ${PREVIOUS_ID} ${PREVIOUS_URL}"
echo "Receipt: ${RECEIPT}"
