import { timingSafeEqual } from "node:crypto";

import { NextResponse } from "next/server";

import {
  expectedMigrations,
  requiredConstraintDefinitions,
  requiredCoreColumns,
  requiredDatabaseStructure,
  requiredIndexDefinitions,
} from "@/lib/database-schema";
import { getSql } from "@/lib/postgres";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function safeEqual(left: string, right: string) {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  return (
    leftBuffer.length === rightBuffer.length &&
    timingSafeEqual(leftBuffer, rightBuffer)
  );
}

function normalizeDatabaseDefinition(value: string) {
  return value
    .toLowerCase()
    .replace(/\bpublic\./g, "")
    .replace(/::(?:text|character varying)/g, "")
    .replace(/[\s()]/g, "");
}

function definitionsMatch(
  actual: Record<string, string> | null | undefined,
  expected: Record<string, string>,
) {
  if (!actual || Object.keys(actual).length !== Object.keys(expected).length) return false;
  return Object.entries(expected).every(([name, definition]) =>
    normalizeDatabaseDefinition(actual[name] ?? "") ===
      normalizeDatabaseDefinition(definition));
}

function isHealthcheckAuthorized(request: Request) {
  const secret = process.env.HEALTHCHECK_SECRET?.trim();
  const authorization = request.headers.get("authorization");
  if (!secret || !authorization?.startsWith("Bearer ")) return false;
  return safeEqual(authorization.slice(7), secret);
}

function response(body: Record<string, unknown>, status: number) {
  return NextResponse.json(body, {
    status,
    headers: { "cache-control": "no-store" },
  });
}

