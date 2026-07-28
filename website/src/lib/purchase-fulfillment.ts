import {
  issuePurchaseActivationCredential,
  lookupHash,
} from "@/lib/license-lifecycle-contract";

export type PaidPurchaseInput = {
  orderIdentifier: string;
  orderNumber?: number;
  eventName: string;
  purchaserEmail: string;
  purchaserName?: string;
  productName?: string;
  variantName?: string;
  receiptUrl?: string;
  currency?: string;
  total?: string;
  totalFormatted?: string;
  storeId?: number;
  lemonsqueezyOrderId?: string;
  testMode: boolean;
  lookupPepper: string;
};

export type StoredPaidPurchase = {
  orderIdentifier: string;
  orderNumber?: number;
  purchaserEmail: string;
  purchaserName?: string;
  productName?: string;
  receiptUrl?: string;
  licenseId: string;
  licenseToken: string;
  deliveryStatus: "stored" | "delivered" | "failed" | "refunded";
  testMode: boolean;
};

export type PurchaseDeliverySummary = {
  claimed: number;
  delivered: number;
  failed: number;
};

export type PaidPurchaseFulfillmentDependencies = {
  createOrGetFulfillment(input: {
    orderIdentifier: string;
    orderLookupHash: string;
    orderNumber?: number;
    eventName: string;
    purchaserEmail: string;
    purchaserName?: string;
    productName?: string;
    variantName?: string;
    receiptUrl?: string;
    currency?: string;
    total?: string;
    totalFormatted?: string;
    storeId?: number;
    lemonsqueezyOrderId?: string;
    licenseId: string;
    licenseLookupHash: string;
    emailLookupHash: string;
    activationCredentialHash: string;
    licenseToken: string;
    testMode: boolean;
  }): Promise<StoredPaidPurchase>;
  ensureActiveEntitlement(input: {
    licenseId: string;
    orderIdentifier: string;
    pepper: string;
  }): Promise<void>;
  enqueueLicenseEmail(input: {
    dedupeKey: string;
    kind: "license_delivery";
    recipientEmail: string;
    payload: Record<string, unknown>;
  }): Promise<unknown>;
  processLicenseOutbox(limit: number): Promise<PurchaseDeliverySummary>;
  reportInlineDeliveryFailure(error: unknown): void;
};

export type PaidPurchaseFulfillmentResult =
  | {
      kind: "duplicate";
      orderIdentifier: string;
    }
  | {
      kind: "queued";
      orderIdentifier: string;
      delivery: PurchaseDeliverySummary;
    };

/**
 * Runs the paid-order path after the webhook signature, offer allowlist, and
 * payment status have already been verified. The injected side effects keep
 * the full orchestration hermetically testable while production still uses the
 * PostgreSQL fulfilment store, entitlement store, persistent outbox, and
 * Resend worker.
 */
export async function fulfillPaidPurchase(
  input: PaidPurchaseInput,
  dependencies: PaidPurchaseFulfillmentDependencies,
): Promise<PaidPurchaseFulfillmentResult> {
  // The purchase email carries an opaque exchange credential. It cannot grant
  // offline access until the activation route exchanges it for a device-bound
  // signed entitlement.
  const activationCredential = issuePurchaseActivationCredential();
  const fulfillment = await dependencies.createOrGetFulfillment({
    orderIdentifier: input.orderIdentifier,
    orderLookupHash: lookupHash(
      "order",
      input.orderIdentifier,
      input.lookupPepper,
    ),
    orderNumber: input.orderNumber,
    eventName: input.eventName,
    purchaserEmail: input.purchaserEmail,
    purchaserName: input.purchaserName,
    productName: input.productName,
    variantName: input.variantName,
    receiptUrl: input.receiptUrl,
    currency: input.currency,
    total: input.total,
    totalFormatted: input.totalFormatted,
    storeId: input.storeId,
    lemonsqueezyOrderId: input.lemonsqueezyOrderId,
    licenseId: input.orderIdentifier,
    licenseLookupHash: lookupHash(
      "license",
      input.orderIdentifier,
      input.lookupPepper,
    ),
    emailLookupHash: lookupHash(
      "email",
      input.purchaserEmail,
      input.lookupPepper,
    ),
    activationCredentialHash: lookupHash(
      "license",
      activationCredential,
      input.lookupPepper,
    ),
    licenseToken: activationCredential,
    testMode: input.testMode,
  });

  await dependencies.ensureActiveEntitlement({
    licenseId: fulfillment.licenseId,
    orderIdentifier: fulfillment.orderIdentifier,
    pepper: input.lookupPepper,
  });

  if (fulfillment.deliveryStatus === "delivered") {
    return {
      kind: "duplicate",
      orderIdentifier: fulfillment.orderIdentifier,
    };
  }

  await dependencies.enqueueLicenseEmail({
    dedupeKey: `purchase:${fulfillment.orderIdentifier}`,
    kind: "license_delivery",
    recipientEmail: fulfillment.purchaserEmail,
    payload: {
      orderIdentifier: fulfillment.orderIdentifier,
      licenseKey: fulfillment.licenseToken,
      productName: fulfillment.productName,
      receiptUrl: fulfillment.receiptUrl,
      orderNumber: fulfillment.orderNumber,
      testMode: fulfillment.testMode,
      name: fulfillment.purchaserName,
    },
  });

  let delivery: PurchaseDeliverySummary;
  try {
    delivery = await dependencies.processLicenseOutbox(1);
  } catch (error) {
    dependencies.reportInlineDeliveryFailure(error);
    delivery = { claimed: 0, delivered: 0, failed: 1 };
  }

  return {
    kind: "queued",
    orderIdentifier: fulfillment.orderIdentifier,
    delivery,
  };
}
