import assert from "node:assert/strict";
import test from "node:test";

import {
  fulfillPaidPurchase,
  type PaidPurchaseFulfillmentDependencies,
  type PaidPurchaseInput,
} from "../src/lib/purchase-fulfillment.js";

const purchase: PaidPurchaseInput = {
  orderIdentifier: "order-123",
  orderNumber: 123,
  eventName: "order_created",
  purchaserEmail: "buyer@example.com",
  purchaserName: "Test Buyer",
  productName: "CmdTab",
  variantName: "Personal licence",
  receiptUrl: "https://example.com/receipt/123",
  currency: "USD",
  total: "1200",
  totalFormatted: "$12.00",
  storeId: 10,
  lemonsqueezyOrderId: "ls-order-123",
  testMode: true,
  lookupPepper: "a-production-secret-with-more-than-thirty-two-bytes",
};

test("paid purchase persists entitlement, queues the same credential, and attempts immediate delivery", async () => {
  let created:
    | Parameters<PaidPurchaseFulfillmentDependencies["createOrGetFulfillment"]>[0]
    | undefined;
  let entitlement:
    | Parameters<PaidPurchaseFulfillmentDependencies["ensureActiveEntitlement"]>[0]
    | undefined;
  let email:
    | Parameters<PaidPurchaseFulfillmentDependencies["enqueueLicenseEmail"]>[0]
    | undefined;
  let processedLimit: number | undefined;

  const dependencies: PaidPurchaseFulfillmentDependencies = {
    async createOrGetFulfillment(input) {
      created = input;
      return {
        orderIdentifier: input.orderIdentifier,
        orderNumber: input.orderNumber,
        purchaserEmail: input.purchaserEmail,
        purchaserName: input.purchaserName,
        productName: input.productName,
        receiptUrl: input.receiptUrl,
        licenseId: input.licenseId,
        licenseToken: input.licenseToken,
        deliveryStatus: "stored",
        testMode: input.testMode,
      };
    },
    async ensureActiveEntitlement(input) {
      entitlement = input;
    },
    async enqueueLicenseEmail(input) {
      email = input;
      return "outbox-job-1";
    },
    async processLicenseOutbox(limit) {
      processedLimit = limit;
      return { claimed: 1, delivered: 1, failed: 0 };
    },
    reportInlineDeliveryFailure() {
      assert.fail("successful delivery must not report a failure");
    },
  };

  const result = await fulfillPaidPurchase(purchase, dependencies);

  assert.deepEqual(result, {
    kind: "queued",
    orderIdentifier: purchase.orderIdentifier,
    delivery: { claimed: 1, delivered: 1, failed: 0 },
  });
  assert.ok(created);
  assert.match(created.licenseToken, /^CMDTAB-ACT-[A-Za-z0-9_-]{43}$/);
  assert.match(created.orderLookupHash, /^[a-f0-9]{64}$/);
  assert.match(created.licenseLookupHash, /^[a-f0-9]{64}$/);
  assert.match(created.emailLookupHash, /^[a-f0-9]{64}$/);
  assert.match(created.activationCredentialHash, /^[a-f0-9]{64}$/);
  assert.notEqual(created.orderLookupHash, created.licenseLookupHash);
  assert.deepEqual(entitlement, {
    licenseId: purchase.orderIdentifier,
    orderIdentifier: purchase.orderIdentifier,
    pepper: purchase.lookupPepper,
  });
  assert.equal(email?.dedupeKey, `purchase:${purchase.orderIdentifier}`);
  assert.equal(email?.kind, "license_delivery");
  assert.equal(email?.recipientEmail, purchase.purchaserEmail);
  assert.equal(email?.payload.licenseKey, created.licenseToken);
  assert.equal(email?.payload.receiptUrl, purchase.receiptUrl);
  assert.equal(processedLimit, 1);
});

test("duplicate delivered webhook remains idempotent and sends no second email", async () => {
  let entitlementCalls = 0;
  let emailCalls = 0;
  let processorCalls = 0;

  const dependencies: PaidPurchaseFulfillmentDependencies = {
    async createOrGetFulfillment(input) {
      return {
        orderIdentifier: input.orderIdentifier,
        orderNumber: input.orderNumber,
        purchaserEmail: input.purchaserEmail,
        purchaserName: input.purchaserName,
        productName: input.productName,
        receiptUrl: input.receiptUrl,
        licenseId: input.licenseId,
        licenseToken: "CMDTAB-ACT-existing-delivered-credential-000000000000000000",
        deliveryStatus: "delivered",
        testMode: input.testMode,
      };
    },
    async ensureActiveEntitlement() {
      entitlementCalls += 1;
    },
    async enqueueLicenseEmail() {
      emailCalls += 1;
    },
    async processLicenseOutbox() {
      processorCalls += 1;
      return { claimed: 0, delivered: 0, failed: 0 };
    },
    reportInlineDeliveryFailure() {
      assert.fail("duplicate delivery must not invoke delivery handling");
    },
  };

  const result = await fulfillPaidPurchase(purchase, dependencies);

  assert.deepEqual(result, {
    kind: "duplicate",
    orderIdentifier: purchase.orderIdentifier,
  });
  assert.equal(entitlementCalls, 1);
  assert.equal(emailCalls, 0);
  assert.equal(processorCalls, 0);
});

test("email provider failure stays queued and is surfaced for persistent retry", async () => {
  const deliveryError = new Error("temporary provider outage");
  let reportedError: unknown;
  let queued = false;

  const dependencies: PaidPurchaseFulfillmentDependencies = {
    async createOrGetFulfillment(input) {
      return {
        orderIdentifier: input.orderIdentifier,
        purchaserEmail: input.purchaserEmail,
        licenseId: input.licenseId,
        licenseToken: input.licenseToken,
        deliveryStatus: "stored",
        testMode: input.testMode,
      };
    },
    async ensureActiveEntitlement() {},
    async enqueueLicenseEmail() {
      queued = true;
    },
    async processLicenseOutbox() {
      throw deliveryError;
    },
    reportInlineDeliveryFailure(error) {
      reportedError = error;
    },
  };

  const result = await fulfillPaidPurchase(purchase, dependencies);

  assert.equal(queued, true);
  assert.equal(reportedError, deliveryError);
  assert.deepEqual(result, {
    kind: "queued",
    orderIdentifier: purchase.orderIdentifier,
    delivery: { claimed: 0, delivered: 0, failed: 1 },
  });
});

test("entitlement persistence failure stops before any customer email is queued", async () => {
  let emailCalls = 0;
  let processorCalls = 0;

  const dependencies: PaidPurchaseFulfillmentDependencies = {
    async createOrGetFulfillment(input) {
      return {
        orderIdentifier: input.orderIdentifier,
        purchaserEmail: input.purchaserEmail,
        licenseId: input.licenseId,
        licenseToken: input.licenseToken,
        deliveryStatus: "stored",
        testMode: input.testMode,
      };
    },
    async ensureActiveEntitlement() {
      throw new Error("database transaction failed");
    },
    async enqueueLicenseEmail() {
      emailCalls += 1;
    },
    async processLicenseOutbox() {
      processorCalls += 1;
      return { claimed: 0, delivered: 0, failed: 0 };
    },
    reportInlineDeliveryFailure() {},
  };

  await assert.rejects(
    () => fulfillPaidPurchase(purchase, dependencies),
    /database transaction failed/,
  );
  assert.equal(emailCalls, 0);
  assert.equal(processorCalls, 0);
});
