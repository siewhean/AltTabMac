import { createHash, createHmac } from "node:crypto";

import { optionalStrongInternalSecret } from "@/lib/env";
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

export type RateLimitResult =
  | { allowed: true; fingerprint: string }
  | { allowed: false; retryAfterSeconds: number }
  | { allowed: false; retryAfterSeconds: number; unavailable: true };

type BucketStore = Map<string, number[]>;
type DuplicateStore = Map<string, number>;

export type IngestEndpoint =
  | "analytics"
  | "app-telemetry"
  | "trial-start"
  | "license-activation"
  | "license-recovery"
  | "license-deactivation"
  | "license-devices"
  | "license-renewal";

const globalState = globalThis as typeof globalThis & {
  __cmdtabLocalRequestBuckets?: BucketStore;
  __cmdtabLocalRequestDuplicates?: DuplicateStore;
  __cmdtabLocalRequestLastCleanupAt?: number;
  __cmdtabRequestControlSchemaReady?: boolean;
  __cmdtabRequestControlLastCleanupAt?: number;
};

const localBuckets =
  globalState.__cmdtabLocalRequestBuckets ?? new Map<string, number[]>();
const localDuplicates =
  globalState.__cmdtabLocalRequestDuplicates ?? new Map<string, number>();

globalState.__cmdtabLocalRequestBuckets = localBuckets;
globalState.__cmdtabLocalRequestDuplicates = localDuplicates;

const PUBLIC_FORM_RATE_LIMITS: Bucket[] = [
  { max: 6, windowMs: 60_000 },
  { max: 24, windowMs: 60 * 60_000 },
];
const INGEST_RATE_LIMITS: Bucket[] = [
  { max: 120, windowMs: 60_000 },
  { max: 1_000, windowMs: 60 * 60_000 },
];
const SENSITIVE_INGEST_RATE_LIMITS: Bucket[] = [
  { max: 6, windowMs: 60_000 },
  { max: 24, windowMs: 60 * 60_000 },
];

function ingestRateLimits(endpoint: IngestEndpoint) {
  return endpoint === "trial-start" ||
    endpoint === "license-activation" ||
    endpoint === "license-recovery" ||
    endpoint === "license-deactivation" ||
    endpoint === "license-renewal"
    ? SENSITIVE_INGEST_RATE_LIMITS
    : INGEST_RATE_LIMITS;
}

const DUPLICATE_WINDOW_MS = 24 * 60 * 60_000;
const CLEANUP_INTERVAL_MS = 5 * 60_000;
const MAX_LOCAL_BUCKET_KEYS = 2_048;
const MAX_LOCAL_DUPLICATE_KEYS = 2_048;

// Rate-limit keys contain emails and IPs. Keyed with a server secret, a leaked
// request_controls table cannot be reversed by hashing guessed addresses.
// Without the secret (local development) plain SHA-256 keeps limits working.
function sha(value: string) {
  const secret = optionalStrongInternalSecret(process.env.REQUEST_FINGERPRINT_SECRET);
  if (!secret) return createHash("sha256").update(value).digest("hex");
  return createHmac("sha256", secret)
    .update(`cmdtab:request-fingerprint:v1\0${value}`)
    .digest("hex");
}

export function createFingerprint(value: string) {
  return sha(value);
}

function rememberLocal(bucketKey: string, now: number, config: Bucket) {
  const entries = localBuckets.get(bucketKey) ?? [];
  const fresh = entries.filter((entry) => now - entry < config.windowMs);
  fresh.push(now);
  localBuckets.set(bucketKey, fresh);
  return fresh;
}

function secondsUntilReset(entries: number[], now: number, windowMs: number) {
  const oldest = entries[0] ?? now;
  return Math.max(1, Math.ceil((windowMs - (now - oldest)) / 1_000));
}

