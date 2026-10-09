#!/usr/bin/env node

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const read = (path) => readFileSync(resolve(root, path), "utf8");

const trial = read("src/app/api/trial/start/route.ts");
assert.match(trial, /readBoundedJson\(request, MAX_REQUEST_BODY_BYTES\)/);
assert.match(trial, /enforceIngestRateLimit\(request, "trial-start"\)/);
assert.match(trial, /installId: z\.string\(\)\.trim\(\)\.regex\(\/\^\[a-f0-9\]\{64\}\$\/\)/);
assert.match(trial, /code: "trial_unavailable"/);
assert.doesNotMatch(trial, /code: result\.reason/);

const recovery = read("src/app/api/license/recover/route.ts");
assert.match(recovery, /enforceIngestRateLimit\([\s\S]*"license-recovery"/);
assert.match(recovery, /getIngestClient\(request\)\.ip/);
assert.doesNotMatch(recovery, /request\.headers\.get\("x-real-ip"\)/);

const activation = read("src/app/api/license/activate/route.ts");
assert.match(activation, /"license-activation"/);

const webhook = read("src/app/api/lemonsqueezy/webhook/route.ts");
assert.match(
  webhook,
  /export async function POST\(request: Request\) \{[\s\S]*?if \(!isCommerceLaunchEnabled\(\)\) \{\s*return json\(\s*\{[\s\S]*?code: "commerce_disabled"[\s\S]*?\},\s*503,\s*\);\s*\}\s*const env = getServerEnv\(\);/,
  "webhook must return before configuration or database access while commerce is disabled",
);
assert.match(webhook, /readBoundedText\(request, MAX_WEBHOOK_BODY_BYTES\)/);
assert.doesNotMatch(webhook, /await request\.text\(\)/);
assert.match(webhook, /fulfillPaidPurchase\(/);
assert.match(webhook, /createOrGetFulfillment: createOrGetLicenseFulfillment/);
assert.match(webhook, /reportInlineDeliveryFailure\(error\)/);

const purchaseFulfillment = read("src/lib/purchase-fulfillment.ts");
assert.match(purchaseFulfillment, /issuePurchaseActivationCredential\(\)/);
assert.match(purchaseFulfillment, /ensureActiveEntitlement\(/);
assert.match(purchaseFulfillment, /enqueueLicenseEmail\(/);
assert.match(purchaseFulfillment, /processLicenseOutbox\(1\)/);
assert.match(purchaseFulfillment, /deliveryStatus === "delivered"/);
assert.match(purchaseFulfillment, /purchase:\$\{fulfillment\.orderIdentifier\}/);

const purchaseTests = read("tests/purchase-fulfillment.test.ts");
assert.match(purchaseTests, /duplicate delivered webhook remains idempotent/);
assert.match(purchaseTests, /email provider failure stays queued/);
assert.match(purchaseTests, /entitlement persistence failure stops/);

const reminderRoute = read("src/app/api/trial/reminder/route.ts");
assert.match(reminderRoute, /isAuthorizedInternalWorker\(\s*request,\s*optionalStrongInternalSecret\(process\.env\.CRON_SECRET\)/);
assert.doesNotMatch(reminderRoute, /if \(!secret\) return true/, "trial reminder must fail closed without CRON_SECRET");

const outboxRoute = read("src/app/api/internal/license-outbox/route.ts");
assert.match(outboxRoute, /export async function GET\(request: Request\)/);
assert.match(outboxRoute, /process\.env\.CRON_SECRET/);
assert.match(outboxRoute, /export async function POST\(request: Request\)/);
assert.match(outboxRoute, /getLicenseLifecycleEnv\(\)\.outboxSecret/);
assert.match(outboxRoute, /isAuthorizedInternalWorker\(request, secret\)/);
assert.match(outboxRoute, /isCommerceLaunchEnabled\(\)/);
assert.match(outboxRoute, /reason: "commerce_disabled"/);
assert.match(
  outboxRoute,
  /if \(!isCommerceLaunchEnabled\(\)\) \{\s*return licenseJson\(\{[\s\S]*?reason: "commerce_disabled"[\s\S]*?\}\);\s*\}\s*const result = await processLicenseOutbox\(25\);/,
  "outbox worker must return before database access while commerce is disabled",
);

const commerce = read("src/lib/commerce.ts");
assert.match(commerce, /import \{ isCommerceLaunchEnabled \} from "\.\/env(?:\.js)?"/);
assert.match(commerce, /const launchEnabled = isCommerceLaunchEnabled\(env\)/);
assert.match(
  commerce,
  /checkoutProvider: launchEnabled[\s\S]*?checkoutUrl: launchEnabled[\s\S]*?NEXT_PUBLIC_CHECKOUT_URL/,
  "public checkout provider and URL must remain hidden while commerce is disabled",
);

const workerAuth = read("src/lib/internal-worker-auth.ts");
assert.match(workerAuth, /constantTimeEqual\(bearerToken\(request\), expectedSecret\)/);
assert.match(workerAuth, /\^Bearer\\s\+\(\.\+\)\$\/i/);

const vercelConfig = JSON.parse(read("vercel.json"));
const outboxCron = vercelConfig.crons?.find(
  (cron) => cron.path === "/api/internal/license-outbox",
);
assert.ok(outboxCron, "license outbox retry cron is missing");
assert.equal(outboxCron.schedule, "15 2 * * *");

for (const path of [
  "src/lib/license-api.ts",
  "src/app/api/license-help/route.ts",
  "src/app/api/waitlist/route.ts",
]) {
  const source = read(path);
  assert.match(source, /readBounded(?:Ingest)?Json\(/);
  assert.doesNotMatch(source, /await request\.text\(\)/);
}

const rateLimit = read("src/lib/rate-limit.ts");
assert.match(rateLimit, /"trial-start"/);
assert.match(rateLimit, /"license-recovery"/);
assert.match(rateLimit, /"license-activation"/);
assert.doesNotMatch(rateLimit, /uaKey/);
assert.match(rateLimit, /SENSITIVE_INGEST_RATE_LIMITS/);
assert.match(rateLimit, /ingest_rate_limits/);
assert.match(rateLimit, /request_deduplication/);
assert.match(rateLimit, /databaseUnavailableResult/);
assert.match(rateLimit, /process\.env\.NODE_ENV !== "production"/);

const migration = read("db/migrations/001_commerce_lifecycle.sql");
assert.match(migration, /create table if not exists ingest_rate_limits/);
assert.match(migration, /create table if not exists request_deduplication/);

const auth0 = read("src/lib/auth0-oidc.ts");
assert.doesNotMatch(auth0, /acr.*includes\(/);

const env = read("src/lib/env.ts");
assert.match(env, /optionalStrongInternalSecret/);
assert.match(env, /candidate\.length < 32/);
assert.match(env, /isCommerceLaunchEnabled/);
assert.match(env, /CMDTAB_REQUIRE_COMMERCE_READY\?\.trim\(\) === "1"/);

const lifecycle = read("src/lib/license-lifecycle-store.ts");
assert.match(lifecycle, /lifecycle_backfilled_at is null/);
assert.match(lifecycle, /limit 100/);
assert.match(lifecycle, /attempts < 8/);
assert.match(lifecycle, /2 \*\* Math\.min\(attempts, 10\)/);

// Static marketing pages cannot carry a request nonce, so they use the static
// policy; the authenticated dashboard keeps the strict per-request nonce.
const proxy = read("src/proxy.ts");
const csp = read("src/lib/content-security-policy.ts");
const layout = read("src/app/layout.tsx");
assert.match(proxy, /if \(!pathname\.startsWith\("\/dashboard"\)\)/);
assert.match(proxy, /staticContentSecurityPolicy\(\)/);
assert.match(proxy, /requestHeaders\.set\("x-nonce", nonce\)/);
assert.match(proxy, /requestHeaders\.set\("Content-Security-Policy", policy\)/);
assert.match(csp, /`'self' 'nonce-\$\{nonce\}' 'strict-dynamic'`/);
assert.match(csp, /"frame-ancestors 'none'"/);
assert.match(csp, /"object-src 'none'"/);
assert.doesNotMatch(
  layout,
  /export const dynamic = "force-dynamic"/,
  "marketing pages must stay statically prerendered and CDN-cacheable",
);

console.log("API security source verification passed");
