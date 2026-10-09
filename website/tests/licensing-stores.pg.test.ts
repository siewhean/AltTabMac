import "./support/route-alias.js";

import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

// Store SQL against a real, disposable Postgres. Opt-in: set
// CMDTAB_TEST_DATABASE_URL to a *local* database you are happy to write to
// (see `npm run test:stores:pg`). Without it every test here is skipped, so
// the default unit run never needs a database.
const testDatabaseUrl = process.env.CMDTAB_TEST_DATABASE_URL?.trim();

function isLocalDatabase(url: string) {
  try {
    const host = new URL(url).hostname;
    return host === "" || host === "localhost" || host === "127.0.0.1" || host === "[::1]";
  } catch {
    return false;
  }
}

if (testDatabaseUrl && !isLocalDatabase(testDatabaseUrl)) {
  throw new Error("CMDTAB_TEST_DATABASE_URL must point at a local database.");
}
const skip = testDatabaseUrl
  ? false
  : "CMDTAB_TEST_DATABASE_URL not set (store tests need a disposable local Postgres)";

if (testDatabaseUrl) {
  // Point the store modules' shared client at the test database only.
  process.env.DATABASE_URL = testDatabaseUrl;
  delete process.env.POSTGRES_URL;
  delete process.env.POSTGRES_PRISMA_URL;
}

import { lookupHash } from "../src/lib/license-lifecycle-contract.js";
import { hashEntitlementIdentifier } from "../src/lib/entitlement-token.js";
import * as lifecycle from "../src/lib/license-lifecycle-store.js";
import { createOrGetTrialClaim } from "../src/lib/trial-claim-store.js";
import { getSql } from "../src/lib/postgres.js";

const PEPPER = "store-test-pepper-with-more-than-thirty-two-bytes";

function hex() {
  return randomBytes(32).toString("hex");
}

test.before(async () => {
  if (skip) return;
  // The checked-in migration creates license_fulfillments, which the
  // lifecycle store's runtime schema step extends.
  const migration = readFileSync(
    path.resolve(process.cwd(), "db/migrations/001_commerce_lifecycle.sql"),
    "utf8",
  );
  await getSql().unsafe(migration);
  // Silence "already exists, skipping" notices from the idempotent DDL.
  await getSql()`set client_min_messages = warning`;
});

test.after(async () => {
  if (!skip) await getSql().end({ timeout: 5 });
});

async function activateWithClaims(licenseId: string, deviceId: string) {
  const result = await lifecycle.activateDevice({
    licenseId,
    deviceId,
    deviceName: `Mac ${deviceId.slice(0, 6)}`,
    pepper: PEPPER,
    entitlementOrderHash: hashEntitlementIdentifier(licenseId),
    entitlementSubjectHash: hashEntitlementIdentifier(`${licenseId}@example.com`),
  });
  assert.ok(result.kind === "activated" || result.kind === "existing", result.kind);
  return result;
}

async function newActiveLicense() {
  const licenseId = `order-${hex().slice(0, 16)}`;
  await lifecycle.ensureActiveEntitlement({
    licenseId,
    orderIdentifier: licenseId,
    pepper: PEPPER,
  });
  return licenseId;
}

