// Must load first: maps the "@/..." alias used by the route handlers.
import "./support/route-alias.js";

import assert from "node:assert/strict";
import { generateKeyPairSync } from "node:crypto";
import test, { type TestContext } from "node:test";

import * as kms from "../src/lib/aws-kms-p256.js";
import * as fulfillmentStore from "../src/lib/license-fulfillment-store.js";
import * as lifecycleStore from "../src/lib/license-lifecycle-store.js";
import * as rateLimit from "../src/lib/rate-limit.js";
import * as trialStore from "../src/lib/trial-claim-store.js";
import {
  issueCmdTabTokenV2,
  LocalPemP256Signer,
} from "../src/lib/license-signing.js";
import { genericRecoveryResponse } from "../src/lib/license-lifecycle-contract.js";
import { POST as activate } from "../src/app/api/license/activate/route.js";
import { POST as deactivate } from "../src/app/api/license/deactivate/route.js";
import { GET as listDevices } from "../src/app/api/license/devices/route.js";
import { POST as recover } from "../src/app/api/license/recover/route.js";
import { POST as renew } from "../src/app/api/license/renew/route.js";
import { POST as startTrial } from "../src/app/api/trial/start/route.js";
import { POST as lemonWebhook } from "../src/app/api/lemonsqueezy/webhook/route.js";

// Route handlers are exercised in-process. Every store, rate limiter and
// signer is replaced with a test double, so no database, KMS, Resend or
// network access happens here. Store SQL is covered separately by
// licensing-stores.pg.test.ts against a disposable local Postgres.

const PEPPER = "route-test-pepper-with-more-than-thirty-two-bytes";
const DEVICE_A = "a".repeat(64);
const DEVICE_B = "b".repeat(64);
const ACTIVATION_CODE = `CMDTAB-ACT-${"c".repeat(43)}`;

type Json = Record<string, unknown>;

function licenseSigningMaterials() {
  const { privateKey, publicKey } = generateKeyPairSync("ec", {
    namedCurve: "prime256v1",
  });
  const kid = "license-test-01";
  return {
    signer: new LocalPemP256Signer(
      kid,
      privateKey.export({ format: "pem", type: "pkcs8" }).toString(),
    ),
    keyring: {
      [kid]: publicKey.export({ format: "der", type: "spki" }).toString("base64"),
    },
  };
}

const signing = licenseSigningMaterials();

