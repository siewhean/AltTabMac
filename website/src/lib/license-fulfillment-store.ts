import { randomUUID } from "node:crypto";

import { getSql, isDatabaseConfigured } from "@/lib/postgres";

type LicenseFulfillmentRow = {
  id: string;
  order_identifier: string;
  order_lookup_hash: string | null;
  order_number: number | null;
  event_name: string;
  purchaser_email: string;
  purchaser_name: string | null;
  product_name: string | null;
  variant_name: string | null;
  receipt_url: string | null;
  currency: string | null;
  total: string | null;
  total_formatted: string | null;
  store_id: number | null;
  lemonsqueezy_order_id: string | null;
  license_id: string;
  license_lookup_hash: string | null;
  email_lookup_hash: string | null;
  activation_credential_hash: string | null;
  license_token: string;
  delivery_status: string;
  delivery_error: string | null;
  test_mode: boolean;
  fulfilled_at: string | null;
  refunded_at: string | null;
  created_at: string;
  updated_at: string;
};

export type LicenseFulfillment = {
  id: string;
  orderIdentifier: string;
  orderLookupHash?: string;
  orderNumber?: number;
  eventName: string;
  purchaserEmail: string;
  purchaserName?: string;
  productName?: string;
  variantName?: string;
  receiptUrl?: string;
  currency?: string;
  total?: string;
  totalFormatted?: string;
  storeId?: number;
  lemonsqueezyOrderId?: string;
  licenseId: string;
  licenseLookupHash?: string;
  emailLookupHash?: string;
  activationCredentialHash?: string;
  licenseToken: string;
  deliveryStatus: "stored" | "delivered" | "failed" | "refunded";
  deliveryError?: string;
  testMode: boolean;
  fulfilledAt?: string;
  refundedAt?: string;
  createdAt: string;
  updatedAt: string;
};

export type LicenseFulfillmentAggregateStats = {
  total: number;
  delivered: number;
  failed: number;
  pending: number;
  refunded: number;
  purchases30d: number;
  latestFulfillment?: string;
};

let schemaReady = false;

export function isLicenseFulfillmentStoreConfigured() {
  return isDatabaseConfigured();
}

async function ensureSchema() {
  if (schemaReady) return;

  const sql = getSql();
  await sql`
    create table if not exists license_fulfillments (
      id text primary key,
      order_identifier text not null unique,
      order_lookup_hash text,
      order_number integer,
      event_name text not null,
      purchaser_email text not null,
      purchaser_name text,
      product_name text,
      variant_name text,
      receipt_url text,
      currency text,
      total text,
      total_formatted text,
      store_id integer,
      lemonsqueezy_order_id text,
      license_id text not null,
      license_lookup_hash text,
      email_lookup_hash text,
      activation_credential_hash text,
      license_token text not null,
      delivery_status text not null default 'stored',
      delivery_error text,
      test_mode boolean not null default false,
      fulfilled_at timestamptz,
      refunded_at timestamptz,
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now()
    )
  `;
  await sql`
    alter table license_fulfillments
      add column if not exists order_lookup_hash text,
      add column if not exists license_lookup_hash text,
      add column if not exists email_lookup_hash text
      , add column if not exists activation_credential_hash text
      , add column if not exists credential_generation integer not null default 0
  `;
  // Activation codes are derived on demand (deriveActivationCredential); drop
  // any plaintext codes or legacy tokens persisted by earlier releases.
  await sql`
    update license_fulfillments set license_token = '', updated_at = now()
    where license_token <> ''
  `;

  schemaReady = true;
}

