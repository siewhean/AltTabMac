import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { generateKeyPairSync } from "node:crypto";

import {
  shouldRequireBetaTrialReadiness,
  validateBetaTrialEnvironment,
} from "../scripts/verify-beta-trial-readiness.mjs";

const verifierPath = fileURLToPath(
  new URL("../scripts/verify-beta-trial-readiness.mjs", import.meta.url),
);

function betaTrialEnvironment() {
  const { publicKey } = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  return {
    CMDTAB_REQUIRE_BETA_TRIAL_READY: "1",
    DATABASE_URL: "postgres://user:password@db.example.net:5432/cmdtab",
    AWS_REGION: "us-east-1",
    AWS_ROLE_ARN: "arn:aws:iam::123456789012:role/cmdtab-trial",
    CMDTAB_TRIAL_KMS_KEY_ID: "trial-key",
    CMDTAB_TRIAL_SIGNING_KID: "trial-2026-01",
    CMDTAB_TRIAL_PUBLIC_KEYRING_JSON: JSON.stringify({
      "trial-2026-01": publicKey.export({ format: "der", type: "spki" }).toString("base64"),
    }),
    VERCEL_OIDC_TOKEN: "injected-by-vercel-at-runtime",
  };
}

test("beta trial readiness has no commerce or paid-license prerequisite", () => {
  assert.deepEqual(validateBetaTrialEnvironment(betaTrialEnvironment()), []);
});

test("beta trial readiness rejects missing trial configuration without enabling commerce", () => {
  const issues = validateBetaTrialEnvironment({
    CMDTAB_REQUIRE_BETA_TRIAL_READY: "1",
    DATABASE_URL: "invalid",
    CMDTAB_TRIAL_PRIVATE_KEY_PEM: "forbidden",
    CMDTAB_LICENSE_PRIVATE_KEY_PEM: "also-forbidden",
  });
  assert.ok(issues.some((issue) => issue.includes("CMDTAB_TRIAL_KMS_KEY_ID")));
  assert.ok(issues.some((issue) => issue.includes("CMDTAB_TRIAL_PRIVATE_KEY_PEM is forbidden")));
  assert.ok(issues.some((issue) => issue.includes("CMDTAB_LICENSE_PRIVATE_KEY_PEM is forbidden")));
  assert.equal(issues.some((issue) => issue.includes("LICENSE_KMS")), false);
  assert.equal(issues.some((issue) => issue.includes("CHECKOUT")), false);
});

test("beta trial readiness is explicitly enabled", () => {
  assert.equal(shouldRequireBetaTrialReadiness({}), false);
  assert.equal(shouldRequireBetaTrialReadiness({ CMDTAB_REQUIRE_BETA_TRIAL_READY: "1" }), true);
});

test("readiness CLI fails closed only when beta trial readiness is requested", () => {
  const disabled = spawnSync(process.execPath, [verifierPath], {
    env: {}, encoding: "utf8",
  });
  assert.equal(disabled.status, 0, disabled.stderr);
  assert.match(disabled.stdout, /remains fail-closed/);

  const required = spawnSync(process.execPath, [verifierPath], {
    env: { CMDTAB_REQUIRE_BETA_TRIAL_READY: "1" }, encoding: "utf8",
  });
  assert.equal(required.status, 1);
  assert.match(required.stderr, /Beta trial configuration is incomplete/);
  assert.match(required.stderr, /CMDTAB_TRIAL_KMS_KEY_ID/);
});
