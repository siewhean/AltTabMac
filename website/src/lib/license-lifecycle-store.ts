import { randomUUID } from "node:crypto";

import {
  deriveActivationCredential,
  lookupHash,
} from "@/lib/license-lifecycle-contract";
import { getSql, isDatabaseConfigured } from "@/lib/postgres";

const MAX_DEVICES = 3;
// Freeing a slot is cheap for the license holder, so cap it: otherwise one
// code can rotate any number of Macs through three slots.
export const MAX_DEACTIVATIONS_PER_WINDOW = 3;
const DEACTIVATION_WINDOW = "30 days";

type DeviceRow = {
  device_lookup_hash: string;
  device_name: string;
  activated_at: string;
};

export type LicensedDevice = {
  deviceId: string;
  deviceName: string;
  activatedAt: string;
};

export type ActivationResult =
  | { kind: "activated" | "existing"; devices: LicensedDevice[] }
  | { kind: "slot_full"; devices: LicensedDevice[] }
  | { kind: "unknown_license" | "revoked" };

export type DeactivationResult =
  | { kind: "deactivated" | "not_active" }
  | { kind: "limit_reached" };

let schemaReady = false;

export function isLicenseLifecycleStoreConfigured() {
  return isDatabaseConfigured();
}

async function ensureSchema() {
  if (schemaReady) return;
  const sql = getSql();
  await sql`
    create table if not exists license_access_states (
      license_lookup_hash text primary key,
      order_lookup_hash text not null,
      access_status text not null default 'active',
      reason text,
      refunded_amount bigint,
      order_total bigint,
      revoked_at timestamptz,
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now()
    )
  `;
  await sql`
    create unique index if not exists license_access_states_order_idx
    on license_access_states (order_lookup_hash)
  `;
  await sql`
    create table if not exists license_activations (
      id text primary key,
      license_lookup_hash text not null,
      device_lookup_hash text not null,
      device_name text not null,
      activated_at timestamptz not null default now(),
      deactivated_at timestamptz,
      updated_at timestamptz not null default now(),
      unique (license_lookup_hash, device_lookup_hash)
    )
  `;
  // Unpeppered SHA-256 claims exactly as signed into the entitlement token, so
  // a lease renewal can find its activation from the token alone.
  await sql`
    alter table license_activations
      add column if not exists entitlement_order_hash text,
      add column if not exists entitlement_subject_hash text
  `;
  await sql`
    create index if not exists license_activations_entitlement_idx
    on license_activations (entitlement_order_hash, device_lookup_hash)
  `;
  await sql`
    create table if not exists license_deactivation_events (
      id text primary key,
      license_lookup_hash text not null,
      device_lookup_hash text not null,
      created_at timestamptz not null default now()
    )
  `;
  await sql`
    create index if not exists license_deactivation_events_license_idx
    on license_deactivation_events (license_lookup_hash, created_at)
  `;
  await sql`
    create table if not exists license_delivery_outbox (
      id text primary key,
      dedupe_key text not null unique,
      kind text not null,
      recipient_email text not null,
      payload jsonb not null,
      status text not null default 'pending',
      attempts integer not null default 0,
      available_at timestamptz not null default now(),
      last_error text,
      delivered_at timestamptz,
      claim_token text,
      lease_expires_at timestamptz,
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now()
    )
  `;
  await sql`
    alter table license_delivery_outbox
      add column if not exists claim_token text,
      add column if not exists lease_expires_at timestamptz
  `;
  // Delivered emails no longer need the activation code they carried.
  await sql`
    update license_delivery_outbox
    set payload = payload - 'licenseKey', updated_at = now()
    where status = 'delivered' and payload ? 'licenseKey'
  `;
  await sql`
    create table if not exists license_recovery_requests (
      id text primary key,
      email_lookup_hash text not null,
      request_fingerprint text not null,
      created_at timestamptz not null default now()
    )
  `;
  await sql`
    alter table license_fulfillments
      add column if not exists lifecycle_backfilled_at timestamptz
  `;
  // Convert pre-migration refunded fulfillments into the same permanent,
  // peppered access tombstones used by current webhook processing.
  const legacyRefunds = await sql<
    { license_id: string; order_identifier: string }[]
  >`
    select license_id, order_identifier
    from license_fulfillments
    where delivery_status = 'refunded'
      and lifecycle_backfilled_at is null
    order by created_at asc
    limit 100
  `;
  const pepper = process.env.CMDTAB_LICENSE_LOOKUP_PEPPER?.trim();
  if (pepper) {
    for (const row of legacyRefunds) {
      const licenseLookupHash = lookupHash("license", row.license_id, pepper);
      const orderLookupHash = lookupHash("order", row.order_identifier, pepper);
      // Repair the earlier order-ID-keyed tombstone shape before inserting
      // the canonical license-ID-keyed row.
      await sql`
        delete from license_access_states
        where order_lookup_hash = ${orderLookupHash}
          and license_lookup_hash <> ${licenseLookupHash}
      `;
      await sql`
        insert into license_access_states (
          license_lookup_hash, order_lookup_hash, access_status, reason, revoked_at
        ) values (
          ${licenseLookupHash}, ${orderLookupHash}, ${"revoked"},
          ${"legacy_full_refund"}, now()
        )
        on conflict (license_lookup_hash) do update set
          access_status = 'revoked',
          reason = coalesce(license_access_states.reason, excluded.reason),
          revoked_at = coalesce(license_access_states.revoked_at, excluded.revoked_at),
          updated_at = now()
      `;
      await sql`
        update license_fulfillments
        set lifecycle_backfilled_at = now(), updated_at = now()
        where order_identifier = ${row.order_identifier}
      `;
    }
  }
  schemaReady = true;
}

