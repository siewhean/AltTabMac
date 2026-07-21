import { beforeEach, describe, expect, it, vi } from "vitest";

const { checkRateLimit } = vi.hoisted(() => ({ checkRateLimit: vi.fn() }));
vi.mock("@/lib/rate-limit", () => ({ checkRateLimit }));

describe("release smoke rate-limit probe", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
    process.env.VERCEL_ENV = "preview";
    process.env.HEALTHCHECK_SECRET = "preview-health";
  });

  it("rejects unauthenticated requests", async () => {
    const { POST } = await import("./route");
    const response = await POST(new Request("https://preview.invalid/api/release-smoke/rate-limit", {
      method: "POST",
      body: JSON.stringify({ nonce: "12345678-1234-1234-1234-123456789012" }),
    }));
    expect(response.status).toBe(401);
    expect(checkRateLimit).not.toHaveBeenCalled();
  });

  it("validates the shared Redis bucket without application writes", async () => {
    checkRateLimit
      .mockResolvedValueOnce({ allowed: true, fingerprint: "a" })
      .mockResolvedValueOnce({ allowed: true, fingerprint: "b" })
      .mockResolvedValueOnce({ allowed: true, fingerprint: "c" })
      .mockResolvedValueOnce({ allowed: true, fingerprint: "d" })
      .mockResolvedValueOnce({ allowed: true, fingerprint: "e" })
      .mockResolvedValueOnce({ allowed: true, fingerprint: "f" })
      .mockResolvedValueOnce({ allowed: false, retryAfterSeconds: 60 });
    const { POST } = await import("./route");
    const response = await POST(new Request("https://preview.invalid/api/release-smoke/rate-limit", {
      method: "POST",
      headers: { authorization: "Bearer preview-health", "content-type": "application/json" },
      body: JSON.stringify({ nonce: "12345678-1234-1234-1234-123456789012" }),
    }));
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({ ok: true, backend: "redis", allowedCount: 6, blocked: true });
    expect(checkRateLimit).toHaveBeenCalledTimes(7);
  });

  it("is unavailable outside Preview", async () => {
    process.env.VERCEL_ENV = "production";
    const { POST } = await import("./route");
    const response = await POST(new Request("https://cmdtab.invalid/api/release-smoke/rate-limit", {
      method: "POST",
      headers: { authorization: "Bearer preview-health" },
      body: JSON.stringify({ nonce: "12345678-1234-1234-1234-123456789012" }),
    }));
    expect(response.status).toBe(404);
  });
});
