import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  verifySignature: vi.fn(() => false),
  getOrderAttributes: vi.fn(),
  claimLicenseFulfillment: vi.fn(),
  updateLicenseFulfillmentDeliveryStatus: vi.fn(),
  issueLicenseToken: vi.fn(),
  sendEmail: vi.fn(),
}));

vi.mock("@/lib/env", () => ({
  getServerEnv: vi.fn(() => ({
    resendApiKey: "test-resend-key",
    waitlistFromEmail: "from@example.com",
    waitlistToEmail: "owner@example.com",
    lemonsqueezyWebhookSecret: "test-webhook-secret",
    cmdtabLicensePrivateKeyPem: "test-private-key",
  })),
  getSiteUrl: vi.fn(() => "https://cmdtab.example"),
}));

vi.mock("@/lib/lemonsqueezy", () => ({
  getOrderAttributes: mocks.getOrderAttributes,
  verifyLemonSqueezySignature: mocks.verifySignature,
}));

vi.mock("@/lib/license-fulfillment-store", () => ({
  claimLicenseFulfillment: mocks.claimLicenseFulfillment,
  markLicenseFulfillmentRefunded: vi.fn(),
  updateLicenseFulfillmentDeliveryStatus: mocks.updateLicenseFulfillmentDeliveryStatus,
}));

vi.mock("@/lib/license-token", () => ({ issueCmdTabLicenseToken: mocks.issueLicenseToken }));
vi.mock("@/lib/resend", () => ({
  getResendClient: vi.fn(() => ({ emails: { send: mocks.sendEmail } })),
}));

import { POST } from "./route";

