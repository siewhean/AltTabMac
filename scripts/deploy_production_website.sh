#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
WEBSITE_DIR="${ROOT_DIR}/website"
VERCEL_BIN="${CMDTAB_VERCEL_BIN:-vercel}"
CURL_BIN="${CMDTAB_CURL_BIN:-curl}"
DEPLOYMENT_ENVIRONMENT="production"
# shellcheck source=release_metadata.sh
source "${ROOT_DIR}/scripts/release_metadata.sh"

fail() {
    echo "$1" >&2
    exit 1
}

usage() {
    echo "Usage: $0 [--preview]" >&2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --preview) DEPLOYMENT_ENVIRONMENT="preview" ;;
        -h|--help) usage; exit 0 ;;
        *) usage; fail "Unknown argument: $1" ;;
    esac
    shift
done

for variable in VERCEL_TOKEN CMDTAB_VERCEL_PROJECT_ID CMDTAB_VERCEL_ORG_ID; do
    [ -n "${!variable:-}" ] || fail "${variable} is required"
done
command -v "${VERCEL_BIN}" >/dev/null 2>&1 || fail "Vercel CLI is unavailable"
command -v "${CURL_BIN}" >/dev/null 2>&1 || fail "curl is unavailable"
validate_release_metadata_against_source \
    || fail "Release metadata must match the tracked Info.plist"

SOURCE_COMMIT="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
[ -z "$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=all)" ] \
    || fail "Production deployment requires a clean source tree"
[ "$(git -C "${ROOT_DIR}" rev-list -n 1 "${CMDTAB_RELEASE_TAG}" 2>/dev/null || true)" = \
    "${SOURCE_COMMIT}" ] || fail "${CMDTAB_RELEASE_TAG} must point to HEAD"

if [ "${DEPLOYMENT_ENVIRONMENT}" = production ]; then
    [ -n "${CMDTAB_PRODUCTION_HEALTHCHECK_SECRET:-}" ] \
        || fail "CMDTAB_PRODUCTION_HEALTHCHECK_SECRET is required before Production promotion"
    [ -n "${CMDTAB_PRODUCTION_PROTECTION_BYPASS_SECRET:-}" ] \
        || fail "CMDTAB_PRODUCTION_PROTECTION_BYPASS_SECRET is required for private staging validation"
    CMDTAB_ENVIRONMENT_RECEIPT="${CMDTAB_ENVIRONMENT_RECEIPT:-${ROOT_DIR}/dist/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-environment-validation.json}" \
    CMDTAB_VALIDATED_RELEASE_TAG="${CMDTAB_RELEASE_TAG}" \
        "${ROOT_DIR}/scripts/validate_production_environment.sh" --require-waf-enforcement
else
    [ -n "${CMDTAB_PREVIEW_HEALTHCHECK_SECRET:-}" ] \
        || fail "CMDTAB_PREVIEW_HEALTHCHECK_SECRET is required for Preview smoke validation"
    "${ROOT_DIR}/scripts/validate_production_environment.sh"
fi

TMP_DIR="$(mktemp -d /tmp/cmdtab-vercel-deploy.XXXXXX)"
chmod 700 "${TMP_DIR}"
cleanup() {
    find "${TMP_DIR}" -type f -exec chmod 600 {} + 2>/dev/null || true
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT INT TERM
DEPLOY_RESULT="${TMP_DIR}/deploy.json"
INSPECT_RESULT="${TMP_DIR}/inspect.json"
POLL_ATTEMPTS="${CMDTAB_DEPLOY_POLL_ATTEMPTS:-60}"
POLL_DELAY_SECONDS="${CMDTAB_DEPLOY_POLL_DELAY_SECONDS:-5}"
case "${POLL_ATTEMPTS}:${POLL_DELAY_SECONDS}" in
    *[!0-9:]*|0:*|*:0) fail "Deployment polling values must be positive integers" ;;
esac

DEPLOY_TARGET_ARGUMENTS=(--target=preview)
if [ "${DEPLOYMENT_ENVIRONMENT}" = production ]; then
    DEPLOY_TARGET_ARGUMENTS=(--prod)
