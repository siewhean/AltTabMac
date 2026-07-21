#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_DIR="$(mktemp -d /tmp/cmdtab-production-ops-tests.XXXXXX)"
NEON_SERVER_PID=""
trap '[ -z "${NEON_SERVER_PID}" ] || { kill "${NEON_SERVER_PID}" 2>/dev/null || true; wait "${NEON_SERVER_PID}" 2>/dev/null || true; }; rm -rf "${TMP_DIR}"' EXIT

fail() {
    echo "$1" >&2
    exit 1
}

for script in \
    "${ROOT_DIR}/scripts/validate_production_environment.sh" \
    "${ROOT_DIR}/scripts/deploy_production_website.sh" \
    "${ROOT_DIR}/scripts/publish_release_dmg.sh" \
    "${ROOT_DIR}/scripts/promote_production_release.sh" \
    "${ROOT_DIR}/scripts/run_preview_smoke.sh" \
    "${ROOT_DIR}/scripts/aggregate_release_evidence.sh"; do
    bash -n "${script}"
done

PROJECT_FILE="${TMP_DIR}/project.json"
printf '{"projectId":"project-test","orgId":"org-test"}\n' >"${PROJECT_FILE}"
chmod 600 "${PROJECT_FILE}"

write_environment() {
    local destination="$1"
    local suffix="$2"
    local database="$3"
    local redis="$4"
    cat >"${destination}" <<EOF
NEXT_PUBLIC_SITE_URL="https://${suffix}.cmdtab.invalid"
SITE_URL="https://${suffix}.cmdtab.invalid"
RESEND_API_KEY="resend-${suffix}"
WAITLIST_FROM_EMAIL="hello-${suffix}@cmdtab.invalid"
WAITLIST_TO_EMAIL="ops-${suffix}@cmdtab.invalid"
WAITLIST_REPLY_TO_EMAIL="reply-${suffix}@cmdtab.invalid"
DATABASE_URL="postgresql://runtime:password@${database}/cmdtab"
ADMIN_DASHBOARD_PASSWORD="password-${suffix}"
ADMIN_DASHBOARD_SECRET="dashboard-${suffix}"
NEXT_PUBLIC_CHECKOUT_PROVIDER="lemonsqueezy"
NEXT_PUBLIC_CHECKOUT_URL="https://checkout.invalid/${suffix}/founder"
NEXT_PUBLIC_STANDARD_CHECKOUT_URL="https://checkout.invalid/${suffix}/standard"
NEXT_PUBLIC_TRIAL_URL="https://blob.invalid/${suffix}/CmdTab.dmg"
NEXT_PUBLIC_LICENSE_PORTAL_URL="https://checkout.invalid/${suffix}/portal"
NEXT_PUBLIC_SUPPORT_EMAIL="support-${suffix}@cmdtab.invalid"
LEMONSQUEEZY_WEBHOOK_SECRET="webhook-${suffix}"
LEMONSQUEEZY_ALLOWED_STORE_IDS="1"
LEMONSQUEEZY_ALLOWED_PRODUCT_IDS="2"
LEMONSQUEEZY_ALLOWED_VARIANT_IDS="3"
CMDTAB_LICENSE_PRIVATE_KEY_PEM="private-key-${suffix}"
LICENSE_DELIVERY_FROM_EMAIL="license-${suffix}@cmdtab.invalid"
CRON_SECRET="cron-${suffix}"
HEALTHCHECK_SECRET="health-${suffix}"
UPSTASH_REDIS_REST_URL="https://${redis}.upstash.invalid"
UPSTASH_REDIS_REST_TOKEN="redis-${suffix}"
EOF
    chmod 600 "${destination}"
}

PRODUCTION_FIXTURE="${TMP_DIR}/production.env"
PREVIEW_FIXTURE="${TMP_DIR}/preview.env"
write_environment "${PRODUCTION_FIXTURE}" production production-db production-redis
write_environment "${PREVIEW_FIXTURE}" preview preview-db preview-redis

MOCK_VERCEL="${TMP_DIR}/vercel"
cat >"${MOCK_VERCEL}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = --version ]; then
    echo 'Vercel CLI 56.3.2'
    exit 0
fi
if [ "${1:-}" = env ] && [ "${2:-}" = pull ]; then
    destination="$3"
    environment=""
    for argument in "$@"; do
        case "$argument" in --environment=*) environment="${argument#*=}" ;; esac
    done
    if [ "$environment" = production ]; then
        cp "$MOCK_PRODUCTION_ENV" "$destination"
    else
        cp "$MOCK_PREVIEW_ENV" "$destination"
    fi
    exit 0
fi
if [ "${1:-}" = firewall ]; then
    cat <<WAF
{"name":"Rate limit public POST endpoints","active":true,"valid":true,"action":{"mitigate":{"action":"rate_limit","rateLimit":{"limit":30,"action":"${MOCK_WAF_RESULT:-deny}","window":60,"algo":"fixed_window","keys":["ip"]}}},"conditionGroup":[{"conditions":[{"type":"method","op":"eq","value":"POST"},{"type":"path","op":"inc","value":["/api/waitlist","/api/license-help","/api/trial/start","/dashboard/login/submit"]}]}]}
WAF
    exit 0
