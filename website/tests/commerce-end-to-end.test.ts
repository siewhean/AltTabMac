import assert from "node:assert/strict";
import { generateKeyPairSync } from "node:crypto";
import test from "node:test";

import { renderLicenseDeliveryEmail } from "../src/content/license-delivery-email.js";
import {
  verifyCmdTabTokenV2,
} from "../src/lib/entitlement-token.js";
import {
  issueCmdTabTokenV2,
  LocalPemP256Signer,
} from "../src/lib/license-signing.js";
import {
  fulfillPaidPurchase,
  type PaidPurchaseFulfillmentDependencies,
} from "../src/lib/purchase-fulfillment.js";

test("verified paid order flows through licence email to a device-bound offline entitlement", async () => {
  const orderIdentifier = "order-e2e-1001";
  const purchaserEmail = "buyer@example.com";
  const deviceIdentifier = "device-secret-from-keychain";
  let activeEntitlement = false;
  let deliveredEmail:
    | ReturnType<typeof renderLicenseDeliveryEmail>
    | undefined;
  let storedCredential = "";

  const dependencies: PaidPurchaseFulfillmentDependencies = {
    async createOrGetFulfillment(input) {
      storedCredential = input.licenseToken;
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
    async ensureActiveEntitlement() {
      activeEntitlement = true;
    },
    async enqueueLicenseEmail(input) {
      const licenseKey = input.payload.licenseKey;
      if (typeof licenseKey !== "string") {
        throw new TypeError("purchase email payload must contain a licence key");
      }
      deliveredEmail = renderLicenseDeliveryEmail({
        email: input.recipientEmail,
        name:
          typeof input.payload.name === "string"
            ? input.payload.name
            : undefined,
        licenseKey,
        productName:
          typeof input.payload.productName === "string"
            ? input.payload.productName
            : undefined,
        receiptUrl:
          typeof input.payload.receiptUrl === "string"
            ? input.payload.receiptUrl
            : undefined,
        orderNumber:
          typeof input.payload.orderNumber === "number"
            ? input.payload.orderNumber
            : undefined,
        siteUrl: "https://cmdtab.net",
        testMode: input.payload.testMode === true,
      });
    },
    async processLicenseOutbox() {
      return { claimed: 1, delivered: 1, failed: 0 };
    },
    reportInlineDeliveryFailure(error) {
      assert.fail(`unexpected delivery error: ${String(error)}`);
    },
  };

  const purchase = await fulfillPaidPurchase(
    {
      orderIdentifier,
      orderNumber: 1001,
      eventName: "order_created",
      purchaserEmail,
      purchaserName: "Test Buyer",
      productName: "CmdTab",
      receiptUrl: "https://example.com/receipt/1001",
      testMode: true,
      lookupPepper:
        "hermetic-commerce-e2e-pepper-with-at-least-thirty-two-characters",
    },
    dependencies,
  );

  assert.equal(purchase.kind, "queued");
  assert.equal(activeEntitlement, true);
  assert.match(storedCredential, /^CMDTAB-ACT-[A-Za-z0-9_-]{43}$/);
  assert.ok(deliveredEmail);
  assert.ok(deliveredEmail.text.includes(storedCredential));
  assert.ok(
    deliveredEmail.html.includes(
      `cmdtab://activate?code=${encodeURIComponent(storedCredential)}`,
    ),
  );

  const { privateKey, publicKey } = generateKeyPairSync("ec", {
    namedCurve: "prime256v1",
  });
  const signer = new LocalPemP256Signer(
    "license-e2e",
    privateKey.export({ format: "pem", type: "pkcs8" }).toString(),
  );
  const entitlement = await issueCmdTabTokenV2({
    signer,
    typ: "license",
    subjectIdentifier: purchaserEmail,
    orderIdentifier,
    binding: { typ: "activation", value: deviceIdentifier },
    issuedAt: new Date("2026-07-28T00:00:00Z"),
  });
  const keyring = {
    [signer.kid]: publicKey.export({ format: "der", type: "spki" }),
  };

  const verified = verifyCmdTabTokenV2({
    token: entitlement.token,
    keyring,
    expectedType: "license",
    expectedBinding: { typ: "activation", value: deviceIdentifier },
    now: new Date("2036-07-28T00:00:00Z"),
  });

  assert.equal(verified?.tokenVersion, 2);
  assert.equal(verified?.kind, "license");
  assert.equal(entitlement.payload.exp, undefined);
  assert.equal(
    verifyCmdTabTokenV2({
      token: entitlement.token,
      keyring,
      expectedType: "license",
      expectedBinding: {
        typ: "activation",
        value: "a-different-device",
      },
    }),
    null,
  );
});
