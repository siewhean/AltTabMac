import { randomUUID } from "node:crypto";

import type { AppTelemetryEventInput } from "@/lib/app-telemetry-contract";
import { getSql, isDatabaseConfigured } from "@/lib/postgres";

type AppUsageRow = {
  id: string;
  event_name: string;
  license_state: string;
  app_version: string;
  os_version: string;
  occurred_at: string;
  created_at: string;
};

export type AppUsageEventInput = AppTelemetryEventInput;

export type AppUsageOverview = {
  appActivations7d: number;
  heartbeats7d: number;
  appEvents7d: number;
  licenseActivations30d: number;
  latestActivity?: string;
};

let schemaReady = false;

export function isAppUsageStoreConfigured() {
  return isDatabaseConfigured();
}

async function ensureSchema() {
  if (schemaReady || !isDatabaseConfigured()) return;

  const sql = getSql();
  await sql`
    create table if not exists app_usage_events (
      id text primary key,
      event_name text not null,
      license_state text not null,
      app_version text not null,
      os_version text not null,
      occurred_at timestamptz not null,
      created_at timestamptz not null default now()
    )
  `;

  await sql`
    create index if not exists app_usage_events_occurred_at_idx
      on app_usage_events (occurred_at desc)
  `;

  // Older deployments used these columns for stable identifiers. Keep the
  // columns only for safe application rollback, but make every stored value
  // anonymous before accepting the v2 aggregate-only payload.
  await sql`
    do $$
    begin
      if exists (
        select 1
        from information_schema.columns
        where table_schema = current_schema()
          and table_name = 'app_usage_events'
          and column_name = 'install_id'
      ) then
        alter table app_usage_events alter column install_id drop not null;
        update app_usage_events set install_id = null where install_id is not null;
      end if;

      if exists (
        select 1
        from information_schema.columns
        where table_schema = current_schema()
          and table_name = 'app_usage_events'
          and column_name = 'license_id'
      ) then
        update app_usage_events set license_id = null where license_id is not null;
      end if;
    end
    $$;
  `;

  await sql`
    create index if not exists app_usage_events_name_idx
      on app_usage_events (event_name, occurred_at desc)
  `;

  schemaReady = true;
}

export async function recordAppUsageEvent(input: AppUsageEventInput) {
  if (!isDatabaseConfigured()) return null;
  await ensureSchema();
  const sql = getSql();
  const occurredAt = new Date(input.occurredAt);

  const [row] = await sql<AppUsageRow[]>`
    insert into app_usage_events (
      id,
      event_name,
      license_state,
      app_version,
      os_version,
      occurred_at
    ) values (
      ${randomUUID()},
      ${input.eventName},
      ${input.licenseState},
      ${input.appVersion},
      ${input.osVersion},
      ${occurredAt.toISOString()}
    )
    returning *
  `;

  return row ?? null;
}

export async function getAppUsageOverview() {
  if (!isDatabaseConfigured()) {
    return {
      appActivations7d: 0,
      heartbeats7d: 0,
      appEvents7d: 0,
      licenseActivations30d: 0,
      latestActivity: undefined,
    } satisfies AppUsageOverview;
  }

  await ensureSchema();
  const sql = getSql();
  const [row] = await sql<
    {
      app_activations_7d: number;
      heartbeats_7d: number;
      app_events_7d: number;
      license_activations_30d: number;
      latest_activity: string | null;
    }[]
  >`
    select
      count(*) filter (
        where event_name = 'app_activation'
          and occurred_at >= now() - interval '7 days'
      )::int as app_activations_7d,
      count(*) filter (
        where event_name = 'app_heartbeat'
          and occurred_at >= now() - interval '7 days'
      )::int as heartbeats_7d,
      count(*) filter (
        where occurred_at >= now() - interval '7 days'
      )::int as app_events_7d,
      count(*) filter (
        where event_name = 'license_activated'
          and occurred_at >= now() - interval '30 days'
      )::int as license_activations_30d,
      max(occurred_at)::text as latest_activity
    from app_usage_events
  `;

  return {
    appActivations7d: row?.app_activations_7d ?? 0,
    heartbeats7d: row?.heartbeats_7d ?? 0,
    appEvents7d: row?.app_events_7d ?? 0,
    licenseActivations30d: row?.license_activations_30d ?? 0,
    latestActivity: row?.latest_activity ?? undefined,
  } satisfies AppUsageOverview;
}
