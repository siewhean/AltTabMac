import { createHash } from "node:crypto";

import { getSql, isDatabaseConfigured } from "@/lib/postgres";

type Bucket = {
  max: number;
  windowMs: number;
};

type RateLimitInput = {
  email: string;
  ip: string;
  userAgent: string;
};

type RateLimitResult =
  | { allowed: true; fingerprint: string }
  | { allowed: false; retryAfterSeconds: number };

type BucketStore = Map<string, number[]>;

type DuplicateStore = Map<string, number>;
export type IngestEndpoint =
  | "analytics"
  | "app-telemetry"
  | "trial-start"
  | "license-activation"
  | "license-recovery";

const globalState = globalThis as typeof globalThis & {
  __cmdtabWaitlistBuckets?: BucketStore;
  __cmdtabWaitlistDuplicates?: DuplicateStore;
  __cmdtabWaitlistLastCleanupAt?: number;
  __cmdtabIngestRateSchemaReady?: boolean;
  __cmdtabIngestRateLastCleanupAt?: number;
};

const buckets = globalState.__cmdtabWaitlistBuckets ?? new Map<string, number[]>();
const duplicates = globalState.__cmdtabWaitlistDuplicates ?? new Map<string, number>();

globalState.__cmdtabWaitlistBuckets = buckets;
globalState.__cmdtabWaitlistDuplicates = duplicates;

const RATE_LIMITS: Bucket[] = [
  { max: 6, windowMs: 60_000 },
  { max: 24, windowMs: 60 * 60_000 },
];
const INGEST_RATE_LIMITS: Bucket[] = [
  { max: 120, windowMs: 60_000 },
  { max: 1_000, windowMs: 60 * 60_000 },
];
const TRIAL_RATE_LIMITS: Bucket[] = [
  { max: 6, windowMs: 60_000 },
  { max: 24, windowMs: 60 * 60_000 },
];

function ingestRateLimits(endpoint: IngestEndpoint) {
  return endpoint === "trial-start" ||
    endpoint === "license-activation" ||
    endpoint === "license-recovery"
    ? TRIAL_RATE_LIMITS
    : INGEST_RATE_LIMITS;
}

const DUPLICATE_WINDOW_MS = 24 * 60 * 60_000;
const CLEANUP_INTERVAL_MS = 5 * 60_000;
const MAX_BUCKET_KEYS = 2_048;
const MAX_DUPLICATE_KEYS = 2_048;

function remember(bucketKey: string, now: number, config: Bucket) {
  const entries = buckets.get(bucketKey) ?? [];
  const fresh = entries.filter((entry) => now - entry < config.windowMs);
  fresh.push(now);
  buckets.set(bucketKey, fresh);
  return fresh;
}

function secondsUntilReset(entries: number[], now: number, windowMs: number) {
  const oldest = entries[0];
  return Math.max(1, Math.ceil((windowMs - (now - oldest)) / 1000));
}

function sha(value: string) {
  return createHash("sha256").update(value).digest("hex");
}

function maybeCleanup(now: number) {
  const lastCleanupAt = globalState.__cmdtabWaitlistLastCleanupAt ?? 0;
  if (now - lastCleanupAt < CLEANUP_INTERVAL_MS) return;

  for (const [bucketKey, entries] of buckets) {
    const windowMs = Number.parseInt(bucketKey.split(":").at(-1) ?? "", 10);
    if (!Number.isFinite(windowMs) || windowMs <= 0) {
      buckets.delete(bucketKey);
      continue;
    }

    const fresh = entries.filter((entry) => now - entry < windowMs);
    if (fresh.length === 0) {
      buckets.delete(bucketKey);
    } else {
      buckets.set(bucketKey, fresh);
    }
  }

  for (const [fingerprint, lastSeen] of duplicates) {
    if (now - lastSeen > DUPLICATE_WINDOW_MS) {
      duplicates.delete(fingerprint);
    }
  }

  while (buckets.size > MAX_BUCKET_KEYS) {
    const oldestKey = buckets.keys().next().value;
    if (!oldestKey) break;
    buckets.delete(oldestKey);
  }

  while (duplicates.size > MAX_DUPLICATE_KEYS) {
    const oldestKey = duplicates.keys().next().value;
    if (!oldestKey) break;
    duplicates.delete(oldestKey);
  }

  globalState.__cmdtabWaitlistLastCleanupAt = now;
}

export function createFingerprint(value: string) {
  return sha(value);
}

export function recentlySubmitted(fingerprint: string) {
  maybeCleanup(Date.now());
  const lastSeen = duplicates.get(fingerprint);
  if (!lastSeen) return false;
  if (Date.now() - lastSeen > DUPLICATE_WINDOW_MS) {
    duplicates.delete(fingerprint);
    return false;
  }
  return true;
}