fi
(
    umask 077
    cd "${ROOT_DIR}"
    export VERCEL_PROJECT_ID="${CMDTAB_VERCEL_PROJECT_ID}"
    export VERCEL_ORG_ID="${CMDTAB_VERCEL_ORG_ID}"
    "${VERCEL_BIN}" deploy . "${DEPLOY_TARGET_ARGUMENTS[@]}" \
        --skip-domain --yes --archive=tgz --format=json \
        --project "${CMDTAB_VERCEL_PROJECT_ID}" \
        --scope "${CMDTAB_VERCEL_ORG_ID}" \
        --meta "cmdtabSourceCommit=${SOURCE_COMMIT}" \
        --meta "cmdtabReleaseTag=${CMDTAB_RELEASE_TAG}" \
        --meta "cmdtabDeploymentEnvironment=${DEPLOYMENT_ENVIRONMENT}" >"${DEPLOY_RESULT}"
)
chmod 600 "${DEPLOY_RESULT}"

DEPLOYMENT_ID="$(node -e '
const value = require(process.argv[1]);
process.stdout.write(String(value.id ?? ""));
' "${DEPLOY_RESULT}")"
DEPLOYMENT_URL="$(node -e '
const value = require(process.argv[1]);
const raw = String(value.url ?? "");
process.stdout.write(raw.startsWith("http") ? raw : (raw ? `https://${raw}` : ""));
' "${DEPLOY_RESULT}")"
[ -n "${DEPLOYMENT_ID}" ] || fail "Vercel deployment did not return an ID"
[ -n "${DEPLOYMENT_URL}" ] || fail "Vercel deployment did not return a URL"

CURL_CONFIG="${TMP_DIR}/curl.config"
write_curl_config() {
    (
        umask 077
        printf 'fail\nsilent\nshow-error\nheader = "Authorization: Bearer %s"\nurl = "https://api.vercel.com/v13/deployments/%s?teamId=%s"\noutput = "%s"\n' \
            "${VERCEL_TOKEN}" "${DEPLOYMENT_ID}" "${CMDTAB_VERCEL_ORG_ID}" "${INSPECT_RESULT}" \
            >"${CURL_CONFIG}"
    )
}
write_curl_config

deployment_state() {
    EXPECTED_COMMIT="${SOURCE_COMMIT}" EXPECTED_TAG="${CMDTAB_RELEASE_TAG}" \
    EXPECTED_PROJECT="${CMDTAB_VERCEL_PROJECT_ID}" \
EXPECTED_ENVIRONMENT="${DEPLOYMENT_ENVIRONMENT}" node -e '
const value = require(process.argv[1]);
const failures = [];
if (value.projectId !== process.env.EXPECTED_PROJECT) failures.push("project ID");
if (value.meta?.cmdtabSourceCommit !== process.env.EXPECTED_COMMIT) failures.push("source commit");
if (value.meta?.cmdtabReleaseTag !== process.env.EXPECTED_TAG) failures.push("release tag");
if (value.meta?.cmdtabDeploymentEnvironment !== process.env.EXPECTED_ENVIRONMENT) failures.push("deployment environment");
if (failures.length) {
  console.error(`Deployment metadata mismatch: ${failures.join(", ")}`);
  process.exit(1);
}
if (process.env.EXPECTED_ENVIRONMENT === "production" &&
    (!Array.isArray(value.alias) || value.alias.length !== 0 || value.aliasAssigned === true)) {
  console.error("Production staging deployment is not verified as unaliased");
  process.exit(1);
}
if (["ERROR", "CANCELED"].includes(value.readyState)) process.exit(2);
process.stdout.write(String(value.readyState ?? "UNKNOWN"));
' "${INSPECT_RESULT}"
}

READY=false
for ((attempt = 1; attempt <= POLL_ATTEMPTS; attempt++)); do
    "${CURL_BIN}" --config "${CURL_CONFIG}"
    chmod 600 "${INSPECT_RESULT}"
    set +e
    STATE="$(deployment_state)"
    STATE_STATUS=$?
    set -e
    [ "${STATE_STATUS}" -ne 1 ] || fail "Deployment source metadata validation failed"
    [ "${STATE_STATUS}" -ne 2 ] || fail "Vercel deployment entered terminal state ${STATE}"
    if [ "${STATE}" = READY ]; then
        READY=true
        break
    fi
    [ "${attempt}" -eq "${POLL_ATTEMPTS}" ] || sleep "${POLL_DELAY_SECONDS}"