function setEnv(t: TestContext, values: Record<string, string | undefined>) {
  const previous = new Map<string, string | undefined>();
  for (const [key, value] of Object.entries(values)) {
    previous.set(key, process.env[key]);
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
  t.after(() => {
    for (const [key, value] of previous) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });
}

function allowRateLimits(t: TestContext) {
  const ingest = t.mock.method(rateLimit, "checkIngestRateLimit", async () => ({
    allowed: true as const,
    fingerprint: "ingest-fingerprint",
  }));
  const form = t.mock.method(rateLimit, "checkRateLimit", async () => ({
    allowed: true as const,
    fingerprint: "form-fingerprint",
  }));
  return { ingest, form };
}

function useLicenseSigning(t: TestContext) {
  t.mock.method(kms, "loadCmdTabPublicKeyrings", () => ({
    trial: {},
    license: signing.keyring,
  }));
  t.mock.method(kms, "getLicenseTokenSigner", () => signing.signer);
}

function jsonRequest(path: string, body: unknown, headers: Record<string, string> = {}) {
  return new Request(`https://cmdtab.net${path}`, {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

async function read(response: Response) {
  return { status: response.status, body: (await response.json()) as Json };
}

async function leaseToken(input: { deviceId: string; issuedAt?: Date }) {
  const issued = await issueCmdTabTokenV2({
    signer: signing.signer,
    typ: "license",
    subjectIdentifier: "owner@example.com",
    orderIdentifier: "order-renew-1",
    binding: { typ: "activation", value: input.deviceId },
    issuedAt: input.issuedAt,
  });
  return issued;
}

// ---------------------------------------------------------------- renew

test("renew issues a fresh lease for an active slot, even after the old lease lapsed", async (t) => {
  setEnv(t, { CMDTAB_LICENSE_LOOKUP_PEPPER: PEPPER });
  allowRateLimits(t);
  useLicenseSigning(t);
  const lapsed = await leaseToken({
    deviceId: DEVICE_A,
    issuedAt: new Date(Date.now() - 45 * 24 * 60 * 60 * 1000),
  });
  const lookup = t.mock.method(lifecycleStore, "findRenewableActivation", async () => ({
    kind: "active" as const,
    subjectHash: lapsed.payload.sub,
  }));

  const { status, body } = await read(
    await renew(
      jsonRequest("/api/license/renew", {
        entitlementToken: lapsed.token,
        deviceId: DEVICE_A,
      }),
    ),
  );

  assert.equal(status, 200);
  assert.equal(body.ok, true);
  assert.match(String(body.entitlementToken), /^CMDTAB2\./);
  assert.notEqual(body.entitlementToken, lapsed.token);
  assert.equal(lookup.mock.callCount(), 1);
  assert.deepEqual(lookup.mock.calls[0]!.arguments[0], {
    entitlementOrderHash: lapsed.payload.order,
    deviceId: DEVICE_A,
    pepper: PEPPER,
  });
});

test("renew rejects a revoked license without signing a new lease", async (t) => {
  setEnv(t, { CMDTAB_LICENSE_LOOKUP_PEPPER: PEPPER });
  allowRateLimits(t);
  useLicenseSigning(t);
  const sign = t.mock.method(signing.signer, "sign");
  const lease = await leaseToken({ deviceId: DEVICE_A });
  sign.mock.resetCalls();
  t.mock.method(lifecycleStore, "findRenewableActivation", async () => ({
    kind: "revoked" as const,
  }));

  const { status, body } = await read(
    await renew(
      jsonRequest("/api/license/renew", { entitlementToken: lease.token, deviceId: DEVICE_A }),
    ),
  );

  assert.equal(status, 403);
  assert.equal(body.code, "license_revoked");
  assert.equal(body.entitlementToken, undefined);
  assert.equal(sign.mock.callCount(), 0);
});

test("renew rejects a deactivated (inactive) slot, including a lapsed lease", async (t) => {
  setEnv(t, { CMDTAB_LICENSE_LOOKUP_PEPPER: PEPPER });
  allowRateLimits(t);
  useLicenseSigning(t);
  const lapsed = await leaseToken({
    deviceId: DEVICE_A,
    issuedAt: new Date(Date.now() - 45 * 24 * 60 * 60 * 1000),
  });
  t.mock.method(lifecycleStore, "findRenewableActivation", async () => ({
    kind: "inactive" as const,
  }));

  const { status, body } = await read(
    await renew(
      jsonRequest("/api/license/renew", { entitlementToken: lapsed.token, deviceId: DEVICE_A }),
    ),
  );

  assert.equal(status, 403);
  assert.equal(body.code, "device_inactive");
  assert.equal(body.entitlementToken, undefined);
});

test("renew rejects a lease presented by a different device before touching the store", async (t) => {
  setEnv(t, { CMDTAB_LICENSE_LOOKUP_PEPPER: PEPPER });
  allowRateLimits(t);
  useLicenseSigning(t);
  const lease = await leaseToken({ deviceId: DEVICE_A });
  const lookup = t.mock.method(lifecycleStore, "findRenewableActivation", async () => ({
    kind: "active" as const,
    subjectHash: lease.payload.sub,
  }));

  const { status, body } = await read(
    await renew(
      jsonRequest("/api/license/renew", { entitlementToken: lease.token, deviceId: DEVICE_B }),
    ),
  );

  assert.equal(status, 401);
  assert.equal(body.code, "invalid_license");
  assert.equal(lookup.mock.callCount(), 0);
});

test("renew rejects a lease signed by a key outside the license keyring", async (t) => {
  setEnv(t, { CMDTAB_LICENSE_LOOKUP_PEPPER: PEPPER });
  allowRateLimits(t);
  useLicenseSigning(t);
  const foreign = licenseSigningMaterials();
  const forged = await issueCmdTabTokenV2({
    signer: foreign.signer,
    typ: "license",
    subjectIdentifier: "owner@example.com",
    orderIdentifier: "order-renew-1",
    binding: { typ: "activation", value: DEVICE_A },
  });
  const lookup = t.mock.method(lifecycleStore, "findRenewableActivation", async () => ({
    kind: "inactive" as const,
  }));

  const { status, body } = await read(
    await renew(
      jsonRequest("/api/license/renew", { entitlementToken: forged.token, deviceId: DEVICE_A }),
    ),
  );

  assert.equal(status, 401);
  assert.equal(body.code, "invalid_license");
  assert.equal(lookup.mock.callCount(), 0);
});

test("renew fails closed with 503 when the pepper or license keyring is not configured", async (t) => {
  allowRateLimits(t);
  const lease = await leaseToken({ deviceId: DEVICE_A });
  const lookup = t.mock.method(lifecycleStore, "findRenewableActivation", async () => ({
    kind: "active" as const,
    subjectHash: lease.payload.sub,
  }));

  await t.test("missing pepper", async (st) => {
    setEnv(st, { CMDTAB_LICENSE_LOOKUP_PEPPER: undefined });
    useLicenseSigning(st);
    const { status, body } = await read(
      await renew(
        jsonRequest("/api/license/renew", { entitlementToken: lease.token, deviceId: DEVICE_A }),
      ),
    );
    assert.equal(status, 503);
    assert.equal(body.code, "not_configured");
  });

  await t.test("missing license keyring", async (st) => {
    setEnv(st, {
      CMDTAB_LICENSE_LOOKUP_PEPPER: PEPPER,
      CMDTAB_TRIAL_PUBLIC_KEYRING_JSON: undefined,
      CMDTAB_LICENSE_PUBLIC_KEYRING_JSON: undefined,
    });
    const { status, body } = await read(
      await renew(
        jsonRequest("/api/license/renew", { entitlementToken: lease.token, deviceId: DEVICE_A }),
      ),
    );
    assert.equal(status, 503);
    assert.equal(body.code, "not_configured");
  });

  assert.equal(lookup.mock.callCount(), 0);
});

// ---------------------------------------------------------- rate limits

test("license endpoints return 429 when rate limited and 503 when the limiter is unavailable", async (t) => {
  setEnv(t, { CMDTAB_LICENSE_LOOKUP_PEPPER: PEPPER });
  const lease = await leaseToken({ deviceId: DEVICE_A });
  const renewLookup = t.mock.method(lifecycleStore, "findRenewableActivation");
  const deactivateStore = t.mock.method(lifecycleStore, "deactivateDevice");
  const activateStore = t.mock.method(lifecycleStore, "activateDevice");
  const listStore = t.mock.method(lifecycleStore, "listLicensedDevices");

  const calls: Array<{ name: string; run: () => Promise<Response> }> = [
    {
      name: "renew",
      run: () =>
        renew(
          jsonRequest("/api/license/renew", { entitlementToken: lease.token, deviceId: DEVICE_A }),
        ),
    },
    {
      name: "deactivate",
      run: () =>
        deactivate(
          jsonRequest("/api/license/deactivate", {
            licenseKey: ACTIVATION_CODE,
            deviceId: DEVICE_A,
          }),
        ),
    },
    {
      name: "activate",
      run: () =>
        activate(
          jsonRequest("/api/license/activate", {
            licenseKey: ACTIVATION_CODE,
            deviceId: DEVICE_A,
            deviceName: "Test Mac",
          }),
        ),
    },
    {
      name: "devices",
      run: () =>
        listDevices(
          new Request("https://cmdtab.net/api/license/devices", {
            headers: { authorization: `Bearer ${ACTIVATION_CODE}` },
          }),
        ),
    },
  ];

  for (const [limit, expectedStatus] of [
    [{ allowed: false as const, retryAfterSeconds: 30 }, 429],
    [{ allowed: false as const, retryAfterSeconds: 60, unavailable: true as const }, 503],
  ] as const) {
    const limiter = t.mock.method(rateLimit, "checkIngestRateLimit", async () => limit);
    for (const call of calls) {
      const { status, body } = await read(await call.run());
      assert.equal(status, expectedStatus, `${call.name} status`);
      assert.equal(body.code, "rate_limited", `${call.name} code`);
    }
    assert.deepEqual(
      limiter.mock.calls.map((entry) => entry.arguments[0]!.endpoint),
      ["license-renewal", "license-deactivation", "license-activation", "license-devices"],
    );
    limiter.mock.restore();
  }

  assert.equal(renewLookup.mock.callCount(), 0);
  assert.equal(deactivateStore.mock.callCount(), 0);
  assert.equal(activateStore.mock.callCount(), 0);
  assert.equal(listStore.mock.callCount(), 0);
});

test("trial start returns 429 with Retry-After, or 503 when the limiter is unavailable", async (t) => {
  const claim = t.mock.method(trialStore, "createOrGetTrialClaim");
  const body = { installId: "d".repeat(64), hardwareId: "e".repeat(64) };

  t.mock.method(rateLimit, "checkIngestRateLimit", async () => ({
    allowed: false as const,
    retryAfterSeconds: 42,
  }));
  const limited = await startTrial(jsonRequest("/api/trial/start", body));
  assert.equal(limited.status, 429);
  assert.equal(limited.headers.get("retry-after"), "42");
  assert.equal(((await limited.json()) as Json).code, "rate_limited");

  t.mock.method(rateLimit, "checkIngestRateLimit", async () => ({
    allowed: false as const,
    retryAfterSeconds: 60,
    unavailable: true as const,
  }));
  const unavailable = await startTrial(jsonRequest("/api/trial/start", body));
  assert.equal(unavailable.status, 503);
  assert.equal(((await unavailable.json()) as Json).code, "service_unavailable");

  assert.equal(claim.mock.callCount(), 0);
});

// ----------------------------------------------------------- deactivate

test("deactivation over the 30-day cap returns 429 and does not list devices", async (t) => {
  setEnv(t, { CMDTAB_LICENSE_LOOKUP_PEPPER: PEPPER });
  allowRateLimits(t);
  t.mock.method(lifecycleStore, "findLicenseByActivationCredential", async () => ({
    licenseId: "order-1",
    email: "owner@example.com",
    orderIdentifier: "order-1",
  }));
  const deactivateStore = t.mock.method(lifecycleStore, "deactivateDevice", async () => ({
    kind: "limit_reached" as const,
  }));
  const listStore = t.mock.method(lifecycleStore, "listLicensedDevices", async () => []);

  const { status, body } = await read(
    await deactivate(
      jsonRequest("/api/license/deactivate", { licenseKey: ACTIVATION_CODE, deviceId: DEVICE_A }),
    ),
  );

  assert.equal(status, 429);
  assert.equal(body.code, "deactivation_limit");
  assert.equal(deactivateStore.mock.callCount(), 1);
  assert.deepEqual(deactivateStore.mock.calls[0]!.arguments[0], {
    licenseId: "order-1",
    deviceId: DEVICE_A,
    pepper: PEPPER,
  });
  assert.equal(listStore.mock.callCount(), 0);
});

test("deactivation within the cap returns the remaining devices", async (t) => {
  setEnv(t, { CMDTAB_LICENSE_LOOKUP_PEPPER: PEPPER });
  allowRateLimits(t);
  t.mock.method(lifecycleStore, "findLicenseByActivationCredential", async () => ({
    licenseId: "order-1",
    email: "owner@example.com",
    orderIdentifier: "order-1",
  }));
  t.mock.method(lifecycleStore, "deactivateDevice", async () => ({
    kind: "deactivated" as const,
  }));
  const remaining = [
    { deviceId: "f".repeat(64), deviceName: "Other Mac", activatedAt: "2026-10-01T00:00:00Z" },
  ];
  t.mock.method(lifecycleStore, "listLicensedDevices", async () => remaining);

  const { status, body } = await read(
    await deactivate(
      jsonRequest("/api/license/deactivate", { licenseKey: ACTIVATION_CODE, deviceId: DEVICE_A }),
    ),
  );

  assert.equal(status, 200);
  assert.deepEqual(body, { ok: true, devices: remaining });
});

test("deactivation with an unknown activation code is rejected before the store mutates", async (t) => {
  setEnv(t, { CMDTAB_LICENSE_LOOKUP_PEPPER: PEPPER });
  allowRateLimits(t);
  t.mock.method(lifecycleStore, "findLicenseByActivationCredential", async () => null);
  const deactivateStore = t.mock.method(lifecycleStore, "deactivateDevice");

  const { status, body } = await read(
    await deactivate(
      jsonRequest("/api/license/deactivate", { licenseKey: ACTIVATION_CODE, deviceId: DEVICE_A }),
    ),
  );

  assert.equal(status, 401);
  assert.equal(body.code, "invalid_license");
  assert.equal(deactivateStore.mock.callCount(), 0);
});

// ------------------------------------------- unconfigured / commerce off

test("license routes fail closed with 503 when the lookup pepper is not configured", async (t) => {
  setEnv(t, { CMDTAB_LICENSE_LOOKUP_PEPPER: undefined });
  allowRateLimits(t);
  const credentialLookup = t.mock.method(lifecycleStore, "findLicenseByActivationCredential");
  const activateStore = t.mock.method(lifecycleStore, "activateDevice");
  const deactivateStore = t.mock.method(lifecycleStore, "deactivateDevice");

  const responses = [
    await activate(
      jsonRequest("/api/license/activate", {
        licenseKey: ACTIVATION_CODE,
        deviceId: DEVICE_A,
        deviceName: "Test Mac",
      }),
    ),
    await deactivate(
      jsonRequest("/api/license/deactivate", { licenseKey: ACTIVATION_CODE, deviceId: DEVICE_A }),
    ),
    await listDevices(
      new Request("https://cmdtab.net/api/license/devices", {
        headers: { authorization: `Bearer ${ACTIVATION_CODE}` },
      }),
    ),
  ];
  for (const response of responses) {
    const { status, body } = await read(response);
    assert.equal(status, 503);
    assert.equal(body.code, "not_configured");
  }
  assert.equal(credentialLookup.mock.callCount(), 0);
  assert.equal(activateStore.mock.callCount(), 0);
  assert.equal(deactivateStore.mock.callCount(), 0);
});

test("Lemon Squeezy webhook returns 503 commerce_disabled and touches no store while commerce is off", async (t) => {
  setEnv(t, {
    CMDTAB_REQUIRE_COMMERCE_READY: undefined,
    RESEND_API_KEY: undefined,
    WAITLIST_FROM_EMAIL: undefined,
    WAITLIST_TO_EMAIL: undefined,
  });
  const fulfillmentLookup = t.mock.method(fulfillmentStore, "findLicenseFulfillmentByOrder");
  const accessState = t.mock.method(lifecycleStore, "recordOrderAccessState");
  const enqueue = t.mock.method(lifecycleStore, "enqueueLicenseEmail");

  for (const flag of [undefined, "0", "true"]) {
    if (flag === undefined) delete process.env.CMDTAB_REQUIRE_COMMERCE_READY;
    else process.env.CMDTAB_REQUIRE_COMMERCE_READY = flag;
    const { status, body } = await read(
      await lemonWebhook(
        jsonRequest(
          "/api/lemonsqueezy/webhook",
          { meta: { event_name: "order_refunded" }, data: { attributes: { identifier: "o-1" } } },
          { "x-signature": "0".repeat(64) },
        ),
      ),
    );
    assert.equal(status, 503, `flag=${String(flag)}`);
    assert.equal(body.code, "commerce_disabled");
  }
  assert.equal(fulfillmentLookup.mock.callCount(), 0);
  assert.equal(accessState.mock.callCount(), 0);
  assert.equal(enqueue.mock.callCount(), 0);
});

test("Lemon Squeezy webhook returns 503 missing_configuration when enabled without its secrets", async (t) => {
  setEnv(t, {
    CMDTAB_REQUIRE_COMMERCE_READY: "1",
    RESEND_API_KEY: "re_test_placeholder",
    WAITLIST_FROM_EMAIL: "from@example.com",
    WAITLIST_TO_EMAIL: "to@example.com",
    LEMONSQUEEZY_WEBHOOK_SECRET: undefined,
    CMDTAB_LICENSE_LOOKUP_PEPPER: undefined,
  });
  const accessState = t.mock.method(lifecycleStore, "recordOrderAccessState");

  const { status, body } = await read(
    await lemonWebhook(jsonRequest("/api/lemonsqueezy/webhook", { meta: {} })),
  );

  assert.equal(status, 503);
  assert.equal(body.code, "missing_configuration");
  assert.equal(accessState.mock.callCount(), 0);
});

// ---------------------------------------------------------------- trial

test("trial start returns the existing claim's original dates when a Mac's hardware hash is rebound", async (t) => {
  allowRateLimits(t);
  const trialSigner = licenseSigningMaterials().signer;
  t.mock.method(kms, "getTrialTokenSigner", () => trialSigner);
  const original = {
    id: "claim-1",
    email: "anonymous+x@trial.cmdtab.invalid",
    installId: "1".repeat(64),
    startedAt: "2026-10-01T00:00:00.000Z",
    endsAt: "2026-10-15T00:00:00.000Z",
    lastSeenAt: "2026-10-01T00:00:00.000Z",
    createdAt: "2026-10-01T00:00:00.000Z",
    updatedAt: "2026-10-01T00:00:00.000Z",
  };
  const newInstall = "2".repeat(64);
  const claim = t.mock.method(trialStore, "createOrGetTrialClaim", async () => ({
    kind: "existing" as const,
    claim: { ...original, installId: newInstall },
  }));

  const { status, body } = await read(
    await startTrial(
      jsonRequest("/api/trial/start", { installId: newInstall, hardwareId: "e".repeat(64) }),
    ),
  );

  assert.equal(status, 200);
  assert.equal(body.alreadyRegistered, true);
  assert.equal(body.notificationDelivered, false);
  const returned = body.claim as Json;
  assert.equal(returned.startedAt, original.startedAt);
  assert.equal(returned.endsAt, original.endsAt);
  assert.equal(returned.installId, newInstall);
  assert.match(String(body.entitlementToken), /^CMDTAB2\./);
  const forwarded = claim.mock.calls[0]!.arguments[0]!;
  assert.equal(forwarded.hardwareId, "e".repeat(64));
  assert.equal(forwarded.installId, newInstall);
  assert.equal(forwarded.trialLengthDays, 14);
});

test("trial start refuses a second trial with 409 and signs nothing", async (t) => {
  allowRateLimits(t);
  const getSigner = t.mock.method(kms, "getTrialTokenSigner");
  t.mock.method(trialStore, "createOrGetTrialClaim", async () => ({
    kind: "blocked" as const,
    reason: "install_already_registered" as const,
  }));

  const { status, body } = await read(
    await startTrial(
      jsonRequest("/api/trial/start", { installId: "3".repeat(64), hardwareId: "e".repeat(64) }),
    ),
  );

  assert.equal(status, 409);
  assert.equal(body.code, "trial_unavailable");
  assert.equal(body.entitlementToken, undefined);
  assert.equal(getSigner.mock.callCount(), 0);
});

test("trial start rejects a raw (unhashed) hardware identifier", async (t) => {
  allowRateLimits(t);
  const claim = t.mock.method(trialStore, "createOrGetTrialClaim");

  const { status, body } = await read(
    await startTrial(
      jsonRequest("/api/trial/start", {
        installId: "3".repeat(64),
        hardwareId: "12345678-90AB-CDEF-1234-567890ABCDEF",
      }),
    ),
  );

  assert.equal(status, 400);
  assert.equal(body.code, "invalid_request");
  assert.equal(claim.mock.callCount(), 0);
});

// ------------------------------------------------------------- recovery

function recoveryStore(t: TestContext, licenses: Array<{ order_identifier: string }>) {
  return {
    find: t.mock.method(lifecycleStore, "findRecoverableLicenses", async () =>
      licenses.map((license) => ({
        ...license,
        purchaser_email: "owner@example.com",
        product_name: "CmdTab",
        receipt_url: null,
        delivery_status: "stored",
      })),
    ),
    rotate: t.mock.method(lifecycleStore, "rotateActivationCredential", async () => ({
      credential: ACTIVATION_CODE,
      generation: 2,
    })),
    enqueue: t.mock.method(lifecycleStore, "enqueueLicenseEmail", async () => "job-1"),
    configured: t.mock.method(lifecycleStore, "isLicenseLifecycleStoreConfigured", () => true),
  };
}

function withoutRequestId(body: Json) {
  const { requestId, ...rest } = body;
  assert.match(String(requestId), /^[0-9a-f-]{36}$/);
  return rest;
}

test("recovery responds identically for known and unknown emails", async (t) => {
  setEnv(t, { CMDTAB_LICENSE_LOOKUP_PEPPER: PEPPER });
  allowRateLimits(t);

  const unknownStore = recoveryStore(t, []);
  const unknown = await read(
    await recover(jsonRequest("/api/license/recover", { email: "nobody@example.com" })),
  );
  assert.equal(unknownStore.enqueue.mock.callCount(), 0);
  for (const fake of Object.values(unknownStore)) fake.mock.restore();

  const knownStore = recoveryStore(t, [{ order_identifier: "order-1" }]);
  const known = await read(
    await recover(jsonRequest("/api/license/recover", { email: "Owner@Example.com" })),
  );
  assert.equal(knownStore.rotate.mock.callCount(), 1);
  assert.equal(knownStore.enqueue.mock.callCount(), 1);
  assert.equal(knownStore.find.mock.calls[0]!.arguments[0]!.email, "owner@example.com");

  assert.equal(unknown.status, 202);
  assert.equal(known.status, 202);
  assert.deepEqual(withoutRequestId(unknown.body), { ...genericRecoveryResponse });
  assert.deepEqual(withoutRequestId(known.body), { ...genericRecoveryResponse });
  assert.notEqual(unknown.body.requestId, known.body.requestId);
});

test("recovery stays generic when rate limited and performs no lookup", async (t) => {
  setEnv(t, { CMDTAB_LICENSE_LOOKUP_PEPPER: PEPPER });
  const store = recoveryStore(t, [{ order_identifier: "order-1" }]);

  await t.test("shared ingest limit", async (st) => {
    st.mock.method(rateLimit, "checkIngestRateLimit", async () => ({
      allowed: false as const,
      retryAfterSeconds: 30,
    }));
    const { status, body } = await read(
      await recover(jsonRequest("/api/license/recover", { email: "owner@example.com" })),
    );
    assert.equal(status, 202);
    assert.deepEqual(withoutRequestId(body), { ...genericRecoveryResponse });
  });

  await t.test("per-email limit", async (st) => {
    st.mock.method(rateLimit, "checkIngestRateLimit", async () => ({
      allowed: true as const,
      fingerprint: "ingest",
    }));
    st.mock.method(rateLimit, "checkRateLimit", async () => ({
      allowed: false as const,
      retryAfterSeconds: 60,
    }));
    const { status, body } = await read(
      await recover(jsonRequest("/api/license/recover", { email: "owner@example.com" })),
    );
    assert.equal(status, 202);
    assert.deepEqual(withoutRequestId(body), { ...genericRecoveryResponse });
  });

  assert.equal(store.find.mock.callCount(), 0);
  assert.equal(store.rotate.mock.callCount(), 0);
});

test("recovery stays generic when the lifecycle store is not configured", async (t) => {
  setEnv(t, { CMDTAB_LICENSE_LOOKUP_PEPPER: undefined });
  allowRateLimits(t);
  const store = recoveryStore(t, [{ order_identifier: "order-1" }]);

  const { status, body } = await read(
    await recover(jsonRequest("/api/license/recover", { email: "owner@example.com" })),
  );

  assert.equal(status, 202);
  assert.deepEqual(withoutRequestId(body), { ...genericRecoveryResponse });
  assert.equal(store.find.mock.callCount(), 0);
});

test("recovery does not reveal a matching purchase when rotation or enqueue fails", async (t) => {
  setEnv(t, { CMDTAB_LICENSE_LOOKUP_PEPPER: PEPPER });
  allowRateLimits(t);
  t.mock.method(console, "error", () => {});
  for (const failing of ["rotate", "enqueue"] as const) {
    const store = recoveryStore(t, [{ order_identifier: "order-1" }]);
    store[failing].mock.mockImplementation(async () => {
      throw new Error("connection terminated unexpectedly");
    });

    const { status, body } = await read(
      await recover(jsonRequest("/api/license/recover", { email: "owner@example.com" })),
    );

    assert.equal(status, 202, `${failing} failure`);
    assert.deepEqual(withoutRequestId(body), { ...genericRecoveryResponse });
    for (const fake of Object.values(store)) fake.mock.restore();
  }
});

test("recovery still rejects a non-JSON body with its media-type error", async (t) => {
  setEnv(t, { CMDTAB_LICENSE_LOOKUP_PEPPER: PEPPER });
  allowRateLimits(t);
  const store = recoveryStore(t, []);

  const response = await recover(
    new Request("https://cmdtab.net/api/license/recover", {
      method: "POST",
      headers: { "content-type": "text/plain" },
      body: "owner@example.com",
    }),
  );

  assert.equal(response.status, 415);
  assert.equal(((await response.json()) as Json).code, "unsupported_media_type");
  assert.equal(store.find.mock.callCount(), 0);
});

test("recovery still reports malformed input as a validation error", async (t) => {
  setEnv(t, { CMDTAB_LICENSE_LOOKUP_PEPPER: PEPPER });
  allowRateLimits(t);

  const { status, body } = await read(
    await recover(jsonRequest("/api/license/recover", { email: "not-an-email" })),
  );

  assert.equal(status, 400);
  assert.equal(body.code, "validation_error");
});
