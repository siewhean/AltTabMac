import assert from "node:assert/strict";
import { createSign, generateKeyPairSync } from "node:crypto";
import test from "node:test";

import {
  AWS_KMS_P256_SIGNING_ALGORITHM,
  AwsKmsP256Signer,
  getTrialTokenSigner,
  loadCmdTabKmsSigningConfiguration,
  loadCmdTabPublicKeyrings,
  type AwsKmsP256Client,
} from "../src/lib/aws-kms-p256.js";
import {
  validateCmdTabTokenV2Payload,
  verifyCmdTabEntitlementToken,
  verifyCmdTabTokenV2,
} from "../src/lib/entitlement-token.js";
import {
  issueCmdTabTokenV2,
  LocalPemP256Signer,
} from "../src/lib/license-signing.js";
import { issueCmdTabLicenseToken } from "../src/lib/license-token.js";

function signingMaterials() {
  const { privateKey, publicKey } = generateKeyPairSync("ec", {
    namedCurve: "prime256v1",
  });
  return {
    privateKey,
    privateKeyPem: privateKey.export({ format: "pem", type: "pkcs8" }).toString(),
    publicKeyPem: publicKey.export({ format: "pem", type: "spki" }).toString(),
    publicKeyDer: publicKey.export({ format: "der", type: "spki" }),
  };
}

test("token v2 hashes identifiers, binds activation, and remains offline-valid", async () => {
  const materials = signingMaterials();
  const signer = new LocalPemP256Signer("license-2026-01", materials.privateKeyPem);
  const issued = await issueCmdTabTokenV2({
    signer,
    typ: "license",
    subjectIdentifier: "Owner@Example.com",
    orderIdentifier: "order-123",
    binding: { typ: "activation", value: "device-secret" },
    issuedAt: new Date("2026-07-27T00:00:00Z"),
  });

  assert.equal(issued.payload.v, 2);
  assert.equal(issued.payload.aud, "cmdtab");
  assert.equal(issued.payload.typ, "license");
  assert.equal(issued.payload.updates, "1.x");
  assert.equal(issued.payload.exp, undefined);
  assert.equal(issued.payload.sub.length, 64);
  assert.equal(issued.payload.order.length, 64);
  assert.equal(issued.token.includes("Owner@Example.com"), false);
  assert.equal(issued.token.includes("order-123"), false);

  const verified = verifyCmdTabTokenV2({
    token: issued.token,
    keyring: { [signer.kid]: materials.publicKeyDer },
    expectedType: "license",
    expectedBinding: { typ: "activation", value: "device-secret" },
    now: new Date("2036-07-27T00:00:00Z"),
  });
  assert.equal(verified?.tokenVersion, 2);
  assert.equal(verified?.kind, "license");
  assert.equal(
    verifyCmdTabTokenV2({
      token: issued.token,
      keyring: { [signer.kid]: materials.publicKeyDer },
      expectedBinding: { typ: "activation", value: "wrong-device" },
    }),
    null,
  );
});

test("trial v2 is install-bound and exactly fourteen UTC days", async () => {
  const materials = signingMaterials();
  const signer = new LocalPemP256Signer("trial-2026-01", materials.privateKeyPem);
  const issued = await issueCmdTabTokenV2({
    signer,
    typ: "trial",
    subjectIdentifier: "owner@example.com",
    orderIdentifier: "trial-claim-123",
    binding: { typ: "install", value: "install-secret" },
    issuedAt: new Date("2026-07-27T00:00:00Z"),
  });

  assert.equal(issued.payload.exp! - issued.payload.iat, 14 * 24 * 60 * 60);
  assert.ok(
    verifyCmdTabTokenV2({
      token: issued.token,
      keyring: { [signer.kid]: materials.publicKeyDer },
      expectedType: "trial",
      expectedBinding: { typ: "install", value: "install-secret" },
      now: new Date("2026-08-09T23:59:59Z"),
    }),
  );
  assert.equal(
    verifyCmdTabTokenV2({
      token: issued.token,
      keyring: { [signer.kid]: materials.publicKeyDer },
      now: new Date("2026-08-10T00:00:00Z"),
    }),
    null,
  );
});

test("purchase-like types and wrong binding classes never grant entitlement", async () => {
  const materials = signingMaterials();
  const signer = new LocalPemP256Signer("license-2026-01", materials.privateKeyPem);
  await assert.rejects(() =>
    issueCmdTabTokenV2({
      signer,
      typ: "license",
      subjectIdentifier: "owner@example.com",
      orderIdentifier: "order-123",
      binding: { typ: "install", value: "install-secret" },
    }),
  );
  assert.equal(
    validateCmdTabTokenV2Payload({
      v: 2,
      kid: "purchase-2026-01",
      typ: "purchase",
      aud: "cmdtab",
      sub: "a".repeat(64),
      order: "b".repeat(64),
      binding: { typ: "activation", hash: "c".repeat(64) },
      iat: 1_800_000_000,
      updates: "1.x",
    }),
    null,
  );
});

