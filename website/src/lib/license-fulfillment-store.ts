import { createHash, randomUUID } from "node:crypto";

import { getSql, isDatabaseConfigured } from "@/lib/postgres";

type LicenseFulfillmentRow = {
  id: string;
  order_identifier: string | null;
  order_hash: string | null;
  order_number: number | null;
  event_name: string;
  purchaser_email: string | null;
  purchaser_name: string | null;
  product_name: string | null;
  variant_name: string | null;
  receipt_url: string | null;
  currency: string | null;
  total: string | null;
  total_formatted: string | null;
  store_id: number | null;
  lemonsqueezy_order_id: string | null;
  license_id: string | null;
  license_token: string | null;
  processing_token: string | null;
  delivery_status: string;
  delivery_error: string | null;
  test_mode: boolean;
  fulfilled_at: string | null;
  refunded_at: string | null;
  anonymized_at: string | null;
  created_at: string;
  updated_at: string;
};

export type LicenseFulfillment = {
  id: string;
  orderIdentifier: string;
  orderHash?: string;
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
  licenseToken: string;
  deliveryStatus: "stored" | "processing" | "delivered" | "failed" | "refunded";
  deliveryError?: string;
  testMode: boolean;
  fulfilledAt?: string;
  refundedAt?: string;
  anonymizedAt?: string;
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

export function isLicenseFulfillmentStoreConfigured() {
  return isDatabaseConfigured();
}

function mapRow(row: LicenseFulfillmentRow): LicenseFulfillment {
  return {
    id: row.id,
    orderIdentifier: row.order_identifier ?? `anonymized:${row.order_hash ?? row.id}`,
    orderHash: row.order_hash ?? undefined,
    orderNumber: row.order_number ?? undefined,
    eventName: row.event_name,
    purchaserEmail: row.purchaser_email ?? "Anonymized",
    purchaserName: row.purchaser_name ?? undefined,
    productName: row.product_name ?? undefined,
    variantName: row.variant_name ?? undefined,
    receiptUrl: row.receipt_url ?? undefined,
    currency: row.currency ?? undefined,
    total: row.total ?? undefined,
    totalFormatted: row.total_formatted ?? undefined,
    storeId: row.store_id ?? undefined,
    lemonsqueezyOrderId: row.lemonsqueezy_order_id ?? undefined,
    licenseId: row.license_id ?? "",
    licenseToken: row.license_token ?? "",
    deliveryStatus: row.delivery_status as LicenseFulfillment["deliveryStatus"],
    deliveryError: row.delivery_error ?? undefined,
    testMode: row.test_mode,
    fulfilledAt: row.fulfilled_at ?? undefined,
    refundedAt: row.refunded_at ?? undefined,
    anonymizedAt: row.anonymized_at ?? undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function claimLicenseFulfillment(input: {
  orderIdentifier: string;
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
  licenseToken: string;
  testMode: boolean;
}) {
  const sql = getSql();
  const orderHash = createHash("sha256").update(input.orderIdentifier).digest("hex");
  const processingToken = randomUUID();
  const rows = await sql<LicenseFulfillmentRow[]>`
    insert into license_fulfillments (
      id,
      order_identifier,
      order_hash,
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
      license_token,
      processing_token,
      delivery_status,
      delivery_error,
      test_mode
    ) values (
      ${randomUUID()},
      ${input.orderIdentifier},
      ${orderHash},
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
      ${input.licenseToken},
      ${processingToken},
      ${"processing"},
      ${null},
      ${input.testMode}
    )
    on conflict (order_hash) do update
      set
        order_hash = coalesce(license_fulfillments.order_hash, excluded.order_hash),
        order_number = coalesce(license_fulfillments.order_number, excluded.order_number),
        purchaser_name = coalesce(license_fulfillments.purchaser_name, excluded.purchaser_name),
        product_name = coalesce(license_fulfillments.product_name, excluded.product_name),
        variant_name = coalesce(license_fulfillments.variant_name, excluded.variant_name),
        receipt_url = coalesce(license_fulfillments.receipt_url, excluded.receipt_url),
        currency = coalesce(license_fulfillments.currency, excluded.currency),
        total = coalesce(license_fulfillments.total, excluded.total),
        total_formatted = coalesce(license_fulfillments.total_formatted, excluded.total_formatted),
        store_id = coalesce(license_fulfillments.store_id, excluded.store_id),
        lemonsqueezy_order_id = coalesce(license_fulfillments.lemonsqueezy_order_id, excluded.lemonsqueezy_order_id),
        processing_token = excluded.processing_token,
        delivery_status = 'processing',
        delivery_error = null,
        updated_at = now()
      where license_fulfillments.delivery_status = 'failed'
         or (
           license_fulfillments.delivery_status = 'processing'
           and license_fulfillments.updated_at < now() - interval '15 minutes'
         )
    returning *
  `;
  if (rows[0]) {
    return {
      fulfillment: mapRow(rows[0]),
      acquired: true as const,
      processingToken,
    };
  }
  const [existing] = await sql<LicenseFulfillmentRow[]>`
    select * from license_fulfillments where order_hash = ${orderHash} limit 1
  `;
  if (!existing) throw new Error("License fulfillment claim disappeared.");
  return { fulfillment: mapRow(existing), acquired: false as const };
}

export async function updateLicenseFulfillmentDeliveryStatus(
  orderIdentifier: string,
  processingToken: string,
  status: "delivered" | "failed",
  deliveryError?: string,
) {
  const sql = getSql();
  const [row] = await sql<LicenseFulfillmentRow[]>`
    update license_fulfillments
    set
      delivery_status = ${status},
      processing_token = null,
      delivery_error = ${deliveryError ?? null},
      fulfilled_at = case
        when ${status === "delivered"} then now()
        else fulfilled_at
      end,
      updated_at = now()
    where order_identifier = ${orderIdentifier}
      and delivery_status = 'processing'
      and processing_token = ${processingToken}
    returning *
  `;

  return row ? mapRow(row) : null;
}

export async function markLicenseFulfillmentRefunded(orderIdentifier: string) {
  const sql = getSql();
  const orderHash = createHash("sha256").update(orderIdentifier).digest("hex");
  const [row] = await sql<LicenseFulfillmentRow[]>`
    insert into license_fulfillments (
      id, order_identifier, order_hash, event_name, delivery_status,
      test_mode, refunded_at, created_at, updated_at
    ) values (
      ${randomUUID()}, ${orderIdentifier}, ${orderHash}, ${"order_refunded"},
      ${"refunded"}, ${false}, now(), now(), now()
    )
    on conflict (order_hash) do update set
      delivery_status = 'refunded',
      processing_token = null,
      refunded_at = now(),
      updated_at = now()
    returning *
  `;
  return mapRow(row);
}

export async function getLicenseFulfillmentStatusByLicenseID(licenseID: string) {
  const sql = getSql();
  const [row] = await sql<LicenseFulfillmentRow[]>`
    select *
    from license_fulfillments
    where license_id = ${licenseID}
    order by updated_at desc
    limit 1
  `;

  return row ? mapRow(row) : null;
}

export async function listLicenseFulfillments(limit = 50) {
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
