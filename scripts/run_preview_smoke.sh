#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CURL_BIN="${CMDTAB_CURL_BIN:-curl}"
# shellcheck source=release_metadata.sh
source "${ROOT_DIR}/scripts/release_metadata.sh"

fail() { echo "$1" >&2; exit 1; }

for variable in CMDTAB_PREVIEW_DEPLOYMENT_URL CMDTAB_PREVIEW_DEPLOYMENT_ID \
    CMDTAB_PREVIEW_HEALTHCHECK_SECRET CMDTAB_PREVIEW_PROTECTION_BYPASS_SECRET \
    CMDTAB_PREVIEW_WEBHOOK_SECRET \
    CMDTAB_PREVIEW_DATABASE_MAINTENANCE_URL CMDTAB_PREVIEW_STORE_ID \
    CMDTAB_PREVIEW_PRODUCT_ID CMDTAB_PREVIEW_VARIANT_ID CMDTAB_EXPECTED_TRIAL_URL \
    CMDTAB_EXPECTED_FOUNDER_CHECKOUT_URL CMDTAB_EXPECTED_STANDARD_CHECKOUT_URL \
    CMDTAB_EXPECTED_LICENSE_PORTAL_URL; do
    [ -n "${!variable:-}" ] || fail "${variable} is required"
done
command -v "${CURL_BIN}" >/dev/null 2>&1 || fail "curl is unavailable"
validate_release_metadata_against_source || fail "Release metadata is not canonical"
SOURCE_COMMIT="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
[ -z "$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=all)" ] \
    || fail "Preview smoke validation requires a clean source tree"
[ "$(git -C "${ROOT_DIR}" rev-list -n 1 "${CMDTAB_RELEASE_TAG}" 2>/dev/null || true)" = \
    "${SOURCE_COMMIT}" ] || fail "${CMDTAB_RELEASE_TAG} must point to HEAD"

TMP_DIR="$(mktemp -d /tmp/cmdtab-preview-smoke.XXXXXX)"
chmod 700 "${TMP_DIR}"
REPLAY_ORDER_HASH=""
cleanup() {
    if [ -n "${REPLAY_ORDER_HASH}" ]; then
        (
            cd "${ROOT_DIR}/website"
            DATABASE_URL="${CMDTAB_PREVIEW_DATABASE_MAINTENANCE_URL}" \
            ORDER_HASH="${REPLAY_ORDER_HASH}" node --input-type=module -e '
import postgres from "postgres";
const sql = postgres(process.env.DATABASE_URL, { max: 1 });
await sql`delete from license_fulfillments where order_hash = ${process.env.ORDER_HASH}`;
await sql.end();
' >/dev/null 2>&1
        ) || {
            echo "CRITICAL: Preview webhook smoke fixture cleanup failed for hash ${REPLAY_ORDER_HASH}" >&2
            return 1
        }
    fi
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT INT TERM
BASE_URL="${CMDTAB_PREVIEW_DEPLOYMENT_URL%/}"
BYPASS_SECRET="${CMDTAB_PREVIEW_PROTECTION_BYPASS_SECRET:-}"

request() {
    local name="$1" method="$2" path="$3" expected="$4" body="${5:-}" auth="${6:-none}"
    local config="${TMP_DIR}/${name}.curl" output="${TMP_DIR}/${name}.body" headers="${TMP_DIR}/${name}.headers"
    {
        printf 'silent\nshow-error\nrequest = "%s"\nurl = "%s%s"\noutput = "%s"\ndump-header = "%s"\nwrite-out = "%%{http_code}"\n' \
            "${method}" "${BASE_URL}" "${path}" "${output}" "${headers}"
        [ -z "${BYPASS_SECRET}" ] || printf 'header = "x-vercel-protection-bypass: %s"\n' "${BYPASS_SECRET}"
        [ "${auth}" != health ] || printf 'header = "Authorization: Bearer %s"\n' "${CMDTAB_PREVIEW_HEALTHCHECK_SECRET}"
        if [ -n "${body}" ]; then
            printf 'header = "Content-Type: application/json"\ndata = "%s"\n' "${body//\"/\\\"}"
        fi
        [ "${name}" != webhook_invalid_1 ] && [ "${name}" != webhook_invalid_2 ] \
            || printf 'header = "x-signature: invalid-release-smoke-signature"\n'
    } >"${config}"
    chmod 600 "${config}"
    local status
    status="$("${CURL_BIN}" --config "${config}")" || fail "Preview smoke request failed: ${name}"
    [ "${status}" = "${expected}" ] || fail "Preview smoke ${name} expected ${expected}, received ${status}"
    printf '%s' "${status}"
}

external_status() {
    local name="$1" url="$2" config="${TMP_DIR}/${name}.curl" output="${TMP_DIR}/${name}.body"
    printf 'silent\nshow-error\nlocation\nmax-redirs = 5\nurl = "%s"\noutput = "%s"\nwrite-out = "%%{http_code}"\n' \
        "${url}" "${output}" >"${config}"
    local status
    status="$("${CURL_BIN}" --config "${config}")" || fail "Hosted target is unreachable: ${name}"
    case "${status}" in 2??|3??) ;; *) fail "Hosted target ${name} returned ${status}" ;; esac
    printf '%s' "${status}"
}

