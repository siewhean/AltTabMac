import { randomUUID } from "node:crypto";

import { getSql, isDatabaseConfigured } from "@/lib/postgres";
import {
  canonicalEmail,
  evaluateReferrals,
  generateReferralCode,
  isDisposableEmail,
  REFERRAL_REWARD_CAP,
  REFERRAL_REWARD_TARGET,
  type ReferralFlag,
} from "@/lib/waitlist-referral";

type WaitlistRow = {
  id: string;
  email: string;
  name: string | null;
  source: string | null;
  metadata: Record<string, string> | null;
  referral_code: string | null;
  referred_by: string | null;
  canonical_email: string | null;
  device_hash: string | null;
  network_hash: string | null;
  confirm_network_hash: string | null;
  confirmed_at: string | null;
  confirmation_sent_at: string | null;
  referral_status: "pending" | "qualified" | "flagged" | null;
  referral_flag: string | null;
  reward_status: "earned" | "waitlisted" | "granted" | "denied" | null;
  reward_earned_at: string | null;
  marketing_consent: boolean | null;
  marketing_consent_at: string | null;
  use_case: string | null;
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
  referralCode?: string;
  referredBy?: string;
  confirmedAt?: string;
  referralStatus?: "pending" | "qualified" | "flagged";
  referralFlag?: string;
  rewardStatus?: "earned" | "waitlisted" | "granted" | "denied";
  marketingConsent?: boolean;
  useCase?: string;
  requestId: string;
  notificationStatus: "stored" | "delivered" | "failed";
  notificationError?: string;
  createdAt: string;
  updatedAt: string;
};

export type WaitlistReferralProgress = {
  code: string;
  /** Invitations that confirmed their email and passed the device/network checks. */
  qualified: number;
  target: number;
  /** Whether this address has confirmed its own email (required to earn the reward). */
  confirmed: boolean;
  /** Internal only: never include in public API responses (see the waitlist route). */
  rewardStatus?: "earned" | "waitlisted" | "granted" | "denied";
};

export type WaitlistUpsertResult = {
  submission: WaitlistSubmission;
  alreadyRegistered: boolean;
  /** The address is an alias of a different registered mailbox; no row was created. */
  aliasOfExisting?: boolean;
  referral?: WaitlistReferralProgress;
};

export type WaitlistAggregateStats = {
  total: number;
  /** Addresses whose owner clicked the confirmation link. Only these count toward goals. */
  confirmed: number;
  /** Awaiting confirmation, plus rows created before confirmation existed. */
  unconfirmed: number;
  delivered: number;
  failed: number;
  pending: number;
  signups24h: number;
  signups7d: number;
  signups30d: number;
  namedCount: number;
  sourceCount: number;
  latestSignup?: string;
};

export type WaitlistBreakdownItem = {
  label: string;
  count: number;
};

export type WaitlistSignupSeriesPoint = {
  day: string;
  count: number;
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

  // Additive, idempotent migrations for the referral queue.
  await sql`alter table waitlist_signups add column if not exists referral_code text`;
  await sql`alter table waitlist_signups add column if not exists referred_by text`;
  await sql`
    create unique index if not exists waitlist_signups_referral_code_key
    on waitlist_signups (referral_code)
  `;
  await sql`
    create index if not exists waitlist_signups_referred_by_idx
    on waitlist_signups (referred_by)
  `;
  // Double opt-in and abuse-prevention signals. Hashes only; see the privacy policy.
  // Column names for confirmation match the double opt-in design in docs/PR #76.
  for (const column of [
    "canonical_email text",
    "device_hash text",
    "network_hash text",
    "confirm_network_hash text",
    "confirmed_at timestamptz",
    "confirmation_sent_at timestamptz",
    "referral_status text",
    "referral_flag text",
    "reward_status text",
    "reward_earned_at timestamptz",
    "marketing_consent boolean not null default false",
    "marketing_consent_at timestamptz",
    "marketing_consent_version text",
    "use_case text",
  ]) {
    await sql.unsafe(`alter table waitlist_signups add column if not exists ${column}`);
  }
  // Keyed hashes of unsubscribed addresses: the opt-out survives re-submission.
  await sql`
    create table if not exists waitlist_suppressions (
      email_hash text primary key,
      reason text not null check (reason in ('unsubscribed', 'bounced', 'complained')),
      created_at timestamptz not null default now()
    )
  `;
  await sql`create index if not exists waitlist_signups_canonical_email_idx on waitlist_signups (canonical_email)`;
  await sql`create index if not exists waitlist_signups_device_hash_idx on waitlist_signups (device_hash)`;

  schemaReady = true;
}

