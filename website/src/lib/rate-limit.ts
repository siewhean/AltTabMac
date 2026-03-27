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

export function createFingerprint(value: string) {
  return sha(value);
}

export function recentlySubmitted(fingerprint: string) {
  const lastSeen = duplicates.get(fingerprint);
  if (!lastSeen) return false;
  if (Date.now() - lastSeen > DUPLICATE_WINDOW_MS) {
    duplicates.delete(fingerprint);
    return false;
  }
  return true;
}

export function markSubmitted(fingerprint: string) {
  duplicates.set(fingerprint, Date.now());
}

export function checkRateLimit(input: RateLimitInput): RateLimitResult {
  const now = Date.now();
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

