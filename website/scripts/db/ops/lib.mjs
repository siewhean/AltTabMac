import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

import postgres from "postgres";

export const migrationsDirectory = fileURLToPath(
  new URL("../../../db/migrations/", import.meta.url),
);

export const requiredTables = [
  "admin_settings",
  "app_usage_events",
  "license_fulfillments",
  "license_requests",
  "site_analytics_events",
  "trial_claims",
  "waitlist_signups",
];

export const requiredIndexes = [
  "admin_settings_updated_at_idx",
  "app_usage_events_install_idx",
  "app_usage_events_name_idx",
  "app_usage_events_occurred_at_idx",
  "license_fulfillments_stale_idx",
  "license_fulfillments_anonymization_idx",
  "license_fulfillments_status_idx",
  "license_fulfillments_order_hash_key",
  "license_fulfillments_updated_at_idx",
  "license_requests_request_id_key",
  "license_requests_created_at_idx",
  "license_requests_status_idx",
  "license_requests_updated_at_idx",
  "site_analytics_events_name_idx",
  "site_analytics_events_occurred_at_idx",
  "site_analytics_events_path_idx",
  "site_analytics_events_type_idx",
  "trial_claims_ends_at_idx",
  "trial_claims_reminder_due_idx",
  "waitlist_signups_status_idx",
  "waitlist_signups_created_at_idx",
  "waitlist_signups_updated_at_idx",
];

export const requiredConstraintDefinitions = {
  app_usage_events_event_name_check:
    "check (event_name = any (array['app_activation'::text, 'app_heartbeat'::text, 'license_activated'::text, 'trial_started'::text]))",
  app_usage_events_license_state_check:
    "check (license_state = any (array['unregistered'::text, 'trial_active'::text, 'trial_expired'::text, 'licensed'::text]))",
  license_fulfillments_delivery_status_check:
    "check (delivery_status = any (array['stored'::text, 'processing'::text, 'delivered'::text, 'failed'::text, 'refunded'::text]))",
  license_fulfillments_order_hash_check:
    "check (order_hash is null or order_hash ~ '^[0-9a-f]{64}$'::text)",
  license_fulfillments_processing_token_check:
    "check (delivery_status <> 'processing'::text or processing_token is not null)",
  license_requests_notification_status_check:
    "check (notification_status = any (array['stored'::text, 'delivered'::text, 'failed'::text]))",
  site_analytics_events_event_type_check:
    "check (event_type = any (array['pageview'::text, 'event'::text]))",
  trial_claims_window_check: "check (ends_at > started_at)",
  waitlist_signups_notification_status_check:
    "check (notification_status = any (array['stored'::text, 'delivered'::text, 'failed'::text]))",
};

export const requiredConstraints = Object.keys(requiredConstraintDefinitions);

export const requiredColumns = [
  { table: "license_fulfillments", column: "order_hash", type: "text", nullable: true, default: null },
  { table: "license_fulfillments", column: "anonymized_at", type: "timestamptz", nullable: true, default: null },
  { table: "license_fulfillments", column: "order_identifier", type: "text", nullable: true, default: null },
  { table: "license_fulfillments", column: "purchaser_email", type: "text", nullable: true, default: null },
  { table: "license_fulfillments", column: "license_id", type: "text", nullable: true, default: null },
  { table: "license_fulfillments", column: "license_token", type: "text", nullable: true, default: null },
  { table: "license_fulfillments", column: "processing_token", type: "text", nullable: true, default: null },
];

export function normalizeConstraintDefinition(value) {
  return String(value)
    .toLowerCase()
    .replace(/::(?:text|character varying)/g, "")
    .replace(/[\s()]/g, "");
}

export function databaseUrl(preferredVariable) {
  if (preferredVariable) return process.env[preferredVariable]?.trim() || null;
  return (
    process.env.DATABASE_URL?.trim() ||
    process.env.POSTGRES_URL?.trim() ||
    process.env.POSTGRES_PRISMA_URL?.trim() ||
    null
  );
}

export function connect(preferredVariable) {
  const url = databaseUrl(preferredVariable);
  if (!url) throw new Error(`${preferredVariable ?? "DATABASE_URL"} is not configured`);
  return postgres(url, {
    max: 1,
    connect_timeout: 10,
    idle_timeout: 5,
    prepare: false,
    onnotice: () => {},
  });
}

export async function loadMigrations() {
  const names = (await readdir(migrationsDirectory))
    .filter((name) => /^\d{4}_[a-z0-9_-]+\.sql$/.test(name))
    .sort();
  if (names.length === 0) throw new Error("No database migrations found");

  return Promise.all(
    names.map(async (name) => {
      const sql = await readFile(`${migrationsDirectory}/${name}`, "utf8");
      return {
        name,
        sql,
        checksum: createHash("sha256").update(sql).digest("hex"),
      };
    }),
  );
}

export async function readAppliedMigrations(sql) {
  const [exists] = await sql`
    select to_regclass('public.schema_migrations') is not null as exists
  `;
  if (!exists?.exists) return [];
  return sql`
    select name, checksum, applied_at::text
    from schema_migrations
    order by name
  `;
}

export function compareMigrations(files, applied) {
  const fileByName = new Map(files.map((item) => [item.name, item]));
  const appliedByName = new Map(applied.map((item) => [item.name, item]));
  const changed = applied.filter(
    (item) => fileByName.has(item.name) && fileByName.get(item.name).checksum !== item.checksum,
  );
  const missing = applied.filter((item) => !fileByName.has(item.name));
  const pending = files.filter((item) => !appliedByName.has(item.name));
  return { changed, missing, pending };
}

export async function withConnection(callback, preferredVariable) {
  const sql = connect(preferredVariable);
  try {
    return await callback(sql);
  } finally {
    await sql.end({ timeout: 5 });
  }
}

export function fail(error, operation = "database-operation") {
  const code =
    error && typeof error === "object" && "code" in error
      ? String(error.code).slice(0, 32)
      : "unknown";
  const constraint =
    error && typeof error === "object" && "constraint_name" in error
      ? String(error.constraint_name).slice(0, 96)
      : undefined;
  console.error(JSON.stringify({ ok: false, operation, code, constraint }));
  process.exitCode = 1;
}