function mapRow(row: WaitlistRow): WaitlistSubmission {
  return {
    id: row.id,
    email: row.email,
    name: row.name ?? undefined,
    source: row.source ?? undefined,
    metadata: row.metadata ?? undefined,
    referralCode: row.referral_code ?? undefined,
    referredBy: row.referred_by ?? undefined,
    confirmedAt: row.confirmed_at ? new Date(row.confirmed_at).toISOString() : undefined,
    referralStatus: row.referral_status ?? undefined,
    referralFlag: row.referral_flag ?? undefined,
    rewardStatus: row.reward_status ?? undefined,
    marketingConsent: row.marketing_consent ?? undefined,
    useCase: row.use_case ?? undefined,
    requestId: row.request_id,
    notificationStatus: row.notification_status as WaitlistSubmission["notificationStatus"],
    notificationError: row.notification_error ?? undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function isUniqueViolation(error: unknown) {
  return (
    typeof error === "object" &&
    error !== null &&
    (error as { code?: string }).code === "23505"
  );
}

const SIGNAL_RETENTION_DAYS = 90;
/** Identifies the wording of the optional product-update checkbox the signer saw. */
export const MARKETING_CONSENT_VERSION = "2026-10-product-updates-v1";

/** Beta cap on free licenses; CMDTAB_REFERRAL_REWARD_CAP overrides it (positive integers only). */
function rewardCap() {
  const override = Number.parseInt(process.env.CMDTAB_REFERRAL_REWARD_CAP ?? "", 10);
  return Number.isInteger(override) && override > 0 ? override : REFERRAL_REWARD_CAP;
}

/**
 * One transaction-scoped lock serializes every referral decision. Reward slots
 * are global, so two confirmations must never both take the last one, and a
 * single lock order (this one, then rows) rules out deadlocks. Volume is tiny.
 */
async function lockReferralDecisions(sql: ReturnType<typeof getSql>) {
  await sql`select pg_advisory_xact_lock(hashtext('cmdtab-referral-decisions'))`;
}
let lastPurgeAt = 0;

/**
 * Deletes device and network hashes 90 days after signup. Hashes stay for
 * flagged referrals and earned rewards that still await review. Referral
 * verdicts are kept, so a purge never changes a decided outcome.
 */
async function purgeExpiredSignals() {
  if (Date.now() - lastPurgeAt < 60 * 60 * 1000) return;
  lastPurgeAt = Date.now();
  const sql = getSql();
  await purgeUnconfirmedSignups();
  await sql`
    update waitlist_signups
    set device_hash = null, network_hash = null, confirm_network_hash = null
    where created_at < now() - ${SIGNAL_RETENTION_DAYS} * interval '1 day'
      and (device_hash is not null or network_hash is not null or confirm_network_hash is not null)
      and coalesce(referral_status, '') <> 'flagged'
      and coalesce(reward_status, '') <> 'earned'
  `;
}

const UNCONFIRMED_EXPIRY_DAYS = 30;

/**
 * Deletes signups that were sent a confirmation link and never used it within
 * 30 days. Rows created before confirmation existed (no link was ever sent)
 * are kept: their owners were never asked, so silence is not abandonment.
 */
async function purgeUnconfirmedSignups() {
  const sql = getSql();
  await sql`
    delete from waitlist_signups
    where confirmed_at is null
      and confirmation_sent_at is not null
      and confirmation_sent_at < now() - ${UNCONFIRMED_EXPIRY_DAYS} * interval '1 day'
      and reward_status is null
  `;
}

export async function upsertWaitlistSubmission(input: {
  email: string;
  name?: string;
  source?: string;
  metadata?: Record<string, string>;
  referralCode?: string;
  /** HMAC of the browser's device id and of the IP network; see waitlist-signals. */
  deviceHash?: string;
  networkHash?: string;
  /** Optional product-update consent; recorded as effective on confirmation. */
  marketingConsent?: boolean;
  requestId: string;
}) {
  await ensureSchema();
  await purgeExpiredSignals().catch(() => undefined);
  const sql = getSql();
  const normalizedEmail = input.email.trim().toLowerCase();
  const canonical = canonicalEmail(normalizedEmail);
  const [existing] = await sql<Pick<WaitlistRow, "id">[]>`
    select id
    from waitlist_signups
    where email = ${normalizedEmail}
    limit 1
  `;

  // A different spelling of a mailbox that is already registered (Gmail dots,
  // +tags) is not a new person: no row, no email, no credit.
  if (!existing) {
    const [alias] = await sql<WaitlistRow[]>`
      select *
      from waitlist_signups
      where canonical_email = ${canonical} and email <> ${normalizedEmail}
      limit 1
    `;
    if (alias) {
      return {
        submission: mapRow(alias),
        alreadyRegistered: true,
        aliasOfExisting: true,
      } satisfies WaitlistUpsertResult;
    }
  }

  // Only a brand-new signup can be credited to an inviter. Already-registered
  // addresses are never re-attributed, so two friends cannot swap links.
  let referredBy: string | null = null;
  if (!existing && input.referralCode) {
    const [inviter] = await sql<Pick<WaitlistRow, "referral_code">[]>`
      select referral_code
      from waitlist_signups
      where referral_code = ${input.referralCode}
        and canonical_email is distinct from ${canonical}
        and email <> ${normalizedEmail}
      limit 1
    `;
    referredBy = inviter?.referral_code ?? null;
  }

  let row: WaitlistRow | undefined;
  for (let attempt = 0; attempt < 4 && !row; attempt += 1) {
    try {
      [row] = await sql<WaitlistRow[]>`
        insert into waitlist_signups (
          id, email, name, source, metadata,
          referral_code, referred_by, canonical_email, device_hash, network_hash,
          marketing_consent, request_id, notification_status, notification_error
        ) values (
          ${randomUUID()},
          ${normalizedEmail},
          ${input.name?.trim() || null},
          ${input.source?.trim() || null},
          ${input.metadata ? sql.json(input.metadata) : null},
          ${generateReferralCode()},
          ${referredBy},
          ${canonical},
          ${input.deviceHash ?? null},
          ${input.networkHash ?? null},
          ${input.marketingConsent === true},
          ${input.requestId},
          ${"stored"},
          ${null}
        )
        -- Repeat signups keep first-touch attribution: the original source,
        -- metadata, inviter and signals are never overwritten, and a missing
        -- name never erases one. Rows created before referrals existed receive
        -- a code and their canonical address.
        on conflict (email) do update set
          name = coalesce(excluded.name, waitlist_signups.name),
          source = coalesce(waitlist_signups.source, excluded.source),
          metadata = coalesce(waitlist_signups.metadata, excluded.metadata),
          referral_code = coalesce(waitlist_signups.referral_code, excluded.referral_code),
          canonical_email = coalesce(waitlist_signups.canonical_email, excluded.canonical_email),
          device_hash = coalesce(waitlist_signups.device_hash, excluded.device_hash),
          network_hash = coalesce(waitlist_signups.network_hash, excluded.network_hash),
          marketing_consent = waitlist_signups.marketing_consent or excluded.marketing_consent,
          request_id = excluded.request_id,
          notification_status = 'stored',
          notification_error = null,
          updated_at = now()
        returning *
      `;
    } catch (error) {
      // A random-code collision is astronomically unlikely; retry with a new code.
      if (!isUniqueViolation(error) || attempt === 3) throw error;
    }
  }

  if (!row) throw new Error("Waitlist upsert returned no row.");

  return {
    submission: mapRow(row),
    alreadyRegistered: Boolean(existing),
    referral: (await getReferralProgress(normalizedEmail)) ?? undefined,
  } satisfies WaitlistUpsertResult;
}

export async function markWaitlistConfirmationSent(email: string) {
  await ensureSchema();
  const sql = getSql();
  await sql`
    update waitlist_signups
    set confirmation_sent_at = now()
    where email = ${email.trim().toLowerCase()}
  `;
}

/** Progress toward the reward for one address. Same shape for every address. */
export async function getReferralProgress(email: string) {
  await ensureSchema();
  const sql = getSql();
  const [row] = await sql<
    {
      referral_code: string | null;
      confirmed_at: string | null;
      reward_status: WaitlistRow["reward_status"];
      qualified: number;
    }[]
  >`
    select
      s.referral_code,
      s.confirmed_at,
      s.reward_status,
      (
        select count(*)
        from waitlist_signups r
        where s.referral_code is not null
          and r.referred_by = s.referral_code
          and r.referral_status = 'qualified'
      )::int as qualified
    from waitlist_signups s
    where s.email = ${email.trim().toLowerCase()}
  `;

  if (!row?.referral_code) return null;
  return {
    code: row.referral_code,
    qualified: row.qualified,
    target: REFERRAL_REWARD_TARGET,
    confirmed: Boolean(row.confirmed_at),
    rewardStatus: row.reward_status ?? undefined,
  } satisfies WaitlistReferralProgress;
}

/**
 * Re-judges every invitation of one inviter and updates the reward. Runs inside
 * one transaction so concurrent confirmations cannot both claim a slot.
 */
async function recomputeReferrals(
  sql: ReturnType<typeof getSql>,
  inviterCode: string,
) {
  // Callers hold lockReferralDecisions() for the whole transaction.
  const [inviter] = await sql<WaitlistRow[]>`
    select * from waitlist_signups where referral_code = ${inviterCode} for update
  `;
  if (!inviter) return;

  const invitees = await sql<(WaitlistRow & { signups_from_device: number })[]>`
    select
      s.*,
      case
        when s.device_hash is null then 1
        else (select count(*) from waitlist_signups d where d.device_hash = s.device_hash)::int
      end as signups_from_device
    from waitlist_signups s
    where s.referred_by = ${inviterCode}
  `;

  const result = evaluateReferrals(
    {
      canonicalEmail: inviter.canonical_email ?? canonicalEmail(inviter.email),
      deviceHash: inviter.device_hash,
      networkHash: inviter.network_hash,
      confirmed: Boolean(inviter.confirmed_at),
    },
    invitees.map((invitee) => ({
      id: invitee.id,
      canonicalEmail: invitee.canonical_email ?? canonicalEmail(invitee.email),
      disposable: isDisposableEmail(invitee.email),
      deviceHash: invitee.device_hash,
      networkHash: invitee.network_hash,
      confirmNetworkHash: invitee.confirm_network_hash,
      signupsFromDevice: invitee.signups_from_device,
      // postgres.js returns timestamptz as Date objects at runtime.
      confirmedAt: invitee.confirmed_at ? new Date(invitee.confirmed_at).toISOString() : null,
      priorStatus:
        invitee.referral_status === "qualified" || invitee.referral_status === "flagged"
          ? invitee.referral_status
          : null,
    })),
  );

  for (const verdict of result.verdicts) {
    await sql`
      update waitlist_signups
      set referral_status = ${verdict.status},
          referral_flag = ${(verdict.flag as ReferralFlag | undefined) ?? null}
      where id = ${verdict.id}
    `;
  }

  // 'granted' and 'denied' are human decisions and are never overwritten.
  const cap = rewardCap();
  if (inviter.reward_status !== "granted" && inviter.reward_status !== "denied") {
    if (result.rewardEarned) {
      if (inviter.reward_status !== "earned") {
        const [{ taken }] = await sql<{ taken: number }[]>`
          select count(*)::int as taken
          from waitlist_signups
          where reward_status in ('earned', 'granted') and id <> ${inviter.id}
        `;
        await sql`
          update waitlist_signups
          set reward_status = ${taken < cap ? "earned" : "waitlisted"},
              reward_earned_at = coalesce(reward_earned_at, now())
          where id = ${inviter.id}
        `;
      }
    } else if (inviter.reward_status === "earned" || inviter.reward_status === "waitlisted") {
      await sql`
        update waitlist_signups
        set reward_status = null, reward_earned_at = null
        where id = ${inviter.id}
      `;
    }
  }

  // A freed slot (a withdrawn or denied reward) goes to the longest-waiting member.
  await sql`
    update waitlist_signups
    set reward_status = 'earned'
    where id in (
      select id
      from waitlist_signups
      where reward_status = 'waitlisted'
      order by reward_earned_at, id
      limit greatest(
        0,
        ${cap} - (
          select count(*) from waitlist_signups where reward_status in ('earned', 'granted')
        )
      )
    )
  `;
}

/**
 * Marks an address as confirmed (the owner clicked the emailed link) and
 * re-judges the invitation it belongs to, plus any invitations it sent.
 */
export async function confirmWaitlistSignup(
  email: string,
  signals: { networkHash?: string },
) {
  await ensureSchema();
  const sql = getSql();
  const normalizedEmail = email.trim().toLowerCase();

  return sql.begin(async (transaction) => {
    // postgres.js types a transaction handle as non-callable; it is the same tagged-template client.
    const tx = transaction as unknown as typeof sql;
    await lockReferralDecisions(tx);
    const [before] = await tx<Pick<WaitlistRow, "confirmed_at">[]>`
      select confirmed_at from waitlist_signups where email = ${normalizedEmail}
    `;
    const [row] = await tx<WaitlistRow[]>`
      update waitlist_signups
      set confirmed_at = coalesce(confirmed_at, now()),
          confirm_network_hash = coalesce(confirm_network_hash, ${signals.networkHash ?? null}),
          marketing_consent_at = case
            when marketing_consent and marketing_consent_at is null then now()
            else marketing_consent_at
          end,
          marketing_consent_version = case
            when marketing_consent and marketing_consent_version is null then ${MARKETING_CONSENT_VERSION}
            else marketing_consent_version
          end,
          updated_at = now()
      where email = ${normalizedEmail}
      returning *
    `;
    if (!row) return { found: false as const };
    const firstConfirmation = !before?.confirmed_at;

    if (row.referred_by) await recomputeReferrals(tx, row.referred_by);
    if (row.referral_code) await recomputeReferrals(tx, row.referral_code);
    return { found: true as const, firstConfirmation, submission: mapRow(row) };
  });
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

/**
 * Removes a signup on the applicant's request (unsubscribe). Idempotent.
 * When a suppression hash is supplied, it is recorded in the same transaction
 * so a later re-submission of the address (or an alias) is not emailed again.
 * If the address had been counted toward someone's reward, that inviter's
 * referrals are re-judged so the reward cannot outlive the friend.
 */
export async function deleteWaitlistSignup(
  email: string,
  options: { suppressionHash?: string } = {},
) {
  await ensureSchema();
  const sql = getSql();
  await sql.begin(async (transaction) => {
    const tx = transaction as unknown as typeof sql;
    await lockReferralDecisions(tx);
    if (options.suppressionHash) {
      await tx`
        insert into waitlist_suppressions (email_hash, reason)
        values (${options.suppressionHash}, 'unsubscribed')
        on conflict (email_hash) do nothing
      `;
    }
    const [deleted] = await tx<Pick<WaitlistRow, "referred_by">[]>`
      delete from waitlist_signups
      where email = ${email.trim().toLowerCase()}
      returning referred_by
    `;
    if (deleted?.referred_by) await recomputeReferrals(tx, deleted.referred_by);
  });
}

/** True when the address (or an alias of it) previously unsubscribed. */
export async function isEmailSuppressed(emailHash: string | undefined) {
  if (!emailHash) return false;
  await ensureSchema();
  const sql = getSql();
  const [row] = await sql<{ email_hash: string }[]>`
    select email_hash from waitlist_suppressions where email_hash = ${emailHash}
  `;
  return Boolean(row);
}

export const WAITLIST_USE_CASES = ["browsing", "development", "design", "writing", "other"] as const;
export type WaitlistUseCase = (typeof WAITLIST_USE_CASES)[number];

/** Records one optional answer, keyed by the signup's own invite code. First answer wins. */
export async function setWaitlistUseCase(code: string, useCase: WaitlistUseCase) {
  await ensureSchema();
  const sql = getSql();
  const result = await sql`
    update waitlist_signups
    set use_case = coalesce(use_case, ${useCase})
    where referral_code = ${code}
  `;
  return result.count > 0;
}

export async function listWaitlistSubmissions(limit = 100) {
  await ensureSchema();
  const sql = getSql();
  const rows = await sql<WaitlistRow[]>`
    select *
    from waitlist_signups
    order by updated_at desc
    limit ${Math.max(1, Math.min(limit, 5000))}
  `;

  return rows.map(mapRow);
}

export async function getWaitlistAggregateStats() {
  await ensureSchema();
  const sql = getSql();
  const [row] = await sql<
    {
      total: number;
      confirmed: number;
      delivered: number;
      failed: number;
      pending: number;
      signups24h: number;
      signups7d: number;
      signups30d: number;
      named_count: number;
      source_count: number;
      latest_signup: string | null;
    }[]
  >`
    select
      count(*)::int as total,
      count(*) filter (where confirmed_at is not null)::int as confirmed,
      count(*) filter (where notification_status = 'delivered')::int as delivered,
      count(*) filter (where notification_status = 'failed')::int as failed,
      count(*) filter (where notification_status = 'stored')::int as pending,
      count(*) filter (where created_at >= now() - interval '24 hours')::int as signups24h,
      count(*) filter (where created_at >= now() - interval '7 days')::int as signups7d,
      count(*) filter (where created_at >= now() - interval '30 days')::int as signups30d,
      count(*) filter (where name is not null and btrim(name) <> '')::int as named_count,
      count(distinct coalesce(nullif(source, ''), 'homepage_waitlist'))::int as source_count,
      max(updated_at)::text as latest_signup
    from waitlist_signups
  `;

  return {
    total: row?.total ?? 0,
    confirmed: row?.confirmed ?? 0,
    unconfirmed: (row?.total ?? 0) - (row?.confirmed ?? 0),
    delivered: row?.delivered ?? 0,
    failed: row?.failed ?? 0,
    pending: row?.pending ?? 0,
    signups24h: row?.signups24h ?? 0,
    signups7d: row?.signups7d ?? 0,
    signups30d: row?.signups30d ?? 0,
    namedCount: row?.named_count ?? 0,
    sourceCount: row?.source_count ?? 0,
    latestSignup: row?.latest_signup ?? undefined,
  } satisfies WaitlistAggregateStats;
}

export async function listWaitlistSignupSeries(days = 14) {
  await ensureSchema();
  const sql = getSql();
  const safeDays = Math.max(1, Math.min(days, 90));
  const rows = await sql<WaitlistSignupSeriesPoint[]>`
    with series as (
      select generate_series(
        timezone('Asia/Singapore', now())::date - ${safeDays - 1},
        timezone('Asia/Singapore', now())::date,
        interval '1 day'
      )::date as day
    )
    select
      series.day::text as day,
      coalesce(count(waitlist_signups.id), 0)::int as count
    from series
    left join waitlist_signups
      on timezone('Asia/Singapore', waitlist_signups.created_at)::date = series.day
    group by series.day
    order by series.day asc
  `;

  return rows;
}

export async function listWaitlistBreakdown(
  kind: "source" | "utm_source" | "utm_medium" | "path",
  limit = 6,
) {
  await ensureSchema();
  const sql = getSql();
  const safeLimit = Math.max(1, Math.min(limit, 20));

  const query =
    kind === "source"
      ? sql<WaitlistBreakdownItem[]>`
          select
            coalesce(nullif(source, ''), 'homepage_waitlist') as label,
            count(*)::int as count
          from waitlist_signups
          group by 1
          order by count desc, label asc
          limit ${safeLimit}
        `
      : kind === "utm_source"
        ? sql<WaitlistBreakdownItem[]>`
            select
              coalesce(nullif(metadata->>'utm_source', ''), 'direct') as label,
              count(*)::int as count
            from waitlist_signups
            group by 1
            order by count desc, label asc
            limit ${safeLimit}
          `
        : kind === "utm_medium"
          ? sql<WaitlistBreakdownItem[]>`
              select
                coalesce(nullif(metadata->>'utm_medium', ''), 'unknown') as label,
                count(*)::int as count
              from waitlist_signups
              group by 1
              order by count desc, label asc
              limit ${safeLimit}
            `
          : sql<WaitlistBreakdownItem[]>`
              select
                coalesce(nullif(metadata->>'path', ''), '/') as label,
                count(*)::int as count
              from waitlist_signups
              group by 1
              order by count desc, label asc
              limit ${safeLimit}
            `;

  const rows = await query;
  return rows;
}
