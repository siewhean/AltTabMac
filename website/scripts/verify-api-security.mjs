#!/usr/bin/env node

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const read = (path) => readFileSync(resolve(root, path), "utf8");

const trial = read("src/app/api/trial/start/route.ts");
assert.match(trial, /readBoundedJson\(request, MAX_REQUEST_BODY_BYTES\)/);
assert.match(trial, /enforceIngestRateLimit\(request, "trial-start"\)/);
assert.match(trial, /installId: z\.string\(\)\.trim\(\)\.regex\(\/\^\[a-f0-9\]\{64\}\\$\/\)/);
assert.match(trial, /code: "trial_unavailable"/);
assert.doesNotMatch(trial, /code: result\.reason/);

const recovery = read("src/app/api/license/recover/route.ts");
assert.match(recovery, /enforceIngestRateLimit\([\s\S]*"license-recovery"/);
assert.match(recovery, /getIngestClient\(request\)\.ip/);
assert.doesNotMatch(recovery, /request\.headers\.get\("x-real-ip"\)/);

const activation = read("src/app/api/license/activate/route.ts");
assert.match(activation, /"license-activation"/);

const webhook = read("src/app/api/lemonsqueezy/webhook/route.ts");
assert.match(webhook, /readBoundedText\(request, MAX_WEBHOOK_BODY_BYTES\)/);
assert.doesNotMatch(webhook, /await request\.text\(\)/);

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

const lifecycle = read("src/lib/license-lifecycle-store.ts");
assert.match(lifecycle, /lifecycle_backfilled_at is null/);
assert.match(lifecycle, /limit 100/);

console.log("API security source verification passed");