test("AWS KMS adapter requests RAW ECDSA SHA-256 and validates key use", async () => {
  const materials = signingMaterials();
  let signInput:
    | { MessageType: string; SigningAlgorithm: string }
    | undefined;
  const client: AwsKmsP256Client = {
    async sign(input) {
      signInput = input;
      const signer = createSign("sha256");
      signer.update(Buffer.from(input.Message));
      signer.end();
      return {
        Signature: signer.sign({
          key: materials.privateKey,
          dsaEncoding: "der",
        }),
      };
    },
    async getPublicKey() {
      return {
        PublicKey: materials.publicKeyDer,
        KeyUsage: "SIGN_VERIFY",
        SigningAlgorithms: [AWS_KMS_P256_SIGNING_ALGORITHM],
      };
    },
  };
  const signer = new AwsKmsP256Signer(
    "license-2026-01",
    "arn:aws:kms:us-east-1:123:key/license",
    client,
  );
  const issued = await issueCmdTabTokenV2({
    signer,
    typ: "license",
    subjectIdentifier: "owner@example.com",
    orderIdentifier: "order-123",
    binding: { typ: "activation", value: "device-secret" },
  });

  assert.ok(
    verifyCmdTabTokenV2({
      token: issued.token,
      keyring: { [signer.kid]: await signer.getPublicKeyDer() },
    }),
  );
  assert.equal(signInput?.MessageType, "RAW");
  assert.equal(signInput?.SigningAlgorithm, "ECDSA_SHA_256");
});

test("production config rejects PEM and requires separate trial/license keys", () => {
  const base = {
    AWS_REGION: "us-east-1",
    CMDTAB_TRIAL_KMS_KEY_ID: "trial-key",
    CMDTAB_TRIAL_SIGNING_KID: "trial-2026-01",
    CMDTAB_LICENSE_KMS_KEY_ID: "license-key",
    CMDTAB_LICENSE_SIGNING_KID: "license-2026-01",
  };
  assert.deepEqual(loadCmdTabKmsSigningConfiguration(base), {
    region: "us-east-1",
    trial: { keyId: "trial-key", kid: "trial-2026-01" },
    license: { keyId: "license-key", kid: "license-2026-01" },
  });
  assert.throws(() =>
    loadCmdTabKmsSigningConfiguration({
      ...base,
      VERCEL_ENV: "production",
      CMDTAB_LICENSE_PRIVATE_KEY_PEM: "exported-secret",
    }),
  );
  assert.throws(() =>
    loadCmdTabKmsSigningConfiguration({
      ...base,
      CMDTAB_LICENSE_KMS_KEY_ID: "trial-key",
    }),
  );
});

test("local route signer and public keyrings are explicit and hermetic", async () => {
  const trial = signingMaterials();
  const license = signingMaterials();
  const env = {
    CMDTAB_TRIAL_PRIVATE_KEY_PEM: trial.privateKeyPem,
    CMDTAB_TRIAL_SIGNING_KID: "trial-local",
    CMDTAB_TRIAL_PUBLIC_KEYRING_JSON: JSON.stringify({
      "trial-local": trial.publicKeyDer.toString("base64"),
    }),
    CMDTAB_LICENSE_PUBLIC_KEYRING_JSON: JSON.stringify({
      "license-local": license.publicKeyDer.toString("base64"),
    }),
  };
  const signer = getTrialTokenSigner(env);
  assert.equal(signer.kid, "trial-local");
  assert.deepEqual(loadCmdTabPublicKeyrings(env), {
    trial: { "trial-local": trial.publicKeyDer.toString("base64") },
    license: { "license-local": license.publicKeyDer.toString("base64") },
  });
  assert.deepEqual(await signer.getPublicKeyDer(), trial.publicKeyDer);
});

test("v1 paid licenses verify during migration", () => {
  const materials = signingMaterials();
  const issued = issueCmdTabLicenseToken({
    privateKeyPem: materials.privateKeyPem,
    email: "owner@example.com",
    licenseID: "ORDER-123",
    issuedAt: "2026-07-27T00:00:00Z",
  });
  const verified = verifyCmdTabEntitlementToken({
    token: issued.token,
    v2Keyring: {},
    legacyV1PublicKeyPem: materials.publicKeyPem,
    expectedType: "license",
  });
  assert.equal(verified?.tokenVersion, 1);
  assert.equal(verified?.kind, "license");
});