function mapRow(row: LicenseFulfillmentRow): LicenseFulfillment {
  return {
    id: row.id,
    orderIdentifier: row.order_identifier,
    orderLookupHash: row.order_lookup_hash ?? undefined,
    orderNumber: row.order_number ?? undefined,
    eventName: row.event_name,
    purchaserEmail: row.purchaser_email,
    purchaserName: row.purchaser_name ?? undefined,
    productName: row.product_name ?? undefined,
    variantName: row.variant_name ?? undefined,
    receiptUrl: row.receipt_url ?? undefined,
    currency: row.currency ?? undefined,
    total: row.total ?? undefined,
    totalFormatted: row.total_formatted ?? undefined,
    storeId: row.store_id ?? undefined,
    lemonsqueezyOrderId: row.lemonsqueezy_order_id ?? undefined,
    licenseId: row.license_id,
    licenseLookupHash: row.license_lookup_hash ?? undefined,
    emailLookupHash: row.email_lookup_hash ?? undefined,
    activationCredentialHash: row.activation_credential_hash ?? undefined,
    licenseToken: row.license_token,
    deliveryStatus: row.delivery_status as LicenseFulfillment["deliveryStatus"],
    deliveryError: row.delivery_error ?? undefined,
    testMode: row.test_mode,
    fulfilledAt: row.fulfilled_at ?? undefined,
    refundedAt: row.refunded_at ?? undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function createOrGetLicenseFulfillment(input: {
  orderIdentifier: string;
  orderLookupHash?: string;
  orderNumber?: number;
  eventName: string;
  purchaserEmail: string;
  purchaserName?: string;
  productName?: string;
  variantName?: string;
  receiptUrl?: string;
  currency?: string;
  total?: string;
  totalFormatted?: string;
  storeId?: number;
  lemonsqueezyOrderId?: string;
  licenseId: string;
  licenseLookupHash?: string;
  emailLookupHash?: string;
  activationCredentialHash?: string;
  licenseToken: string;
  testMode: boolean;
}) {
  await ensureSchema();
  const sql = getSql();
  const rows = await sql<LicenseFulfillmentRow[]>`
    insert into license_fulfillments (
      id,
      order_identifier,
      order_lookup_hash,
      order_number,
      event_name,
      purchaser_email,
      purchaser_name,
      product_name,
      variant_name,
      receipt_url,
      currency,
      total,
      total_formatted,
      store_id,
      lemonsqueezy_order_id,
      license_id,
      license_lookup_hash,
      email_lookup_hash,
      activation_credential_hash,
      license_token,
      delivery_status,
      delivery_error,
      test_mode
    ) values (
      ${randomUUID()},
      ${input.orderIdentifier},
      ${input.orderLookupHash ?? null},
      ${input.orderNumber ?? null},
      ${input.eventName},
      ${input.purchaserEmail.trim().toLowerCase()},
      ${input.purchaserName?.trim() || null},
      ${input.productName?.trim() || null},
      ${input.variantName?.trim() || null},
      ${input.receiptUrl?.trim() || null},
      ${input.currency?.trim() || null},
      ${input.total?.trim() || null},
      ${input.totalFormatted?.trim() || null},
      ${input.storeId ?? null},
      ${input.lemonsqueezyOrderId ?? null},
      ${input.licenseId},
      ${input.licenseLookupHash ?? null},
      ${input.emailLookupHash ?? null},
      ${input.activationCredentialHash ?? null},
      ${input.licenseToken},
      ${"stored"},
      ${null},
      ${input.testMode}
    )
    on conflict (order_identifier) do update
      set
        order_number = coalesce(license_fulfillments.order_number, excluded.order_number),
        order_lookup_hash = coalesce(license_fulfillments.order_lookup_hash, excluded.order_lookup_hash),
        license_lookup_hash = coalesce(license_fulfillments.license_lookup_hash, excluded.license_lookup_hash),
        email_lookup_hash = coalesce(license_fulfillments.email_lookup_hash, excluded.email_lookup_hash),
        -- Until delivery, the derived code in the outgoing email must match the
        -- stored hash; afterwards keep whatever the customer already holds.
        activation_credential_hash = case
          when license_fulfillments.delivery_status = 'delivered'
            then coalesce(license_fulfillments.activation_credential_hash, excluded.activation_credential_hash)
          else excluded.activation_credential_hash
        end,
        purchaser_name = coalesce(license_fulfillments.purchaser_name, excluded.purchaser_name),
        product_name = coalesce(license_fulfillments.product_name, excluded.product_name),
        variant_name = coalesce(license_fulfillments.variant_name, excluded.variant_name),
        receipt_url = coalesce(license_fulfillments.receipt_url, excluded.receipt_url),
        currency = coalesce(license_fulfillments.currency, excluded.currency),
        total = coalesce(license_fulfillments.total, excluded.total),
        total_formatted = coalesce(license_fulfillments.total_formatted, excluded.total_formatted),
        store_id = coalesce(license_fulfillments.store_id, excluded.store_id),
        lemonsqueezy_order_id = coalesce(license_fulfillments.lemonsqueezy_order_id, excluded.lemonsqueezy_order_id),
        updated_at = now()
    returning *
  `;

  return mapRow(rows[0]);
}

export async function updateLicenseFulfillmentDeliveryStatus(
  orderIdentifier: string,
  status: LicenseFulfillment["deliveryStatus"],
  deliveryError?: string,
) {
  await ensureSchema();
  const sql = getSql();
  const [row] = await sql<LicenseFulfillmentRow[]>`
    update license_fulfillments
    set
      delivery_status = ${status},
      delivery_error = ${deliveryError ?? null},
      fulfilled_at = case
        when ${status === "delivered"} then now()
        else fulfilled_at
      end,
      refunded_at = case
        when ${status === "refunded"} then now()
        else refunded_at
      end,
      updated_at = now()
    where order_identifier = ${orderIdentifier}
    returning *
  `;

  return row ? mapRow(row) : null;
}

export async function markLicenseFulfillmentRefunded(orderIdentifier: string) {
  return updateLicenseFulfillmentDeliveryStatus(orderIdentifier, "refunded");
}

export async function findLicenseFulfillmentByOrder(
  orderIdentifier: string,
) {
  await ensureSchema();
  const [row] = await getSql()<LicenseFulfillmentRow[]>`
    select *
    from license_fulfillments
    where order_identifier = ${orderIdentifier}
    limit 1
  `;
  return row ? mapRow(row) : null;
}

export async function listLicenseFulfillments(limit = 50) {
  await ensureSchema();
  const sql = getSql();
  const rows = await sql<LicenseFulfillmentRow[]>`
    select *
    from license_fulfillments
    order by updated_at desc
    limit ${Math.max(1, Math.min(limit, 500))}
  `;

  return rows.map(mapRow);
}

export async function getLicenseFulfillmentAggregateStats() {
  await ensureSchema();
  const sql = getSql();
  const [row] = await sql<
    {
      total: number;
      delivered: number;
      failed: number;
      pending: number;
      refunded: number;
      purchases30d: number;
      latest_fulfillment: string | null;
    }[]
  >`
    select
      count(*)::int as total,
      count(*) filter (where delivery_status = 'delivered')::int as delivered,
      count(*) filter (where delivery_status = 'failed')::int as failed,
      count(*) filter (where delivery_status = 'stored')::int as pending,
      count(*) filter (where delivery_status = 'refunded')::int as refunded,
      count(*) filter (where created_at >= now() - interval '30 days')::int as purchases30d,
      max(updated_at)::text as latest_fulfillment
    from license_fulfillments
  `;

  return {
    total: row?.total ?? 0,
    delivered: row?.delivered ?? 0,
    failed: row?.failed ?? 0,
    pending: row?.pending ?? 0,
    refunded: row?.refunded ?? 0,
    purchases30d: row?.purchases30d ?? 0,
    latestFulfillment: row?.latest_fulfillment ?? undefined,
  } satisfies LicenseFulfillmentAggregateStats;
}
