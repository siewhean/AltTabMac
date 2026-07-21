#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
WEBSITE_DIR="${ROOT_DIR}/website"
VERCEL_BIN="${CMDTAB_VERCEL_BIN:-vercel}"
PROJECT_FILE="${CMDTAB_VERCEL_PROJECT_FILE:-${ROOT_DIR}/.vercel/project.json}"
REQUIRE_WAF=false

usage() {
    echo "Usage: $0 [--require-waf-enforcement]" >&2
}

fail() {
    echo "$1" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --require-waf-enforcement) REQUIRE_WAF=true ;;
        -h|--help) usage; exit 0 ;;
        *) usage; fail "Unknown argument: $1" ;;
    esac
    shift
done

for variable in VERCEL_TOKEN CMDTAB_VERCEL_PROJECT_ID CMDTAB_VERCEL_ORG_ID; do
    [ -n "${!variable:-}" ] || fail "${variable} is required"
done
[ -x "$(command -v "${VERCEL_BIN}" 2>/dev/null || true)" ] \
    || fail "Vercel CLI is unavailable: ${VERCEL_BIN}"
VERCEL_VERSION="$("${VERCEL_BIN}" --version 2>&1 | tail -1)"
VERCEL_MAJOR="$(VERCEL_VERSION="${VERCEL_VERSION}" node -e '
const match = process.env.VERCEL_VERSION.match(/([0-9]+)\./);
process.stdout.write(match?.[1] ?? "");
')"
case "${VERCEL_MAJOR}" in ''|*[!0-9]*) fail "Unable to determine Vercel CLI version" ;; esac
[ "${VERCEL_MAJOR}" -ge 56 ] || fail "Vercel CLI 56 or newer is required"

PROJECT_ID="${CMDTAB_VERCEL_PROJECT_ID}"
ORG_ID="${CMDTAB_VERCEL_ORG_ID}"
if [ -f "${PROJECT_FILE}" ]; then
    LINKED_PROJECT_ID="$(node -e '
const project = require(process.argv[1]);
process.stdout.write(String(project.projectId ?? ""));
' "${PROJECT_FILE}")"
    LINKED_ORG_ID="$(node -e '
const project = require(process.argv[1]);
process.stdout.write(String(project.orgId ?? ""));
' "${PROJECT_FILE}")"
    [ "${LINKED_PROJECT_ID}" = "${PROJECT_ID}" ] \
        || fail "Linked Vercel project ID does not match CMDTAB_VERCEL_PROJECT_ID"
    [ "${LINKED_ORG_ID}" = "${ORG_ID}" ] \
        || fail "Linked Vercel organization ID does not match CMDTAB_VERCEL_ORG_ID"
fi