function mapDevices(rows: DeviceRow[]): LicensedDevice[] {
  return rows.map((row) => ({
    deviceId: row.device_lookup_hash,
    deviceName: row.device_name,
    activatedAt: row.activated_at,
  }));
}

async function listDevicesWithSql(
  sql: ReturnType<typeof getSql>,
  licenseLookupHash: string,
) {
  const rows = await sql<DeviceRow[]>`
    select device_lookup_hash, device_name, activated_at::text
    from license_activations
    where license_lookup_hash = ${licenseLookupHash}
      and deactivated_at is null
    order by activated_at asc
  `;
  return mapDevices(rows);
}

export async function ensureActiveEntitlement(input: {
  licenseId: string;
  orderIdentifier: string;
  pepper: string;
}) {
  await ensureSchema();
  const sql = getSql();
  const licenseLookupHash = lookupHash("license", input.licenseId, input.pepper);
  const orderLookupHash = lookupHash("order", input.orderIdentifier, input.pepper);
  await sql`
    insert into license_access_states (
      license_lookup_hash, order_lookup_hash, access_status
    ) values (
      ${licenseLookupHash}, ${orderLookupHash}, ${"active"}
    )
    on conflict (license_lookup_hash) do nothing
  `;
}

export async function ensureEntitlementForVerifiedLicense(input: {
  licenseId: string;
  pepper: string;
}) {
  await ensureSchema();
  const sql = getSql();
  const licenseLookupHash = lookupHash("license", input.licenseId, input.pepper);
  const [existing] = await sql<{ access_status: string }[]>`
    select access_status
    from license_access_states
    where license_lookup_hash = ${licenseLookupHash}
    limit 1
  `;
  if (existing) return existing.access_status !== "revoked";

  const [fulfillment] = await sql<
    { order_identifier: string; delivery_status: string }[]
  >`
    select order_identifier, delivery_status
    from license_fulfillments
    where license_id = ${input.licenseId}
    limit 1
  `;
  if (!fulfillment) return false;

  if (fulfillment.delivery_status === "refunded") {
    await recordOrderAccessState({
      orderIdentifier: fulfillment.order_identifier,
      licenseId: input.licenseId,
      pepper: input.pepper,
      state: "revoked",
      reason: "legacy_full_refund",
    });
    return false;
  }

  await ensureActiveEntitlement({
    licenseId: input.licenseId,
    orderIdentifier: fulfillment.order_identifier,
    pepper: input.pepper,
  });
  return true;
}

