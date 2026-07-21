import { randomUUID } from "node:crypto";

import { getSql, isDatabaseConfigured } from "@/lib/postgres";
import { touchTrialClaim } from "@/lib/trial-claim-store";

type AppUsageRow = {
  id: string;
  install_id: string;
  event_name: string;
  license_state: string;
  license_id: string | null;
  app_version: string | null;
  os_version: string | null;
  metadata: Record<string, unknown> | null;
  occurred_at: string;
  created_at: string;
};

export type AppUsageEventInput = {
  installId: string;
  eventName: "app_activation" | "app_heartbeat" | "license_activated" | "trial_started";
  licenseState: "unregistered" | "trial_active" | "trial_expired" | "licensed";
  licenseId?: string;
  appVersion?: string;
  osVersion?: string;
  metadata?: Record<string, unknown>;
  occurredAt?: string;
};

export type AppUsageOverview = {
  appActivations7d: number;
  heartbeats7d: number;
  activeInstalls7d: number;
  licenseActivations30d: number;
  latestActivity?: string;
};

export function isAppUsageStoreConfigured() {
  return isDatabaseConfigured();
}

export async function recordAppUsageEvent(input: AppUsageEventInput) {
  if (!isDatabaseConfigured()) return null;
  const sql = getSql();
  const occurredAt = input.occurredAt ? new Date(input.occurredAt) : new Date();
  const safeOccurredAt = Number.isNaN(occurredAt.getTime()) ? new Date() : occurredAt;

  const [row] = await sql<AppUsageRow[]>`
    insert into app_usage_events (
      id,
      install_id,
      event_name,
      license_state,
      license_id,
      app_version,
      os_version,
      metadata,
      occurred_at
    ) values (
      ${randomUUID()},
      ${input.installId.trim()},
      ${input.eventName},
      ${input.licenseState},
      ${input.licenseId?.trim() || null},
      ${input.appVersion?.trim() || null},
      ${input.osVersion?.trim() || null},
      ${input.metadata ? sql.json(JSON.parse(JSON.stringify(input.metadata))) : null},
      ${safeOccurredAt.toISOString()}
    )
    returning *
  `;

  await touchTrialClaim(input.installId);
  return row ?? null;
}

export async function getAppUsageOverview() {
  if (!isDatabaseConfigured()) {
    return {
      appActivations7d: 0,
      heartbeats7d: 0,
      activeInstalls7d: 0,
      licenseActivations30d: 0,
      latestActivity: undefined,
    } satisfies AppUsageOverview;
  }

  const sql = getSql();
  const [row] = await sql<
    {
      app_activations_7d: number;
      heartbeats_7d: number;
      active_installs_7d: number;
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
      count(distinct install_id) filter (
        where occurred_at >= now() - interval '7 days'
      )::int as active_installs_7d,
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
    activeInstalls7d: row?.active_installs_7d ?? 0,
    licenseActivations30d: row?.license_activations_30d ?? 0,
    latestActivity: row?.latest_activity ?? undefined,
  } satisfies AppUsageOverview;
}