CRON_STATUS="$(request cron_unauthorized GET /api/trial/reminder 401)"
node -e 'const result=require(process.argv[1]); if (result.ok !== false || result.message !== "Unauthorized") process.exit(1)' \
    "${TMP_DIR}/cron_unauthorized.body" || fail "Unauthorized cron response is invalid"
WEBHOOK_BODY='{\"meta\":{\"event_name\":\"order_created\"}}'
WEBHOOK_FIRST_STATUS="$(request webhook_invalid_1 POST /api/lemonsqueezy/webhook 401 "${WEBHOOK_BODY}")"
node -e 'if (require(process.argv[1]).code !== "invalid_signature") process.exit(1)' \
    "${TMP_DIR}/webhook_invalid_1.body" || fail "Invalid webhook response is invalid"
TRIAL_STATUS="$(request trial_page GET /trial 200)"
CHECKOUT_STATUS="$(request checkout_page GET /buy 200)"
TRIAL_API_STATUS="$(request trial_api_validation POST /api/trial/start 400 '{}')"
node -e 'if (require(process.argv[1]).code !== "invalid_request") process.exit(1)' \
    "${TMP_DIR}/trial_api_validation.body" || fail "Trial API validation smoke response is invalid"
LICENSE_STATUS="$(request license_page GET /license 307)"
rg -qi '^location: .*/help' "${TMP_DIR}/license_page.headers" || fail "License route did not redirect to Help"
HELP_STATUS="$(request help_page GET /help 200)"
DASHBOARD_STATUS="$(request dashboard_auth GET /dashboard 307)"
rg -qi '^location: .*/dashboard/login' "${TMP_DIR}/dashboard_auth.headers" \
    || fail "Dashboard did not redirect to login"
LOGIN_STATUS="$(request dashboard_login GET /dashboard/login 200)"

rg -Fq "${CMDTAB_EXPECTED_TRIAL_URL}" "${TMP_DIR}/trial_page.body" \
    || fail "Trial page does not contain the configured download URL"
rg -Fq "${CMDTAB_EXPECTED_FOUNDER_CHECKOUT_URL}" "${TMP_DIR}/checkout_page.body" \
    || fail "Buy page does not contain the configured founder checkout URL"
rg -Fq "${CMDTAB_EXPECTED_STANDARD_CHECKOUT_URL}" "${TMP_DIR}/checkout_page.body" \
    || fail "Buy page does not contain the configured standard checkout URL"
rg -Fq "${CMDTAB_EXPECTED_LICENSE_PORTAL_URL}" "${TMP_DIR}/help_page.body" \
    || fail "Help page does not contain the configured license portal URL"
TRIAL_TARGET_STATUS="$(external_status trial_target "${CMDTAB_EXPECTED_TRIAL_URL}")"
FOUNDER_TARGET_STATUS="$(external_status founder_target "${CMDTAB_EXPECTED_FOUNDER_CHECKOUT_URL}")"
STANDARD_TARGET_STATUS="$(external_status standard_target "${CMDTAB_EXPECTED_STANDARD_CHECKOUT_URL}")"
PORTAL_TARGET_STATUS="$(external_status portal_target "${CMDTAB_EXPECTED_LICENSE_PORTAL_URL}")"