export async function findLicenseByActivationCredential(input: {
  credential: string;
  pepper: string;
}) {
  await ensureSchema();
  const [row] = await getSql()<
    { license_id: string; purchaser_email: string; order_identifier: string }[]
  >`
    select license_id, purchaser_email, order_identifier
    from license_fulfillments
    where activation_credential_hash = ${lookupHash(
      "license",
      input.credential,
      input.pepper,
    )}
    limit 1
  `;
  return row
    ? {
        licenseId: row.license_id,
        email: row.purchaser_email,
        orderIdentifier: row.order_identifier,
      }
    : null;
}

export async function recordOrderAccessState(input: {
  orderIdentifier: string;
  licenseId?: string;
  pepper: string;
  state: "partial_refund" | "revoked";
  reason: string;
  refundedAmount?: number;
  total?: number;
}) {
  await ensureSchema();
  const sql = getSql();
  const licenseId = input.licenseId ?? input.orderIdentifier;
  const licenseLookupHash = lookupHash("license", licenseId, input.pepper);
  const orderLookupHash = lookupHash("order", input.orderIdentifier, input.pepper);

  await sql.begin(async (transaction) => {
    const tx = transaction as unknown as ReturnType<typeof getSql>;
    await tx`select pg_advisory_xact_lock(hashtext(${licenseLookupHash}))`;
    await tx`
      insert into license_access_states (
      license_lookup_hash,
      order_lookup_hash,
      access_status,
      reason,
      refunded_amount,
      order_total,
      revoked_at
    ) values (
      ${licenseLookupHash},
      ${orderLookupHash},
      ${input.state},
      ${input.reason},
      ${input.refundedAmount ?? null},
      ${input.total ?? null},
      ${input.state === "revoked" ? new Date().toISOString() : null}
    )
    on conflict (license_lookup_hash) do update set
      access_status = case
        when license_access_states.access_status = 'revoked' then 'revoked'
        else excluded.access_status
      end,
      reason = case
        when license_access_states.access_status = 'revoked' then license_access_states.reason
        else excluded.reason
      end,
      refunded_amount = excluded.refunded_amount,
      order_total = excluded.order_total,
      revoked_at = case
        when license_access_states.access_status = 'revoked' then license_access_states.revoked_at
        else excluded.revoked_at
      end,
      updated_at = now()
    `;
  });
}

