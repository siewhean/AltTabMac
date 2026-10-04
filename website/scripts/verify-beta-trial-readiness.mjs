#!/usr/bin/env node

import { pathToFileURL } from "node:url";
import { createPublicKey } from "node:crypto";

const REQUIRED_NONEMPTY = [
  "DATABASE_URL",
  "AWS_REGION",
  "AWS_ROLE_ARN",
  "VERCEL_OIDC_TOKEN",
  "CMDTAB_TRIAL_KMS_KEY_ID",
  "CMDTAB_TRIAL_SIGNING_KID",
  "CMDTAB_TRIAL_PUBLIC_KEYRING_JSON",
];

function value(env, name) {
  const candidate = env[name];
  return typeof candidate === "string" ? candidate.trim() : "";
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

function validKeyring(candidate, kid) {
  try {
    const parsed = JSON.parse(candidate);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return false;
    if (typeof parsed[kid] !== "string") return false;
    return Object.entries(parsed).every(([entryKid, encoded]) => {
      if (!/^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$/.test(entryKid)) return false;
      if (typeof encoded !== "string") return false;
      const der = Buffer.from(encoded, "base64");
      if (!der.byteLength || der.toString("base64") !== encoded) return false;
      const key = createPublicKey({ key: der, format: "der", type: "spki" });
      return (
        key.asymmetricKeyType === "ec" &&
        key.asymmetricKeyDetails?.namedCurve === "prime256v1"
      );
    });
  } catch {
    return false;
  }
}

/**
 * Beta entitlement issuance needs its claim database and trial signing key
 * only. This deliberately has no checkout, paid-license, delivery-email, or
 * license-keyring prerequisite.
 */
export function validateBetaTrialEnvironment(env) {
  const issues = [];
  for (const name of REQUIRED_NONEMPTY) {
    if (!value(env, name)) issues.push(`${name} is missing`);
  }
  if (!validPostgresUrl(value(env, "DATABASE_URL"))) {
    issues.push("DATABASE_URL must be a valid PostgreSQL connection URL");
  }
  const kid = value(env, "CMDTAB_TRIAL_SIGNING_KID");
  if (!/^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$/.test(kid)) {
    issues.push("CMDTAB_TRIAL_SIGNING_KID contains unsupported characters");
  }
  if (!validKeyring(value(env, "CMDTAB_TRIAL_PUBLIC_KEYRING_JSON"), kid)) {
    issues.push("CMDTAB_TRIAL_PUBLIC_KEYRING_JSON must contain the configured trial kid");
  }
  if (value(env, "CMDTAB_TRIAL_PRIVATE_KEY_PEM")) {
    issues.push("CMDTAB_TRIAL_PRIVATE_KEY_PEM is forbidden for beta trial readiness");
  }
  if (value(env, "CMDTAB_LICENSE_PRIVATE_KEY_PEM")) {
    issues.push("CMDTAB_LICENSE_PRIVATE_KEY_PEM is forbidden for beta trial readiness");
  }
  return issues;
}

export function shouldRequireBetaTrialReadiness(env) {
  return value(env, "CMDTAB_REQUIRE_BETA_TRIAL_READY") === "1";
}

function run() {
  if (!shouldRequireBetaTrialReadiness(process.env)) {
    console.log("Beta trial readiness gate is disabled; beta entitlement issuance remains fail-closed.");
    return;
  }
  const issues = validateBetaTrialEnvironment(process.env);
  if (issues.length > 0) {
    console.error("Beta trial configuration is incomplete:");
    for (const issue of issues) console.error(`- ${issue}`);
    process.exitCode = 1;
    return;
  }
  console.log("Beta trial readiness verification passed.");
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  run();
}