done
[ "${READY}" = true ] || fail "Vercel deployment did not become READY before timeout"

ACCESS_CONTROL_VERIFIED=false
if [ "${DEPLOYMENT_ENVIRONMENT}" = production ]; then
    UNAUTHORIZED_CONFIG="${TMP_DIR}/unauthorized-staging.curl"
    printf 'silent\nshow-error\nurl = "%s/api/health"\noutput = "%s"\ndump-header = "%s"\nwrite-out = "%%{http_code}"\n' \
        "${DEPLOYMENT_URL}" "${TMP_DIR}/unauthorized-staging.body" \
        "${TMP_DIR}/unauthorized-staging.headers" >"${UNAUTHORIZED_CONFIG}"
    UNAUTHORIZED_STATUS="$("${CURL_BIN}" --config "${UNAUTHORIZED_CONFIG}")" \
        || fail "Unable to verify private Production staging access control"
    [ "${UNAUTHORIZED_STATUS}" = 302 ] \
        || fail "Production staging did not require Vercel Deployment Protection (${UNAUTHORIZED_STATUS})"
    rg -qi '^location: .*(_vercel|vercel\.com)' "${TMP_DIR}/unauthorized-staging.headers" \
        || fail "Production staging redirect is not Vercel Deployment Protection"
    ACCESS_CONTROL_VERIFIED=true
fi

HEALTH_STATUS="not-applicable"
HEALTHCHECK_SECRET="${CMDTAB_PREVIEW_HEALTHCHECK_SECRET:-}"
if [ "${DEPLOYMENT_ENVIRONMENT}" = production ]; then
    HEALTHCHECK_SECRET="${CMDTAB_PRODUCTION_HEALTHCHECK_SECRET}"
fi
if [ -n "${HEALTHCHECK_SECRET}" ]; then
    HEALTH_RESULT="${TMP_DIR}/health.json"
    HEALTH_CURL_CONFIG="${TMP_DIR}/health-curl.config"
    (
        umask 077
        {
            printf 'fail\nsilent\nshow-error\nheader = "Authorization: Bearer %s"\n' \
                "${HEALTHCHECK_SECRET}"
            if [ "${DEPLOYMENT_ENVIRONMENT}" = preview ] && \
               [ -n "${CMDTAB_PREVIEW_PROTECTION_BYPASS_SECRET:-}" ]; then
                printf 'header = "x-vercel-protection-bypass: %s"\n' \
                    "${CMDTAB_PREVIEW_PROTECTION_BYPASS_SECRET}"
            fi
            if [ "${DEPLOYMENT_ENVIRONMENT}" = production ]; then
                printf 'header = "x-vercel-protection-bypass: %s"\n' \
                    "${CMDTAB_PRODUCTION_PROTECTION_BYPASS_SECRET}"
            fi
            printf 'url = "%s/api/health"\noutput = "%s"\n' \
                "${DEPLOYMENT_URL}" "${HEALTH_RESULT}"
        } >"${HEALTH_CURL_CONFIG}"
    )
    "${CURL_BIN}" --config "${HEALTH_CURL_CONFIG}"
    chmod 600 "${HEALTH_RESULT}"
    node -e '
const result = require(process.argv[1]);
if (result.ok !== true || result.connectivity !== "ok" ||
    result.schema !== "current" || result.staleFulfillment !== false) {
  console.error("Preview health, migration drift, or fulfillment-delay check failed");
  process.exit(1);
}
' "${HEALTH_RESULT}"
    HEALTH_STATUS="passed"
fi
if [ "${DEPLOYMENT_ENVIRONMENT}" = production ]; then
    PREVIEW_RECEIPT="${CMDTAB_PREVIEW_DEPLOY_RECEIPT:-${ROOT_DIR}/dist/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-preview-deployment.json}"
    PREVIEW_SMOKE_RECEIPT="${CMDTAB_PREVIEW_SMOKE_RECEIPT:-${ROOT_DIR}/dist/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-preview-smoke.json}"
    [ -f "${PREVIEW_RECEIPT}" ] || fail "Missing same-release Preview evidence: ${PREVIEW_RECEIPT}"
    [ -f "${PREVIEW_SMOKE_RECEIPT}" ] || fail "Missing live Preview smoke evidence: ${PREVIEW_SMOKE_RECEIPT}"
    EXPECTED_COMMIT="${SOURCE_COMMIT}" EXPECTED_TAG="${CMDTAB_RELEASE_TAG}" \
    EXPECTED_PROJECT="${CMDTAB_VERCEL_PROJECT_ID}" PREVIEW_RECEIPT="${PREVIEW_RECEIPT}" node -e '