TMP_DIR="$(mktemp -d /tmp/cmdtab-vercel-environment.XXXXXX)"
chmod 700 "${TMP_DIR}"
cleanup() {
    find "${TMP_DIR}" -type f -exec chmod 600 {} + 2>/dev/null || true
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT INT TERM
PRODUCTION_ENV="${TMP_DIR}/production.env"
PREVIEW_ENV="${TMP_DIR}/preview.env"

pull_environment() {
    local environment="$1"
    local destination="$2"
    (
        umask 077
        cd "${ROOT_DIR}"
        export VERCEL_PROJECT_ID="${CMDTAB_VERCEL_PROJECT_ID}"
        export VERCEL_ORG_ID="${CMDTAB_VERCEL_ORG_ID}"
        "${VERCEL_BIN}" env pull "${destination}" \
            "--environment=${environment}" --yes --scope "${CMDTAB_VERCEL_ORG_ID}" \
            >/dev/null
    )
    [ -s "${destination}" ] || fail "Vercel returned an empty ${environment} environment"
    chmod 600 "${destination}"
}

pull_environment production "${PRODUCTION_ENV}"
pull_environment preview "${PREVIEW_ENV}"

PRODUCTION_ENV="${PRODUCTION_ENV}" PREVIEW_ENV="${PREVIEW_ENV}" node <<'NODE'
const { createHash } = require("node:crypto");
const { readFileSync } = require("node:fs");

function parseDotEnv(path) {
  const values = {};
  for (const rawLine of readFileSync(path, "utf8").split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const separator = line.indexOf("=");
    if (separator < 1) continue;
    const name = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();
    if (value.startsWith('"')) {
      try { value = JSON.parse(value); } catch { /* presence validation handles malformed values */ }
    } else if (value.startsWith("'") && value.endsWith("'")) {
      value = value.slice(1, -1);
    }
    values[name] = String(value);
  }
  return values;
}

function present(values, name) {
  return typeof values[name] === "string" && values[name].trim().length > 0;
}

const production = parseDotEnv(process.env.PRODUCTION_ENV);
const preview = parseDotEnv(process.env.PREVIEW_ENV);
const required = [
  "NEXT_PUBLIC_SITE_URL",
  "SITE_URL",
  "RESEND_API_KEY",
  "WAITLIST_FROM_EMAIL",
  "WAITLIST_TO_EMAIL",
  "WAITLIST_REPLY_TO_EMAIL",
  "DATABASE_URL",
  "ADMIN_DASHBOARD_PASSWORD",
  "ADMIN_DASHBOARD_SECRET",
  "NEXT_PUBLIC_CHECKOUT_PROVIDER",
  "NEXT_PUBLIC_CHECKOUT_URL",
  "NEXT_PUBLIC_STANDARD_CHECKOUT_URL",
  "NEXT_PUBLIC_TRIAL_URL",
  "NEXT_PUBLIC_LICENSE_PORTAL_URL",
  "NEXT_PUBLIC_SUPPORT_EMAIL",
  "LEMONSQUEEZY_WEBHOOK_SECRET",
  "LEMONSQUEEZY_ALLOWED_STORE_IDS",
  "LEMONSQUEEZY_ALLOWED_PRODUCT_IDS",
  "LEMONSQUEEZY_ALLOWED_VARIANT_IDS",
  "CMDTAB_LICENSE_PRIVATE_KEY_PEM",
  "LICENSE_DELIVERY_FROM_EMAIL",
  "CRON_SECRET",
  "HEALTHCHECK_SECRET",
];

function effectiveRedisPair(values, kind) {
  const prefix = kind === "public" ? "PUBLIC" : "ADMIN";
  const kvUrl = values[`${prefix}_RATE_LIMIT_KV_REST_API_URL`]?.trim();
  const kvToken = values[`${prefix}_RATE_LIMIT_KV_REST_API_TOKEN`]?.trim();
  if (kvUrl || kvToken) {
    return kvUrl && kvToken ? { kind, url: kvUrl, token: kvToken } : null;
  }
  const legacyUrl = values[`${prefix}_RATE_LIMIT_REDIS_REST_URL`]?.trim();
  const legacyToken = values[`${prefix}_RATE_LIMIT_REDIS_REST_TOKEN`]?.trim();
  const url = legacyUrl || values.UPSTASH_REDIS_REST_URL?.trim();
  const token = legacyToken || values.UPSTASH_REDIS_REST_TOKEN?.trim();
  return url && token ? { kind, url, token } : null;
}

function redisConfiguration(values) {
  const pairs = [effectiveRedisPair(values, "public"), effectiveRedisPair(values, "admin")];
  return pairs.every(Boolean) ? pairs : null;
}

const failures = [];
for (const [environment, values] of [["Production", production], ["Preview", preview]]) {
  const missing = required.filter((name) => !present(values, name));
  if (missing.length > 0) failures.push(`${environment} missing: ${missing.join(", ")}`);
  if (!redisConfiguration(values)) {
    failures.push(`${environment} missing a complete Upstash configuration`);
  }
}

function databaseTarget(raw) {
  try {
    const url = new URL(raw);
    return `${url.protocol}//${url.hostname.toLowerCase()}:${url.port || "default"}${url.pathname}`;
  } catch {
    return null;
  }
}

const productionDatabase = databaseTarget(production.DATABASE_URL);
const previewDatabase = databaseTarget(preview.DATABASE_URL);
if (!productionDatabase) failures.push("Production DATABASE_URL is invalid");
if (!previewDatabase) failures.push("Preview DATABASE_URL is invalid");
if (productionDatabase && productionDatabase === previewDatabase) {
  failures.push("Preview and Production target the same database");
}

const separatedSecrets = [
  "DATABASE_URL",
  "RESEND_API_KEY",
  "LEMONSQUEEZY_WEBHOOK_SECRET",
  "CMDTAB_LICENSE_PRIVATE_KEY_PEM",
  "ADMIN_DASHBOARD_PASSWORD",
  "ADMIN_DASHBOARD_SECRET",
  "CRON_SECRET",
  "HEALTHCHECK_SECRET",
];
for (const name of separatedSecrets) {
  if (present(production, name) && present(preview, name) && production[name] === preview[name]) {
    failures.push(`${name} must differ between Preview and Production`);
  }
}
const productionRedis = redisConfiguration(production);
const previewRedis = redisConfiguration(preview);
if (productionRedis && previewRedis) {
  for (const productionPair of productionRedis) {
    for (const previewPair of previewRedis) {
      if (productionPair.url === previewPair.url || productionPair.token === previewPair.token) {
        failures.push("Preview and Production must not share any Upstash store or token");
      }
    }
  }
}

if (failures.length > 0) {
  for (const failure of failures) console.error(`environment gate: ${failure}`);
  process.exit(1);
}

const fingerprint = createHash("sha256")
  .update(`${productionDatabase}|${previewDatabase}`)
  .digest("hex")
  .slice(0, 12);
console.log(`Vercel environment isolation passed (${fingerprint})`);
NODE

if [ "${REQUIRE_WAF}" = true ]; then
    WAF_OUTPUT="${TMP_DIR}/waf.txt"
    (
        cd "${ROOT_DIR}"
        export VERCEL_PROJECT_ID="${CMDTAB_VERCEL_PROJECT_ID}"
        export VERCEL_ORG_ID="${CMDTAB_VERCEL_ORG_ID}"
        "${VERCEL_BIN}" firewall rules inspect \
            "${CMDTAB_VERCEL_WAF_RULE:-Rate limit public POST endpoints}" \
            --json --project "${CMDTAB_VERCEL_PROJECT_ID}" \
            --scope "${CMDTAB_VERCEL_ORG_ID}" >"${WAF_OUTPUT}"
    )
    chmod 600 "${WAF_OUTPUT}"
    WAF_OUTPUT="${WAF_OUTPUT}" node <<'NODE'
const { readFileSync } = require("node:fs");
const rule = JSON.parse(readFileSync(process.env.WAF_OUTPUT, "utf8"));
const expected = new Set([
  "/api/waitlist",
  "/api/license-help",
  "/api/trial/start",
  "/dashboard/login/submit",
]);
const groups = Array.isArray(rule.conditionGroup) ? rule.conditionGroup : [];
const conditions = groups.length === 1 && Array.isArray(groups[0].conditions)
  ? groups[0].conditions : [];
const method = conditions.find((condition) => condition.type === "method");
const path = conditions.find((condition) => condition.type === "path");
const actual = new Set(Array.isArray(path?.value) ? path.value : []);
const rate = rule.action?.mitigate?.rateLimit;
const failures = [];
if (rule.active !== true || rule.valid !== true) failures.push("enabled/valid state");
if (conditions.length !== 2 || method?.op !== "eq" || method?.value !== "POST") failures.push("POST-only method condition");
if (path?.op !== "inc" || actual.size !== expected.size || [...expected].some((item) => !actual.has(item))) failures.push("exact public mutation path set");
if (rule.action?.mitigate?.action !== "rate_limit" || rate?.limit !== 30 || rate?.window !== 60) failures.push("30/60 rate limit");
if (rate?.algo !== "fixed_window" || JSON.stringify(rate?.keys) !== JSON.stringify(["ip"])) failures.push("fixed-window IP key");
if (!["deny", "block", "429"].includes(String(rate?.action).toLowerCase())) failures.push("429 enforcement action");
if (failures.length) {
  console.error(`Vercel WAF validation failed: ${failures.join(", ")}`);
  process.exit(1);
}
NODE
    echo "Vercel WAF enforcement passed"
fi

if [ -n "${CMDTAB_ENVIRONMENT_RECEIPT:-}" ]; then
    RECEIPT_DIR="$(dirname "${CMDTAB_ENVIRONMENT_RECEIPT}")"
    mkdir -p "${RECEIPT_DIR}"
    RECEIPT_PATH="${CMDTAB_ENVIRONMENT_RECEIPT}" PROJECT_ID="${PROJECT_ID}" \
    SOURCE_COMMIT="$(git -C "${ROOT_DIR}" rev-parse HEAD)" \
    RELEASE_TAG="${CMDTAB_VALIDATED_RELEASE_TAG:-}" WAF_ENFORCED="${REQUIRE_WAF}" node <<'NODE'
const { writeFileSync } = require("node:fs");
if (!process.env.RELEASE_TAG) throw new Error("CMDTAB_VALIDATED_RELEASE_TAG is required for an environment receipt");
const evidenceCreatedAt = new Date().toISOString();
writeFileSync(process.env.RECEIPT_PATH, JSON.stringify({
  version: 1,
  ok: true,
  projectId: process.env.PROJECT_ID,
  sourceCommit: process.env.SOURCE_COMMIT,
  releaseTag: process.env.RELEASE_TAG,
  previewProductionSeparated: true,
  wafEnforced: process.env.WAF_ENFORCED === "true",
  validatedAt: evidenceCreatedAt,
  evidenceCreatedAt,
}, null, 2) + "\n", { mode: 0o600 });
NODE
    chmod 600 "${CMDTAB_ENVIRONMENT_RECEIPT}"
fi

echo "Production environment validation passed for ${PROJECT_ID}"