describe("Lemon Squeezy webhook rejection", () => {
  beforeEach(() => {
    vi.stubEnv("LEMONSQUEEZY_ALLOWED_STORE_IDS", "42");
    vi.stubEnv("LEMONSQUEEZY_ALLOWED_PRODUCT_IDS", "100");
    vi.stubEnv("LEMONSQUEEZY_ALLOWED_VARIANT_IDS", "200");
    mocks.verifySignature.mockReturnValue(false);
    mocks.getOrderAttributes.mockReset();
    mocks.claimLicenseFulfillment.mockReset();
    mocks.updateLicenseFulfillmentDeliveryStatus.mockReset();
    mocks.issueLicenseToken.mockReset();
    mocks.sendEmail.mockReset();
  });

  afterEach(() => vi.unstubAllEnvs());
  it("rejects non-JSON requests before processing", async () => {
    const response = await POST(
      new Request("https://cmdtab.example/api/lemonsqueezy/webhook", {
        method: "POST",
        body: "not-json",
        headers: { "content-type": "text/plain" },
      }),
    );

    expect(response.status).toBe(415);
    expect(mocks.verifySignature).not.toHaveBeenCalled();
  });

  it("rejects bodies above the 256 KiB limit", async () => {
    const response = await POST(
      new Request("https://cmdtab.example/api/lemonsqueezy/webhook", {
        method: "POST",
        body: "x".repeat(256 * 1024 + 1),
        headers: { "content-type": "application/json" },
      }),
    );

    expect(response.status).toBe(413);
    expect(mocks.verifySignature).not.toHaveBeenCalled();
  });

  it("rejects an invalid signature before parsing or persistence", async () => {
    const response = await POST(
      new Request("https://cmdtab.example/api/lemonsqueezy/webhook", {
        method: "POST",
        body: JSON.stringify({ meta: { event_name: "order_created" } }),
        headers: {
          "content-type": "application/json",
          "x-signature": "invalid",
        },
      }),
    );

    expect(response.status).toBe(401);
    expect(mocks.verifySignature).toHaveBeenCalledOnce();
  });

  it("does not issue a license for an unapproved product", async () => {
    mocks.verifySignature.mockReturnValue(true);
    mocks.getOrderAttributes.mockReturnValue({
      identifier: "order-1",
      user_email: "buyer@example.com",
      status: "paid",
      store_id: 42,
      first_order_item: { product_id: 999, variant_id: 998 },
    });
    const response = await POST(new Request("https://cmdtab.example/api/lemonsqueezy/webhook", {
      method: "POST",
      body: JSON.stringify({ meta: { event_name: "order_created" } }),
      headers: { "content-type": "application/json", "x-signature": "valid" },
    }));

    expect(response.status).toBe(200);
    expect(mocks.claimLicenseFulfillment).not.toHaveBeenCalled();
  });

  it("requires both product and variant to match when both allowlists are configured", async () => {
    mocks.verifySignature.mockReturnValue(true);
    mocks.getOrderAttributes.mockReturnValue({
      identifier: "order-intersection",
      user_email: "buyer@example.com",
      status: "paid",
      store_id: 42,
      first_order_item: { product_id: 100, variant_id: 999 },
    });
    const response = await POST(new Request("https://cmdtab.example/api/lemonsqueezy/webhook", {
      method: "POST",
      body: JSON.stringify({ meta: { event_name: "order_created" } }),
      headers: { "content-type": "application/json", "x-signature": "valid" },
    }));

    expect(response.status).toBe(200);
    expect(mocks.claimLicenseFulfillment).not.toHaveBeenCalled();
  });

  it("does not issue production licenses for test-mode orders", async () => {
    mocks.verifySignature.mockReturnValue(true);
    mocks.getOrderAttributes.mockReturnValue({
      identifier: "order-2",
      user_email: "buyer@example.com",
      status: "paid",
      store_id: 42,
      test_mode: true,
      first_order_item: { product_id: 100, variant_id: 200 },
    });
    const response = await POST(new Request("https://cmdtab.example/api/lemonsqueezy/webhook", {
      method: "POST",
      body: JSON.stringify({ meta: { event_name: "order_created" } }),
      headers: { "content-type": "application/json", "x-signature": "valid" },
    }));

    expect(response.status).toBe(200);
    expect(mocks.claimLicenseFulfillment).not.toHaveBeenCalled();
  });

  it("does not issue a license when paid status is missing", async () => {
    mocks.verifySignature.mockReturnValue(true);
    mocks.getOrderAttributes.mockReturnValue({
      identifier: "order-without-status",
      user_email: "buyer@example.com",
      store_id: 42,
      first_order_item: { product_id: 100, variant_id: 200 },
    });

    const response = await POST(new Request("https://cmdtab.example/api/lemonsqueezy/webhook", {
      method: "POST",
      body: JSON.stringify({ meta: { event_name: "order_created" } }),
      headers: { "content-type": "application/json", "x-signature": "valid" },
    }));

    expect(response.status).toBe(200);
    expect(mocks.claimLicenseFulfillment).not.toHaveBeenCalled();
  });

  it("uses order-scoped email idempotency and reports a superseded claim", async () => {
    mocks.verifySignature.mockReturnValue(true);
    mocks.getOrderAttributes.mockReturnValue({
      identifier: "order-owned",
      user_email: "buyer@example.com",
      status: "paid",
      store_id: 42,
      first_order_item: { product_id: 100, variant_id: 200 },
    });
    mocks.issueLicenseToken.mockReturnValue({
      payload: { licenseID: "order-owned" },
      token: "signed-license",
    });
    mocks.claimLicenseFulfillment.mockResolvedValue({
      acquired: true,
      processingToken: "claim-token",
      fulfillment: {
        orderIdentifier: "order-owned",
        orderHash: "a".repeat(64),
        purchaserEmail: "buyer@example.com",
        licenseToken: "signed-license",
        testMode: false,
      },
    });
    mocks.sendEmail.mockResolvedValue({ data: { id: "email-1" }, error: null });
    mocks.updateLicenseFulfillmentDeliveryStatus.mockResolvedValue(null);

    const response = await POST(new Request("https://cmdtab.example/api/lemonsqueezy/webhook", {
      method: "POST",
      body: JSON.stringify({ meta: { event_name: "order_created" } }),
      headers: { "content-type": "application/json", "x-signature": "valid" },
    }));

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({ handled: true, superseded: true });
    expect(mocks.sendEmail).toHaveBeenCalledWith(
      expect.any(Object),
      { idempotencyKey: `cmdtab-license/${"a".repeat(64)}` },
    );
    expect(mocks.updateLicenseFulfillmentDeliveryStatus).toHaveBeenCalledWith(
      "order-owned",
      "claim-token",
      "delivered",
    );
  });
});
