import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  adminLoginAllowance: vi.fn(),
  claimDuplicateSubmission: vi.fn(),
  checkEndpointRateLimit: vi.fn(),
  checkRateLimit: vi.fn(),
  createAdminSession: vi.fn(),
  createLicenseRequest: vi.fn(),
  createOrGetTrialClaim: vi.fn(),
  isLicenseRequestStoreConfigured: vi.fn(),
  recordAppUsageEvent: vi.fn(),
  releaseDuplicateSubmissionClaim: vi.fn(),
  upsertWaitlistSubmission: vi.fn(),
}));

vi.mock("@/lib/rate-limit", () => ({
  RequestBodyTooLargeError: class RequestBodyTooLargeError extends Error {},
  checkEndpointRateLimit: mocks.checkEndpointRateLimit,
  checkRateLimit: mocks.checkRateLimit,
  claimDuplicateSubmission: mocks.claimDuplicateSubmission,
  createFingerprint: vi.fn((value: string) => value),
  readRequestBody: vi.fn((request: Request) => request.text()),
  releaseDuplicateSubmissionClaim: mocks.releaseDuplicateSubmissionClaim,
}));

vi.mock("@/lib/admin-login-rate-limit", () => ({
  adminLoginAllowance: mocks.adminLoginAllowance,
  clearAdminLoginFailures: vi.fn(),
  recordAdminLoginFailure: vi.fn(),
}));

vi.mock("@/lib/admin-auth", () => ({
  createAdminSession: mocks.createAdminSession,
  validateAdminPassword: vi.fn(),
}));

vi.mock("@/lib/app-usage-store", () => ({
  recordAppUsageEvent: mocks.recordAppUsageEvent,
}));

vi.mock("@/lib/trial-claim-store", () => ({
  createOrGetTrialClaim: mocks.createOrGetTrialClaim,
}));

vi.mock("@/lib/license-request-store", () => ({
  createLicenseRequest: mocks.createLicenseRequest,
  isLicenseRequestStoreConfigured: mocks.isLicenseRequestStoreConfigured,
  updateLicenseRequestNotificationStatus: vi.fn(),
}));

vi.mock("@/lib/waitlist-store", () => ({
  isWaitlistStoreConfigured: vi.fn(() => true),
  updateWaitlistNotificationStatus: vi.fn(),
  upsertWaitlistSubmission: mocks.upsertWaitlistSubmission,
}));

import { POST as postTelemetry } from "./api/app-telemetry/route";
import { POST as postAnalytics } from "./api/analytics/route";
import { POST as postLicenseHelp } from "./api/license-help/route";
import { POST as postTrialStart } from "./api/trial/start/route";
import { POST as postWaitlist } from "./api/waitlist/route";
import { POST as postAdminLogin } from "./dashboard/login/submit/route";

describe("rate-limit backend failures", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.spyOn(console, "error").mockImplementation(() => undefined);
    mocks.checkEndpointRateLimit.mockRejectedValue(new Error("Redis unavailable"));
    mocks.checkRateLimit.mockRejectedValue(new Error("Redis unavailable"));
    mocks.adminLoginAllowance.mockRejectedValue(new Error("Redis unavailable"));
    mocks.isLicenseRequestStoreConfigured.mockReturnValue(true);
  });

  it("returns 503 before starting a trial", async () => {
    const response = await postTrialStart(
      new Request("https://cmdtab.example/api/trial/start", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          email: "person@example.com",
          installId: "install-12345",
        }),
      }),
    );

    expect(response.status).toBe(503);
    expect(mocks.createOrGetTrialClaim).not.toHaveBeenCalled();
  });

  it("returns 503 before persisting a waitlist submission", async () => {
    const response = await postWaitlist(
      new Request("https://cmdtab.example/api/waitlist", {
        method: "POST",
        headers: { "content-type": "application/json", origin: "https://cmdtab.example" },
        body: JSON.stringify({ email: "person@example.com", source: "homepage" }),
      }),
    );

    expect(response.status).toBe(503);
    expect(mocks.upsertWaitlistSubmission).not.toHaveBeenCalled();
  });

  it("returns 503 before recording telemetry", async () => {
    const response = await postTelemetry(
      new Request("https://cmdtab.example/api/app-telemetry", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          installId: "install-12345",
          eventName: "app_activation",
          licenseState: "trial_active",
        }),
      }),
    );

    expect(response.status).toBe(503);
    expect(mocks.recordAppUsageEvent).not.toHaveBeenCalled();
  });

  it("returns 503 before recording site analytics", async () => {
    const response = await postAnalytics(
      new Request("https://cmdtab.example/api/analytics", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          origin: "https://cmdtab.example",
          host: "cmdtab.example",
        },
        body: JSON.stringify({
          eventType: "pageview",
          path: "/",
          visitorId: "visitor-123",
        }),
      }),
    );

    expect(response.status).toBe(503);
  });

  it("returns 503 before validating or creating an admin session", async () => {
    const response = await postAdminLogin(
      new Request("https://cmdtab.example/dashboard/login/submit", {
        method: "POST",
        headers: {
          "content-type": "application/x-www-form-urlencoded",
          "sec-fetch-site": "same-origin",
        },
        body: new URLSearchParams({ password: "not-used" }),
      }),
    );

    expect(response.status).toBe(503);
    expect(mocks.createAdminSession).not.toHaveBeenCalled();
  });

  it("returns duplicate success when a public-form claim is already held", async () => {
    mocks.checkRateLimit.mockResolvedValue({ allowed: true, fingerprint: "rate" });
    mocks.claimDuplicateSubmission.mockResolvedValue({ acquired: false });

    const response = await postWaitlist(
      new Request("https://cmdtab.example/api/waitlist", {
        method: "POST",
        headers: { "content-type": "application/json", origin: "https://cmdtab.example" },
        body: JSON.stringify({ email: "person@example.com", source: "homepage" }),
      }),
    );

    expect(response.status).toBe(200);
    expect(mocks.upsertWaitlistSubmission).not.toHaveBeenCalled();
  });

  it("releases a waitlist claim when persistence fails", async () => {
    const claim = {
      acquired: true as const,
      fingerprints: ["email", "request"],
      token: "claim-token",
    };
    mocks.checkRateLimit.mockResolvedValue({ allowed: true, fingerprint: "rate" });
    mocks.claimDuplicateSubmission.mockResolvedValue(claim);
    mocks.upsertWaitlistSubmission.mockRejectedValue(new Error("database unavailable"));

    const response = await postWaitlist(
      new Request("https://cmdtab.example/api/waitlist", {
        method: "POST",
        headers: { "content-type": "application/json", origin: "https://cmdtab.example" },
        body: JSON.stringify({ email: "person@example.com", source: "homepage" }),
      }),
    );

    expect(response.status).toBe(503);
    expect(mocks.releaseDuplicateSubmissionClaim).toHaveBeenCalledWith(claim);
  });

  it("returns duplicate success for a held license-help claim", async () => {
    mocks.checkRateLimit.mockResolvedValue({ allowed: true, fingerprint: "rate" });
    mocks.claimDuplicateSubmission.mockResolvedValue({ acquired: false });

    const response = await postLicenseHelp(
      new Request("https://cmdtab.example/api/license-help", {
        method: "POST",
        headers: { "content-type": "application/json", origin: "https://cmdtab.example" },
        body: JSON.stringify({
          email: "person@example.com",
          reason: "general",
          message: "Please help with my license request.",
        }),
      }),
    );

    expect(response.status).toBe(200);
    expect(mocks.createLicenseRequest).not.toHaveBeenCalled();
  });
});
