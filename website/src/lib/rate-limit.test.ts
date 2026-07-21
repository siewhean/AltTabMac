import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const redisMock = vi.hoisted(() => ({
  eval: vi.fn(),
}));

vi.mock("@upstash/redis", () => ({
  Redis: class {
    eval = redisMock.eval;
  },
}));

import {
  RateLimitBackendError,
  RequestBodyTooLargeError,
  checkRateLimit,
  claimDuplicateSubmission,
  checkEndpointRateLimit,
  readRequestBody,
  releaseDuplicateSubmissionClaim,
} from "./rate-limit";

type Counter = { count: number; expiresAt: number };

const counters = new Map<string, Counter>();
const duplicateClaims = new Map<string, { token: string; expiresAt: number }>();

function installRedisCounterMock() {
  redisMock.eval.mockImplementation(
    async (script: string, keys: string[], args: Array<string | number>) => {
      const now = Date.now();
      if (script.includes('redis.call("EXISTS", key)')) {
        const held = keys.some((key) => {
          const claim = duplicateClaims.get(key);
          return claim && claim.expiresAt > now;
        });
        if (held) return 0;

        const token = String(args[0]);
        const ttlSeconds = Number(args[1]);
        for (const key of keys) {
          duplicateClaims.set(key, { token, expiresAt: now + ttlSeconds * 1_000 });
        }
        return 1;
      }

      if (script.includes('redis.call("GET", key) == ARGV[1]')) {
        let released = 0;
        for (const key of keys) {
          if (duplicateClaims.get(key)?.token === String(args[0])) {
            duplicateClaims.delete(key);
            released += 1;
          }
        }
        return released;
      }

      for (let index = 0; index < keys.length; index += 1) {
        const key = keys[index];
        const max = Number(args[index * 2]);
        const windowSeconds = Number(args[index * 2 + 1]);
        const existing = counters.get(key);
        if (existing && existing.expiresAt > now && existing.count >= max) {
          return [0, Math.max(1, Math.ceil((existing.expiresAt - now) / 1_000))];
        }
        if (existing && existing.expiresAt <= now) counters.delete(key);
        expect(windowSeconds).toBeGreaterThan(0);
      }

      for (let index = 0; index < keys.length; index += 1) {
        const key = keys[index];
        const windowSeconds = Number(args[index * 2 + 1]);
        const existing = counters.get(key);
        counters.set(key, {
          count: (existing?.count ?? 0) + 1,
          expiresAt: existing?.expiresAt ?? now + windowSeconds * 1_000,
        });
      }
      return [1, 0];
    },
  );
}

describe("readRequestBody", () => {
  it("returns a body at the byte limit", async () => {
    const request = new Request("https://cmdtab.example/api/trial/start", {
      method: "POST",
      body: "1234",
    });
    expect(await readRequestBody(request, 4)).toBe("1234");
  });

  it("rejects an oversized declared content length", async () => {
    const request = new Request("https://cmdtab.example/api/trial/start", {
      method: "POST",
      body: "small",
      headers: { "content-length": "100" },
    });
    await expect(readRequestBody(request, 10)).rejects.toBeInstanceOf(
      RequestBodyTooLargeError,
    );
  });

  it("enforces streamed UTF-8 byte size rather than character count", async () => {
    const request = new Request("https://cmdtab.example/api/trial/start", {
      method: "POST",
      body: "\u{1F600}\u{1F600}",
    });
    request.headers.delete("content-length");
    await expect(readRequestBody(request, 7)).rejects.toBeInstanceOf(
      RequestBodyTooLargeError,
    );
  });
});

