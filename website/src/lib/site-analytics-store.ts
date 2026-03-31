import { randomUUID } from "node:crypto";

import { getSql, isDatabaseConfigured } from "@/lib/postgres";

type SiteAnalyticsRow = {
  id: string;
  event_type: "pageview" | "event";
  event_name: string | null;
  path: string;
  referrer: string | null;
  context: string | null;
  event_data: Record<string, unknown> | null;
  visitor_id: string | null;
  session_id: string | null;
  occurred_at: string;
  created_at: string;
};

export type SiteAnalyticsEventInput = {
  eventType: "pageview" | "event";
  eventName?: string;
  path: string;
  referrer?: string;
  context?: string;
  eventData?: Record<string, unknown>;
  visitorId?: string;
  sessionId?: string;
  occurredAt?: string;
};

export type SiteAnalyticsOverview = {
  pageviews24h: number;
  pageviews7d: number;
  visitors24h: number;
  visitors7d: number;
  totalEvents7d: number;
  latestEvent?: string;
};

export type SiteAnalyticsBreakdownItem = {
  label: string;
  count: number;
};

export type SiteAnalyticsSeriesPoint = {
  day: string;
  pageviews: number;
  visitors: number;
};

let schemaReady = false;

function serializeEventData(data?: Record<string, unknown>) {
  if (!data) return null;
  return JSON.parse(JSON.stringify(data));
}

export function isSiteAnalyticsConfigured() {
  return isDatabaseConfigured();
}

async function ensureSchema() {
  if (schemaReady || !isDatabaseConfigured()) return;

  const sql = getSql();
  await sql`
    create table if not exists site_analytics_events (
      id text primary key,
      event_type text not null,
      event_name text,
      path text not null,
      referrer text,
      context text,
      event_data jsonb,
      visitor_id text,
      session_id text,
      occurred_at timestamptz not null,
      created_at timestamptz not null default now()
    )
  `;

  await sql`
    create index if not exists site_analytics_events_occurred_at_idx
      on site_analytics_events (occurred_at desc)
  `;

  await sql`
    create index if not exists site_analytics_events_type_idx
      on site_analytics_events (event_type, occurred_at desc)
  `;

  await sql`
    create index if not exists site_analytics_events_path_idx
      on site_analytics_events (path, occurred_at desc)
  `;

  await sql`
    create index if not exists site_analytics_events_name_idx
      on site_analytics_events (event_name, occurred_at desc)
  `;

  schemaReady = true;
}

export async function recordSiteAnalyticsEvent(input: SiteAnalyticsEventInput) {
  if (!isDatabaseConfigured()) return null;
  await ensureSchema();

  const sql = getSql();
  const occurredAt = input.occurredAt ? new Date(input.occurredAt) : new Date();
  const safeOccurredAt = Number.isNaN(occurredAt.getTime()) ? new Date() : occurredAt;

  const [row] = await sql<SiteAnalyticsRow[]>`
    insert into site_analytics_events (
      id,
      event_type,
      event_name,
      path,
      referrer,
      context,
      event_data,
      visitor_id,
      session_id,
      occurred_at
    ) values (
      ${randomUUID()},
      ${input.eventType},
      ${input.eventName ?? null},
      ${input.path},
      ${input.referrer ?? null},
      ${input.context ?? null},
      ${input.eventData ? sql.json(serializeEventData(input.eventData) as never) : null},
      ${input.visitorId ?? null},
      ${input.sessionId ?? null},
      ${safeOccurredAt.toISOString()}
    )
    returning *
  `;

  return row ?? null;
}

