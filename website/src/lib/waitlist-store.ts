import { randomUUID } from "node:crypto";

import { getSql, isDatabaseConfigured } from "@/lib/postgres";

type WaitlistRow = {
  id: string;
  email: string;
  name: string | null;
  source: string | null;
  metadata: Record<string, string> | null;
  request_id: string;
  notification_status: string;
  notification_error: string | null;
  created_at: string;
  updated_at: string;
};

export type WaitlistSubmission = {
  id: string;
  email: string;
  name?: string;
  source?: string;
  metadata?: Record<string, string>;
  requestId: string;
  notificationStatus: "stored" | "delivered" | "failed";
  notificationError?: string;
  createdAt: string;
  updatedAt: string;
};

export type WaitlistUpsertResult = {
  submission: WaitlistSubmission;
  alreadyRegistered: boolean;
};

export type WaitlistAggregateStats = {
  total: number;
  delivered: number;
  failed: number;
  pending: number;
  signups24h: number;
  signups7d: number;
  signups30d: number;
  namedCount: number;
  sourceCount: number;
  latestSignup?: string;
};

export type WaitlistBreakdownItem = {
  label: string;
  count: number;
};

export type WaitlistSignupSeriesPoint = {
  day: string;
  count: number;
};

let schemaReady = false;

export function isWaitlistStoreConfigured() {
  return isDatabaseConfigured();
}

async function ensureSchema() {
  if (schemaReady) return;

  const sql = getSql();
  await sql`
    create table if not exists waitlist_signups (
      id text primary key,
      email text not null unique,
      name text,
      source text,
      metadata jsonb,
      request_id text not null,
      notification_status text not null default 'stored',
      notification_error text,
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now()
    )
  `;

  schemaReady = true;
}