export async function activateDevice(input: {
  licenseId: string;
  deviceId: string;
  deviceName: string;
  pepper: string;
  entitlementOrderHash: string;
  entitlementSubjectHash: string;
}): Promise<ActivationResult> {
  await ensureSchema();
  const sql = getSql();
  const licenseLookupHash = lookupHash("license", input.licenseId, input.pepper);
  const deviceLookupHash = lookupHash("device", input.deviceId, input.pepper);

  return sql.begin(async (transaction) => {
    const tx = transaction as unknown as ReturnType<typeof getSql>;
    await tx`select pg_advisory_xact_lock(hashtext(${licenseLookupHash}))`;
    const [access] = await tx<{ access_status: string }[]>`
      select access_status
      from license_access_states
      where license_lookup_hash = ${licenseLookupHash}
      for update
    `;
    if (!access) return { kind: "unknown_license" } as const;
    if (access.access_status === "revoked") return { kind: "revoked" } as const;

    const [existing] = await tx<DeviceRow[]>`
      select device_lookup_hash, device_name, activated_at::text
      from license_activations
      where license_lookup_hash = ${licenseLookupHash}
        and device_lookup_hash = ${deviceLookupHash}
        and deactivated_at is null
      limit 1
    `;
    if (existing) {
      await tx`
        update license_activations
        set device_name = ${input.deviceName},
            entitlement_order_hash = ${input.entitlementOrderHash},
            entitlement_subject_hash = ${input.entitlementSubjectHash},
            updated_at = now()
        where license_lookup_hash = ${licenseLookupHash}
          and device_lookup_hash = ${deviceLookupHash}
      `;
      return {
        kind: "existing",
        devices: await listDevicesWithSql(tx, licenseLookupHash),
      } as const;
    }

    const [{ count }] = await tx<{ count: number }[]>`
      select count(*)::int as count
      from license_activations
      where license_lookup_hash = ${licenseLookupHash}
        and deactivated_at is null
    `;
    if (count >= MAX_DEVICES) {
      return {
        kind: "slot_full",
        devices: await listDevicesWithSql(tx, licenseLookupHash),
      } as const;
    }

    await tx`
      insert into license_activations (
        id, license_lookup_hash, device_lookup_hash, device_name,
        entitlement_order_hash, entitlement_subject_hash
      ) values (
        ${randomUUID()}, ${licenseLookupHash}, ${deviceLookupHash}, ${input.deviceName},
        ${input.entitlementOrderHash}, ${input.entitlementSubjectHash}
      )
      on conflict (license_lookup_hash, device_lookup_hash) do update set
        device_name = excluded.device_name,
        entitlement_order_hash = excluded.entitlement_order_hash,
        entitlement_subject_hash = excluded.entitlement_subject_hash,
        deactivated_at = null,
        activated_at = now(),
        updated_at = now()
    `;
    return {
      kind: "activated",
      devices: await listDevicesWithSql(tx, licenseLookupHash),
    } as const;
  });
}

export async function deactivateDevice(input: {
  licenseId: string;
  deviceId: string;
  pepper: string;
}) {
  await ensureSchema();
  const sql = getSql();
  const licenseLookupHash = lookupHash("license", input.licenseId, input.pepper);
  const deviceLookupHash = lookupHash("device", input.deviceId, input.pepper);
  const publicDeviceHandle = /^[a-f0-9]{64}$/.test(input.deviceId)
    ? input.deviceId
    : "";
  return sql.begin(async (transaction): Promise<DeactivationResult> => {
    const tx = transaction as unknown as ReturnType<typeof getSql>;
    await tx`select pg_advisory_xact_lock(hashtext(${licenseLookupHash}))`;
    const [active] = await tx<{ device_lookup_hash: string }[]>`
      select device_lookup_hash
      from license_activations
      where license_lookup_hash = ${licenseLookupHash}
        and device_lookup_hash in (${deviceLookupHash}, ${publicDeviceHandle})
        and deactivated_at is null
      limit 1
    `;
    if (!active) return { kind: "not_active" };
    const [{ count }] = await tx<{ count: number }[]>`
      select count(*)::int as count
      from license_deactivation_events
      where license_lookup_hash = ${licenseLookupHash}
        and created_at > now() - ${DEACTIVATION_WINDOW}::interval
    `;
    if (count >= MAX_DEACTIVATIONS_PER_WINDOW) return { kind: "limit_reached" };
    await tx`
      update license_activations
      set deactivated_at = now(), updated_at = now()
      where license_lookup_hash = ${licenseLookupHash}
        and device_lookup_hash = ${active.device_lookup_hash}
    `;
    await tx`
      insert into license_deactivation_events (
        id, license_lookup_hash, device_lookup_hash
      ) values (
        ${randomUUID()}, ${licenseLookupHash}, ${active.device_lookup_hash}
      )
    `;
    return { kind: "deactivated" };
  });
}

/**
 * Lease renewal: the caller has proven possession of a signed, device-bound
 * entitlement. Renew only while that device still holds an active slot on a
 * license that has not been revoked.
 */
