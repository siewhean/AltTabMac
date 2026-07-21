import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const redisMock = vi.hoisted(() => ({
  del: vi.fn(),
  eval: vi.fn(),
  ttl: vi.fn(),
}));

vi.mock("@upstash/redis", () => ({
  Redis: class {
    del = redisMock.del;
    eval = redisMock.eval;
    ttl = redisMock.ttl;
  },
}));

import {
  adminLoginAllowance,
  clearAdminLoginFailures,
  recordAdminLoginFailure,
} from "./admin-login-rate-limit";
import { RateLimitBackendError } from "./rate-limit";

const failures = new Map<string, { count: number; expiresAt: number }>();
const blocks = new Map<string, number>();

function ttlFor(key: string) {
  const blockedUntil = blocks.get(key);
  if (!blockedUntil || blockedUntil <= Date.now()) return -2;
  return Math.ceil((blockedUntil - Date.now()) / 1_000);
}

function installRedisMock() {
  redisMock.ttl.mockImplementation(async (key: string) => ttlFor(key));
  redisMock.eval.mockImplementation(
    async (_script: string, keys: string[], args: number[]) => {
      const [blockKey, failureKey] = keys;
      const [windowSeconds, maxFailures, blockSeconds] = args;
      const blockedTtl = ttlFor(blockKey);
      if (blockedTtl > 0) return blockedTtl;

      const existing = failures.get(failureKey);
      const count = existing && existing.expiresAt > Date.now() ? existing.count + 1 : 1;
      failures.set(failureKey, {
        count,
        expiresAt: existing?.expiresAt ?? Date.now() + windowSeconds * 1_000,
      });
      if (count >= maxFailures) {
        blocks.set(blockKey, Date.now() + blockSeconds * 1_000);
        failures.delete(failureKey);
        return blockSeconds;
      }
      return 0;
    },
  );
  redisMock.del.mockImplementation(async (...keys: string[]) => {
    for (const key of keys) {
      failures.delete(key);
      blocks.delete(key);
    }
    return keys.length;
  });
}

function clientRequest() {
  return new Request("https://cmdtab.example/dashboard/login", {
    headers: {
      "user-agent": "vitest-client",
      "x-real-ip": "192.0.2.1",
    },
  });
}

describe("admin login throttling", () => {
  beforeEach(() => {
    vi.useFakeTimers({ now: new Date("2026-07-14T00:00:00Z") });
    process.env.ADMIN_RATE_LIMIT_KV_REST_API_URL = "https://admin-redis.example";
    process.env.ADMIN_RATE_LIMIT_KV_REST_API_TOKEN = "test-token";
    failures.clear();
    blocks.clear();
    vi.clearAllMocks();
    installRedisMock();
  });

  afterEach(() => {
    vi.useRealTimers();
    delete process.env.ADMIN_RATE_LIMIT_KV_REST_API_URL;
    delete process.env.ADMIN_RATE_LIMIT_KV_REST_API_TOKEN;
    delete process.env.ADMIN_RATE_LIMIT_REDIS_REST_URL;
    delete process.env.ADMIN_RATE_LIMIT_REDIS_REST_TOKEN;
    delete process.env.UPSTASH_REDIS_REST_URL;
    delete process.env.UPSTASH_REDIS_REST_TOKEN;
  });

  it("blocks a client after five failures", async () => {
    const request = clientRequest();
    for (let attempt = 0; attempt < 4; attempt += 1) {
      await recordAdminLoginFailure(request);
      expect((await adminLoginAllowance(request)).allowed).toBe(true);
    }

    await recordAdminLoginFailure(request);
    expect(await adminLoginAllowance(request)).toEqual({
      allowed: false,
      retryAfterSeconds: 30 * 60,
    });
  });

  it("allows the client after the block expires", async () => {
    const request = clientRequest();
    for (let attempt = 0; attempt < 5; attempt += 1) {
      await recordAdminLoginFailure(request);
    }

    vi.advanceTimersByTime(30 * 60 * 1_000 + 1);
    expect((await adminLoginAllowance(request)).allowed).toBe(true);
  });

  it("clears failures and blocks after a successful login", async () => {
    const request = clientRequest();
    for (let attempt = 0; attempt < 5; attempt += 1) {
      await recordAdminLoginFailure(request);
    }

    await clearAdminLoginFailures(request);
    expect((await adminLoginAllowance(request)).allowed).toBe(true);
    expect(redisMock.del).toHaveBeenCalledWith(
      expect.stringContaining(":block:"),
      expect.stringContaining(":failures:"),
    );
  });

  it("starts a new failure window after fifteen minutes", async () => {
    const request = clientRequest();
    for (let attempt = 0; attempt < 4; attempt += 1) {
      await recordAdminLoginFailure(request);
    }

    vi.advanceTimersByTime(15 * 60 * 1_000 + 1);
    await recordAdminLoginFailure(request);
    expect((await adminLoginAllowance(request)).allowed).toBe(true);
  });

  it("fails closed when Redis is unavailable", async () => {
    redisMock.ttl.mockRejectedValueOnce(new Error("offline"));
    await expect(adminLoginAllowance(clientRequest())).rejects.toBeInstanceOf(
      RateLimitBackendError,
    );
  });

  it("rejects requests without a stable client identifier", async () => {
    await expect(
      adminLoginAllowance(new Request("https://cmdtab.example/dashboard/login")),
    ).rejects.toThrow("Admin login requires a stable rate-limit identifier.");
    expect(redisMock.ttl).not.toHaveBeenCalled();
  });

  it("accepts the legacy admin Redis environment names as a fallback", async () => {
    delete process.env.ADMIN_RATE_LIMIT_KV_REST_API_URL;
    delete process.env.ADMIN_RATE_LIMIT_KV_REST_API_TOKEN;
    process.env.ADMIN_RATE_LIMIT_REDIS_REST_URL = "https://legacy-admin-redis.example";
    process.env.ADMIN_RATE_LIMIT_REDIS_REST_TOKEN = "legacy-test-token";

    await expect(adminLoginAllowance(clientRequest())).resolves.toMatchObject({
      allowed: true,
    });
  });

  it("accepts canonical environment-scoped Upstash credentials", async () => {
    delete process.env.ADMIN_RATE_LIMIT_KV_REST_API_URL;
    delete process.env.ADMIN_RATE_LIMIT_KV_REST_API_TOKEN;
    process.env.UPSTASH_REDIS_REST_URL = "https://environment-redis.example";
    process.env.UPSTASH_REDIS_REST_TOKEN = "environment-test-token";

    await expect(adminLoginAllowance(clientRequest())).resolves.toMatchObject({
      allowed: true,
    });
  });
});
