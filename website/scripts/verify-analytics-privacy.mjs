#!/usr/bin/env node

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const read = (path) => readFileSync(resolve(root, path), "utf8");

const controls = read("src/components/analytics-consent-controls.tsx");
assert.match(
  controls,
  /<Analytics beforeSend=\{consentAwareVercelAnalyticsBeforeSend\}/,
  "Vercel Analytics must retain a live consent-aware beforeSend hook",
);
assert.match(
  controls,
  /<SpeedInsights beforeSend=\{consentAwareSpeedInsightsBeforeSend\}/,
  "Vercel Speed Insights must retain a live consent-aware beforeSend hook",
);
assert.equal(
  controls.match(/getAnalyticsConsent\(\) === "accepted" \? event : null/g)?.length,
  2,
  "both Vercel request hooks must fail closed when consent is absent",
);

const pageTracker = read("src/components/site-page-tracker.tsx");
assert.match(pageTracker, /addEventListener\("storage", handleConsentStorage\)/);
assert.match(pageTracker, /lastTrackedPath\.current = null/);
assert.match(pageTracker, /getAnalyticsConsent\(\) !== "accepted"/);

const appUsageStore = read("src/lib/app-usage-store.ts");
assert.doesNotMatch(
  appUsageStore,
  /touchTrialClaim/,
  "generic optional telemetry must not mutate essential trial records",
);

console.log("Analytics privacy source verification passed");
