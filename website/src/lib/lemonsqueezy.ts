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
      created_at?: string;
      updated_at?: string;
      test_mode?: boolean;
      first_order_item?: {
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
