import { createHmac } from "node:crypto";

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => {
  let cookieValue: string | undefined;
  return {
    cookieStore: {
      delete: vi.fn(() => {
        cookieValue = undefined;
      }),
      get: vi.fn(() => (cookieValue ? { value: cookieValue } : undefined)),
      set: vi.fn((_name: string, value: string) => {
        cookieValue = value;
      }),
    },
    getCookie: () => cookieValue,
    setCookie: (value: string | undefined) => {
      cookieValue = value;
    },
    validateStoredDashboardPassword: vi.fn(async () => null as boolean | null),
  };
});

vi.mock("next/headers", () => ({
  cookies: vi.fn(async () => mocks.cookieStore),
}));
vi.mock("next/navigation", () => ({ redirect: vi.fn() }));
vi.mock("@/lib/admin-store", () => ({
  getDashboardAuthSummary: vi.fn(async () => ({ source: "environment" })),
  validateStoredDashboardPassword: mocks.validateStoredDashboardPassword,
}));

import { createAdminSession, hasAdminSession, validateAdminPassword } from "./admin-auth";

const secret = "a-test-secret-with-enough-entropy";

function signedCookie(issuedAt: number, nonce = "n".repeat(24)) {
  const payload = `${issuedAt}.${nonce}`;
  const signature = createHmac("sha256", secret).update(payload).digest("base64url");
  return `${payload}.${signature}`;
}

describe("admin session cookies", () => {
  beforeEach(() => {
    vi.useFakeTimers({ now: new Date("2026-07-14T00:00:00Z") });
    vi.stubEnv("ADMIN_DASHBOARD_SECRET", secret);
    vi.stubEnv("NODE_ENV", "test");
    mocks.setCookie(undefined);
    mocks.cookieStore.set.mockClear();
    mocks.validateStoredDashboardPassword.mockResolvedValue(null);
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.useRealTimers();
  });

  it("creates a signed, HTTP-only, two-hour session", async () => {
    await createAdminSession();

    expect(await hasAdminSession()).toBe(true);
    expect(mocks.cookieStore.set).toHaveBeenCalledWith(
      "cmdtab_admin_session",
      expect.stringMatching(/^\d+\.[A-Za-z0-9_-]{24}\.[A-Za-z0-9_-]+$/),
      expect.objectContaining({
        httpOnly: true,
        maxAge: 2 * 60 * 60,
        sameSite: "lax",
        secure: false,
      }),
    );
  });

  it("rejects a tampered signature", async () => {
    await createAdminSession();
    const cookie = mocks.getCookie();
    expect(cookie).toBeDefined();
    const [issuedAt, nonce, signature] = cookie!.split(".");
    const tamperedSignature = `${signature[0] === "A" ? "B" : "A"}${signature.slice(1)}`;
    mocks.setCookie(`${issuedAt}.${nonce}.${tamperedSignature}`);

    expect(await hasAdminSession()).toBe(false);
  });

  it("rejects expired and future-issued sessions", async () => {
    const nowSeconds = Math.floor(Date.now() / 1_000);
    mocks.setCookie(signedCookie(nowSeconds - 2 * 60 * 60 - 1));
    expect(await hasAdminSession()).toBe(false);

    mocks.setCookie(signedCookie(nowSeconds + 1));
    expect(await hasAdminSession()).toBe(false);
  });

  it("rejects malformed cookies and sessions when no secret is configured", async () => {
    mocks.setCookie("malformed");
    expect(await hasAdminSession()).toBe(false);

    mocks.setCookie(signedCookie(Math.floor(Date.now() / 1_000)));
    vi.stubEnv("ADMIN_DASHBOARD_SECRET", "");
    vi.stubEnv("ADMIN_DASHBOARD_PASSWORD", "");
    expect(await hasAdminSession()).toBe(false);
  });

  it("stops accepting the bootstrap environment password after database rotation", async () => {
    vi.stubEnv("ADMIN_DASHBOARD_PASSWORD", "bootstrap-password");
    mocks.validateStoredDashboardPassword.mockResolvedValue(false);
    expect(await validateAdminPassword("bootstrap-password")).toBe(false);
  });
});
