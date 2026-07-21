import { createHash } from "node:crypto";

import { Redis } from "@upstash/redis";

import { RateLimitBackendError } from "./rate-limit";

export type AdminLoginRateLimitInput = Request;

export type AdminLoginRateLimitDecision =
  | { allowed: true; retryAfterSeconds: 0 }
  | { allowed: false; retryAfterSeconds: number };

const WINDOW_SECONDS = 15 * 60;
const BLOCK_SECONDS = 30 * 60;
const MAX_FAILURES = 5;
const KEY_PREFIX = "cmdtab:website:admin-login";

const RECORD_FAILURE_SCRIPT = `
local blockedTtl = redis.call("TTL", KEYS[1])
if blockedTtl > 0 then
  return blockedTtl
end

local failures = redis.call("INCR", KEYS[2])
if failures == 1 then
  redis.call("EXPIRE", KEYS[2], tonumber(ARGV[1]))
end

if failures >= tonumber(ARGV[2]) then
  redis.call("SET", KEYS[1], "1", "EX", tonumber(ARGV[3]))
  redis.call("DEL", KEYS[2])
  return tonumber(ARGV[3])
end

return 0
`;

let redisClient: Redis | undefined;
let redisConfig: string | undefined;

function getRedis() {
  const kvUrl = process.env.ADMIN_RATE_LIMIT_KV_REST_API_URL?.trim();
  const kvToken = process.env.ADMIN_RATE_LIMIT_KV_REST_API_TOKEN?.trim();
  const useKvConfig = Boolean(kvUrl || kvToken);
  const url = useKvConfig
    ? kvUrl
    : process.env.ADMIN_RATE_LIMIT_REDIS_REST_URL?.trim() ||
      process.env.UPSTASH_REDIS_REST_URL?.trim();
  const token = useKvConfig
    ? kvToken
    : process.env.ADMIN_RATE_LIMIT_REDIS_REST_TOKEN?.trim() ||
      process.env.UPSTASH_REDIS_REST_TOKEN?.trim();
  if (!url || !token) {
    throw new RateLimitBackendError("Admin rate-limit Redis is not configured.");
  }

  const config = `${url}\n${token}`;
  if (!redisClient || redisConfig !== config) {
    redisClient = new Redis({ url, token });
    redisConfig = config;
  }
  return redisClient;
}

function clientFingerprint(request: Request) {
  const forwarded = request.headers.has("x-vercel-id")
    ? request.headers.get("x-forwarded-for")?.split(",")[0]?.trim()
    : undefined;
  const ip = request.headers.get("x-real-ip")?.trim() || forwarded;
  const userAgent = request.headers.get("user-agent")?.trim().slice(0, 256);
  const identifiers = [
    ip && ip.toLowerCase() !== "unknown" ? `ip:${ip}` : undefined,
    userAgent && userAgent.toLowerCase() !== "unknown" ? `ua:${userAgent}` : undefined,
  ].filter((value): value is string => Boolean(value));
  if (identifiers.length === 0) {
    throw new RateLimitBackendError("Admin login requires a stable rate-limit identifier.");
  }
  return createHash("sha256").update(identifiers.join("|")).digest("hex");
}

function keysFor(request: Request) {
  const fingerprint = clientFingerprint(request);
  return {
    block: `${KEY_PREFIX}:block:${fingerprint}`,
    failures: `${KEY_PREFIX}:failures:${fingerprint}`,
  };
}

function backendFailure(message: string, error: unknown): never {
  if (error instanceof RateLimitBackendError) throw error;
  throw new RateLimitBackendError(message, { cause: error });
}

export async function adminLoginAllowance(
  request: AdminLoginRateLimitInput,
): Promise<AdminLoginRateLimitDecision> {
  try {
    const ttl = await getRedis().ttl(keysFor(request).block);
    return ttl > 0
      ? { allowed: false, retryAfterSeconds: ttl }
      : { allowed: true, retryAfterSeconds: 0 };
  } catch (error) {
    backendFailure("Admin rate-limit Redis read failed.", error);
  }
}

export async function recordAdminLoginFailure(request: Request) {
  const keys = keysFor(request);
  try {
    return await getRedis().eval<number[], number>(
      RECORD_FAILURE_SCRIPT,
      [keys.block, keys.failures],
      [WINDOW_SECONDS, MAX_FAILURES, BLOCK_SECONDS],
    );
  } catch (error) {
    backendFailure("Admin rate-limit Redis write failed.", error);
  }
}

export async function clearAdminLoginFailures(request: Request) {
  const keys = keysFor(request);
  try {
    await getRedis().del(keys.block, keys.failures);
  } catch (error) {
    backendFailure("Admin rate-limit Redis clear failed.", error);
  }
}