test("deactivation is capped at 3 per license per rolling 30 days", { skip }, async () => {
  assert.equal(lifecycle.MAX_DEACTIVATIONS_PER_WINDOW, 3);
  const licenseId = await newActiveLicense();
  const devices = Array.from({ length: 6 }, hex);
  const deactivate = (deviceId: string) =>
    lifecycle.deactivateDevice({ licenseId, deviceId, pepper: PEPPER });

  for (const device of devices.slice(0, 3)) await activateWithClaims(licenseId, device);
  const full = await lifecycle.activateDevice({
    licenseId,
    deviceId: devices[3],
    deviceName: "Fourth Mac",
    pepper: PEPPER,
    entitlementOrderHash: hashEntitlementIdentifier(licenseId),
    entitlementSubjectHash: hashEntitlementIdentifier("x"),
  });
  assert.equal(full.kind, "slot_full");

  // Rotate three Macs through the slots: each frees one slot.
  for (let index = 0; index < 3; index += 1) {
    assert.deepEqual(await deactivate(devices[index]), { kind: "deactivated" });
    await activateWithClaims(licenseId, devices[index + 3]);
  }

  // A device that is not active neither succeeds nor consumes the quota.
  assert.deepEqual(await deactivate(hex()), { kind: "not_active" });

  // Fourth deactivation inside the window is refused; the slot stays active.
  assert.deepEqual(await deactivate(devices[3]), { kind: "limit_reached" });
  const active = await lifecycle.listLicensedDevices({ licenseId, pepper: PEPPER });
  assert.equal(active.length, 3);
  assert.ok(active.some((device) => device.deviceId === lookupHash("device", devices[3], PEPPER)));

  // The deactivation handle shown to the app (the lookup hash) is accepted too.
  const handle = lookupHash("device", devices[4], PEPPER);
  assert.deepEqual(
    await lifecycle.deactivateDevice({ licenseId, deviceId: handle, pepper: PEPPER }),
    { kind: "limit_reached" },
  );

  // Once those events age out of the 30-day window the cap resets.
  await getSql()`
    update license_deactivation_events
    set created_at = now() - interval '31 days'
    where license_lookup_hash = ${lookupHash("license", licenseId, PEPPER)}
  `;
  assert.deepEqual(await deactivate(devices[3]), { kind: "deactivated" });

  // Another license's quota is independent.
  const other = await newActiveLicense();
  await activateWithClaims(other, devices[0]);
  assert.deepEqual(
    await lifecycle.deactivateDevice({ licenseId: other, deviceId: devices[0], pepper: PEPPER }),
    { kind: "deactivated" },
  );
});

test("renewal lookup requires an active slot, live claims, and an unrevoked license", { skip }, async () => {
  const licenseId = await newActiveLicense();
  const deviceA = hex();
  const deviceB = hex();
  await activateWithClaims(licenseId, deviceA);
  await activateWithClaims(licenseId, deviceB);
  const orderHash = hashEntitlementIdentifier(licenseId);
  const find = (deviceId: string, entitlementOrderHash = orderHash) =>
    lifecycle.findRenewableActivation({ entitlementOrderHash, deviceId, pepper: PEPPER });

  assert.deepEqual(await find(deviceA), {
    kind: "active",
    subjectHash: hashEntitlementIdentifier(`${licenseId}@example.com`),
  });
  // A token for another order, or a device never activated, finds nothing.
  assert.deepEqual(await find(deviceA, hashEntitlementIdentifier("other-order")), {
    kind: "inactive",
  });
  assert.deepEqual(await find(hex()), { kind: "inactive" });

  // A freed slot can no longer renew.
  await lifecycle.deactivateDevice({ licenseId, deviceId: deviceB, pepper: PEPPER });
  assert.deepEqual(await find(deviceB), { kind: "inactive" });

  // An activation made before entitlement claims were stored cannot renew.
  const legacyDevice = hex();
  await getSql()`
    insert into license_activations (
      id, license_lookup_hash, device_lookup_hash, device_name,
      entitlement_order_hash, entitlement_subject_hash
    ) values (
      ${hex()}, ${lookupHash("license", licenseId, PEPPER)},
      ${lookupHash("device", legacyDevice, PEPPER)}, ${"Legacy Mac"},
      ${orderHash}, ${null}
    )
  `;
  assert.deepEqual(await find(legacyDevice), { kind: "inactive" });

  // A partial refund keeps access; a full refund revokes renewal.
  await lifecycle.recordOrderAccessState({
    orderIdentifier: licenseId,
    licenseId,
    pepper: PEPPER,
    state: "partial_refund",
    reason: "partial_refund",
  });
  assert.equal((await find(deviceA)).kind, "active");
  await lifecycle.recordOrderAccessState({
    orderIdentifier: licenseId,
    licenseId,
    pepper: PEPPER,
    state: "revoked",
    reason: "full_refund",
  });
  assert.deepEqual(await find(deviceA), { kind: "revoked" });
  // Revocation is sticky: a later partial-refund event does not restore it.
  await lifecycle.recordOrderAccessState({
    orderIdentifier: licenseId,
    licenseId,
    pepper: PEPPER,
    state: "partial_refund",
    reason: "partial_refund",
  });
  assert.deepEqual(await find(deviceA), { kind: "revoked" });

  // An activation whose license has no access-state row is treated as revoked.
  const orphan = `order-${hex().slice(0, 16)}`;
  const orphanDevice = hex();
  await getSql()`
    insert into license_activations (
      id, license_lookup_hash, device_lookup_hash, device_name,
      entitlement_order_hash, entitlement_subject_hash
    ) values (
      ${hex()}, ${lookupHash("license", orphan, PEPPER)},
      ${lookupHash("device", orphanDevice, PEPPER)}, ${"Orphan Mac"},
      ${hashEntitlementIdentifier(orphan)}, ${hashEntitlementIdentifier("s")}
    )
  `;
  assert.deepEqual(
    await find(orphanDevice, hashEntitlementIdentifier(orphan)),
    { kind: "revoked" },
  );
});

