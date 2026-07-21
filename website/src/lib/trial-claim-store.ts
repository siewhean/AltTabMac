import { randomUUID } from "node:crypto";

import { getSql, isDatabaseConfigured } from "@/lib/postgres";

type TrialClaimRow = {
  id: string;
  email: string;
  install_id: string;
  app_version: string | null;
  os_version: string | null;
  started_at: string;
  ends_at: string;
  last_seen_at: string;
  reminder_sent_at: string | null;
  created_at: string;
  updated_at: string;
};

export type TrialClaim = {
  id: string;
  email: string;
  installId: string;
  appVersion?: string;
  osVersion?: string;
  startedAt: string;
  endsAt: string;
  lastSeenAt: string;
  reminderSentAt?: string;
  createdAt: string;
  updatedAt: string;
};

export type TrialClaimAggregateStats = {
  total: number;
  active: number;
  expired: number;
  claims30d: number;
  latestClaim?: string;
};

type CreateTrialClaimResult =
  | { kind: "created" | "existing"; claim: TrialClaim }
  | { kind: "blocked"; reason: "email_already_used" | "install_already_registered"; claim?: TrialClaim };

export function isTrialClaimStoreConfigured() {
  return isDatabaseConfigured();
}

function mapRow(row: TrialClaimRow): TrialClaim {
  return {
    id: row.id,
    email: row.email,
    installId: row.install_id,
    appVersion: row.app_version ?? undefined,
    osVersion: row.os_version ?? undefined,
    startedAt: row.started_at,
    endsAt: row.ends_at,
    lastSeenAt: row.last_seen_at,
    reminderSentAt: row.reminder_sent_at ?? undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function createOrGetTrialClaim(input: {
  email: string;
  installId: string;
  appVersion?: string;
  osVersion?: string;
  trialLengthDays: number;
  now?: Date;
}): Promise<CreateTrialClaimResult> {
  const sql = getSql();
  const now = input.now ?? new Date();
  const normalizedEmail = input.email.trim().toLowerCase();
  const installId = input.installId.trim();

  const [existingByEmail] = await sql<TrialClaimRow[]>`
    select *
    from trial_claims
    where email = ${normalizedEmail}
    limit 1
  `;
  const [existingByInstall] = await sql<TrialClaimRow[]>`
    select *
    from trial_claims
    where install_id = ${installId}
    limit 1
  `;

  if (existingByEmail && existingByEmail.install_id === installId) {
    return { kind: "existing", claim: mapRow(existingByEmail) };
  }

  if (existingByEmail && existingByEmail.install_id !== installId) {
    return {
      kind: "blocked",
      reason: "email_already_used",
      claim: mapRow(existingByEmail),
    };
  }

  if (existingByInstall && existingByInstall.email !== normalizedEmail) {
    return {
      kind: "blocked",
      reason: "install_already_registered",
      claim: mapRow(existingByInstall),
    };
  }

  const startedAt = now.toISOString();
  const endsAt = new Date(now.getTime() + input.trialLengthDays * 24 * 60 * 60 * 1000).toISOString();

  const [row] = await sql<TrialClaimRow[]>`
    insert into trial_claims (
      id,
      email,
      install_id,
      app_version,
      os_version,
      started_at,
      ends_at,
      last_seen_at
    ) values (
      ${randomUUID()},
      ${normalizedEmail},
      ${installId},
      ${input.appVersion?.trim() || null},
      ${input.osVersion?.trim() || null},
      ${startedAt},
      ${endsAt},
      ${startedAt}
    )
    returning *
  `;

  return { kind: "created", claim: mapRow(row) };
}

export async function touchTrialClaim(installId: string) {
  const sql = getSql();
  const [row] = await sql<TrialClaimRow[]>`
    update trial_claims
    set
      last_seen_at = now(),
      updated_at = now()
    where install_id = ${installId.trim()}
    returning *
  `;

  return row ? mapRow(row) : null;
}

export async function getTrialClaimAggregateStats() {
  const sql = getSql();
  const [row] = await sql<
    {
      total: number;
      active: number;
      expired: number;
      claims30d: number;
      latest_claim: string | null;
    }[]
  >`
    select
      count(*)::int as total,
      count(*) filter (where ends_at > now())::int as active,
      count(*) filter (where ends_at <= now())::int as expired,
      count(*) filter (where created_at >= now() - interval '30 days')::int as claims30d,
      max(updated_at)::text as latest_claim
    from trial_claims
  `;

  return {
    total: row?.total ?? 0,
    active: row?.active ?? 0,
    expired: row?.expired ?? 0,
    claims30d: row?.claims30d ?? 0,
    latestClaim: row?.latest_claim ?? undefined,
  } satisfies TrialClaimAggregateStats;
}

export async function listTrialClaimsDueForReminder(limit = 100) {
  const sql = getSql();
  const rows = await sql<TrialClaimRow[]>`
    select *
    from trial_claims
    where reminder_sent_at is null
      and ends_at > now()
      and ends_at <= now() + interval '36 hours'
    order by ends_at asc
    limit ${Math.max(1, Math.min(limit, 500))}
  `;

  return rows.map(mapRow);
}

export async function markTrialReminderSent(id: string) {
  const sql = getSql();
  const [row] = await sql<TrialClaimRow[]>`
    update trial_claims
    set
      reminder_sent_at = now(),
      updated_at = now()
    where id = ${id}
    returning *
  `;

  return row ? mapRow(row) : null;
}