function cleanupLocal(now: number) {
  const lastCleanupAt = globalState.__cmdtabLocalRequestLastCleanupAt ?? 0;
  if (now - lastCleanupAt < CLEANUP_INTERVAL_MS) return;

  for (const [bucketKey, entries] of localBuckets) {
    const windowMs = Number.parseInt(bucketKey.split(":").at(-1) ?? "", 10);
    if (!Number.isFinite(windowMs) || windowMs <= 0) {
      localBuckets.delete(bucketKey);
      continue;
    }
    const fresh = entries.filter((entry) => now - entry < windowMs);
    if (fresh.length === 0) localBuckets.delete(bucketKey);
    else localBuckets.set(bucketKey, fresh);
  }

  for (const [fingerprint, lastSeen] of localDuplicates) {
    if (now - lastSeen > DUPLICATE_WINDOW_MS) {
      localDuplicates.delete(fingerprint);
    }
  }

  while (localBuckets.size > MAX_LOCAL_BUCKET_KEYS) {
    const oldestKey = localBuckets.keys().next().value;
    if (!oldestKey) break;
    localBuckets.delete(oldestKey);
  }
  while (localDuplicates.size > MAX_LOCAL_DUPLICATE_KEYS) {
    const oldestKey = localDuplicates.keys().next().value;
    if (!oldestKey) break;
    localDuplicates.delete(oldestKey);
  }

  globalState.__cmdtabLocalRequestLastCleanupAt = now;
}

