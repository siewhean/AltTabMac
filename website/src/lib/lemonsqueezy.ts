import { createHmac, timingSafeEqual } from "node:crypto";

export type LemonSqueezyOrderWebhook = {
  meta?: {
    event_name?: string;
    custom_data?: Record<string, unknown>;
  };
  data?: {
    id?: string;
    type?: string;
    attributes?: {
      store_id?: number;
      identifier?: string;
      order_number?: number;
      user_name?: string;
      user_email?: string;
      total?: number | string;
      total_formatted?: string;
      currency?: string;
      status?: string;
      refunded?: boolean | null;
      refunded_amount?: number | string | null;
      refunded_at?: string | null;
      created_at?: string;
      updated_at?: string;
      test_mode?: boolean;
      first_order_item?: {
        product_id?: number;
        variant_id?: number;
        product_name?: string;
        variant_name?: string;
      };
      urls?: {
        receipt?: string;
      };
    };
  };
};

export function verifyLemonSqueezySignature(input: {
  secret: string;
  rawBody: string;
  signatureHeader?: string | null;
}) {
  if (!input.signatureHeader) return false;

  const digest = createHmac("sha256", input.secret)
    .update(input.rawBody)
    .digest("hex");
  const expected = Buffer.from(digest, "utf8");
  const actual = Buffer.from(input.signatureHeader, "utf8");

  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

export function getOrderAttributes(payload: LemonSqueezyOrderWebhook) {
  return payload.data?.attributes;
}

export function isExpectedLemonOrder(
  payload: LemonSqueezyOrderWebhook,
  expected: {
    storeId: number;
    productId: number;
    variantId: number;
    testMode: boolean;
  },
) {
  const attributes = getOrderAttributes(payload);
  return (
    payload.data?.type === "orders" &&
    attributes?.store_id === expected.storeId &&
    attributes.first_order_item?.product_id === expected.productId &&
    attributes.first_order_item?.variant_id === expected.variantId &&
    typeof attributes.test_mode === "boolean" &&
    attributes.test_mode === expected.testMode
  );
}

export function isPaidLemonOrderStatus(
  payload: LemonSqueezyOrderWebhook,
) {
  return getOrderAttributes(payload)?.status === "paid";
}