describe("Redis-backed rate limiting", () => {
  beforeEach(() => {
    vi.useFakeTimers({ now: new Date("2026-07-14T00:00:00Z") });
    process.env.PUBLIC_RATE_LIMIT_KV_REST_API_URL = "https://public-redis.example";
    process.env.PUBLIC_RATE_LIMIT_KV_REST_API_TOKEN = "test-token";
    counters.clear();
    duplicateClaims.clear();
    vi.clearAllMocks();
    installRedisCounterMock();
  });

  afterEach(() => {
    vi.useRealTimers();
    delete process.env.PUBLIC_RATE_LIMIT_KV_REST_API_URL;
    delete process.env.PUBLIC_RATE_LIMIT_KV_REST_API_TOKEN;
    delete process.env.PUBLIC_RATE_LIMIT_REDIS_REST_URL;
    delete process.env.PUBLIC_RATE_LIMIT_REDIS_REST_TOKEN;
    delete process.env.UPSTASH_REDIS_REST_URL;
    delete process.env.UPSTASH_REDIS_REST_TOKEN;
  });

  it("blocks trial-start on the seventh request in one minute", async () => {
    for (let request = 0; request < 6; request += 1) {
      expect(
        (await checkEndpointRateLimit({
          endpoint: "trial-start",
          identifiers: ["trial-client"],
        })).allowed,
      ).toBe(true);
    }

    expect(
      await checkEndpointRateLimit({ endpoint: "trial-start", identifiers: ["trial-client"] }),
    ).toEqual({ allowed: false, retryAfterSeconds: 60 });
  });

  it("deduplicates identifiers so one request consumes one allowance", async () => {
    for (let request = 0; request < 6; request += 1) {
      expect(
        (await checkEndpointRateLimit({
          endpoint: "trial-start",
          identifiers: ["same-client", "same-client"],
        })).allowed,
      ).toBe(true);
    }
  });

  it("uses the higher telemetry threshold and resets after the minute", async () => {
    for (let request = 0; request < 120; request += 1) {
      expect(
        (await checkEndpointRateLimit({
          endpoint: "app-telemetry",
          identifiers: ["telemetry-client"],
        })).allowed,
      ).toBe(true);
    }
    expect(
      (await checkEndpointRateLimit({
        endpoint: "app-telemetry",
        identifiers: ["telemetry-client"],
      })).allowed,
    ).toBe(false);

    vi.advanceTimersByTime(60_001);
    expect(
      (await checkEndpointRateLimit({
        endpoint: "app-telemetry",
        identifiers: ["telemetry-client"],
      })).allowed,
    ).toBe(true);
  });

  it("atomically holds duplicate claims for 24 hours and releases by token", async () => {
    const claim = await claimDuplicateSubmission({
      fingerprints: ["email-fingerprint", "request-fingerprint"],
    });
    expect(claim.acquired).toBe(true);
    expect(
      await claimDuplicateSubmission({ fingerprints: ["request-fingerprint"] }),
    ).toEqual({ acquired: false });
    expect([...duplicateClaims.values()][0]?.expiresAt).toBe(
      Date.now() + 24 * 60 * 60 * 1_000,
    );

    if (!claim.acquired) throw new Error("Expected an acquired duplicate claim.");
    await releaseDuplicateSubmissionClaim(claim);
    expect(
      (await claimDuplicateSubmission({ fingerprints: ["request-fingerprint"] })).acquired,
    ).toBe(true);
  });

  it("omits unavailable public identifiers instead of creating shared buckets", async () => {
    await checkRateLimit({ email: "person@example.com", ip: "unknown", userAgent: "" });
    const [, keys] = redisMock.eval.mock.calls.at(-1) ?? [];
    expect(keys).toHaveLength(2);
  });

  it("requires at least one stable endpoint identifier", async () => {
    await expect(
      checkEndpointRateLimit({
        endpoint: "trial-start",
        identifiers: ["", "unknown", "ip:unknown"],
      }),
    ).rejects.toThrow("Rate-limit identifiers are required.");
    expect(redisMock.eval).not.toHaveBeenCalled();
  });

  it("blocks public endpoints on the twenty-fifth request in one hour", async () => {
    for (let request = 0; request < 24; request += 1) {
      expect(
        (await checkEndpointRateLimit({
          endpoint: "trial-start",
          identifiers: ["hourly-trial-client"],
        })).allowed,
      ).toBe(true);
      vi.advanceTimersByTime(61_000);
    }

    expect(
      (await checkEndpointRateLimit({
        endpoint: "trial-start",
        identifiers: ["hourly-trial-client"],
      })).allowed,
    ).toBe(false);
  });

  it("blocks telemetry on the one-thousand-and-first request in one hour", async () => {
    for (let batch = 0; batch < 10; batch += 1) {
      for (let request = 0; request < 100; request += 1) {
        expect(
          (await checkEndpointRateLimit({
            endpoint: "app-telemetry",
            identifiers: ["hourly-telemetry-client"],
          })).allowed,
        ).toBe(true);
      }
      vi.advanceTimersByTime(61_000);
    }

    expect(
      (await checkEndpointRateLimit({
        endpoint: "app-telemetry",
        identifiers: ["hourly-telemetry-client"],
      })).allowed,
    ).toBe(false);
  });

  it("fails closed when Redis is unavailable", async () => {
    redisMock.eval.mockRejectedValueOnce(new Error("offline"));
    await expect(
      checkEndpointRateLimit({ endpoint: "trial-start", identifiers: ["client"] }),
    ).rejects.toBeInstanceOf(RateLimitBackendError);
  });

  it("accepts the legacy public Redis environment names as a fallback", async () => {
    delete process.env.PUBLIC_RATE_LIMIT_KV_REST_API_URL;
    delete process.env.PUBLIC_RATE_LIMIT_KV_REST_API_TOKEN;
    process.env.PUBLIC_RATE_LIMIT_REDIS_REST_URL = "https://legacy-public-redis.example";
    process.env.PUBLIC_RATE_LIMIT_REDIS_REST_TOKEN = "legacy-test-token";

    await expect(
      checkEndpointRateLimit({ endpoint: "trial-start", identifiers: ["legacy-client"] }),
    ).resolves.toMatchObject({ allowed: true });
  });

  it("accepts canonical environment-scoped Upstash credentials", async () => {
    delete process.env.PUBLIC_RATE_LIMIT_KV_REST_API_URL;
    delete process.env.PUBLIC_RATE_LIMIT_KV_REST_API_TOKEN;
    process.env.UPSTASH_REDIS_REST_URL = "https://environment-redis.example";
    process.env.UPSTASH_REDIS_REST_TOKEN = "environment-test-token";

    await expect(
      checkEndpointRateLimit({ endpoint: "trial-start", identifiers: ["canonical-client"] }),
    ).resolves.toMatchObject({ allowed: true });
  });
});