test("trial claims are one per hardware hash and rebind to a reset install with original dates", { skip }, async () => {
  const hardwareId = hex();
  const firstInstall = hex();
  const resetInstall = hex();
  const startedAt = new Date("2026-09-01T12:00:00.000Z");
  const iso = (value: unknown) => new Date(value as string).toISOString();

  const created = await createOrGetTrialClaim({
    email: `anonymous+${hex().slice(0, 32)}@trial.cmdtab.invalid`,
    installId: firstInstall,
    hardwareId,
    trialLengthDays: 14,
    now: startedAt,
  });
  assert.equal(created.kind, "created");

  // Keychain reset: new install ID and new anonymous subject, same Mac.
  const rebound = await createOrGetTrialClaim({
    email: `anonymous+${hex().slice(0, 32)}@trial.cmdtab.invalid`,
    installId: resetInstall,
    hardwareId,
    trialLengthDays: 14,
    now: new Date("2026-10-10T00:00:00.000Z"),
  });
  assert.equal(rebound.kind, "existing");
  assert.equal(rebound.claim.id, created.kind === "created" ? created.claim.id : "");
  assert.equal(rebound.claim.installId, resetInstall);
  assert.equal(iso(rebound.claim.startedAt), startedAt.toISOString());
  assert.equal(iso(rebound.claim.endsAt), "2026-09-15T12:00:00.000Z");

  const [row] = await getSql()<{ count: number; install_id: string }[]>`
    select count(*)::int as count, max(install_id) as install_id
    from trial_claims where hardware_id = ${hardwareId}
  `;
  assert.deepEqual(row, { count: 1, install_id: resetInstall });

  // Same Mac, same install again: idempotent.
  const repeat = await createOrGetTrialClaim({
    email: "someone@example.com",
    installId: resetInstall,
    hardwareId,
    trialLengthDays: 14,
  });
  assert.equal(repeat.kind, "existing");

  // Rebinding onto an install that already owns a different claim is refused.
  const otherInstall = hex();
  await createOrGetTrialClaim({
    email: `anonymous+${hex().slice(0, 32)}@trial.cmdtab.invalid`,
    installId: otherInstall,
    hardwareId: hex(),
    trialLengthDays: 14,
  });
  const collision = await createOrGetTrialClaim({
    email: `anonymous+${hex().slice(0, 32)}@trial.cmdtab.invalid`,
    installId: otherInstall,
    hardwareId,
    trialLengthDays: 14,
  });
  assert.equal(collision.kind, "blocked");
  assert.equal(
    collision.kind === "blocked" ? collision.reason : null,
    "install_already_registered",
  );

  // A different Mac still gets its own trial.
  const otherMac = await createOrGetTrialClaim({
    email: `anonymous+${hex().slice(0, 32)}@trial.cmdtab.invalid`,
    installId: hex(),
    hardwareId: hex(),
    trialLengthDays: 14,
  });
  assert.equal(otherMac.kind, "created");
});