fi
if [ "${1:-}" = deploy ]; then
    if printf '%s\n' "$@" | grep -Fq -- '--target=preview'; then
        printf '{"id":"deployment-preview","url":"deployment-preview.vercel.app"}\n'
    else
        printf '{"id":"deployment-production","url":"deployment-production.vercel.app"}\n'
    fi
    exit 0
fi
if [ "${1:-}" = promote ]; then
    [ -z "${MOCK_PROMOTE_LOG:-}" ] || printf '%s\n' "${2:-}" >>"$MOCK_PROMOTE_LOG"
    if [ -n "${MOCK_PROMOTE_MARKER:-}" ]; then
        if [[ "${2:-}" == *previous-production* ]]; then rm -f "$MOCK_PROMOTE_MARKER"
        else touch "$MOCK_PROMOTE_MARKER"
        fi
    fi
    echo 'Promoted deployment-test.vercel.app'
    exit 0
fi
if [ "${1:-}" = blob ] && [ "${2:-}" = put ]; then
    printf '{"url":"https://public.blob.vercel-storage.com/releases/CmdTab.dmg"}\n'
    exit 0
fi
exit 2
EOF
chmod +x "${MOCK_VERCEL}"

VALIDATOR_ENV=(
    VERCEL_TOKEN=test-token
    CMDTAB_VERCEL_PROJECT_ID=project-test
    CMDTAB_VERCEL_ORG_ID=org-test
    CMDTAB_VERCEL_PROJECT_FILE="${PROJECT_FILE}"
    CMDTAB_VERCEL_BIN="${MOCK_VERCEL}"
    MOCK_PRODUCTION_ENV="${PRODUCTION_FIXTURE}"
    MOCK_PREVIEW_ENV="${PREVIEW_FIXTURE}"
)
env "${VALIDATOR_ENV[@]}" "${ROOT_DIR}/scripts/validate_production_environment.sh" \
    --require-waf-enforcement >"${TMP_DIR}/validator-success.log"
grep -Fq 'Production environment validation passed' "${TMP_DIR}/validator-success.log" \
    || fail "Environment validator did not report success"
if env "${VALIDATOR_ENV[@]}" MOCK_WAF_RESULT=log \
    "${ROOT_DIR}/scripts/validate_production_environment.sh" --require-waf-enforcement \
    >"${TMP_DIR}/validator-waf.log" 2>&1; then
    fail "Environment validator accepted a log-only WAF rule"
fi
cp "${PRODUCTION_FIXTURE}" "${TMP_DIR}/shared-database.env"
sed -i.bak 's/production-db/preview-db/' "${TMP_DIR}/shared-database.env"
if env "${VALIDATOR_ENV[@]}" MOCK_PRODUCTION_ENV="${TMP_DIR}/shared-database.env" \
    "${ROOT_DIR}/scripts/validate_production_environment.sh" \
    >"${TMP_DIR}/validator-shared.log" 2>&1; then
    fail "Environment validator accepted one Preview/Production database"
fi
grep -Fq 'target the same database' "${TMP_DIR}/validator-shared.log" \
    || fail "Shared database rejection was not explicit"
cp "${PRODUCTION_FIXTURE}" "${TMP_DIR}/partial-redis.env"
printf 'PUBLIC_RATE_LIMIT_KV_REST_API_URL="https://partial.upstash.invalid"\n' \
    >>"${TMP_DIR}/partial-redis.env"
if env "${VALIDATOR_ENV[@]}" MOCK_PRODUCTION_ENV="${TMP_DIR}/partial-redis.env" \
    "${ROOT_DIR}/scripts/validate_production_environment.sh" \
    >"${TMP_DIR}/validator-partial-redis.log" 2>&1; then
    fail "Environment validator accepted a partial specialized Redis configuration"
fi
cp "${PREVIEW_FIXTURE}" "${TMP_DIR}/shared-public-redis.env"
sed -i.bak \
    's#https://preview-redis.upstash.invalid#https://production-redis.upstash.invalid#' \
    "${TMP_DIR}/shared-public-redis.env"
if env "${VALIDATOR_ENV[@]}" MOCK_PREVIEW_ENV="${TMP_DIR}/shared-public-redis.env" \
    "${ROOT_DIR}/scripts/validate_production_environment.sh" \
    >"${TMP_DIR}/validator-shared-redis.log" 2>&1; then
    fail "Environment validator accepted a shared Upstash store"
