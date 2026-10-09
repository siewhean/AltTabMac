import { randomUUID } from "node:crypto";

import { getSql, isDatabaseConfigured } from "@/lib/postgres";

type TrialClaimRow = {
  id: string;
  email: string;
  install_id: string;
  hardware_id?: string | null;
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

let schemaReady = false;

export function isTrialClaimStoreConfigured() {
  return isDatabaseConfigured();
}

async function ensureSchema() {
  if (schemaReady) return;

  const sql = getSql();
  await sql`
    create table if not exists trial_claims (
      id text primary key,
      email text not null unique,
      install_id text not null unique,
      app_version text,
      os_version text,
      started_at timestamptz not null,
      ends_at timestamptz not null,
      last_seen_at timestamptz not null default now(),
      reminder_sent_at timestamptz,
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now()
    )
  `;

  await sql`
    alter table trial_claims
    add column if not exists reminder_sent_at timestamptz,
    add column if not exists hardware_id text
  `;
  await sql`
    create unique index if not exists trial_claims_hardware_idx
    on trial_claims (hardware_id) where hardware_id is not null
  `;

  schemaReady = true;
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
  hardwareId?: string;
  appVersion?: string;
  osVersion?: string;
  trialLengthDays: number;
  now?: Date;
}): Promise<CreateTrialClaimResult> {
  await ensureSchema();
  const sql = getSql();
  const now = input.now ?? new Date();
  const normalizedEmail = input.email.trim().toLowerCase();
  const installId = input.installId.trim();
  const hardwareId = input.hardwareId?.trim() || null;

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

  // A Mac that already had a trial keeps that trial's original dates even
  // after its Keychain identity is reset: rebind the claim to the new install.
  if (hardwareId) {
    const [existingByHardware] = await sql<TrialClaimRow[]>`
      select *
      from trial_claims
      where hardware_id = ${hardwareId}
      limit 1
    `;
    if (existingByHardware) {
      if (existingByHardware.install_id === installId) {
        return { kind: "existing", claim: mapRow(existingByHardware) };
      }
      if (existingByInstall) {
        return {
          kind: "blocked",
          reason: "install_already_registered",
          claim: mapRow(existingByInstall),
        };
      }
      const [rebound] = await sql<TrialClaimRow[]>`
        update trial_claims
        set install_id = ${installId}, updated_at = now()
        where id = ${existingByHardware.id}
        returning *
      `;
      return { kind: "existing", claim: mapRow(rebound) };
    }
  }

  if (existingByEmail && existingByEmail.install_id === installId) {
    if (hardwareId && !existingByEmail.hardware_id) {
      await sql`
        update trial_claims set hardware_id = ${hardwareId}, updated_at = now()
        where id = ${existingByEmail.id} and hardware_id is null
      `;
    }
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
      hardware_id,
      app_version,
      os_version,
      started_at,
      ends_at,
      last_seen_at
    ) values (
      ${randomUUID()},
      ${normalizedEmail},
      ${installId},
      ${hardwareId},
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
  await ensureSchema();
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
  await ensureSchema();
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
  await ensureSchema();
  const sql = getSql();
  const rows = await sql<TrialClaimRow[]>`
    select *
    from trial_claims
    where reminder_sent_at is null
      -- Anonymous trials have no deliverable address; mailing the
      -- placeholder domain only produces bounces.
      and email not like '%@trial.cmdtab.invalid'
      and ends_at > now()
      and ends_at <= now() + interval '36 hours'
    order by ends_at asc
    limit ${Math.max(1, Math.min(limit, 500))}
  `;

  return rows.map(mapRow);
}

export async function markTrialReminderSent(id: string) {
  await ensureSchema();
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