function checkLocalRateLimit(
  keys: string[],
  limits: Bucket[],
  fingerprint: string,
): RateLimitResult {
  const now = Date.now();
  cleanupLocal(now);
  for (const config of limits) {
    for (const key of keys) {
      const entries = rememberLocal(`${key}:${config.windowMs}`, now, config);
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

async function ensureRequestControlSchema() {
  if (globalState.__cmdtabRequestControlSchemaReady) return;
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
  await sql`
    create table if not exists request_deduplication (
      fingerprint text primary key,
      expires_at timestamptz not null
    )
  `;
  globalState.__cmdtabRequestControlSchemaReady = true;
}

async function checkSharedFixedWindowRateLimit(input: {
  keys: string[];
  limits: Bucket[];
  fingerprint: string;
}): Promise<RateLimitResult> {
  await ensureRequestControlSchema();
  const sql = getSql();
  const now = Date.now();

  for (const config of input.limits) {
    const windowStart = Math.floor(now / config.windowMs) * config.windowMs;
    const expiresAt = new Date(windowStart + config.windowMs).toISOString();
    for (const key of input.keys) {
      const [row] = await sql<{ event_count: number }[]>`
        insert into ingest_rate_limits (
          bucket_key,
          window_start,
          event_count,
          expires_at
        ) values (
          ${`${key}:${config.windowMs}`},
          ${windowStart},
          1,
          ${expiresAt}
        )
        on conflict (bucket_key, window_start)
        do update set event_count = ingest_rate_limits.event_count + 1
        returning event_count
      `;
      if ((row?.event_count ?? config.max + 1) > config.max) {
        return {
          allowed: false,
          retryAfterSeconds: Math.max(
            1,
            Math.ceil((windowStart + config.windowMs - now) / 1_000),
          ),
        };
      }
    }
  }

  await cleanupSharedIfNeeded(now);
  return { allowed: true, fingerprint: input.fingerprint };
}

async function cleanupSharedIfNeeded(now: number) {
  const lastCleanupAt = globalState.__cmdtabRequestControlLastCleanupAt ?? 0;
  if (now - lastCleanupAt < CLEANUP_INTERVAL_MS) return;
  globalState.__cmdtabRequestControlLastCleanupAt = now;
  const sql = getSql();
  await sql`
    delete from ingest_rate_limits
    where expires_at < now() - interval '5 minutes'
  `;
  await sql`
    delete from request_deduplication
    where expires_at < now()
  `;
}

function databaseUnavailableResult(): RateLimitResult {
  return { allowed: false, retryAfterSeconds: 60, unavailable: true };
}

function mayUseLocalFallback() {
  return process.env.NODE_ENV !== "production";
}

export async function checkRateLimit(
  input: RateLimitInput,
): Promise<RateLimitResult> {
  const emailKey = `public-form:email:${sha(input.email.trim().toLowerCase())}`;
  const ipKey = `public-form:ip:${sha(input.ip || "unknown")}`;
  const fingerprint = sha(
    `${input.email.trim().toLowerCase()}|${input.ip}|${input.userAgent}`,
  );

  if (!isDatabaseConfigured()) {
    return mayUseLocalFallback()
      ? checkLocalRateLimit(
          [emailKey, ipKey],
          PUBLIC_FORM_RATE_LIMITS,
          fingerprint,
        )
      : databaseUnavailableResult();
  }

  try {
    return await checkSharedFixedWindowRateLimit({
      keys: [emailKey, ipKey],
      limits: PUBLIC_FORM_RATE_LIMITS,
      fingerprint,
    });
  } catch (error) {
    console.error("[CmdTab Website] shared public-form rate limit failed", error);
    return databaseUnavailableResult();
  }
}

export async function recentlySubmitted(fingerprint: string) {
  if (!isDatabaseConfigured()) {
    if (!mayUseLocalFallback()) {
      throw new Error("Persistent duplicate protection is unavailable.");
    }
    cleanupLocal(Date.now());
    const lastSeen = localDuplicates.get(fingerprint);
    if (!lastSeen) return false;
    if (Date.now() - lastSeen > DUPLICATE_WINDOW_MS) {
      localDuplicates.delete(fingerprint);
      return false;
    }
    return true;
  }

  await ensureRequestControlSchema();
  const sql = getSql();
  const [row] = await sql<{ exists: boolean }[]>`
    select exists(
      select 1
      from request_deduplication
      where fingerprint = ${fingerprint}
        and expires_at > now()
    ) as exists
  `;
  return row?.exists ?? false;
}

export async function markSubmitted(fingerprint: string) {
  if (!isDatabaseConfigured()) {
    if (!mayUseLocalFallback()) {
      throw new Error("Persistent duplicate protection is unavailable.");
    }
    cleanupLocal(Date.now());
    localDuplicates.set(fingerprint, Date.now());
    return;
  }

  await ensureRequestControlSchema();
  const sql = getSql();
  const expiresAt = new Date(Date.now() + DUPLICATE_WINDOW_MS).toISOString();
  await sql`
    insert into request_deduplication (fingerprint, expires_at)
    values (${fingerprint}, ${expiresAt})
    on conflict (fingerprint)
    do update set expires_at = excluded.expires_at
  `;
}

function checkLocalIngestRateLimit(input: {
  endpoint: IngestEndpoint;
  ip: string;
  userAgent: string;
}): RateLimitResult {
  const endpointKey = `ingest:${input.endpoint}:${sha(input.ip || "unknown")}`;
  const clientKey = `ingest:${input.endpoint}:client:${sha(
    `${input.ip || "unknown"}|${input.userAgent || "unknown"}`,
  )}`;
  const fingerprint = sha(`${input.endpoint}|${input.ip}|${input.userAgent}`);
  return checkLocalRateLimit(
    [endpointKey, clientKey],
    ingestRateLimits(input.endpoint),
    fingerprint,
  );
}

export async function checkIngestRateLimit(input: {
  endpoint: IngestEndpoint;
  ip: string;
  userAgent: string;
}): Promise<RateLimitResult> {
  const fingerprint = sha(`${input.endpoint}|${input.ip}|${input.userAgent}`);
  const bucketKey = `ingest:${input.endpoint}:${sha(input.ip || "unknown")}`;

  if (!isDatabaseConfigured()) {
    return mayUseLocalFallback()
      ? checkLocalIngestRateLimit(input)
      : databaseUnavailableResult();
  }

  try {
    return await checkSharedFixedWindowRateLimit({
      keys: [bucketKey],
      limits: ingestRateLimits(input.endpoint),
      fingerprint,
    });
  } catch (error) {
    console.error("[CmdTab Website] shared ingest rate limit failed", error);
    return databaseUnavailableResult();
  }
}