fi
if rg -F 'test-token|private-key-production|password-production' "${TMP_DIR}"/*.log >/dev/null; then
    fail "Production validator leaked a secret into output"
fi

REPO="${TMP_DIR}/release-repo"
mkdir -p "${REPO}/scripts" "${REPO}/Resources" "${REPO}/website" "${REPO}/dist"
cp "${ROOT_DIR}/scripts/deploy_production_website.sh" \
   "${ROOT_DIR}/scripts/publish_release_dmg.sh" \
   "${ROOT_DIR}/scripts/promote_production_release.sh" \
   "${ROOT_DIR}/scripts/run_preview_smoke.sh" \
   "${ROOT_DIR}/scripts/aggregate_release_evidence.sh" \
   "${ROOT_DIR}/scripts/release_metadata.sh" "${REPO}/scripts/"
cp "${ROOT_DIR}/scripts/generate_backup_restore_release_receipt.mjs" \
   "${ROOT_DIR}/scripts/generate_final_qa_receipt.mjs" \
   "${ROOT_DIR}/scripts/capture_neon_recovery_evidence.mjs" "${REPO}/scripts/"
cp "${ROOT_DIR}/Resources/Info.plist" "${REPO}/Resources/Info.plist"
cat >"${REPO}/scripts/validate_production_environment.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"${REPO}/scripts/mock-release-verifier.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${REPO}/scripts/"*.sh
printf 'dist/\n.vercel/\n' >"${REPO}/.gitignore"
git -C "${REPO}" init -q
git -C "${REPO}" config user.name CmdTab-Test
git -C "${REPO}" config user.email test@cmdtab.invalid
git -C "${REPO}" add .
git -C "${REPO}" commit -qm 'release fixture'
VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "${REPO}/Resources/Info.plist")"
git -C "${REPO}" tag "v${VERSION}"

cat >"${TMP_DIR}/mock-neon-api.mjs" <<'EOF'
import { createServer } from "node:http";
import { writeFileSync } from "node:fs";
const projectId = "project-production";
const sourceBranchId = "br-production-main";
const recoveryBranchId = "br-release-recovery";
const operationId = "11111111-1111-4111-8111-111111111111";
const createdAt = new Date(Date.now() - 1_000).toISOString();
let checkpointName = "";
const send = (response, status, body) => {
  response.writeHead(status, { "content-type": "application/json" });
  response.end(JSON.stringify(body));
};
const server = createServer((request, response) => {
  const authorization = request.headers.authorization;
  if (!["Bearer neon-test-key", "Bearer neon-bad-action", "Bearer neon-bad-id"].includes(authorization)) {
    return send(response, 401, {});
  }
  if (request.method === "GET" && request.url === `/api/v2/projects/${projectId}`) {
    return send(response, 200, { project: { id: projectId, history_retention_seconds: 604800 } });
  }
  if (request.method === "GET" && request.url === "/api/v2/projects/project-low-retention") {
    return send(response, 200, { project: { id: "project-low-retention", history_retention_seconds: 86400 } });
  }
  if (request.method === "GET" && request.url === `/api/v2/projects/${projectId}/branches/${sourceBranchId}`) {
    return send(response, 200, { branch: { id: sourceBranchId, project_id: projectId, current_state: "ready" } });
  }
  if (request.method === "POST" && request.url === `/api/v2/projects/${projectId}/branches`) {
    let raw = "";
    request.on("data", (chunk) => { raw += chunk; });
    request.on("end", () => {
      const input = JSON.parse(raw);
      checkpointName = input.branch.name;
      send(response, 201, {
        branch: { id: recoveryBranchId, project_id: projectId, parent_id: sourceBranchId, name: checkpointName },
        operations: [{ id: operationId }],
      });
    });
    return;
  }
  if (request.method === "GET" && request.url === `/api/v2/projects/${projectId}/operations/${operationId}`) {
    return send(response, 200, { operation: {
      id: authorization === "Bearer neon-bad-id" ? "22222222-2222-4222-8222-222222222222" : operationId,
      project_id: projectId, branch_id: recoveryBranchId,
      action: authorization === "Bearer neon-bad-action" ? "timeline_update_protected_config" : "create_branch",
      status: "finished", failures_count: 0,
    } });
  }
  if (request.method === "GET" && request.url === `/api/v2/projects/${projectId}/branches/${recoveryBranchId}`) {
    return send(response, 200, { branch: {
      id: recoveryBranchId, project_id: projectId, parent_id: sourceBranchId,
      name: checkpointName, current_state: "ready", protected: true,
      parent_lsn: "0/1DE2850", created_at: createdAt,
    } });
  }
  send(response, 404, {});
});
server.listen(0, "127.0.0.1", () => {
  writeFileSync(process.env.MOCK_NEON_PORT_FILE, String(server.address().port));
});
EOF
MOCK_NEON_PORT_FILE="${TMP_DIR}/neon-port" node "${TMP_DIR}/mock-neon-api.mjs" &
NEON_SERVER_PID=$!
for _ in {1..50}; do [ -s "${TMP_DIR}/neon-port" ] && break; sleep 0.1; done
[ -s "${TMP_DIR}/neon-port" ] || fail "Mock Neon API did not start"
NEON_PORT="$(cat "${TMP_DIR}/neon-port")"
(
    cd "${REPO}"
    NEON_API_KEY=neon-test-key \
    NEON_PROJECT_ID=project-production \
    NEON_PRODUCTION_BRANCH_ID=br-production-main \
    NEON_API_BASE_URL="http://127.0.0.1:${NEON_PORT}/api/v2" \
    CMDTAB_ALLOW_TEST_NEON_API_BASE_URL=1 \
        node scripts/capture_neon_recovery_evidence.mjs
)
[ "$(plutil -extract historyRetentionSeconds raw -o - "${REPO}/dist/neon-recovery-receipt.json")" = 604800 ] \
    || fail "Neon recovery receipt did not preserve provider retention"
if (cd "${REPO}" && NEON_PROJECT_ID=project-production \
    NEON_PRODUCTION_BRANCH_ID=br-production-main \
    node scripts/capture_neon_recovery_evidence.mjs >"${TMP_DIR}/neon-missing-credentials.log" 2>&1); then
    fail "Neon recovery capture accepted missing API credentials"
fi
if (cd "${REPO}" && NEON_API_KEY=wrong-neon-key \
    NEON_PROJECT_ID=project-production NEON_PRODUCTION_BRANCH_ID=br-production-main \
    NEON_API_BASE_URL="http://127.0.0.1:${NEON_PORT}/api/v2" \
    CMDTAB_ALLOW_TEST_NEON_API_BASE_URL=1 \
    node scripts/capture_neon_recovery_evidence.mjs >"${TMP_DIR}/neon-unauthorized.log" 2>&1); then
    fail "Neon recovery capture accepted an unauthorized API response"
fi
if rg -F 'wrong-neon-key|neon-test-key' "${TMP_DIR}"/neon-*.log >/dev/null; then
    fail "Neon recovery capture leaked an API credential"
fi
if (cd "${REPO}" && NEON_API_KEY=neon-test-key \
    NEON_PROJECT_ID=project-low-retention NEON_PRODUCTION_BRANCH_ID=br-production-main \
    NEON_API_BASE_URL="http://127.0.0.1:${NEON_PORT}/api/v2" \
    CMDTAB_ALLOW_TEST_NEON_API_BASE_URL=1 \
    node scripts/capture_neon_recovery_evidence.mjs >"${TMP_DIR}/neon-low-retention.log" 2>&1); then
    fail "Neon recovery capture accepted less than seven days of provider retention"
fi
for bad_case in action id; do
  if (cd "${REPO}" && NEON_API_KEY="neon-bad-${bad_case}" \
      NEON_PROJECT_ID=project-production NEON_PRODUCTION_BRANCH_ID=br-production-main \
      NEON_API_BASE_URL="http://127.0.0.1:${NEON_PORT}/api/v2" \
      CMDTAB_ALLOW_TEST_NEON_API_BASE_URL=1 \
      node scripts/capture_neon_recovery_evidence.mjs >"${TMP_DIR}/neon-bad-${bad_case}.log" 2>&1); then
      fail "Neon recovery capture accepted a mismatched operation ${bad_case}"
  fi
done

MOCK_CURL="${TMP_DIR}/curl"
cat >"${MOCK_CURL}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" != "--config" ]; then
    output=""
    while [ "$#" -gt 0 ]; do
        if [ "$1" = --output ]; then output="$2"; shift; fi
        shift
    done
    cp "$MOCK_BLOB_SOURCE" "$output"
    exit 0
fi
config="${2:?missing curl config}"
output="$(sed -n 's/^output = "\(.*\)"$/\1/p' "$config")"
url="$(sed -n 's/^url = "\(.*\)"$/\1/p' "$config")"
headers="$(sed -n 's/^dump-header = "\(.*\)"$/\1/p' "$config")"
write_out="$(sed -n 's/^write-out = "\(.*\)"$/\1/p' "$config")"
if [[ "$url" == */api/health ]]; then
    if [ -n "$write_out" ]; then
        : >"$output"
        printf 'HTTP/2 302\r\nlocation: https://vercel.com/sso-api?url=test\r\n\r\n' >"$headers"
        printf '302'
        exit 0
    fi
    if [ "${MOCK_CANONICAL_HEALTH_FAIL:-false}" = true ] && [[ "$url" == https://cmdtab.net/* ]] && \
       [ -n "${MOCK_PROMOTE_MARKER:-}" ] && [ -f "$MOCK_PROMOTE_MARKER" ]; then
        printf '{"ok":false,"connectivity":"failed","schema":"unknown","staleFulfillment":false}\n' >"$output"
    else
        printf '{"ok":true,"connectivity":"ok","schema":"current","staleFulfillment":false}\n' >"$output"
    fi
    [ -z "$write_out" ] || printf '200'
    exit 0
fi
if [[ "$url" == *api.vercel.com/v4/aliases/* ]]; then
    if [ -n "${MOCK_PROMOTE_MARKER:-}" ] && [ -f "$MOCK_PROMOTE_MARKER" ]; then
        printf '{"deploymentId":"deployment-production","deployment":{"url":"deployment-production.vercel.app"}}\n' >"$output"
    else
        printf '{"deploymentId":"deployment-previous","deployment":{"url":"previous-production.vercel.app"}}\n' >"$output"
    fi
    exit 0
fi
if [[ "$url" == */api/trial/reminder ]]; then status=401
elif [[ "$url" == */api/lemonsqueezy/webhook ]]; then status=401
elif [[ "$url" == */trial || "$url" == */buy || "$url" == */license ]]; then status=200
elif [[ "$url" == */dashboard ]]; then
    status=307
    printf 'HTTP/2 307\r\nlocation: %s/dashboard/login\r\n\r\n' "${url%/dashboard}" >"$headers"
elif [[ "$url" == */api/release-smoke/rate-limit ]]; then
    status=200
    printf '{"ok":true,"backend":"redis","allowedCount":6,"blocked":true}\n' >"$output"
else status=""
fi
if [ -n "$status" ]; then
    : >"${output:?missing output}"
    if [[ "$url" == */api/release-smoke/rate-limit ]]; then
        printf '{"ok":true,"backend":"redis","allowedCount":6,"blocked":true}\n' >"$output"
    fi
    printf '%s' "$status"
    exit 0
fi
environment=production
if [[ "$url" == *deployment-preview* ]]; then environment=preview; fi
cat >"$output" <<JSON
{"projectId":"project-test","readyState":"READY","alias":[],"aliasAssigned":false,"meta":{"cmdtabSourceCommit":"$(git -C "$MOCK_RELEASE_REPO" rev-parse HEAD)","cmdtabReleaseTag":"$MOCK_RELEASE_TAG","cmdtabDeploymentEnvironment":"$environment"}}
JSON
EOF
chmod +x "${MOCK_CURL}"

(
    cd "${REPO}"
    VERCEL_TOKEN=test-token \
    CMDTAB_VERCEL_PROJECT_ID=project-test \
    CMDTAB_VERCEL_ORG_ID=org-test \
    CMDTAB_VERCEL_BIN="${MOCK_VERCEL}" \
    CMDTAB_CURL_BIN="${MOCK_CURL}" \
    CMDTAB_DEPLOY_POLL_ATTEMPTS=2 \
    CMDTAB_DEPLOY_POLL_DELAY_SECONDS=1 \
    MOCK_RELEASE_REPO="${REPO}" \
    MOCK_RELEASE_TAG="v${VERSION}" \
    CMDTAB_PREVIEW_HEALTHCHECK_SECRET=preview-health \
    ./scripts/deploy_production_website.sh --preview >"${TMP_DIR}/preview-deploy.log"
    SOURCE_COMMIT="$(git rev-parse HEAD)" RELEASE_TAG="v${VERSION}" VERSION="${VERSION}" node -e '
const { readFileSync, writeFileSync } = require("node:fs");
const { createHash } = require("node:crypto");
const preview = require(`./dist/CmdTab-${process.env.VERSION}-preview-deployment.json`);
writeFileSync(`dist/CmdTab-${process.env.VERSION}-preview-smoke.json`, JSON.stringify({
  version: 1, generator: "scripts/run_preview_smoke.sh", ok: true, nonDestructive: true,
  privacySafe: true, sourceCommit: process.env.SOURCE_COMMIT, releaseTag: process.env.RELEASE_TAG,
  deploymentId: preview.deploymentId, deploymentUrl: preview.deploymentUrl,
  checks: {
    unauthorizedCron: { status: 401, passed: true }, invalidWebhook: { status: 401, passed: true },
    webhookReplay: { firstStatus: 200, secondStatus: 200, persistedRows: 1, fixtureCleaned: true, passed: true },
    trialPath: { pageStatus: 200, apiValidationStatus: 400, passed: true },
    checkoutPath: { pageStatus: 200, passed: true },
    licensePath: { redirectStatus: 307, helpStatus: 200, passed: true },
    dashboardAuthentication: { redirectStatus: 307, loginPageStatus: 200, passed: true },
    sharedRedisRateLimit: { status: 200, allowedCount: 6, blocked: true, passed: true },
  },
  evidenceCreatedAt: new Date(Date.now() - 1000).toISOString(),
}) + "\n");
'
    VERCEL_TOKEN=test-token \
    CMDTAB_VERCEL_PROJECT_ID=project-test \
    CMDTAB_VERCEL_ORG_ID=org-test \
    CMDTAB_VERCEL_BIN="${MOCK_VERCEL}" \
    CMDTAB_CURL_BIN="${MOCK_CURL}" \
    CMDTAB_DEPLOY_POLL_ATTEMPTS=2 \
    CMDTAB_DEPLOY_POLL_DELAY_SECONDS=1 \
    MOCK_RELEASE_REPO="${REPO}" \
    MOCK_RELEASE_TAG="v${VERSION}" \
    CMDTAB_PRODUCTION_HEALTHCHECK_SECRET=production-health \
    CMDTAB_PRODUCTION_PROTECTION_BYPASS_SECRET=production-bypass \
    ./scripts/deploy_production_website.sh >"${TMP_DIR}/deploy.log"
)
PREVIEW_RECEIPT="${REPO}/dist/CmdTab-${VERSION}-preview-deployment.json"
[ "$(plutil -extract healthStatus raw -o - "${PREVIEW_RECEIPT}")" = passed ] \
    || fail "Preview receipt did not preserve health evidence"
DEPLOY_RECEIPT="${REPO}/dist/CmdTab-${VERSION}-production-staging-deployment.json"
[ "$(plutil -extract sourceCommit raw -o - "${DEPLOY_RECEIPT}")" = \
  "$(git -C "${REPO}" rev-parse HEAD)" ] || fail "Deployment receipt has the wrong source SHA"
grep -Fq 'staged without a canonical alias' "${TMP_DIR}/deploy.log" \
    || fail "Production deployment was not left in unaliased staging"
[ ! -e "${TMP_DIR}/promoted" ] || fail "Phase 1 promoted Production before final evidence"

DMG="${REPO}/dist/CmdTab-${VERSION}-universal.dmg"
printf 'verified release fixture' >"${DMG}"
if (cd "${REPO}" && BLOB_READ_WRITE_TOKEN=blob-test-token \
    CMDTAB_VERCEL_BIN="${MOCK_VERCEL}" CMDTAB_CURL_BIN="${MOCK_CURL}" \
    MOCK_BLOB_SOURCE="${DMG}" CMDTAB_RELEASE_VERIFIER="${REPO}/scripts/mock-release-verifier.sh" \
    ./scripts/publish_release_dmg.sh) >"${TMP_DIR}/premature-blob.log" 2>&1; then
    fail "Blob publisher accepted a release without final aggregate evidence"
fi
if grep -Fq 'CMDTAB_DMG_PATH' "${ROOT_DIR}/scripts/publish_release_dmg.sh"; then
    fail "Blob publisher must not allow an unverified DMG path override"
fi

SOURCE_COMMIT="$(git -C "${REPO}" rev-parse HEAD)"
RELEASE_TAG="v${VERSION}"
ARTIFACT_SHA256="$(shasum -a 256 "${DMG}" | awk '{print $1}')"
SOURCE_COMMIT="${SOURCE_COMMIT}" RELEASE_TAG="${RELEASE_TAG}" \
ARTIFACT_SHA256="${ARTIFACT_SHA256}" OUTPUT_DIR="${REPO}/dist" VERSION="${VERSION}" node <<'NODE'
const { readFileSync, writeFileSync } = require("node:fs");
const { createHash } = require("node:crypto");
const path = require("node:path");
const base = {
  sourceCommit: process.env.SOURCE_COMMIT,
  releaseTag: process.env.RELEASE_TAG,
  evidenceCreatedAt: new Date().toISOString(),
};
const output = process.env.OUTPUT_DIR;
const artifact = `CmdTab-${process.env.VERSION}-universal.dmg`;
const write = (name, value) => writeFileSync(path.join(output, name), JSON.stringify({ ...base, ...value }) + "\n");
write(`CmdTab-${process.env.VERSION}-release-receipt.json`, {
  artifact, sha256: process.env.ARTIFACT_SHA256,
  notarizationSubmissionIds: { app: "app-notary-test", dmg: "dmg-notary-test" },
});
write("runtime-qa-receipt.json", {
  passed: true, failures: [], warmSessions: 100, coldSessions: 20,
  exactWindowActivations: 100, multiWindowSessions: 100,
  forwardSteps: 200, reverseSteps: 200, callbackSamples: 400,
  warmPostDeadlineP95Milliseconds: 40, warmPostDeadlineMaximumMilliseconds: 80,
  callbackP95Milliseconds: 4, callbackMaximumMilliseconds: 19,
  coldTotalP95Milliseconds: 200,
});
const checks = Object.fromEntries([
  "gatekeeper", "dragInstall", "permissionGrantDenyRevokeRecovery", "launchAtLogin",
  "secureInput", "spaces", "fullscreen", "multipleDisplays", "licensing", "telemetryOptOut",
].map((name) => [name, true]));
for (const architecture of ["arm64", "x86_64"]) {
  write(`clean-mac-${architecture}-qa-receipt.json`, {
    ok: true, cleanMac: true, architecture, macOSMajor: 13,
    artifactSha256: process.env.ARTIFACT_SHA256, checks,
  });
}
write(`CmdTab-${process.env.VERSION}-environment-validation.json`, {
  ok: true, projectId: "project-test", previewProductionSeparated: true, wafEnforced: true,
});
const recoveryPath = path.join(output, "neon-recovery-receipt.json");
const recovery = JSON.parse(readFileSync(recoveryPath));
write("production-migration-receipt.json", {
  ok: true,
  neonRecoveryEvidence: {
    file: "neon-recovery-receipt.json",
    sha256: createHash("sha256").update(readFileSync(recoveryPath)).digest("hex"),
    projectId: recovery.projectId, productionBranchId: recovery.productionBranchId,
    recoveryBranchId: recovery.recoveryBranchId,
    checkpointLsnSha256: recovery.checkpointLsnSha256,
  },
});
write("database-backup-receipt.json", {
  ok: true, operation: "database-backup", status: "succeeded",
  workflow: "CmdTab Database Backup", repository: "cmdtab/test", runId: "1001",
  runAttempt: 1, backupSha256: "b".repeat(64), retentionClasses: ["daily"],
  completedAt: new Date().toISOString(),
});
write("database-restore-receipt.json", {
  ok: true, operation: "database-restore-drill", status: "succeeded",
  workflow: "CmdTab Database Restore Drill", repository: "cmdtab/test", runId: "1002",
  runAttempt: 1, backupRunId: "1001", backupSha256: "b".repeat(64),
  completedAt: new Date().toISOString(),
});
NODE
(
    cd "${REPO}"
    node scripts/generate_backup_restore_release_receipt.mjs \
        dist/database-backup-receipt.json dist/database-restore-receipt.json \
        dist/neon-recovery-receipt.json
    CMDTAB_FINAL_QA_REVIEWER=independent-test \
    CMDTAB_FINAL_QA_REPORT_ID=qa-report-test \
    CMDTAB_FINAL_QA_FINDINGS=0 \
        node scripts/generate_final_qa_receipt.mjs
)
CMDTAB_RELEASE_DIR="${REPO}/dist" \
CMDTAB_RELEASE_VERIFIER="${REPO}/scripts/mock-release-verifier.sh" \
    "${REPO}/scripts/aggregate_release_evidence.sh" >"${TMP_DIR}/aggregate.log"
[ "$(plutil -extract ok raw -o - "${REPO}/dist/CmdTab-${VERSION}-production-evidence.json")" = true ] \
    || fail "Final production evidence aggregation failed"
node -e '
const aggregate = require(process.argv[1]);
const files = new Set(aggregate.evidence.map((entry) => entry.file));
if (files.has(`CmdTab-${process.argv[2]}-blob-publication.json`) ||
    !files.has(`CmdTab-${process.argv[2]}-preview-smoke.json`) ||
    !files.has(`CmdTab-${process.argv[2]}-production-staging-deployment.json`)) process.exit(1);
' "${REPO}/dist/CmdTab-${VERSION}-production-evidence.json" "${VERSION}" \
    || fail "Pre-publication aggregate has circular or missing staging evidence"
AGGREGATE_CHECKSUM="${REPO}/dist/CmdTab-${VERSION}-production-evidence.json.sha256"
cp "${AGGREGATE_CHECKSUM}" "${TMP_DIR}/aggregate.sha256"
printf '%064d  %s\n' 0 "${REPO}/dist/CmdTab-${VERSION}-production-evidence.json" >"${AGGREGATE_CHECKSUM}"
if (cd "${REPO}" && BLOB_READ_WRITE_TOKEN=blob-test-token \
    CMDTAB_VERCEL_BIN="${MOCK_VERCEL}" CMDTAB_CURL_BIN="${MOCK_CURL}" \
    MOCK_BLOB_SOURCE="${DMG}" CMDTAB_RELEASE_VERIFIER="${REPO}/scripts/mock-release-verifier.sh" \
    ./scripts/publish_release_dmg.sh) >"${TMP_DIR}/forged-aggregate.log" 2>&1; then
    fail "Blob publisher accepted a forged aggregate checksum"
fi
cp "${TMP_DIR}/aggregate.sha256" "${AGGREGATE_CHECKSUM}"

(
    cd "${REPO}"
    BLOB_READ_WRITE_TOKEN=blob-test-token \
    CMDTAB_VERCEL_BIN="${MOCK_VERCEL}" CMDTAB_CURL_BIN="${MOCK_CURL}" \
    MOCK_BLOB_SOURCE="${DMG}" CMDTAB_RELEASE_VERIFIER="${REPO}/scripts/mock-release-verifier.sh" \
    ./scripts/publish_release_dmg.sh >"${TMP_DIR}/blob.log"
)
if (
    cd "${REPO}"
    VERCEL_TOKEN=test-token CMDTAB_VERCEL_PROJECT_ID=project-test CMDTAB_VERCEL_ORG_ID=org-test \
    CMDTAB_VERCEL_BIN="${MOCK_VERCEL}" CMDTAB_CURL_BIN="${MOCK_CURL}" \
    MOCK_PROMOTE_MARKER="${TMP_DIR}/failed-promoted" MOCK_PROMOTE_LOG="${TMP_DIR}/rollback.log" \
    MOCK_CANONICAL_HEALTH_FAIL=true CMDTAB_PRODUCTION_HEALTHCHECK_SECRET=production-health \
    ./scripts/promote_production_release.sh
) >"${TMP_DIR}/failed-promote.log" 2>&1; then
    fail "Public release accepted failed canonical health"
fi
[ ! -e "${TMP_DIR}/failed-promoted" ] || fail "Failed promotion did not restore the previous deployment"
[ "$(wc -l <"${TMP_DIR}/rollback.log" | tr -d ' ')" = 2 ] \
    || fail "Failed promotion did not attempt the exact rollback target"
(
    cd "${REPO}"
    VERCEL_TOKEN=test-token CMDTAB_VERCEL_PROJECT_ID=project-test CMDTAB_VERCEL_ORG_ID=org-test \
    CMDTAB_VERCEL_BIN="${MOCK_VERCEL}" CMDTAB_CURL_BIN="${MOCK_CURL}" \
    MOCK_PROMOTE_MARKER="${TMP_DIR}/promoted" CMDTAB_PRODUCTION_HEALTHCHECK_SECRET=production-health \
    ./scripts/promote_production_release.sh >"${TMP_DIR}/promote.log"
)
BLOB_RECEIPT="${REPO}/dist/CmdTab-${VERSION}-blob-publication.json"
[ -s "${BLOB_RECEIPT}" ] || fail "Aggregate-authorized Blob receipt is missing"
[ -s "${REPO}/dist/CmdTab-${VERSION}-public-release.json" ] || fail "Public release receipt is missing"
[ -e "${TMP_DIR}/promoted" ] || fail "Public release did not promote the staged deployment"
grep -Fq 'Rollback target: deployment-previous' "${TMP_DIR}/promote.log" \
    || fail "Public release did not record the previous deployment rollback target"
if rg -F 'blob-test-token|production-health' "${TMP_DIR}/blob.log" "${TMP_DIR}/promote.log" \
    "${BLOB_RECEIPT}" >/dev/null; then
    fail "Public release leaked a secret"
fi
RUNTIME_RECEIPT="${REPO}/dist/runtime-qa-receipt.json"
cp "${RUNTIME_RECEIPT}" "${TMP_DIR}/runtime-qa-receipt.json"
node -e '
const { readFileSync, writeFileSync } = require("node:fs");
const path = process.argv[1];
const value = JSON.parse(readFileSync(path, "utf8"));
delete value.callbackP95Milliseconds;
value.warmSessions = "100";
writeFileSync(path, JSON.stringify(value) + "\n");
' "${RUNTIME_RECEIPT}"
if CMDTAB_RELEASE_DIR="${REPO}/dist" \
   CMDTAB_RELEASE_VERIFIER="${REPO}/scripts/mock-release-verifier.sh" \
   "${REPO}/scripts/aggregate_release_evidence.sh" >"${TMP_DIR}/aggregate-missing-number.log" 2>&1; then
    fail "Evidence aggregator accepted an omitted runtime measurement"
fi
cp "${TMP_DIR}/runtime-qa-receipt.json" "${RUNTIME_RECEIPT}"

FINAL_QA_RECEIPT="${REPO}/dist/final-qa-receipt.json"
cp "${FINAL_QA_RECEIPT}" "${TMP_DIR}/final-qa-receipt.json"
node -e '
const { readFileSync, writeFileSync } = require("node:fs");
const path = process.argv[1];
const value = JSON.parse(readFileSync(path, "utf8"));
value.reviewedEvidence["runtime-qa-receipt.json"].sha256 = "c".repeat(64);
writeFileSync(path, JSON.stringify(value) + "\n");
' "${FINAL_QA_RECEIPT}"
if CMDTAB_RELEASE_DIR="${REPO}/dist" \
   CMDTAB_RELEASE_VERIFIER="${REPO}/scripts/mock-release-verifier.sh" \
   "${REPO}/scripts/aggregate_release_evidence.sh" >"${TMP_DIR}/aggregate-forged-binding.log" 2>&1; then
    fail "Evidence aggregator accepted a forged final-QA binding"
fi
cp "${TMP_DIR}/final-qa-receipt.json" "${FINAL_QA_RECEIPT}"
node -e '
const { readFileSync, writeFileSync } = require("node:fs");
const path = process.argv[1];
const value = JSON.parse(readFileSync(path, "utf8"));
value.reviewedAt = "2000-01-01T00:00:00.000Z";
value.evidenceCreatedAt = value.reviewedAt;
writeFileSync(path, JSON.stringify(value) + "\n");
' "${FINAL_QA_RECEIPT}"
if CMDTAB_RELEASE_DIR="${REPO}/dist" \
   CMDTAB_RELEASE_VERIFIER="${REPO}/scripts/mock-release-verifier.sh" \
   "${REPO}/scripts/aggregate_release_evidence.sh" >"${TMP_DIR}/aggregate-premature-review.log" 2>&1; then
    fail "Evidence aggregator accepted a final-QA review that predates its evidence"
fi
cp "${TMP_DIR}/final-qa-receipt.json" "${FINAL_QA_RECEIPT}"

cp "${REPO}/dist/backup-restore-receipt.json" "${TMP_DIR}/backup-restore-receipt.json"
node -e '
const { readFileSync, writeFileSync } = require("node:fs");
const path = process.argv[1];
const value = JSON.parse(readFileSync(path, "utf8"));
value.inputReceipts.backup.sha256 = "d".repeat(64);
writeFileSync(path, JSON.stringify(value) + "\n");
' "${REPO}/dist/backup-restore-receipt.json"
if CMDTAB_RELEASE_DIR="${REPO}/dist" \
   CMDTAB_RELEASE_VERIFIER="${REPO}/scripts/mock-release-verifier.sh" \
   "${REPO}/scripts/aggregate_release_evidence.sh" >"${TMP_DIR}/aggregate-forged-backup.log" 2>&1; then
    fail "Evidence aggregator accepted forged backup input evidence"
fi
cp "${TMP_DIR}/backup-restore-receipt.json" "${REPO}/dist/backup-restore-receipt.json"

NEON_RECEIPT="${REPO}/dist/neon-recovery-receipt.json"
cp "${NEON_RECEIPT}" "${TMP_DIR}/neon-recovery-receipt.json"
node -e '
const { readFileSync, writeFileSync } = require("node:fs");
const path = process.argv[1];
const value = JSON.parse(readFileSync(path, "utf8"));
value.historyRetentionSeconds = 86400;
value.pitrDays = 1;
writeFileSync(path, JSON.stringify(value) + "\n");
' "${NEON_RECEIPT}"
if CMDTAB_RELEASE_DIR="${REPO}/dist" \
   CMDTAB_RELEASE_VERIFIER="${REPO}/scripts/mock-release-verifier.sh" \
   "${REPO}/scripts/aggregate_release_evidence.sh" >"${TMP_DIR}/aggregate-forged-neon.log" 2>&1; then
    fail "Evidence aggregator accepted forged Neon recovery retention"
fi
cp "${TMP_DIR}/neon-recovery-receipt.json" "${NEON_RECEIPT}"

for ignore_pattern in \
    '/.git' '/.build' '/CmdTab.app' '/dist' \
    '/website/node_modules' '/website/.next' '/website/.env' '/website/.env.local'; do
    grep -Fxq "${ignore_pattern}" "${ROOT_DIR}/.vercelignore" \
        || fail "Root .vercelignore is missing ${ignore_pattern}"
done
grep -Fxq '.env' "${ROOT_DIR}/website/.vercelignore" \
    || fail "Website .vercelignore must exclude local environment files"
grep -Fxq 'node_modules' "${ROOT_DIR}/website/.vercelignore" \
    || fail "Website .vercelignore must exclude dependencies"
if grep -Eq '^/?website($|/\*\*)' "${ROOT_DIR}/.vercelignore"; then
    fail "Root .vercelignore must preserve website source"
fi
if rg -n 'uses: [^#[:space:]]+@v[0-9]+([[:space:]]|$)' \
    "${ROOT_DIR}/.github/workflows" >/dev/null; then
    fail "Production workflows must pin actions to immutable commits"
fi

echo "Production operations regression checks passed"
