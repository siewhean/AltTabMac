import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  shouldRequireCommerceReadiness,
  validateCommerceEnvironment,
} from "../scripts/verify-commerce-readiness.mjs";

const verifierPath = fileURLToPath(
  new URL("../scripts/verify-commerce-readiness.mjs", import.meta.url),
);

function validEnvironment() {
  return {
    VERCEL_ENV: "production",
    CMDTAB_REQUIRE_COMMERCE_READY: "1",
    NEXT_PUBLIC_SITE_URL: "https://cmdtab.net",
    NEXT_PUBLIC_CHECKOUT_PROVIDER: "lemonsqueezy",
    NEXT_PUBLIC_CHECKOUT_URL: "https://store.cmdtab.net/checkout/buy/test",
    DATABASE_URL: "postgres://user:password@db.example.net:5432/cmdtab",
    RESEND_API_KEY: "re_test_value",
    WAITLIST_FROM_EMAIL: "hello@cmdtab.net",
    WAITLIST_TO_EMAIL: "owner@cmdtab.net",
    LEMONSQUEEZY_WEBHOOK_SECRET: "webhook-secret-value",
    LICENSE_DELIVERY_FROM_EMAIL: "hello@cmdtab.net",
    CMDTAB_LICENSE_LOOKUP_PEPPER: "lookup-pepper-with-at-least-thirty-two-characters",
    CMDTAB_LICENSE_OUTBOX_SECRET: "outbox-secret-with-at-least-thirty-two-characters",
    CRON_SECRET: "cron-secret-with-at-least-thirty-two-characters",
    CMDTAB_LEMONSQUEEZY_STORE_ID: "10",
    CMDTAB_LEMONSQUEEZY_PRODUCT_ID: "20",
    CMDTAB_LEMONSQUEEZY_VARIANT_ID: "30",
    CMDTAB_LEMONSQUEEZY_EXPECT_TEST_MODE: "false",
    AWS_REGION: "us-east-1",
    AWS_ROLE_ARN: "arn:aws:iam::123456789012:role/cmdtab",
    CMDTAB_TRIAL_KMS_KEY_ID: "trial-key",
    CMDTAB_TRIAL_SIGNING_KID: "trial-2026-01",
    CMDTAB_LICENSE_KMS_KEY_ID: "license-key",
    CMDTAB_LICENSE_SIGNING_KID: "license-2026-01",
    CMDTAB_TRIAL_PUBLIC_KEYRING_JSON: JSON.stringify({
      "trial-2026-01": "base64-trial-public-key",
    }),
    CMDTAB_LICENSE_PUBLIC_KEYRING_JSON: JSON.stringify({
      "license-2026-01": "base64-license-public-key",
    }),
  };
}

test("complete production commerce configuration passes the release guard", () => {
  assert.deepEqual(validateCommerceEnvironment(validEnvironment()), []);
});

test("production commerce guard reports missing checkout, secrets, database, and KMS boundaries", () => {
  const issues = validateCommerceEnvironment({
    VERCEL_ENV: "production",
    NEXT_PUBLIC_CHECKOUT_PROVIDER: "custom",
    NEXT_PUBLIC_CHECKOUT_URL: "http://example.com/checkout",
    DATABASE_URL: "not-a-database-url",
    CMDTAB_LEMONSQUEEZY_EXPECT_TEST_MODE: "true",
    CMDTAB_LICENSE_PRIVATE_KEY_PEM: "forbidden",
  });

  assert.ok(issues.some((issue) => issue.includes("NEXT_PUBLIC_CHECKOUT_PROVIDER")));
  assert.ok(issues.some((issue) => issue.includes("NEXT_PUBLIC_CHECKOUT_URL")));
  assert.ok(issues.some((issue) => issue.includes("DATABASE_URL")));
  assert.ok(issues.some((issue) => issue.includes("WAITLIST_TO_EMAIL")));
  assert.ok(issues.some((issue) => issue.includes("CMDTAB_LICENSE_LOOKUP_PEPPER")));
  assert.ok(issues.some((issue) => issue.includes("CMDTAB_LICENSE_KMS_KEY_ID")));
  assert.ok(issues.some((issue) => issue.includes("CMDTAB_LICENSE_PRIVATE_KEY_PEM is forbidden")));
  assert.ok(issues.some((issue) => issue.includes("EXPECT_TEST_MODE must be false")));
});

test("commerce readiness enforcement is an explicit launch switch in every environment", () => {
  assert.equal(shouldRequireCommerceReadiness({ VERCEL_ENV: "production" }), false);
  assert.equal(shouldRequireCommerceReadiness({ VERCEL_ENV: "preview" }), false);
  assert.equal(
    shouldRequireCommerceReadiness({
      VERCEL_ENV: "production",
      CMDTAB_REQUIRE_COMMERCE_READY: "1",
    }),
    true,
  );
  assert.equal(
    shouldRequireCommerceReadiness({
      VERCEL_ENV: "preview",
      CMDTAB_REQUIRE_COMMERCE_READY: "1",
    }),
    true,
  );
});

test("production deployment remains safe when the commerce launch switch is disabled", () => {
  const result = spawnSync(process.execPath, [verifierPath], {
    env: { VERCEL_ENV: "production" },
    encoding: "utf8",
  });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /checkout and fulfilment remain fail-closed/);
});

test("readiness CLI fails closed for an incomplete forced deployment", () => {
  const result = spawnSync(process.execPath, [verifierPath], {
    env: { CMDTAB_REQUIRE_COMMERCE_READY: "1" },
    encoding: "utf8",
  });

  assert.equal(result.status, 1);
  assert.match(result.stderr, /Production commerce configuration is incomplete/);
  assert.match(result.stderr, /NEXT_PUBLIC_CHECKOUT_URL/);
  assert.match(result.stderr, /CMDTAB_LICENSE_KMS_KEY_ID/);
});

test("readiness CLI succeeds for a complete production environment", () => {
  const result = spawnSync(process.execPath, [verifierPath], {
    env: validEnvironment(),
    encoding: "utf8",
  });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Production commerce readiness verification passed/);
});
