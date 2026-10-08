#!/usr/bin/env node

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const read = (path) => readFileSync(resolve(root, path), "utf8");

// Enrollment and trial reminders are deliberately closed during waitlist mode.
// Active customer APIs retain their bounded input and abuse protection below.
for (const [path, method, code] of [
  ["src/app/api/trial/start/route.ts", "POST", "trial_unavailable"],
  ["src/app/api/trial/reminder/route.ts", "GET", "waitlist_only"],
]) {
  const source = read(path);
  assert.match(source, /export const dynamic = "force-dynamic"/);
  assert.match(source, new RegExp(`export async function ${method}\\(\\) \\{\\s*return ingestJsonResponse\\(\\{[\\s\\S]*?code: "${code}"[\\s\\S]*?\\}, 403\\);\\s*\\}`));
  assert.doesNotMatch(source, /readBounded|request\.json|request\.text|process\.env|fetch\(|getSql|getServerEnv|createOrGetTrialClaim|issueCmdTabToken|emails\.send|markTrialReminderSent/,
    "closed public trial routes must not parse bodies or reach configuration, storage, signing, or email sinks");
}
const ingest = read("src/lib/ingest-request.ts");
assert.match(ingest, /"Cache-Control": "no-store, max-age=0"/);
assert.match(ingest, /"X-Content-Type-Options": "nosniff"/);
const stableReleaseRoute = read("src/app/releases/stable.json/route.ts");
assert.match(stableReleaseRoute, /error: "waitlist_only"/);
assert.match(stableReleaseRoute, /status: 503/);
assert.match(stableReleaseRoute, /"Cache-Control": "no-store"/);
assert.doesNotMatch(stableReleaseRoute, /getStableReleaseManifest|dmgURL|readFileSync/);

const waitlist = read("src/app/api/waitlist/route.ts");
assert.match(waitlist, /waitlistPayloadSchema\.parse\(body\)/);
assert.match(waitlist, /!isSameOriginFormRequest\(request\) \|\| !passesFetchSiteProtection\(request\)/);
assert.match(waitlist, /checkRateLimit\(\{/);
assert.match(waitlist, /code: "rate_limited"[\s\S]*?429/);
assert.match(waitlist, /if \(!isWaitlistStoreConfigured\(\)\) \{[\s\S]*?503/,
  "waitlist persistence must be mandatory; email delivery alone cannot report enrollment success");
assert.ok(waitlist.indexOf("await upsertWaitlistSubmission(") < waitlist.indexOf("const deliveryTasks ="),
  "waitlist enrollment must be persisted before email notification begins");
assert.match(waitlist, /consent: "waitlist_updates_v1", consent_at: new Date\(\)\.toISOString\(\)/);
assert.match(waitlist, /if \(alreadyRegistered\) \{[\s\S]*?return jsonResponse/);
assert.doesNotMatch(waitlist, /recentlySubmitted\(/,
  "a duplicate fingerprint must not pretend an email exists in durable storage");
assert.match(waitlist, /notificationDelivered = false/);
assert.match(waitlist, /updateWaitlistNotificationStatus\(storedSubmission\.email, "failed"/);
assert.match(waitlist, /code: "service_unavailable"[\s\S]*?503/);
const formOrigin = read("src/lib/form-request-origin.ts");
assert.match(formOrigin, /request\.headers\.get\("host"\)/);
assert.match(formOrigin, /parsed\.origin === expected/);
const validation = read("src/lib/validation.ts");
assert.match(validation, /consent: z\.literal\(true/);
assert.match(validation, /honeypot: z\.string\(\)\.max\(0\)/);
const waitlistStore = read("src/lib/waitlist-store.ts");
assert.match(waitlistStore, /email text not null unique/);
assert.match(waitlistStore, /on conflict \(email\) do nothing/);
assert.match(waitlistStore, /alreadyRegistered: true/);

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

// A nonce-based strict CSP cannot protect a statically prerendered App Router
// page: build-time framework scripts have no request nonce and are blocked in
// production. The root layout must therefore keep every inherited page dynamic.
const proxy = read("src/proxy.ts");
const csp = read("src/lib/content-security-policy.ts");
const layout = read("src/app/layout.tsx");
const globalStyles = read("src/app/globals.css");
assert.match(proxy, /requestHeaders\.set\("x-nonce", nonce\)/);
assert.match(proxy, /requestHeaders\.set\("Content-Security-Policy", policy\)/);
assert.match(csp, /script-src 'self' 'nonce-\$\{nonce\}' 'strict-dynamic'/);
if (/\.motion-reveal\s*\{[\s\S]*?opacity:\s*0/.test(globalStyles)) {
  assert.match(
    layout,
    /export const dynamic = "force-dynamic"/,
    "nonce-protected pages with hydration-dependent hidden content must be dynamically rendered",
  );
}

console.log("API security source verification passed");
