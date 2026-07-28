#!/usr/bin/env node

import { pathToFileURL } from "node:url";

const REQUIRED_NONEMPTY = [
  "DATABASE_URL",
  "RESEND_API_KEY",
  "WAITLIST_FROM_EMAIL",
  "LEMONSQUEEZY_WEBHOOK_SECRET",
  "LICENSE_DELIVERY_FROM_EMAIL",
  "AWS_REGION",
  "AWS_ROLE_ARN",
  "CMDTAB_TRIAL_KMS_KEY_ID",
  "CMDTAB_TRIAL_SIGNING_KID",
  "CMDTAB_LICENSE_KMS_KEY_ID",
  "CMDTAB_LICENSE_SIGNING_KID",
  "CMDTAB_TRIAL_PUBLIC_KEYRING_JSON",
  "CMDTAB_LICENSE_PUBLIC_KEYRING_JSON",
] as const;

const REQUIRED_STRONG_SECRETS = [
  "CMDTAB_LICENSE_LOOKUP_PEPPER",
  "CMDTAB_LICENSE_OUTBOX_SECRET",
  "CRON_SECRET",
] as const;

const REQUIRED_POSITIVE_INTEGERS = [
  "CMDTAB_LEMONSQUEEZY_STORE_ID",
  "CMDTAB_LEMONSQUEEZY_PRODUCT_ID",
  "CMDTAB_LEMONSQUEEZY_VARIANT_ID",
] as const;

function value(env, name) {
  const candidate = env[name];
  return typeof candidate === "string" ? candidate.trim() : "";
}

function validHttpsUrl(candidate) {
  try {
    const url = new URL(candidate);
    return (
      url.protocol === "https:" &&
      Boolean(url.hostname) &&
      !url.username &&
      !url.password
    );
  } catch {
    return false;
  }
}

function validPostgresUrl(candidate) {
  try {
    const url = new URL(candidate);
    return (
      (url.protocol === "postgres:" || url.protocol === "postgresql:") &&
      Boolean(url.hostname) &&
      Boolean(url.pathname && url.pathname !== "/")
    );
  } catch {
    return false;
  }
}

function parsedKeyring(candidate) {
  try {
    const parsed = JSON.parse(candidate);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? parsed
      : null;
  } catch {
    return null;
  }
}

export function validateCommerceEnvironment(env) {
  const issues = [];

  for (const name of REQUIRED_NONEMPTY) {
    if (!value(env, name)) issues.push(`${name} is missing`);
  }

  for (const name of REQUIRED_STRONG_SECRETS) {
    if (value(env, name).length < 32) {
      issues.push(`${name} must contain at least 32 characters`);
    }
  }

  for (const name of REQUIRED_POSITIVE_INTEGERS) {
    const parsed = Number(value(env, name));
    if (!Number.isSafeInteger(parsed) || parsed < 1) {
      issues.push(`${name} must be a positive integer`);
    }
  }

  if (value(env, "NEXT_PUBLIC_CHECKOUT_PROVIDER").toLowerCase() !== "lemonsqueezy") {
    issues.push("NEXT_PUBLIC_CHECKOUT_PROVIDER must be lemonsqueezy");
  }

  const checkoutUrl = value(env, "NEXT_PUBLIC_CHECKOUT_URL");
  if (!validHttpsUrl(checkoutUrl)) {
    issues.push("NEXT_PUBLIC_CHECKOUT_URL must be a credential-free HTTPS URL");
  } else if (/example\.com$/i.test(new URL(checkoutUrl).hostname)) {
    issues.push("NEXT_PUBLIC_CHECKOUT_URL still uses an example domain");
  }

  const siteUrl = value(env, "NEXT_PUBLIC_SITE_URL") || value(env, "SITE_URL");
  if (!validHttpsUrl(siteUrl)) {
    issues.push("NEXT_PUBLIC_SITE_URL or SITE_URL must provide a valid HTTPS origin");
  }

  if (!validPostgresUrl(value(env, "DATABASE_URL"))) {
    issues.push("DATABASE_URL must be a valid PostgreSQL connection URL");
  }

  if (value(env, "CMDTAB_LEMONSQUEEZY_EXPECT_TEST_MODE") !== "false") {
    issues.push("CMDTAB_LEMONSQUEEZY_EXPECT_TEST_MODE must be false in production");
  }

  if (value(env, "CMDTAB_LICENSE_PRIVATE_KEY_PEM")) {
    issues.push("CMDTAB_LICENSE_PRIVATE_KEY_PEM is forbidden in production");
  }
  if (value(env, "CMDTAB_TRIAL_PRIVATE_KEY_PEM")) {
    issues.push("CMDTAB_TRIAL_PRIVATE_KEY_PEM is forbidden in production");
  }

  const trialKeyId = value(env, "CMDTAB_TRIAL_KMS_KEY_ID");
  const licenseKeyId = value(env, "CMDTAB_LICENSE_KMS_KEY_ID");
  if (trialKeyId && licenseKeyId && trialKeyId === licenseKeyId) {
    issues.push("trial and licence KMS keys must be different");
  }

  const trialKid = value(env, "CMDTAB_TRIAL_SIGNING_KID");
  const licenseKid = value(env, "CMDTAB_LICENSE_SIGNING_KID");
  if (trialKid && licenseKid && trialKid === licenseKid) {
    issues.push("trial and licence signing kids must be different");
  }

  const trialKeyring = parsedKeyring(value(env, "CMDTAB_TRIAL_PUBLIC_KEYRING_JSON"));
  if (!trialKeyring || !trialKid || typeof trialKeyring[trialKid] !== "string") {
    issues.push("CMDTAB_TRIAL_PUBLIC_KEYRING_JSON must contain the configured trial kid");
  }

  const licenseKeyring = parsedKeyring(value(env, "CMDTAB_LICENSE_PUBLIC_KEYRING_JSON"));
  if (!licenseKeyring || !licenseKid || typeof licenseKeyring[licenseKid] !== "string") {
    issues.push("CMDTAB_LICENSE_PUBLIC_KEYRING_JSON must contain the configured licence kid");
  }

  return issues;
}

export function shouldRequireCommerceReadiness(env) {
  return env.VERCEL_ENV === "production" || env.CMDTAB_REQUIRE_COMMERCE_READY === "1";
}

function run() {
  if (!shouldRequireCommerceReadiness(process.env)) {
    console.log("Production commerce readiness check skipped outside production.");
    return;
  }

  const issues = validateCommerceEnvironment(process.env);
  if (issues.length > 0) {
    console.error("Production commerce configuration is incomplete:");
    for (const issue of issues) console.error(`- ${issue}`);
    process.exitCode = 1;
    return;
  }

  console.log("Production commerce readiness verification passed.");
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  run();
}
