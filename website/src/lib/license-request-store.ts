import { randomUUID } from "node:crypto";

import { getSql, isDatabaseConfigured } from "@/lib/postgres";

type LicenseRequestRow = {
  id: string;
  email: string;
  name: string | null;
  purchase_email: string | null;
  reason: string;
  message: string;
  metadata: Record<string, string> | null;
  request_id: string;
  notification_status: string;
  notification_error: string | null;
  created_at: string;
  updated_at: string;
};

export type LicenseRequest = {
  id: string;
  email: string;
  name?: string;
  purchaseEmail?: string;
  reason: string;
  message: string;
  metadata?: Record<string, string>;
  requestId: string;
  notificationStatus: "stored" | "delivered" | "failed";
  notificationError?: string;
  createdAt: string;
  updatedAt: string;
};

export type LicenseRequestAggregateStats = {
  total: number;
  delivered: number;
  failed: number;
  pending: number;
  requests30d: number;
  latestRequest?: string;
};

export function isLicenseRequestStoreConfigured() {
  return isDatabaseConfigured();
}

function mapRow(row: LicenseRequestRow): LicenseRequest {
  return {
    id: row.id,
    email: row.email,
    name: row.name ?? undefined,
    purchaseEmail: row.purchase_email ?? undefined,
    reason: row.reason,
    message: row.message,
    metadata: row.metadata ?? undefined,
    requestId: row.request_id,
    notificationStatus: row.notification_status as LicenseRequest["notificationStatus"],
    notificationError: row.notification_error ?? undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function createLicenseRequest(input: {
  email: string;
  name?: string;
  purchaseEmail?: string;
  reason: string;
  message: string;
  metadata?: Record<string, string>;
  requestId: string;
}) {
  const sql = getSql();
  const [row] = await sql<LicenseRequestRow[]>`
    insert into license_requests (
      id,
      email,
      name,
      purchase_email,
      reason,
      message,
      metadata,
      request_id,
      notification_status,
      notification_error
    ) values (
      ${randomUUID()},
      ${input.email.trim().toLowerCase()},
      ${input.name?.trim() || null},
      ${input.purchaseEmail?.trim().toLowerCase() || null},
      ${input.reason},
      ${input.message.trim()},
      ${input.metadata ? sql.json(input.metadata) : null},
      ${input.requestId},
      ${"stored"},
      ${null}
    )
    returning *
  `;

  return mapRow(row);
}

export async function updateLicenseRequestNotificationStatus(
  requestId: string,
  status: LicenseRequest["notificationStatus"],
  notificationError?: string,
) {
  const sql = getSql();
  const [row] = await sql<LicenseRequestRow[]>`
    update license_requests
    set
      notification_status = ${status},
      notification_error = ${notificationError ?? null},
      updated_at = now()
    where request_id = ${requestId}
    returning *
  `;

  return row ? mapRow(row) : null;
}

export async function listLicenseRequests(limit = 50) {
  const sql = getSql();
  const rows = await sql<LicenseRequestRow[]>`
    select *
    from license_requests
    order by updated_at desc
    limit ${Math.max(1, Math.min(limit, 500))}
  `;

  return rows.map(mapRow);
}

export async function getLicenseRequestAggregateStats() {
  const sql = getSql();
  const [row] = await sql<
    {
      total: number;
      delivered: number;
      failed: number;
      pending: number;
      requests30d: number;
      latest_request: string | null;
    }[]
  >`
    select
      count(*)::int as total,
      count(*) filter (where notification_status = 'delivered')::int as delivered,
      count(*) filter (where notification_status = 'failed')::int as failed,
      count(*) filter (where notification_status = 'stored')::int as pending,
      count(*) filter (where created_at >= now() - interval '30 days')::int as requests30d,
      max(updated_at)::text as latest_request
    from license_requests
  `;

  return {
    total: row?.total ?? 0,
    delivered: row?.delivered ?? 0,
    failed: row?.failed ?? 0,
    pending: row?.pending ?? 0,
    requests30d: row?.requests30d ?? 0,
    latestRequest: row?.latest_request ?? undefined,
  } satisfies LicenseRequestAggregateStats;
}
