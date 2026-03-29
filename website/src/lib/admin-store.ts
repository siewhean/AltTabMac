import { randomUUID, scryptSync, timingSafeEqual } from "node:crypto";

import { getSql, isDatabaseConfigured } from "@/lib/postgres";

type AdminSettingRow = {
  key: string;
  value: {
    passwordHash?: string;
    salt?: string;
    updatedAt?: string;
  };
  updated_at: string;
};

export type DashboardAuthSummary = {
  source: "database" | "environment" | "missing";
  updatedAt?: string;
};

let schemaReady = false;

function safeEqual(a: string, b: string) {
  const aBuffer = Buffer.from(a);
  const bBuffer = Buffer.from(b);
  if (aBuffer.length !== bBuffer.length) return false;
  return timingSafeEqual(aBuffer, bBuffer);
}

function hashPassword(password: string, salt: string) {
  return scryptSync(password, salt, 64).toString("hex");
}

async function ensureSchema() {
  if (schemaReady || !isDatabaseConfigured()) return;

  const sql = getSql();
  await sql`
    create table if not exists admin_settings (
      key text primary key,
      value jsonb not null,
      updated_at timestamptz not null default now()
    )
  `;

  schemaReady = true;
}

async function getDashboardAuthRow() {
  if (!isDatabaseConfigured()) return null;

  await ensureSchema();
  const sql = getSql();
  const [row] = await sql<AdminSettingRow[]>`
    select key, value, updated_at
    from admin_settings
    where key = 'dashboard_auth'
    limit 1
  `;

  return row ?? null;
}

export async function getDashboardAuthSummary() {
  const row = await getDashboardAuthRow();
  if (row?.value?.passwordHash && row.value.salt) {
    return {
      source: "database",
      updatedAt: row.value.updatedAt ?? row.updated_at,
    } satisfies DashboardAuthSummary;
  }

  if (process.env.ADMIN_DASHBOARD_PASSWORD?.trim()) {
    return { source: "environment" } satisfies DashboardAuthSummary;
  }

  return { source: "missing" } satisfies DashboardAuthSummary;
}

export async function validateStoredDashboardPassword(input: string) {
  const row = await getDashboardAuthRow();
  const passwordHash = row?.value?.passwordHash;
  const salt = row?.value?.salt;

  if (!passwordHash || !salt) return null;
  return safeEqual(hashPassword(input, salt), passwordHash);
}

export async function setDashboardPassword(password: string) {
  await ensureSchema();
  const sql = getSql();
  const salt = randomUUID().replaceAll("-", "");
  const passwordHash = hashPassword(password, salt);
  const updatedAt = new Date().toISOString();

  await sql`
    insert into admin_settings (key, value, updated_at)
    values (
      'dashboard_auth',
      ${sql.json({ salt, passwordHash, updatedAt })},
      now()
    )
    on conflict (key) do update set
      value = excluded.value,
      updated_at = now()
  `;

  return updatedAt;
}