REPLAY_ID="preview-smoke-$(uuidgen | tr '[:upper:]' '[:lower:]')"
REPLAY_ORDER_HASH="$(printf '%s' "${REPLAY_ID}" | shasum -a 256 | awk '{print $1}')"
REPLAY_BODY="${TMP_DIR}/webhook-replay.json"
REPLAY_ID="${REPLAY_ID}" STORE_ID="${CMDTAB_PREVIEW_STORE_ID}" \
PRODUCT_ID="${CMDTAB_PREVIEW_PRODUCT_ID}" VARIANT_ID="${CMDTAB_PREVIEW_VARIANT_ID}" node -e '
const { writeFileSync } = require("node:fs");
writeFileSync(process.argv[1], JSON.stringify({
  meta: { event_name: "order_refunded" },
  data: { id: process.env.REPLAY_ID, type: "orders", attributes: {
    identifier: process.env.REPLAY_ID, store_id: Number(process.env.STORE_ID), test_mode: false,
    first_order_item: { product_id: Number(process.env.PRODUCT_ID), variant_id: Number(process.env.VARIANT_ID) },
  } },
}));
' "${REPLAY_BODY}"
REPLAY_SIGNATURE="$(WEBHOOK_SECRET="${CMDTAB_PREVIEW_WEBHOOK_SECRET}" node -e '
const { createHmac } = require("node:crypto");
const { readFileSync } = require("node:fs");
process.stdout.write(createHmac("sha256", process.env.WEBHOOK_SECRET).update(readFileSync(process.argv[1])).digest("hex"));
' "${REPLAY_BODY}")"
signed_webhook() {
    local name="$1" config="${TMP_DIR}/${name}.curl" output="${TMP_DIR}/${name}.body"
    {
        printf 'silent\nshow-error\nrequest = "POST"\nurl = "%s/api/lemonsqueezy/webhook"\n' "${BASE_URL}"
        printf 'output = "%s"\nwrite-out = "%%{http_code}"\n' "${output}"
        printf 'header = "Content-Type: application/json"\nheader = "x-signature: %s"\n' "${REPLAY_SIGNATURE}"
        [ -z "${BYPASS_SECRET}" ] || printf 'header = "x-vercel-protection-bypass: %s"\n' "${BYPASS_SECRET}"
        printf 'data-binary = "@%s"\n' "${REPLAY_BODY}"
    } >"${config}"
    local status
    status="$("${CURL_BIN}" --config "${config}")" || fail "Signed webhook smoke failed"
    [ "${status}" = 200 ] || fail "Signed webhook smoke returned ${status}"
    printf '%s' "${status}"
}
WEBHOOK_REPLAY_FIRST_STATUS="$(signed_webhook webhook_replay_first)"
WEBHOOK_REPLAY_SECOND_STATUS="$(signed_webhook webhook_replay_second)"
for response in "${TMP_DIR}/webhook_replay_first.body" "${TMP_DIR}/webhook_replay_second.body"; do
    node -e 'const result=require(process.argv[1]); if (result.ok !== true || result.handled !== true) process.exit(1)' \
        "${response}" || fail "Signed refund replay response is invalid"
done
REPLAY_ROWS="$(
    cd "${ROOT_DIR}/website"
    DATABASE_URL="${CMDTAB_PREVIEW_DATABASE_MAINTENANCE_URL}" ORDER_HASH="${REPLAY_ORDER_HASH}" node --input-type=module -e '
import postgres from "postgres";
const sql = postgres(process.env.DATABASE_URL, { max: 1 });
const rows = await sql`select count(*)::int as count from license_fulfillments where order_hash = ${process.env.ORDER_HASH} and delivery_status = ${"refunded"}`;
process.stdout.write(String(rows[0].count));
await sql.end();
'
)"
[ "${REPLAY_ROWS}" = 1 ] || fail "Webhook replay did not preserve exactly one refund tombstone"
(
    cd "${ROOT_DIR}/website"
    DATABASE_URL="${CMDTAB_PREVIEW_DATABASE_MAINTENANCE_URL}" ORDER_HASH="${REPLAY_ORDER_HASH}" node --input-type=module -e '
import postgres from "postgres";
const sql = postgres(process.env.DATABASE_URL, { max: 1 });
await sql`delete from license_fulfillments where order_hash = ${process.env.ORDER_HASH}`;
const rows = await sql`select count(*)::int as count from license_fulfillments where order_hash = ${process.env.ORDER_HASH}`;
if (rows[0].count !== 0) process.exitCode = 1;
await sql.end();
'
) || fail "Webhook replay fixture cleanup failed"
REPLAY_ORDER_HASH=""
NONCE="$(uuidgen | tr '[:upper:]' '[:lower:]')"
REDIS_STATUS="$(request redis_rate_limit POST /api/release-smoke/rate-limit 200 \
    "{\"nonce\":\"${NONCE}\"}" health)"
node -e '
const result = require(process.argv[1]);
if (result.ok !== true || result.backend !== "redis" || result.allowedCount !== 6 || result.blocked !== true) process.exit(1);
' "${TMP_DIR}/redis_rate_limit.body" || fail "Shared Redis smoke response is invalid"