export async function getSiteAnalyticsOverview() {
  if (!isDatabaseConfigured()) {
    return {
      pageviews24h: 0,
      pageviews7d: 0,
      visitors24h: 0,
      visitors7d: 0,
      totalEvents7d: 0,
      latestEvent: undefined,
    } satisfies SiteAnalyticsOverview;
  }

  await ensureSchema();
  const sql = getSql();
  const [row] = await sql<
    {
      pageviews_24h: number;
      pageviews_7d: number;
      visitors_24h: number;
      visitors_7d: number;
      total_events_7d: number;
      latest_event: string | null;
    }[]
  >`
    select
      count(*) filter (
        where event_type = 'pageview'
          and occurred_at >= now() - interval '24 hours'
      )::int as pageviews_24h,
      count(*) filter (
        where event_type = 'pageview'
          and occurred_at >= now() - interval '7 days'
      )::int as pageviews_7d,
      count(distinct coalesce(nullif(visitor_id, ''), session_id)) filter (
        where event_type = 'pageview'
          and occurred_at >= now() - interval '24 hours'
      )::int as visitors_24h,
      count(distinct coalesce(nullif(visitor_id, ''), session_id)) filter (
        where event_type = 'pageview'
          and occurred_at >= now() - interval '7 days'
      )::int as visitors_7d,
      count(*) filter (
        where event_type = 'event'
          and occurred_at >= now() - interval '7 days'
      )::int as total_events_7d,
      max(occurred_at)::text as latest_event
    from site_analytics_events
    where path not like '/dashboard%'
  `;

  return {
    pageviews24h: row?.pageviews_24h ?? 0,
    pageviews7d: row?.pageviews_7d ?? 0,
    visitors24h: row?.visitors_24h ?? 0,
    visitors7d: row?.visitors_7d ?? 0,
    totalEvents7d: row?.total_events_7d ?? 0,
    latestEvent: row?.latest_event ?? undefined,
  } satisfies SiteAnalyticsOverview;
}

export async function listTopAnalyticsPages(limit = 6) {
  if (!isDatabaseConfigured()) return [] satisfies SiteAnalyticsBreakdownItem[];
  await ensureSchema();
  const sql = getSql();
  const safeLimit = Math.max(1, Math.min(limit, 20));

  return sql<SiteAnalyticsBreakdownItem[]>`
    select
      path as label,
      count(*)::int as count
    from site_analytics_events
    where event_type = 'pageview'
      and path not like '/dashboard%'
    group by path
    order by count desc, path asc
    limit ${safeLimit}
  `;
}

export async function listTopAnalyticsEvents(limit = 8) {
  if (!isDatabaseConfigured()) return [] satisfies SiteAnalyticsBreakdownItem[];
  await ensureSchema();
  const sql = getSql();
  const safeLimit = Math.max(1, Math.min(limit, 20));

  return sql<SiteAnalyticsBreakdownItem[]>`
    select
      coalesce(nullif(event_name, ''), 'unnamed_event') as label,
      count(*)::int as count
    from site_analytics_events
    where event_type = 'event'
      and path not like '/dashboard%'
    group by 1
    order by count desc, label asc
    limit ${safeLimit}
  `;
}

export async function listSiteAnalyticsSeries(days = 14) {
  if (!isDatabaseConfigured()) return [] satisfies SiteAnalyticsSeriesPoint[];
  await ensureSchema();
  const sql = getSql();
  const safeDays = Math.max(1, Math.min(days, 90));

  return sql<SiteAnalyticsSeriesPoint[]>`
    with series as (
      select generate_series(
        timezone('Asia/Singapore', now())::date - ${safeDays - 1},
        timezone('Asia/Singapore', now())::date,
        interval '1 day'
      )::date as day
    ),
    pageviews as (
      select
        timezone('Asia/Singapore', occurred_at)::date as day,
        count(*)::int as count
      from site_analytics_events
      where event_type = 'pageview'
        and path not like '/dashboard%'
      group by 1
    ),
    visitors as (
      select
        timezone('Asia/Singapore', occurred_at)::date as day,
        count(distinct coalesce(nullif(visitor_id, ''), session_id))::int as count
      from site_analytics_events
      where event_type = 'pageview'
        and path not like '/dashboard%'
      group by 1
    )
    select
      series.day::text as day,
      coalesce(pageviews.count, 0)::int as pageviews,
      coalesce(visitors.count, 0)::int as visitors
    from series
    left join pageviews on pageviews.day = series.day
    left join visitors on visitors.day = series.day
    order by series.day asc
  `;
}