export async function findRenewableActivation(input: {
  entitlementOrderHash: string;
  deviceId: string;
  pepper: string;
}) {
  await ensureSchema();
  const [row] = await getSql()<
    { entitlement_subject_hash: string; access_status: string | null }[]
  >`
    select a.entitlement_subject_hash, s.access_status
    from license_activations a
    left join license_access_states s
      on s.license_lookup_hash = a.license_lookup_hash
    where a.entitlement_order_hash = ${input.entitlementOrderHash}
      and a.device_lookup_hash = ${lookupHash("device", input.deviceId, input.pepper)}
      and a.deactivated_at is null
    limit 1
  `;
  if (!row || !row.entitlement_subject_hash) return { kind: "inactive" } as const;
  if (!row.access_status || row.access_status === "revoked") {
    return { kind: "revoked" } as const;
  }
  return { kind: "active", subjectHash: row.entitlement_subject_hash } as const;
}

export async function listLicensedDevices(input: {
  licenseId: string;
  pepper: string;
}) {
  await ensureSchema();
  return listDevicesWithSql(
    getSql(),
    lookupHash("license", input.licenseId, input.pepper),
  );
}

export async function enqueueLicenseEmail(input: {
  dedupeKey: string;
  kind: "license_delivery" | "license_recovery";
  recipientEmail: string;
  payload: Record<string, unknown>;
}) {
  await ensureSchema();
  const sql = getSql();
  const [row] = await sql<{ id: string }[]>`
    insert into license_delivery_outbox (
      id, dedupe_key, kind, recipient_email, payload
    ) values (
      ${randomUUID()},
      ${input.dedupeKey},
      ${input.kind},
      ${input.recipientEmail.trim().toLowerCase()},
      ${sql.json(JSON.parse(JSON.stringify(input.payload)))}
    )
    on conflict (dedupe_key) do update set updated_at = now()
      , status = case
          when license_delivery_outbox.status = 'delivered' then 'delivered'
          when license_delivery_outbox.status = 'processing'
            and license_delivery_outbox.lease_expires_at > now()
            then 'processing'
          else 'pending'
        end
      , available_at = case
          when license_delivery_outbox.status = 'delivered'
            or (
              license_delivery_outbox.status = 'processing'
              and license_delivery_outbox.lease_expires_at > now()
            )
            then license_delivery_outbox.available_at
          else now()
        end
      , last_error = case
          when license_delivery_outbox.status = 'delivered'
            then license_delivery_outbox.last_error
          else null
        end
      , claim_token = case
          when license_delivery_outbox.status = 'processing'
            and license_delivery_outbox.lease_expires_at > now()
            then license_delivery_outbox.claim_token
          else null
        end
      , lease_expires_at = case
          when license_delivery_outbox.status = 'processing'
            and license_delivery_outbox.lease_expires_at > now()
            then license_delivery_outbox.lease_expires_at
          else null
        end
    returning id
  `;
  return row.id;
}

export async function findRecoverableLicenses(input: {
  email: string;
  pepper: string;
  requestFingerprint: string;
}) {
  await ensureSchema();
  const sql = getSql();
  const emailLookupHash = lookupHash("email", input.email, input.pepper);
  await sql`
    insert into license_recovery_requests (
      id, email_lookup_hash, request_fingerprint
    ) values (
      ${randomUUID()}, ${emailLookupHash}, ${input.requestFingerprint}
    )
  `;
  const rows = await sql<
    {
      order_identifier: string;
      purchaser_email: string;
      product_name: string | null;
      receipt_url: string | null;
      delivery_status: string;
    }[]
  >`
    select
      f.order_identifier,
      f.purchaser_email,
      f.product_name,
      f.receipt_url,
      f.delivery_status
    from license_fulfillments f
    where f.email_lookup_hash = ${emailLookupHash}
       or (
         f.email_lookup_hash is null
         and lower(f.purchaser_email) = ${input.email.trim().toLowerCase()}
       )
  `;
  const recoverable = [];
  for (const row of rows) {
    if (row.delivery_status === "refunded") {
      await recordOrderAccessState({
        orderIdentifier: row.order_identifier,
        pepper: input.pepper,
        state: "revoked",
        reason: "legacy_full_refund",
      });
      continue;
    }
    const [access] = await sql<{ access_status: string }[]>`
      select access_status
      from license_access_states
      where license_lookup_hash = ${lookupHash(
        "license",
        row.order_identifier,
        input.pepper,
      )}
      limit 1
    `;
    if (access?.access_status !== "revoked") recoverable.push(row);
  }
  return recoverable;
}