RECEIPT="${CMDTAB_PREVIEW_SMOKE_RECEIPT:-${ROOT_DIR}/dist/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-preview-smoke.json}"
mkdir -p "$(dirname "${RECEIPT}")"
RECEIPT="${RECEIPT}" SOURCE_COMMIT="${SOURCE_COMMIT}" RELEASE_TAG="${CMDTAB_RELEASE_TAG}" \
DEPLOYMENT_ID="${CMDTAB_PREVIEW_DEPLOYMENT_ID}" DEPLOYMENT_URL="${BASE_URL}" \
CRON_STATUS="${CRON_STATUS}" WEBHOOK_FIRST_STATUS="${WEBHOOK_FIRST_STATUS}" \
WEBHOOK_REPLAY_FIRST_STATUS="${WEBHOOK_REPLAY_FIRST_STATUS}" \
WEBHOOK_REPLAY_SECOND_STATUS="${WEBHOOK_REPLAY_SECOND_STATUS}" TRIAL_STATUS="${TRIAL_STATUS}" \
TRIAL_API_STATUS="${TRIAL_API_STATUS}" CHECKOUT_STATUS="${CHECKOUT_STATUS}" \
LICENSE_STATUS="${LICENSE_STATUS}" HELP_STATUS="${HELP_STATUS}" DASHBOARD_STATUS="${DASHBOARD_STATUS}" \
LOGIN_STATUS="${LOGIN_STATUS}" REDIS_STATUS="${REDIS_STATUS}" TRIAL_TARGET_STATUS="${TRIAL_TARGET_STATUS}" \
FOUNDER_TARGET_STATUS="${FOUNDER_TARGET_STATUS}" STANDARD_TARGET_STATUS="${STANDARD_TARGET_STATUS}" \
PORTAL_TARGET_STATUS="${PORTAL_TARGET_STATUS}" node <<'NODE'
const { createHash } = require("node:crypto");
const { writeFileSync } = require("node:fs");
const evidenceCreatedAt = new Date().toISOString();
const hash = (name) => createHash("sha256").update(process.env[name]).digest("hex");
writeFileSync(process.env.RECEIPT, JSON.stringify({
  version: 1,
  generator: "scripts/run_preview_smoke.sh",
  ok: true,
  sourceCommit: process.env.SOURCE_COMMIT,
  releaseTag: process.env.RELEASE_TAG,
  deploymentId: process.env.DEPLOYMENT_ID,
  deploymentUrl: process.env.DEPLOYMENT_URL,
  nonDestructive: true,
  privacySafe: true,
  protectionBypassUsed: true,
  checks: {
    unauthorizedCron: { status: Number(process.env.CRON_STATUS), passed: true },
    invalidWebhook: { status: Number(process.env.WEBHOOK_FIRST_STATUS), passed: true },
    webhookReplay: { firstStatus: Number(process.env.WEBHOOK_REPLAY_FIRST_STATUS), secondStatus: Number(process.env.WEBHOOK_REPLAY_SECOND_STATUS), persistedRows: 1, fixtureCleaned: true, passed: true },
    trialPath: { pageStatus: Number(process.env.TRIAL_STATUS), apiValidationStatus: Number(process.env.TRIAL_API_STATUS), targetStatus: Number(process.env.TRIAL_TARGET_STATUS), targetUrlHash: hash("CMDTAB_EXPECTED_TRIAL_URL"), passed: true },
    checkoutPath: { pageStatus: Number(process.env.CHECKOUT_STATUS), founderTargetStatus: Number(process.env.FOUNDER_TARGET_STATUS), standardTargetStatus: Number(process.env.STANDARD_TARGET_STATUS), founderUrlHash: hash("CMDTAB_EXPECTED_FOUNDER_CHECKOUT_URL"), standardUrlHash: hash("CMDTAB_EXPECTED_STANDARD_CHECKOUT_URL"), passed: true },
    licensePath: { redirectStatus: Number(process.env.LICENSE_STATUS), helpStatus: Number(process.env.HELP_STATUS), portalTargetStatus: Number(process.env.PORTAL_TARGET_STATUS), portalUrlHash: hash("CMDTAB_EXPECTED_LICENSE_PORTAL_URL"), passed: true },
    dashboardAuthentication: { redirectStatus: Number(process.env.DASHBOARD_STATUS), loginPageStatus: Number(process.env.LOGIN_STATUS), passed: true },
    sharedRedisRateLimit: { status: Number(process.env.REDIS_STATUS), allowedCount: 6, blocked: true, passed: true },
  },
  evidenceCreatedAt,
}, null, 2) + "\n", { mode: 0o600 });
NODE
chmod 600 "${RECEIPT}"
echo "Preview release smoke passed: ${RECEIPT}"
