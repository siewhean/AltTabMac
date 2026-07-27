import assert from "node:assert/strict";
import test from "node:test";

import {
  activateLicenseSchema,
  classifyOrderRefund,
  genericRecoveryResponse,
  issuePurchaseActivationCredential,
  lookupHash,
} from "../src/lib/license-lifecycle-contract.js";
import { requireAcceptedDelivery } from "../src/lib/license-delivery-result.js";
import {
  isExpectedLemonOrder,
  isPaidLemonOrderStatus,
} from "../src/lib/lemonsqueezy.js";

test("refund classification preserves partial refunds and revokes only full refunds", () => {
  assert.equal(
    classifyOrderRefund({ status: "partial_refund", refundedAmount: 300, total: 1200 }),
    "partial",
  );
  assert.equal(
    classifyOrderRefund({ status: "refunded", refundedAmount: 1200, total: 1200 }),
    "full",
  );
  assert.equal(
    classifyOrderRefund({ refunded: true, refundedAmount: 1200, total: 1200 }),
    "full",
  );
  assert.equal(
    classifyOrderRefund({ status: "paid", refundedAmount: 0, total: 1200 }),
    "none",
  );
});

test("lookup identifiers are deterministic, peppered, and domain separated", () => {
  const pepper = "a-production-secret-with-more-than-thirty-two-bytes";
  const first = lookupHash("license", "LIC-123", pepper);
  assert.equal(first, lookupHash("license", " lic-123 ", pepper));
  assert.notEqual(first, lookupHash("device", "LIC-123", pepper));
  assert.notEqual(first, lookupHash("license", "LIC-123", `${pepper}-rotated`));
  assert.match(first, /^[a-f0-9]{64}$/);
});

test("activation contract rejects raw or short hardware identifiers", () => {
  assert.throws(() =>
    activateLicenseSchema.parse({
      licenseKey: "CMDTAB1.short",
      deviceId: "IOPlatformUUID",
      deviceName: "My Mac",
    }),
  );
  assert.doesNotThrow(() =>
    activateLicenseSchema.parse({
      licenseKey: `CMDTAB1.${"a".repeat(32)}.${"b".repeat(64)}`,
      deviceId: "c".repeat(64),
      deviceName: "My Mac",
    }),
  );
});

test("recovery response contains no account-existence signal", () => {
  assert.deepEqual(Object.keys(genericRecoveryResponse).sort(), ["message", "ok"]);
  assert.match(genericRecoveryResponse.message, /^If a matching CmdTab purchase exists/);
});

test("new purchase credentials are opaque exchange secrets, not offline entitlements", () => {
  const first = issuePurchaseActivationCredential();
  const second = issuePurchaseActivationCredential();
  assert.match(first, /^CMDTAB-ACT-[A-Za-z0-9_-]{43}$/);
  assert.notEqual(first, second);
  assert.doesNotMatch(first, /^CMDTAB1\./);
  assert.doesNotMatch(first, /^CMDTAB2\./);
});

test("delivery provider error results fail closed so outbox retries", () => {
  assert.throws(
    () =>
      requireAcceptedDelivery({
        data: null,
        error: { message: "provider rejected request" },
      }),
    /provider rejected request/,
  );
  assert.equal(
    requireAcceptedDelivery({ data: { id: "email-123" }, error: null }),
    "email-123",
  );
});

test("Lemon order allowlist fails closed on missing mode or payment status", () => {
  const expected = {
    storeId: 10,
    productId: 20,
    variantId: 30,
    testMode: false,
  };
  const base = {
    meta: { event_name: "order_created" },
    data: {
      id: "1",
      type: "orders",
      attributes: {
        store_id: 10,
        status: "paid",
        test_mode: false,
        first_order_item: { product_id: 20, variant_id: 30 },
      },
    },
  };
  assert.equal(isExpectedLemonOrder(base, expected), true);
  assert.equal(
    isExpectedLemonOrder(
      {
        ...base,
        data: {
          ...base.data,
          attributes: { ...base.data.attributes, test_mode: undefined },
        },
      },
      expected,
    ),
    false,
  );
  assert.equal(isPaidLemonOrderStatus(base), true);
  assert.equal(
    isPaidLemonOrderStatus({
      ...base,
      data: {
        ...base.data,
        attributes: { ...base.data.attributes, status: undefined },
      },
    }),
    false,
  );
});