export function markSubmitted(fingerprint: string) {
  maybeCleanup(Date.now());
  duplicates.set(fingerprint, Date.now());
}

export function checkRateLimit(input: RateLimitInput): RateLimitResult {
  const now = Date.now();
  maybeCleanup(now);
  const emailKey = `email:${sha(input.email)}`;
  const ipKey = `ip:${sha(input.ip)}`;
  const fingerprint = sha(`${input.email}|${input.ip}|${input.userAgent}`);

  for (const config of RATE_LIMITS) {
    for (const key of [emailKey, ipKey]) {
      const entries = remember(`${key}:${config.windowMs}`, now, config);
      if (entries.length > config.max) {
        return {
          allowed: false,
          retryAfterSeconds: secondsUntilReset(entries, now, config.windowMs),
        };
      }
    }
  }

  return { allowed: true, fingerprint };
}

function checkLocalIngestRateLimit(input: {
  endpoint: IngestEndpoint;
  ip: string;
  userAgent: string;
}): RateLimitResult {
  const now = Date.now();
  maybeCleanup(now);
  const endpointKey = `${input.endpoint}:${sha(input.ip || "unknown")}`;
  const clientKey = `${input.endpoint}:client:${sha(
    `${input.ip || "unknown"}|${input.userAgent || "unknown"}`,
  )}`;
  const fingerprint = sha(`${input.endpoint}|${input.ip}|${input.userAgent}`);

  for (const config of ingestRateLimits(input.endpoint)) {
    for (const key of [endpointKey, clientKey]) {
      const entries = remember(`ingest:${key}:${config.windowMs}`, now, config);
      if (entries.length > config.max) {
        return {
          allowed: false,
          retryAfterSeconds: secondsUntilReset(entries, now, config.windowMs),
        };
      }
    }
  }

  return { allowed: true, fingerprint };
}

async function ensureIngestRateLimitSchema() {
  if (globalState.__cmdtabIngestRateSchemaReady) return;
  const sql = getSql();
  await sql`
    create table if not exists ingest_rate_limits (
      bucket_key text not null,
      window_start bigint not null,
      event_count integer not null,
      expires_at timestamptz not null,
      primary key (bucket_key, window_start)
    )
  `;
  globalState.__cmdtabIngestRateSchemaReady = true;
}

async function checkSharedIngestRateLimit(input: {
  endpoint: IngestEndpoint;
  ip: string;
  userAgent: string;
}): Promise<RateLimitResult> {
  await ensureIngestRateLimitSchema();
  const sql = getSql();
  const now = Date.now();
  const fingerprint = sha(`${input.endpoint}|${input.ip}|${input.userAgent}`);
  const bucketKey = `ingest:${input.endpoint}:${sha(input.ip || "unknown")}`;

  for (const config of ingestRateLimits(input.endpoint)) {
    const windowStart = Math.floor(now / config.windowMs) * config.windowMs;
    const expiresAt = new Date(windowStart + config.windowMs);
    const [row] = await sql<{ event_count: number }[]>`
      insert into ingest_rate_limits (bucket_key, window_start, event_count, expires_at)
      values (${`${bucketKey}:${config.windowMs}`}, ${windowStart}, 1, ${expiresAt.toISOString()})
      on conflict (bucket_key, window_start)
      do update set event_count = ingest_rate_limits.event_count + 1
      returning event_count
    `;

    if ((row?.event_count ?? config.max + 1) > config.max) {
      return {
        allowed: false,
        retryAfterSeconds: Math.max(1, Math.ceil((windowStart + config.windowMs - now) / 1_000)),
      };
    }
  }

  const lastCleanupAt = globalState.__cmdtabIngestRateLastCleanupAt ?? 0;
  if (now - lastCleanupAt >= CLEANUP_INTERVAL_MS) {
    globalState.__cmdtabIngestRateLastCleanupAt = now;
    await sql`delete from ingest_rate_limits where expires_at < now() - interval '5 minutes'`;
  }

  return { allowed: true, fingerprint };
}

export async function checkIngestRateLimit(input: {
  endpoint: IngestEndpoint;
  ip: string;
  userAgent: string;
}): Promise<RateLimitResult | { allowed: false; retryAfterSeconds: number; unavailable: true }> {
  if (!isDatabaseConfigured()) {
    return checkLocalIngestRateLimit(input);
  }

  try {
    return await checkSharedIngestRateLimit(input);
  } catch (error) {
    console.error("[CmdTab Website] shared ingest rate limit failed", error);
    return { allowed: false, retryAfterSeconds: 60, unavailable: true };
  }
}
