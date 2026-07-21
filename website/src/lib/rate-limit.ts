import { createHash, randomUUID } from "node:crypto";

import { Redis } from "@upstash/redis";

type Bucket = {
  max: number;
  windowSeconds: number;
};

export type PublicFormRateLimitInput = {
  email: string;
  ip?: string;
  userAgent?: string;
};

export type RateLimitDecision =
  | { allowed: true; fingerprint: string }
  | { allowed: false; retryAfterSeconds: number };

export type EndpointRateLimitInput = {
  endpoint: "trial-start" | "app-telemetry" | "analytics" | "license-status";
  identifiers: readonly string[];
};

export type DuplicateSubmissionClaimInput = {
  fingerprints: readonly string[];
};

export type DuplicateSubmissionClaim =
  | { acquired: true; fingerprints: readonly string[]; token: string }
  | { acquired: false };

const PUBLIC_RATE_LIMITS: Bucket[] = [
  { max: 6, windowSeconds: 60 },
  { max: 24, windowSeconds: 60 * 60 },
];

const ENDPOINT_RATE_LIMITS: Record<EndpointRateLimitInput["endpoint"], Bucket[]> = {
  "trial-start": PUBLIC_RATE_LIMITS,
  "license-status": [
    { max: 60, windowSeconds: 60 },
    { max: 900, windowSeconds: 60 * 60 },
  ],
  "app-telemetry": [
    { max: 120, windowSeconds: 60 },
    { max: 1_000, windowSeconds: 60 * 60 },
  ],
  analytics: [
    { max: 60, windowSeconds: 60 },
    { max: 500, windowSeconds: 60 * 60 },
  ],
};

const DUPLICATE_TTL_SECONDS = 24 * 60 * 60;
const KEY_PREFIX = "cmdtab:website";

const CONSUME_BUCKETS_SCRIPT = `
for index, key in ipairs(KEYS) do
  local max = tonumber(ARGV[(index - 1) * 2 + 1])
  local window = tonumber(ARGV[(index - 1) * 2 + 2])
  local count = tonumber(redis.call("GET", key) or "0")
  if count >= max then
    local ttl = redis.call("TTL", key)
    if ttl < 1 then
      redis.call("EXPIRE", key, window)
      ttl = window
    end
    return {0, ttl}
  end
end

for index, key in ipairs(KEYS) do
  local window = tonumber(ARGV[(index - 1) * 2 + 2])
  local count = redis.call("INCR", key)
  if count == 1 then
    redis.call("EXPIRE", key, window)
  end
end

return {1, 0}
`;

const CLAIM_DUPLICATES_SCRIPT = `
for _, key in ipairs(KEYS) do
  if redis.call("EXISTS", key) == 1 then
    return 0
  end
end

for _, key in ipairs(KEYS) do
  redis.call("SET", key, ARGV[1], "NX", "EX", tonumber(ARGV[2]))
end

return 1
`;

const RELEASE_DUPLICATES_SCRIPT = `
local released = 0
for _, key in ipairs(KEYS) do
  if redis.call("GET", key) == ARGV[1] then
    released = released + redis.call("DEL", key)
  end
end
return released
`;

let redisClient: Redis | undefined;
let redisConfig: string | undefined;

function sha(value: string) {
  return createHash("sha256").update(value).digest("hex");
}

function isStableIdentifier(identifier: string) {
  const value = identifier.trim();
  if (!value) return false;
  const identifierValue = value.includes(":") ? value.slice(value.lastIndexOf(":") + 1) : value;
  return identifierValue.trim().toLowerCase() !== "unknown";
}

function duplicateKeys(fingerprints: readonly string[]) {
  const uniqueFingerprints = [...new Set(fingerprints.map((value) => value.trim()).filter(Boolean))];
  if (uniqueFingerprints.length === 0) {
    throw new RateLimitBackendError("Duplicate fingerprints are required.");
  }
  return uniqueFingerprints.map((fingerprint) => `${KEY_PREFIX}:duplicate:${fingerprint}`);
}

function getRedis() {
  const kvUrl = process.env.PUBLIC_RATE_LIMIT_KV_REST_API_URL?.trim();
  const kvToken = process.env.PUBLIC_RATE_LIMIT_KV_REST_API_TOKEN?.trim();
  const useKvConfig = Boolean(kvUrl || kvToken);
  const url = useKvConfig
    ? kvUrl
    : process.env.PUBLIC_RATE_LIMIT_REDIS_REST_URL?.trim() ||
      process.env.UPSTASH_REDIS_REST_URL?.trim();
  const token = useKvConfig
    ? kvToken
    : process.env.PUBLIC_RATE_LIMIT_REDIS_REST_TOKEN?.trim() ||
      process.env.UPSTASH_REDIS_REST_TOKEN?.trim();
  if (!url || !token) {
    throw new RateLimitBackendError("Public rate-limit Redis is not configured.");
  }

  const config = `${url}\n${token}`;
  if (!redisClient || redisConfig !== config) {
    redisClient = new Redis({ url, token });
    redisConfig = config;
  }
  return redisClient;
}