function mapRow(row: WaitlistRow): WaitlistSubmission {
  return {
    id: row.id,
    email: row.email,
    name: row.name ?? undefined,
    source: row.source ?? undefined,
    metadata: row.metadata ?? undefined,
    requestId: row.request_id,
    notificationStatus: row.notification_status as WaitlistSubmission["notificationStatus"],
    notificationError: row.notification_error ?? undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function upsertWaitlistSubmission(input: {
  email: string;
  name?: string;
  source?: string;
  metadata?: Record<string, string>;
  requestId: string;
}) {
  await ensureSchema();
  const sql = getSql();
  const normalizedEmail = input.email.trim().toLowerCase();
  const [row] = await sql<WaitlistRow[]>`
    insert into waitlist_signups (
      id,
      email,
      name,
      source,
      metadata,
      request_id,
      notification_status,
      notification_error
    ) values (
      ${randomUUID()},
      ${normalizedEmail},
      ${input.name?.trim() || null},
      ${input.source?.trim() || null},
      ${input.metadata ? sql.json(input.metadata) : null},
      ${input.requestId},
      ${"stored"},
      ${null}
    )
    on conflict (email) do nothing
    returning *
  `;

  if (row) return { submission: mapRow(row), alreadyRegistered: false } satisfies WaitlistUpsertResult;
  const [existing] = await sql<WaitlistRow[]>`
    select * from waitlist_signups where email = ${normalizedEmail} limit 1
  `;
  if (!existing) throw new Error("Waitlist enrollment could not be persisted.");
  return { submission: mapRow(existing), alreadyRegistered: true } satisfies WaitlistUpsertResult;
}

export async function updateWaitlistNotificationStatus(
  email: string,
  status: WaitlistSubmission["notificationStatus"],
  notificationError?: string,
) {
  await ensureSchema();
  const sql = getSql();
  const [row] = await sql<WaitlistRow[]>`
    update waitlist_signups
    set
      notification_status = ${status},
      notification_error = ${notificationError ?? null},
      updated_at = now()
    where email = ${email.trim().toLowerCase()}
    returning *
  `;

  return row ? mapRow(row) : null;
}

export async function listWaitlistSubmissions(limit = 100) {
  await ensureSchema();
  const sql = getSql();
  const rows = await sql<WaitlistRow[]>`
    select *
    from waitlist_signups
    order by updated_at desc
    limit ${Math.max(1, Math.min(limit, 5000))}
  `;

  return rows.map(mapRow);
}

export async function getWaitlistAggregateStats() {
  await ensureSchema();
  const sql = getSql();
  const [row] = await sql<
    {
      total: number;
      delivered: number;
      failed: number;
      pending: number;
      signups24h: number;
      signups7d: number;
      signups30d: number;
      named_count: number;
      source_count: number;
      latest_signup: string | null;
    }[]
  >`
    select
      count(*)::int as total,
      count(*) filter (where notification_status = 'delivered')::int as delivered,
      count(*) filter (where notification_status = 'failed')::int as failed,
      count(*) filter (where notification_status = 'stored')::int as pending,
      count(*) filter (where created_at >= now() - interval '24 hours')::int as signups24h,
      count(*) filter (where created_at >= now() - interval '7 days')::int as signups7d,
      count(*) filter (where created_at >= now() - interval '30 days')::int as signups30d,
      count(*) filter (where name is not null and btrim(name) <> '')::int as named_count,
      count(distinct coalesce(nullif(source, ''), 'homepage_waitlist'))::int as source_count,
      max(updated_at)::text as latest_signup
    from waitlist_signups
  `;

  return {
    total: row?.total ?? 0,
    delivered: row?.delivered ?? 0,
    failed: row?.failed ?? 0,
    pending: row?.pending ?? 0,
    signups24h: row?.signups24h ?? 0,
    signups7d: row?.signups7d ?? 0,
    signups30d: row?.signups30d ?? 0,
    namedCount: row?.named_count ?? 0,
    sourceCount: row?.source_count ?? 0,
    latestSignup: row?.latest_signup ?? undefined,
  } satisfies WaitlistAggregateStats;
}

export async function listWaitlistSignupSeries(days = 14) {
  await ensureSchema();
  const sql = getSql();
  const safeDays = Math.max(1, Math.min(days, 90));
  const rows = await sql<WaitlistSignupSeriesPoint[]>`
    with series as (
      select generate_series(
        timezone('Asia/Singapore', now())::date - ${safeDays - 1},
        timezone('Asia/Singapore', now())::date,
        interval '1 day'
      )::date as day
    )
    select
      series.day::text as day,
      coalesce(count(waitlist_signups.id), 0)::int as count
    from series
    left join waitlist_signups
      on timezone('Asia/Singapore', waitlist_signups.created_at)::date = series.day
    group by series.day
    order by series.day asc
  `;

  return rows;
}

export async function listWaitlistBreakdown(
  kind: "source" | "utm_source" | "utm_medium" | "path",
  limit = 6,
) {
  await ensureSchema();
  const sql = getSql();
  const safeLimit = Math.max(1, Math.min(limit, 20));

  const query =
    kind === "source"
      ? sql<WaitlistBreakdownItem[]>`
          select
            coalesce(nullif(source, ''), 'homepage_waitlist') as label,
            count(*)::int as count
          from waitlist_signups
          group by 1
          order by count desc, label asc
          limit ${safeLimit}
        `
      : kind === "utm_source"
        ? sql<WaitlistBreakdownItem[]>`
            select
              coalesce(nullif(metadata->>'utm_source', ''), 'direct') as label,
              count(*)::int as count
            from waitlist_signups
            group by 1
            order by count desc, label asc
            limit ${safeLimit}
          `
        : kind === "utm_medium"
          ? sql<WaitlistBreakdownItem[]>`
              select
                coalesce(nullif(metadata->>'utm_medium', ''), 'unknown') as label,
                count(*)::int as count
              from waitlist_signups
              group by 1
              order by count desc, label asc
              limit ${safeLimit}
            `
          : sql<WaitlistBreakdownItem[]>`
              select
                coalesce(nullif(metadata->>'path', ''), '/') as label,
                count(*)::int as count
              from waitlist_signups
              group by 1
              order by count desc, label asc
              limit ${safeLimit}
            `;

  const rows = await query;
  return rows;
}
