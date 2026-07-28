import { createHash } from "node:crypto";

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

const globalState = globalThis as typeof globalThis & {
  __cmdtabWaitlistBuckets?: BucketStore;
  __cmdtabWaitlistDuplicates?: DuplicateStore;
  __cmdtabWaitlistLastCleanupAt?: number;
};

const buckets = globalState.__cmdtabWaitlistBuckets ?? new Map<string, number[]>();
const duplicates = globalState.__cmdtabWaitlistDuplicates ?? new Map<string, number>();

globalState.__cmdtabWaitlistBuckets = buckets;
globalState.__cmdtabWaitlistDuplicates = duplicates;

const RATE_LIMITS: Bucket[] = [
  { max: 6, windowMs: 60_000 },
  { max: 24, windowMs: 60 * 60_000 },
];

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
  const uaKey = `ua:${sha(input.userAgent || "unknown")}`;
  const fingerprint = sha(`${input.email}|${input.ip}|${input.userAgent}`);

  for (const config of RATE_LIMITS) {
    for (const key of [emailKey, ipKey, uaKey]) {
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

export function checkTrialRateLimit(installId: string, ip: string): RateLimitResult {
  const now = Date.now();
  maybeCleanup(now);

  const installKey = `trial_install:${sha(installId)}:86400000`;
  const ipKey = `trial_ip:${sha(ip)}:3600000`;

  const installEntries = remember(installKey, now, { max: 3, windowMs: 24 * 60 * 60_000 });
  if (installEntries.length > 3) {
    return {
      allowed: false,
      retryAfterSeconds: secondsUntilReset(installEntries, now, 24 * 60 * 60_000),
    };
  }

  const ipEntries = remember(ipKey, now, { max: 10, windowMs: 60 * 60_000 });
  if (ipEntries.length > 10) {
    return {
      allowed: false,
      retryAfterSeconds: secondsUntilReset(ipEntries, now, 60 * 60_000),
    };
  }

  return { allowed: true, fingerprint: sha(`${installId}|${ip}`) };
}