async function consumeBuckets(
  namespace: string,
  identifiers: readonly string[],
  limits: readonly Bucket[],
): Promise<RateLimitDecision> {
  const uniqueIdentifiers = [...new Set(identifiers.filter(isStableIdentifier))];
  const keys: string[] = [];
  const args: Array<string | number> = [];

  for (const identifier of uniqueIdentifiers) {
    for (const limit of limits) {
      keys.push(`${KEY_PREFIX}:limit:${namespace}:${sha(identifier)}:${limit.windowSeconds}`);
      args.push(limit.max, limit.windowSeconds);
    }
  }

  if (keys.length === 0) {
    throw new RateLimitBackendError("Rate-limit identifiers are required.");
  }

  try {
    const result = await getRedis().eval<Array<string | number>, [number, number]>(
      CONSUME_BUCKETS_SCRIPT,
      keys,
      args,
    );
    if (!Array.isArray(result) || result.length < 2) {
      throw new Error("Invalid Redis rate-limit response.");
    }

    if (Number(result[0]) === 0) {
      return {
        allowed: false,
        retryAfterSeconds: Math.max(1, Number(result[1]) || 1),
      };
    }
  } catch (error) {
    if (error instanceof RateLimitBackendError) throw error;
    throw new RateLimitBackendError("Public rate-limit Redis failed.", { cause: error });
  }

  return { allowed: true, fingerprint: sha(`${namespace}|${uniqueIdentifiers.join("|")}`) };
}

export class RateLimitBackendError extends Error {
  constructor(message: string, options?: ErrorOptions) {
    super(message, options);
    this.name = "RateLimitBackendError";
  }
}

export function createFingerprint(value: string) {
  return sha(value);
}

export class RequestBodyTooLargeError extends Error {
  constructor() {
    super("Request body too large.");
    this.name = "RequestBodyTooLargeError";
  }
}

export async function readRequestBody(request: Request, maxBytes: number) {
  const contentLength = request.headers.get("content-length")?.trim();
  if (contentLength && /^\d+$/.test(contentLength)) {
    const declaredBytes = Number(contentLength);
    if (Number.isSafeInteger(declaredBytes) && declaredBytes > maxBytes) {
      throw new RequestBodyTooLargeError();
    }
  }

  if (!request.body) return "";

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      totalBytes += value.byteLength;
      if (totalBytes > maxBytes) {
        await reader.cancel().catch(() => undefined);
        throw new RequestBodyTooLargeError();
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  const body = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    body.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(body);
}

export async function claimDuplicateSubmission(
  input: DuplicateSubmissionClaimInput,
): Promise<DuplicateSubmissionClaim> {
  const fingerprints = [...new Set(input.fingerprints.map((value) => value.trim()).filter(Boolean))];
  const keys = duplicateKeys(fingerprints);
  const token = randomUUID();

  try {
    const acquired = await getRedis().eval<Array<string | number>, number>(
      CLAIM_DUPLICATES_SCRIPT,
      keys,
      [token, DUPLICATE_TTL_SECONDS],
    );
    return Number(acquired) === 1
      ? { acquired: true, fingerprints, token }
      : { acquired: false };
  } catch (error) {
    if (error instanceof RateLimitBackendError) throw error;
    throw new RateLimitBackendError("Duplicate-claim Redis failed.", { cause: error });
  }
}

export async function releaseDuplicateSubmissionClaim(
  claim: Extract<DuplicateSubmissionClaim, { acquired: true }>,
) {
  try {
    await getRedis().eval<string[], number>(
      RELEASE_DUPLICATES_SCRIPT,
      duplicateKeys(claim.fingerprints),
      [claim.token],
    );
  } catch (error) {
    if (error instanceof RateLimitBackendError) throw error;
    throw new RateLimitBackendError("Duplicate-release Redis failed.", { cause: error });
  }
}

export async function checkRateLimit(
  input: PublicFormRateLimitInput,
): Promise<RateLimitDecision> {
  const identifiers = [`email:${input.email.toLowerCase()}`];
  if (input.ip && isStableIdentifier(input.ip)) identifiers.push(`ip:${input.ip.trim()}`);
  if (input.userAgent && isStableIdentifier(input.userAgent)) {
    identifiers.push(`ua:${input.userAgent.trim()}`);
  }

  return consumeBuckets(
    "public-form",
    identifiers,
    PUBLIC_RATE_LIMITS,
  );
}

export async function checkEndpointRateLimit(
  input: EndpointRateLimitInput,
): Promise<RateLimitDecision> {
  return consumeBuckets(input.endpoint, input.identifiers, ENDPOINT_RATE_LIMITS[input.endpoint]);
}