const receipt = require(process.argv[1]);
const smoke = require(process.argv[2]);
if (receipt.projectId !== process.env.EXPECTED_PROJECT ||
    receipt.sourceCommit !== process.env.EXPECTED_COMMIT ||
    receipt.releaseTag !== process.env.EXPECTED_TAG ||
    receipt.environment !== "preview" || receipt.healthStatus !== "passed") {
  console.error("Preview evidence does not match the tagged Production source");
  process.exit(1);
}
if (smoke.generator !== "scripts/run_preview_smoke.sh" || smoke.ok !== true ||
    smoke.nonDestructive !== true || smoke.sourceCommit !== process.env.EXPECTED_COMMIT ||
    smoke.releaseTag !== process.env.EXPECTED_TAG || smoke.deploymentId !== receipt.deploymentId ||
    Object.values(smoke.checks ?? {}).some((check) => check?.passed !== true)) {
  console.error("Preview smoke evidence does not match the validated Preview deployment");
  process.exit(1);
}
' "${PREVIEW_RECEIPT}" "${PREVIEW_SMOKE_RECEIPT}"
fi

DEFAULT_RECEIPT="${ROOT_DIR}/dist/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-production-staging-deployment.json"
if [ "${DEPLOYMENT_ENVIRONMENT}" = preview ]; then
    DEFAULT_RECEIPT="${ROOT_DIR}/dist/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-preview-deployment.json"
fi
RECEIPT_PATH="${CMDTAB_DEPLOY_RECEIPT:-${DEFAULT_RECEIPT}}"
mkdir -p "$(dirname "${RECEIPT_PATH}")"
RECEIPT_PATH="${RECEIPT_PATH}" SOURCE_COMMIT="${SOURCE_COMMIT}" \
DEPLOYMENT_ID="${DEPLOYMENT_ID}" DEPLOYMENT_URL="${DEPLOYMENT_URL}" \
RELEASE_TAG="${CMDTAB_RELEASE_TAG}" PROJECT_ID="${CMDTAB_VERCEL_PROJECT_ID}" \
DEPLOYMENT_ENVIRONMENT="${DEPLOYMENT_ENVIRONMENT}" HEALTH_STATUS="${HEALTH_STATUS}" \
ACCESS_CONTROL_VERIFIED="${ACCESS_CONTROL_VERIFIED}" node <<'NODE'
const { writeFileSync } = require("node:fs");
const evidenceCreatedAt = new Date().toISOString();
writeFileSync(process.env.RECEIPT_PATH, JSON.stringify({
  version: 1,
  projectId: process.env.PROJECT_ID,
  deploymentId: process.env.DEPLOYMENT_ID,
  deploymentUrl: process.env.DEPLOYMENT_URL,
  sourceCommit: process.env.SOURCE_COMMIT,
  releaseTag: process.env.RELEASE_TAG,
  environment: process.env.DEPLOYMENT_ENVIRONMENT,
  releasePhase: process.env.DEPLOYMENT_ENVIRONMENT === "production" ? "staging" : "preview",
  aliasStatus: "unaliased",
  accessControlVerified: process.env.ACCESS_CONTROL_VERIFIED === "true",
  healthStatus: process.env.HEALTH_STATUS,
  deployedAt: evidenceCreatedAt,
  evidenceCreatedAt,
}, null, 2) + "\n", { mode: 0o600 });
NODE
chmod 600 "${RECEIPT_PATH}"
if [ "${DEPLOYMENT_ENVIRONMENT}" = production ]; then
    echo "Production website deployment validated and staged without a canonical alias: ${DEPLOYMENT_URL}"
else
    echo "Preview deployment and schema smoke validation passed: ${DEPLOYMENT_URL}"
fi
echo "Receipt: ${RECEIPT_PATH}"
