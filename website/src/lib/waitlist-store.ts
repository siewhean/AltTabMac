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
  const [existing] = await sql<Pick<WaitlistRow, "id">[]>`
    select id
    from waitlist_signups
    where email = ${normalizedEmail}
    limit 1
  `;

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
    on conflict (email) do update set
      name = excluded.name,
      source = excluded.source,
      metadata = excluded.metadata,
      request_id = excluded.request_id,
      notification_status = 'stored',
      notification_error = null,
      updated_at = now()
    returning *
  `;

  return {
    submission: mapRow(row),
    alreadyRegistered: Boolean(existing),
  } satisfies WaitlistUpsertResult;
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
    limit ${Math.max(1, Math.min(limit, 500))}
  `;

  return rows.map(mapRow);
}
