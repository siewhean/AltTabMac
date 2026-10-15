import { getSql } from "@/lib/postgres";
import { ensureTrialClaimSchema } from "@/lib/trial-claim-store";

// Owner decision (2026-10-15): trial records, app telemetry, website analytics
// events and license help requests are kept for 90 days. Telemetry, analytics
// and help requests are then deleted. Trial claims are anonymised 90 days after
// the trial ENDED: the email, app and OS versions are removed and only the
// hashed install/hardware identifiers and the trial dates remain, so the same
// Mac still cannot start a second trial. Waitlist signups are out of scope
// (they are deleted on unsubscribe). See docs/operations/data-retention.md.
export const RETENTION_DAYS = 90;

// Each statement touches at most this many rows, and the run stops starting
// new batches once the time budget is spent. The next daily run continues
// where this one stopped, so a large first backlog cannot time out the cron.
const DEFAULT_BATCH_SIZE = 5_000;
const DEFAULT_TIME_BUDGET_MS = 40_000;

export type RetentionPurgeResult = {
  cutoff: string;
  trialClaimsAnonymized: number;
  appUsageEventsDeleted: number;
  siteAnalyticsEventsDeleted: number;
  licenseRequestsDeleted: number;
  ingestRateLimitsDeleted: number;
  requestDeduplicationDeleted: number;
  /** False when the time budget ran out with rows possibly left to purge. */
  complete: boolean;
};

type Sql = ReturnType<typeof getSql>;

async function tableExists(sql: Sql, table: string) {
  const [row] = await sql<{ present: boolean }[]>`
    select to_regclass(${table}) is not null as present
  `;
  return Boolean(row?.present);
}

export async function runRetentionPurge(options: {
  now?: Date;
  batchSize?: number;
  timeBudgetMs?: number;
} = {}): Promise<RetentionPurgeResult> {
  const sql = getSql();
  const now = options.now ?? new Date();
  const batchSize = Math.max(1, Math.floor(options.batchSize ?? DEFAULT_BATCH_SIZE));
  const deadline = Date.now() + (options.timeBudgetMs ?? DEFAULT_TIME_BUDGET_MS);
  const cutoff = new Date(now.getTime() - RETENTION_DAYS * 24 * 60 * 60 * 1000);
  const cutoffIso = cutoff.toISOString();
  let complete = true;

  // Runs `step` until it affects fewer rows than a full batch or the time
  // budget is spent. Each batch is its own statement, so a partial run leaves
  // the database consistent and the next run picks up the remainder.
  async function drain(step: () => Promise<number>) {
    let total = 0;
    for (;;) {
      if (Date.now() >= deadline) {
        complete = false;
        return total;
      }
      const affected = await step();
      total += affected;
      if (affected < batchSize) return total;
    }
  }

  // Tables are created lazily by their stores; skip any that do not exist.
  // trial_claims is upgraded first so the anonymized_at column exists.
  await ensureTrialClaimSchema();

  const trialClaimsAnonymized = await drain(async () => {
    const result = await sql`
      update trial_claims
      set
        email = null,
        app_version = null,
        os_version = null,
        anonymized_at = ${now.toISOString()},
        updated_at = ${now.toISOString()}
      where id in (
        select id from trial_claims
        where anonymized_at is null and ends_at < ${cutoffIso}
        limit ${batchSize}
      )
    `;
    return result.count;
  });

  // Both timestamps are checked: occurred_at is reported by the client, while
  // created_at is when the server stored the row. Whichever is older wins.
  const appUsageEventsDeleted = (await tableExists(sql, "app_usage_events"))
    ? await drain(async () => {
        const result = await sql`
          delete from app_usage_events
          where ctid in (
            select ctid from app_usage_events
            where occurred_at < ${cutoffIso} or created_at < ${cutoffIso}
            limit ${batchSize}
          )
        `;
        return result.count;
      })
    : 0;

  const siteAnalyticsEventsDeleted = (await tableExists(sql, "site_analytics_events"))
    ? await drain(async () => {
        const result = await sql`
          delete from site_analytics_events
          where ctid in (
            select ctid from site_analytics_events
            where occurred_at < ${cutoffIso} or created_at < ${cutoffIso}
            limit ${batchSize}
          )
        `;
        return result.count;
      })
    : 0;

  const licenseRequestsDeleted = (await tableExists(sql, "license_requests"))
    ? await drain(async () => {
        const result = await sql`
          delete from license_requests
          where id in (
            select id from license_requests
            where created_at < ${cutoffIso}
            limit ${batchSize}
          )
        `;
        return result.count;
      })
    : 0;

  // Rate-limit counters and dedup fingerprints expire within 24 hours, but
  // rate-limit.ts only sweeps them while requests keep arriving. Sweeping
  // expired rows here (same predicates as rate-limit.ts, on the database
  // clock) guarantees none outlive the retention window.
  const ingestRateLimitsDeleted = (await tableExists(sql, "ingest_rate_limits"))
    ? await drain(async () => {
        const result = await sql`
          delete from ingest_rate_limits
          where ctid in (
            select ctid from ingest_rate_limits
            where expires_at < now() - interval '5 minutes'
            limit ${batchSize}
          )
        `;
        return result.count;
      })
    : 0;

  const requestDeduplicationDeleted = (await tableExists(sql, "request_deduplication"))
    ? await drain(async () => {
        const result = await sql`
          delete from request_deduplication
          where ctid in (
            select ctid from request_deduplication
            where expires_at < now()
            limit ${batchSize}
          )
        `;
        return result.count;
      })
    : 0;

  return {
    cutoff: cutoffIso,
    trialClaimsAnonymized,
    appUsageEventsDeleted,
    siteAnalyticsEventsDeleted,
    licenseRequestsDeleted,
    ingestRateLimitsDeleted,
    requestDeduplicationDeleted,
    complete,
  };
}