export async function GET(request: Request) {
  if (!isHealthcheckAuthorized(request)) {
    return response({ ok: false }, 401);
  }

  let sql: ReturnType<typeof getSql>;
  try {
    sql = getSql();
    await sql`select 1`;
  } catch {
    return response({
      ok: false,
      connectivity: "failed",
      schema: "unknown",
      staleFulfillment: false,
    }, 503);
  }

  try {
    const [catalog] = await sql<{
      migrations_present: boolean;
      fulfillments_present: boolean;
      table_count: number;
      index_count: number;
      constraint_count: number;
      migration_column_count: number;
      fulfillment_column_count: number;
      core_columns: string[];
      index_definitions: Record<string, string>;
      constraint_definitions: Record<string, string>;
    }[]>`
      select
        to_regclass('public.schema_migrations') is not null as migrations_present,
        to_regclass('public.license_fulfillments') is not null as fulfillments_present,
        (
          select count(*)::int
          from information_schema.tables
          where table_schema = 'public'
            and table_name = any(array[
              'admin_settings',
              'app_usage_events',
              'license_fulfillments',
              'license_requests',
              'site_analytics_events',
              'trial_claims',
              'waitlist_signups'
            ])
        ) as table_count,
        (
          select count(*)::int
          from pg_indexes
          where schemaname = 'public'
            and indexname = any(array[
              'admin_settings_updated_at_idx',
              'app_usage_events_install_idx',
              'app_usage_events_name_idx',
              'app_usage_events_occurred_at_idx',
              'license_fulfillments_stale_idx',
              'license_fulfillments_anonymization_idx',
              'license_fulfillments_status_idx',
              'license_fulfillments_order_hash_key',
              'license_fulfillments_updated_at_idx',
              'license_requests_request_id_key',
              'license_requests_created_at_idx',
              'license_requests_status_idx',
              'license_requests_updated_at_idx',
              'site_analytics_events_name_idx',
              'site_analytics_events_occurred_at_idx',
              'site_analytics_events_path_idx',
              'site_analytics_events_type_idx',
              'trial_claims_ends_at_idx',
              'trial_claims_reminder_due_idx',
              'waitlist_signups_status_idx',
              'waitlist_signups_created_at_idx',
              'waitlist_signups_updated_at_idx'
            ])
        ) as index_count,
        (
          select count(distinct relation_record.relname || '.' || constraint_record.conname)::int
          from pg_constraint constraint_record
          join pg_namespace namespace_record
            on namespace_record.oid = constraint_record.connamespace
          join pg_class relation_record
            on relation_record.oid = constraint_record.conrelid
          where namespace_record.nspname = 'public'
            and constraint_record.convalidated
            and constraint_record.conname = any(array[
              'admin_settings_pkey',
              'app_usage_events_pkey',
              'app_usage_events_event_name_check',
              'app_usage_events_license_state_check',
              'license_fulfillments_pkey',
              'license_fulfillments_order_identifier_key',
              'license_fulfillments_delivery_status_check',
              'license_fulfillments_order_hash_check',
              'license_fulfillments_processing_token_check',
              'license_requests_pkey',
              'license_requests_request_id_key',
              'license_requests_notification_status_check',
              'site_analytics_events_pkey',
              'site_analytics_events_event_type_check',
              'trial_claims_pkey',
              'trial_claims_email_key',
              'trial_claims_install_id_key',
              'trial_claims_window_check',
              'waitlist_signups_pkey',
              'waitlist_signups_email_key',
              'waitlist_signups_notification_status_check'
            ])
        ) as constraint_count,
        (
          select count(*)::int
          from information_schema.columns
          where table_schema = 'public'
            and table_name = 'schema_migrations'
            and (
              (
                column_name in ('name', 'checksum')
                and data_type = 'text'
                and is_nullable = 'NO'
              ) or (
                column_name = 'applied_at'
                and data_type = 'timestamp with time zone'
                and is_nullable = 'NO'
                and column_default is not null
              )
            )
        ) as migration_column_count,
        (
          select count(*)::int
          from information_schema.columns
          where table_schema = 'public'
            and table_name = 'license_fulfillments'
            and is_nullable = 'YES'
            and column_default is null
            and (
              (column_name in (
                'order_hash',
                'order_identifier',
                'purchaser_email',
                'license_id',
                'license_token',
                'processing_token'
              ) and data_type = 'text')
              or (column_name = 'anonymized_at' and data_type = 'timestamp with time zone')
            )
        ) as fulfillment_column_count,
        coalesce((
          select jsonb_agg(table_name || '.' || column_name)
          from information_schema.columns
          where table_schema = 'public'
            and table_name = any(array[
              'admin_settings',
              'app_usage_events',
              'license_fulfillments',
              'license_requests',
              'site_analytics_events',
              'trial_claims',
              'waitlist_signups'
            ])
        ), '[]'::jsonb) as core_columns,
        coalesce((
          select jsonb_object_agg(indexname, indexdef)
          from pg_indexes
          where schemaname = 'public'
            and indexname = any(array[
              'admin_settings_updated_at_idx',
              'app_usage_events_install_idx',
              'app_usage_events_name_idx',
              'app_usage_events_occurred_at_idx',
              'license_fulfillments_stale_idx',
              'license_fulfillments_anonymization_idx',
              'license_fulfillments_status_idx',
              'license_fulfillments_order_hash_key',
              'license_fulfillments_updated_at_idx',
              'license_requests_request_id_key',
              'license_requests_created_at_idx',
              'license_requests_status_idx',
              'license_requests_updated_at_idx',
              'site_analytics_events_name_idx',
              'site_analytics_events_occurred_at_idx',
              'site_analytics_events_path_idx',
              'site_analytics_events_type_idx',
              'trial_claims_ends_at_idx',
              'trial_claims_reminder_due_idx',
              'waitlist_signups_status_idx',
              'waitlist_signups_created_at_idx',
              'waitlist_signups_updated_at_idx'
            ])
        ), '{}'::jsonb) as index_definitions,
        coalesce((
          select jsonb_object_agg(
            relation_record.relname || '.' || constraint_record.conname,
            pg_get_constraintdef(constraint_record.oid, true)
          )
          from pg_constraint constraint_record
          join pg_namespace namespace_record
            on namespace_record.oid = constraint_record.connamespace
          join pg_class relation_record
            on relation_record.oid = constraint_record.conrelid
          where namespace_record.nspname = 'public'
            and constraint_record.conname = any(array[
              'admin_settings_pkey',
              'app_usage_events_pkey',
              'app_usage_events_event_name_check',
              'app_usage_events_license_state_check',
              'license_fulfillments_pkey',
              'license_fulfillments_order_identifier_key',
              'license_fulfillments_delivery_status_check',
              'license_fulfillments_order_hash_check',
              'license_fulfillments_processing_token_check',
              'license_requests_pkey',
              'license_requests_request_id_key',
              'license_requests_notification_status_check',
              'site_analytics_events_pkey',
              'site_analytics_events_event_type_check',
              'trial_claims_pkey',
              'trial_claims_email_key',
              'trial_claims_install_id_key',
              'trial_claims_window_check',
              'waitlist_signups_pkey',
              'waitlist_signups_email_key',
              'waitlist_signups_notification_status_check'
            ])
        ), '{}'::jsonb) as constraint_definitions
    `;
    let appliedMigrations: { name: string; checksum: string }[] = [];
    let staleFulfillments = 0;
    if (catalog?.migrations_present) {
      appliedMigrations = await sql<{
        name: string;
        checksum: string;
      }[]>`
        select name, checksum
        from public.schema_migrations
        order by name
      `;
    }
    if (catalog?.fulfillments_present) {
      const [row] = await sql<{ count: number }[]>`
        select count(*)::int as count
        from public.license_fulfillments
        where (
            delivery_status = 'stored'
            and created_at < now() - interval '15 minutes'
          ) or (
            delivery_status = 'processing'
            and updated_at < now() - interval '15 minutes'
          )
      `;
      staleFulfillments = row?.count ?? 0;
    }

    const migrationsCurrent =
      appliedMigrations.length === expectedMigrations.length &&
      expectedMigrations.every((expected, index) => {
        const applied = appliedMigrations[index];
        return applied?.name === expected.name && applied.checksum === expected.checksum;
      });
    const coreColumns = new Set(catalog?.core_columns ?? []);
    const coreColumnsCurrent = Object.entries(requiredCoreColumns).every(
      ([table, columns]) => columns.every((column) => coreColumns.has(`${table}.${column}`)),
    );
    const schemaCurrent =
      migrationsCurrent &&
      catalog?.table_count === requiredDatabaseStructure.tables &&
      catalog.index_count === requiredDatabaseStructure.indexes &&
      catalog.constraint_count === requiredDatabaseStructure.constraints &&
      catalog.migration_column_count === requiredDatabaseStructure.migrationColumns &&
      catalog.fulfillment_column_count === requiredDatabaseStructure.fulfillmentColumns &&
      coreColumnsCurrent &&
      definitionsMatch(catalog.index_definitions, requiredIndexDefinitions) &&
      definitionsMatch(catalog.constraint_definitions, requiredConstraintDefinitions);
    const staleFulfillment = staleFulfillments > 0;
    const ok = schemaCurrent && !staleFulfillment;
    return response({
      ok,
      connectivity: "ok",
      schema: schemaCurrent ? "current" : "outdated",
      staleFulfillment,
    }, ok ? 200 : 503);
  } catch {
    return response({
      ok: false,
      connectivity: "ok",
      schema: "unknown",
      staleFulfillment: false,
    }, 503);
  }
}