/**
 * Recovery never re-sends a stored code (none is stored). It rotates to the
 * next generation, so any previously leaked code stops working. Activated Macs
 * are unaffected: they renew their lease with their device-bound entitlement.
 */
export async function rotateActivationCredential(input: {
  orderIdentifier: string;
  pepper: string;
}) {
  await ensureSchema();
  const sql = getSql();
  return sql.begin(async (transaction) => {
    const tx = transaction as unknown as ReturnType<typeof getSql>;
    const [row] = await tx<{ credential_generation: number }[]>`
      select credential_generation
      from license_fulfillments
      where order_identifier = ${input.orderIdentifier}
      for update
    `;
    if (!row) throw new Error("Unknown fulfillment for credential rotation.");
    const generation = row.credential_generation + 1;
    const credential = deriveActivationCredential(
      input.orderIdentifier,
      generation,
      input.pepper,
    );
    await tx`
      update license_fulfillments
      set credential_generation = ${generation},
          activation_credential_hash = ${lookupHash("license", credential, input.pepper)},
          updated_at = now()
      where order_identifier = ${input.orderIdentifier}
    `;
    return { credential, generation };
  });
}

export type OutboxJob = {
  id: string;
  kind: "license_delivery" | "license_recovery";
  recipientEmail: string;
  payload: Record<string, unknown>;
  attempts: number;
  claimToken: string;
};

export async function claimDueOutboxJobs(limit = 10): Promise<OutboxJob[]> {
  await ensureSchema();
  const sql = getSql();
  return sql.begin(async (transaction) => {
    const tx = transaction as unknown as ReturnType<typeof getSql>;
    const claimToken = randomUUID();
    const rows = await tx<
      {
        id: string;
        kind: OutboxJob["kind"];
        recipient_email: string;
        payload: Record<string, unknown>;
        attempts: number;
      }[]
    >`
      select id, kind, recipient_email, payload, attempts
      from license_delivery_outbox
      where (
          status in ('pending', 'failed')
          or (
            status = 'processing'
            and lease_expires_at is not null
            and lease_expires_at <= now()
          )
        )
        and available_at <= now()
        and attempts < 8
      order by created_at asc
      for update skip locked
      limit ${Math.max(1, Math.min(limit, 50))}
    `;
    if (rows.length > 0) {
      await tx`
        update license_delivery_outbox
        set status = 'processing',
            attempts = attempts + 1,
            claim_token = ${claimToken},
            lease_expires_at = now() + interval '10 minutes',
            updated_at = now()
        where id = any(${rows.map((row) => row.id)})
      `;
    }
    return rows.map((row) => ({
      id: row.id,
      kind: row.kind,
      recipientEmail: row.recipient_email,
      payload: row.payload,
      attempts: row.attempts + 1,
      claimToken,
    }));
  });
}

export async function completeOutboxJob(id: string, claimToken: string) {
  await ensureSchema();
  await getSql()`
    update license_delivery_outbox
    set status = 'delivered', delivered_at = now(), last_error = null,
        claim_token = null, lease_expires_at = null,
        payload = payload - 'licenseKey', updated_at = now()
    where id = ${id} and status = 'processing' and claim_token = ${claimToken}
  `;
}

export async function failOutboxJob(
  id: string,
  claimToken: string,
  attempts: number,
  error: string,
) {
  await ensureSchema();
  const delayMinutes = Math.min(24 * 60, 2 ** Math.min(attempts, 10));
  await getSql()`
    update license_delivery_outbox
    set
      status = case when ${attempts >= 8} then 'dead' else 'failed' end,
      available_at = now() + (${delayMinutes} * interval '1 minute'),
      last_error = ${error.slice(0, 1000)},
      claim_token = null,
      lease_expires_at = null,
      updated_at = now()
    where id = ${id} and status = 'processing' and claim_token = ${claimToken}
  `;
}
