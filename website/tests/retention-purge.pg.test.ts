import "./support/route-alias.js";

import assert from "node:assert/strict";
import { randomBytes, randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

// Retention purge SQL against a real, disposable Postgres. Same opt-in as
// licensing-stores.pg.test.ts: set CMDTAB_TEST_DATABASE_URL to a *local*
// database. Without it every test here is skipped.
const testDatabaseUrl = process.env.CMDTAB_TEST_DATABASE_URL?.trim();

function isLocalDatabase(url: string) {
  try {
    const host = new URL(url).hostname;
    return host === "" || host === "localhost" || host === "127.0.0.1" || host === "[::1]";
  } catch {
    return false;
  }
}

if (testDatabaseUrl && !isLocalDatabase(testDatabaseUrl)) {
  throw new Error("CMDTAB_TEST_DATABASE_URL must point at a local database.");
}
const skip = testDatabaseUrl
  ? false
  : "CMDTAB_TEST_DATABASE_URL not set (retention tests need a disposable local Postgres)";

if (testDatabaseUrl) {
  process.env.DATABASE_URL = testDatabaseUrl;
  delete process.env.POSTGRES_URL;
  delete process.env.POSTGRES_PRISMA_URL;
}

import { getSql } from "../src/lib/postgres.js";
import { RETENTION_DAYS, runRetentionPurge } from "../src/lib/retention-purge.js";
import { createOrGetTrialClaim } from "../src/lib/trial-claim-store.js";

const DAY_MS = 24 * 60 * 60 * 1000;

function hex() {
  return randomBytes(32).toString("hex");
}

function daysAgo(days: number) {
  return new Date(Date.now() - days * DAY_MS).toISOString();
}

test.before(async () => {
  if (skip) return;
  const sql = getSql();
  await sql`set client_min_messages = warning`;
  // Start from the pre-retention trial_claims shape (email NOT NULL) so the
  // migration's upgrade path is exercised, unless an earlier run in this
  // database already created the table.
  await sql`
    create table if not exists trial_claims (
      id text primary key, email text not null unique,
      install_id text not null unique, app_version text, os_version text,
      started_at timestamptz not null, ends_at timestamptz not null,
      last_seen_at timestamptz not null default now(),
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now()
    )
  `;
  for (const file of ["001_commerce_lifecycle.sql", "002_data_retention.sql"]) {
    await sql.unsafe(
      readFileSync(path.resolve(process.cwd(), "db/migrations", file), "utf8"),
    );
  }
  // Applying the migration twice must be harmless.
  await sql.unsafe(
    readFileSync(path.resolve(process.cwd(), "db/migrations/002_data_retention.sql"), "utf8"),
  );
  await sql`
    create table if not exists app_usage_events (
      id text primary key, install_id text not null, event_name text not null,
      license_state text not null, license_id text, app_version text,
      os_version text, metadata jsonb, occurred_at timestamptz not null,
      created_at timestamptz not null default now()
    )
  `;
  await sql`
    create table if not exists site_analytics_events (
      id text primary key, event_type text not null, event_name text,
      path text not null, referrer text, context text, event_data jsonb,
      visitor_id text, session_id text, occurred_at timestamptz not null,
      created_at timestamptz not null default now()
    )
  `;
  await sql`
    create table if not exists license_requests (
      id text primary key, email text not null, name text, purchase_email text,
      reason text not null, message text not null, metadata jsonb,
      request_id text not null, notification_status text not null default 'stored',
      notification_error text, created_at timestamptz not null default now(),
      updated_at timestamptz not null default now()
    )
  `;
});

test.after(async () => {
  if (!skip) await getSql().end({ timeout: 5 });
});

async function insertTrial(input: {
  email: string;
  installId: string;
  hardwareId: string | null;
  endedDaysAgo: number;
}) {
  const id = randomUUID();
  const endsAt = daysAgo(input.endedDaysAgo);
  const startedAt = new Date(Date.parse(endsAt) - 14 * DAY_MS).toISOString();
  await getSql()`
    insert into trial_claims (
      id, email, install_id, hardware_id, app_version, os_version,
      started_at, ends_at, last_seen_at
    ) values (
      ${id}, ${input.email}, ${input.installId}, ${input.hardwareId},
      ${"1.2.3"}, ${"macOS 15.1"}, ${startedAt}, ${endsAt}, ${startedAt}
    )
  `;
  return { id, startedAt, endsAt };
}

async function trialRow(id: string) {
  const [row] = await getSql()<
    {
      email: string | null;
      install_id: string;
      hardware_id: string | null;
      app_version: string | null;
      os_version: string | null;
      started_at: Date;
      ends_at: Date;
      anonymized_at: Date | null;
    }[]
  >`select * from trial_claims where id = ${id}`;
  return row;
}

test("retention purge anonymises trials 90 days after they end and keeps only hashed ids and dates", { skip }, async () => {
  assert.equal(RETENTION_DAYS, 90);
  const old = {
    email: `old-${hex().slice(0, 8)}@example.com`,
    installId: hex(),
    hardwareId: hex(),
  };
  const oldTrial = await insertTrial({ ...old, endedDaysAgo: RETENTION_DAYS + 1 });
  const recent = await insertTrial({
    email: `recent-${hex().slice(0, 8)}@example.com`,
    installId: hex(),
    hardwareId: hex(),
    endedDaysAgo: RETENTION_DAYS - 1,
  });

  const result = await runRetentionPurge();
  assert.ok(result.trialClaimsAnonymized >= 1);
  assert.equal(result.complete, true);

  const anonymised = await trialRow(oldTrial.id);
  assert.equal(anonymised.email, null);
  assert.equal(anonymised.app_version, null);
  assert.equal(anonymised.os_version, null);
  assert.ok(anonymised.anonymized_at);
  assert.equal(anonymised.install_id, old.installId);
  assert.equal(anonymised.hardware_id, old.hardwareId);
  assert.equal(anonymised.started_at.toISOString(), oldTrial.startedAt);
  assert.equal(anonymised.ends_at.toISOString(), oldTrial.endsAt);

  const untouched = await trialRow(recent.id);
  assert.match(String(untouched.email), /^recent-/);
  assert.equal(untouched.app_version, "1.2.3");
  assert.equal(untouched.anonymized_at, null);

  // Idempotent: a second run leaves the anonymised row alone.
  const again = await runRetentionPurge();
  const stillAnonymised = await trialRow(oldTrial.id);
  assert.equal(
    stillAnonymised.anonymized_at?.toISOString(),
    anonymised.anonymized_at?.toISOString(),
  );
  assert.equal(again.complete, true);
});

test("an anonymised trial still blocks a repeat trial on the same Mac", { skip }, async () => {
  const hardwareId = hex();
  const installId = hex();
  const original = await insertTrial({
    email: `repeat-${hex().slice(0, 8)}@example.com`,
    installId,
    hardwareId,
    endedDaysAgo: RETENTION_DAYS + 30,
  });
  await runRetentionPurge();
  assert.equal((await trialRow(original.id)).email, null);

  // Same Mac, new Keychain install, new email: rebinds to the old claim.
  const newInstall = hex();
  const rebound = await createOrGetTrialClaim({
    email: `someone-else-${hex().slice(0, 8)}@example.com`,
    installId: newInstall,
    hardwareId,
    trialLengthDays: 14,
  });
  assert.equal(rebound.kind, "existing");
  assert.equal(rebound.claim.id, original.id);
  assert.equal(rebound.claim.email, null);
  assert.equal(rebound.claim.installId, newInstall);
  assert.equal(new Date(rebound.claim.endsAt).toISOString(), original.endsAt);

  // Same Mac and install again (now the rebound one), anonymous request.
  const sameInstall = await createOrGetTrialClaim({
    email: `anonymous+${hex().slice(0, 32)}@trial.cmdtab.invalid`,
    installId: newInstall,
    hardwareId,
    trialLengthDays: 14,
  });
  assert.equal(sameInstall.kind, "existing");
  assert.equal(sameInstall.claim.id, original.id);

  // Old client that sends no hardware hash: matched by install, not a new trial.
  const noHardware = await createOrGetTrialClaim({
    email: `fresh-${hex().slice(0, 8)}@example.com`,
    installId: newInstall,
    trialLengthDays: 14,
  });
  assert.equal(noHardware.kind, "existing");
  assert.equal(noHardware.claim.id, original.id);
  assert.equal(new Date(noHardware.claim.endsAt).toISOString(), original.endsAt);

  // Several anonymised claims coexist (email unique constraint allows nulls).
  await insertTrial({
    email: `second-${hex().slice(0, 8)}@example.com`,
    installId: hex(),
    hardwareId: hex(),
    endedDaysAgo: RETENTION_DAYS + 2,
  });
  await runRetentionPurge();
  const [{ count }] = await getSql()<{ count: number }[]>`
    select count(*)::int as count from trial_claims where email is null
  `;
  assert.ok(count >= 2);
});

test("retention purge deletes telemetry, analytics and help requests older than 90 days", { skip }, async () => {
  const sql = getSql();
  const tag = hex().slice(0, 12);
  const old = daysAgo(RETENTION_DAYS + 1);
  const fresh = daysAgo(RETENTION_DAYS - 1);

  for (const [suffix, occurredAt, createdAt] of [
    ["old", old, old],
    ["fresh", fresh, fresh],
    // Client clock reported an old time for a row stored recently: still purged.
    ["backdated", old, fresh],
  ] as const) {
    await sql`
      insert into app_usage_events (id, install_id, event_name, license_state, occurred_at, created_at)
      values (${`${tag}-${suffix}`}, ${hex()}, ${"launch"}, ${"trial"}, ${occurredAt}, ${createdAt})
    `;
    await sql`
      insert into site_analytics_events (id, event_type, path, occurred_at, created_at)
      values (${`${tag}-${suffix}`}, ${"pageview"}, ${"/"}, ${occurredAt}, ${createdAt})
    `;
  }
  for (const [suffix, createdAt] of [["old", old], ["fresh", fresh]] as const) {
    await sql`
      insert into license_requests (id, email, reason, message, request_id, created_at, updated_at)
      values (${`${tag}-${suffix}`}, ${"help@example.com"}, ${"other"}, ${"hi"}, ${randomUUID()}, ${createdAt}, ${createdAt})
    `;
  }
  // Expired rate-limit state is swept; live state is kept.
  await sql`
    insert into ingest_rate_limits (bucket_key, window_start, event_count, expires_at)
    values (${`${tag}:old`}, 1, 1, ${daysAgo(1)}), (${`${tag}:live`}, 1, 1, ${new Date(Date.now() + 60_000).toISOString()})
  `;
  await sql`
    insert into request_deduplication (fingerprint, expires_at)
    values (${`${tag}:old`}, ${daysAgo(1)}), (${`${tag}:live`}, ${new Date(Date.now() + 60_000).toISOString()})
  `;

  // A tiny batch size exercises the batching loop.
  const result = await runRetentionPurge({ batchSize: 1 });
  assert.ok(result.appUsageEventsDeleted >= 2);
  assert.ok(result.siteAnalyticsEventsDeleted >= 2);
  assert.ok(result.licenseRequestsDeleted >= 1);
  assert.ok(result.ingestRateLimitsDeleted >= 1);
  assert.ok(result.requestDeduplicationDeleted >= 1);
  assert.equal(result.complete, true);

  const ids = async (table: string) =>
    (
      await sql<{ id: string }[]>`
        select id from ${sql(table)} where id like ${`${tag}-%`} order by id
      `
    ).map((row) => row.id);
  assert.deepEqual(await ids("app_usage_events"), [`${tag}-fresh`]);
  assert.deepEqual(await ids("site_analytics_events"), [`${tag}-fresh`]);
  assert.deepEqual(await ids("license_requests"), [`${tag}-fresh`]);
  const limits = await sql<{ bucket_key: string }[]>`
    select bucket_key from ingest_rate_limits where bucket_key like ${`${tag}:%`}
  `;
  assert.deepEqual(limits.map((row) => row.bucket_key), [`${tag}:live`]);
  const dedup = await sql<{ fingerprint: string }[]>`
    select fingerprint from request_deduplication where fingerprint like ${`${tag}:%`}
  `;
  assert.deepEqual(dedup.map((row) => row.fingerprint), [`${tag}:live`]);
});

test("retention purge stops at the time budget and reports an incomplete run", { skip }, async () => {
  await insertTrial({
    email: `budget-${hex().slice(0, 8)}@example.com`,
    installId: hex(),
    hardwareId: hex(),
    endedDaysAgo: RETENTION_DAYS + 5,
  });
  const partial = await runRetentionPurge({ timeBudgetMs: 0 });
  assert.equal(partial.complete, false);
  assert.equal(partial.trialClaimsAnonymized, 0);
  const finished = await runRetentionPurge();
  assert.equal(finished.complete, true);
  assert.ok(finished.trialClaimsAnonymized >= 1);
});
