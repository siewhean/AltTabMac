import { createHash, randomUUID } from "node:crypto";

import { NextResponse } from "next/server";

import { renderLicenseDeliveryEmail } from "@/content/license-delivery-email";
import { getSiteUrl, getServerEnv } from "@/lib/env";
import {
  claimLicenseFulfillment,
  markLicenseFulfillmentRefunded,
  updateLicenseFulfillmentDeliveryStatus,
} from "@/lib/license-fulfillment-store";
import { issueCmdTabLicenseToken } from "@/lib/license-token";
import { getOrderAttributes, type LemonSqueezyOrderWebhook, verifyLemonSqueezySignature } from "@/lib/lemonsqueezy";
import { readRequestBody, RequestBodyTooLargeError } from "@/lib/rate-limit";
import { getResendClient } from "@/lib/resend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const MAX_REQUEST_BODY_BYTES = 256 * 1024;

function allowedNumericIDs(name: string) {
  return new Set(
    (process.env[name] ?? "")
      .split(",")
      .map((value) => Number.parseInt(value.trim(), 10))
      .filter(Number.isSafeInteger),
  );
}

function isConfiguredCmdTabProduct(attributes: NonNullable<ReturnType<typeof getOrderAttributes>>) {
  const stores = allowedNumericIDs("LEMONSQUEEZY_ALLOWED_STORE_IDS");
  const products = allowedNumericIDs("LEMONSQUEEZY_ALLOWED_PRODUCT_IDS");
  const variants = allowedNumericIDs("LEMONSQUEEZY_ALLOWED_VARIANT_IDS");
  if (stores.size === 0 || (products.size === 0 && variants.size === 0)) return null;
  const item = attributes.first_order_item;
  const productAllowed = products.size === 0 || Boolean(item?.product_id && products.has(item.product_id));
  const variantAllowed = variants.size === 0 || Boolean(item?.variant_id && variants.has(item.variant_id));
  return Boolean(
    attributes.store_id &&
    stores.has(attributes.store_id) &&
    productAllowed &&
    variantAllowed,
  );
}

function json(body: Record<string, unknown>, status = 200) {
  return NextResponse.json(body, {
    status,
    headers: {
      "Cache-Control": "no-store, max-age=0",
    },
  });
}

async function sendLicenseEmail(input: {
  email: string;
  name?: string;
  licenseKey: string;
  productName?: string;
  receiptUrl?: string;
  orderNumber?: number;
  testMode: boolean;
  idempotencyKey: string;
}) {
  const env = getServerEnv();
  const resend = getResendClient(env.resendApiKey);
  const message = renderLicenseDeliveryEmail({
    email: input.email,
    name: input.name,
    licenseKey: input.licenseKey,
    productName: input.productName,
    receiptUrl: input.receiptUrl,
    orderNumber: input.orderNumber,
    siteUrl: getSiteUrl(),
    testMode: input.testMode,
  });

  const result = await resend.emails.send(
    {
      from: env.licenseDeliveryFromEmail ?? env.waitlistFromEmail,
      to: input.email,
      replyTo: env.waitlistReplyToEmail,
      subject: message.subject,
      text: message.text,
      html: message.html,
    },
    { idempotencyKey: input.idempotencyKey },
  );
  if (result.error) {
    throw new Error(`Resend rejected license delivery: ${result.error.message}`);
  }
  return result;
}

function isJsonRequest(request: Request) {
  const mediaType = request.headers.get("content-type")?.split(";", 1)[0];
  return mediaType?.trim().toLowerCase() === "application/json";
}

async function handleWebhook(request: Request, requestId: string) {
  if (!isJsonRequest(request)) {
    return json(
      {
        ok: false,
        code: "unsupported_media_type",
        message: "Content-Type must be application/json.",
        requestId,
      },
      415,
    );
  }

  let rawBody: string;
  try {
    rawBody = await readRequestBody(request, MAX_REQUEST_BODY_BYTES);
  } catch (error) {
    if (error instanceof RequestBodyTooLargeError) {
      return json(
        {
          ok: false,
          code: "payload_too_large",
          message: "Webhook payload is too large.",
          requestId,
        },
        413,
      );
    }
    throw error;
  }

  const env = getServerEnv();

  if (!env.lemonsqueezyWebhookSecret || !env.cmdtabLicensePrivateKeyPem) {
    return json(
      {
        ok: false,
        code: "service_unavailable",
        message: "Webhook fulfillment is temporarily unavailable.",
        requestId,
      },
      503,
    );
  }

  const valid = verifyLemonSqueezySignature({
    secret: env.lemonsqueezyWebhookSecret,
    rawBody,
    signatureHeader: request.headers.get("x-signature"),
  });

  if (!valid) {
    return json(
      {
        ok: false,
        code: "invalid_signature",
        message: "Invalid webhook signature.",
        requestId,
      },
      401,
    );
  }

  let payload: LemonSqueezyOrderWebhook;
  try {
    payload = JSON.parse(rawBody) as LemonSqueezyOrderWebhook;
  } catch {
    return json(
      {
        ok: false,
        code: "invalid_json",
        message: "Webhook payload is not valid JSON.",
        requestId,
      },
      400,
    );
  }

  const eventName = payload.meta?.event_name ?? "unknown";
  const attributes = getOrderAttributes(payload);

  if (eventName !== "order_created" && eventName !== "order_refunded") {
    return json({ ok: true, handled: false, eventName, requestId });
  }

  if (!attributes) {
    return json({ ok: false, code: "invalid_payload", requestId }, 400);
  }

  const configuredProduct = isConfiguredCmdTabProduct(attributes);
  if (configuredProduct === null) {
    return json({ ok: false, code: "service_unavailable", requestId }, 503);
  }
  if (!configuredProduct || attributes.test_mode) {
    return json({ ok: true, handled: false, eventName, requestId });
  }

  if (eventName === "order_refunded" && attributes.identifier) {
    await markLicenseFulfillmentRefunded(attributes.identifier);
    return json({ ok: true, handled: true, eventName, requestId });
  }

  if (!attributes?.identifier || !attributes.user_email) {
    return json(
      {
        ok: false,
        code: "invalid_payload",
        message: "Order payload is missing the required order or email fields.",
        requestId,
      },
      400,
    );
  }

  if (attributes.status !== "paid") {
    return json({ ok: true, handled: false, eventName, requestId, status: attributes.status });
  }

  const issued = issueCmdTabLicenseToken({
    privateKeyPem: env.cmdtabLicensePrivateKeyPem,
    email: attributes.user_email,
    purchaserName: attributes.user_name,
    licenseID: attributes.identifier,
    issuedAt: attributes.created_at,
  });

  const claim = await claimLicenseFulfillment({
    orderIdentifier: attributes.identifier,
    orderNumber: attributes.order_number,
    eventName,
    purchaserEmail: attributes.user_email,
    purchaserName: attributes.user_name,
    productName: attributes.first_order_item?.product_name,
    variantName: attributes.first_order_item?.variant_name,
    receiptUrl: attributes.urls?.receipt,
    currency: attributes.currency,
    total: attributes.total ? String(attributes.total) : undefined,
    totalFormatted: attributes.total_formatted,
    storeId: attributes.store_id,
    lemonsqueezyOrderId: payload.data?.id,
    licenseId: issued.payload.licenseID,
    licenseToken: issued.token,
    testMode: Boolean(attributes.test_mode),
  });
  const fulfillment = claim.fulfillment;

  if (!claim.acquired) {
    return json({
      ok: true,
      handled: true,
      duplicate: true,
      orderIdentifier: fulfillment.orderIdentifier,
      requestId,
    });
  }

  try {
    await sendLicenseEmail({
      email: fulfillment.purchaserEmail,
      name: fulfillment.purchaserName,
      licenseKey: fulfillment.licenseToken,
      productName: fulfillment.productName,
      receiptUrl: fulfillment.receiptUrl,
      orderNumber: fulfillment.orderNumber,
      testMode: fulfillment.testMode,
      idempotencyKey: `cmdtab-license/${
        fulfillment.orderHash ?? createHash("sha256").update(fulfillment.orderIdentifier).digest("hex")
      }`,
    });
    const delivered = await updateLicenseFulfillmentDeliveryStatus(
      fulfillment.orderIdentifier,
      claim.processingToken,
      "delivered",
    );
    if (!delivered) {
      return json({
        ok: true,
        handled: true,
        superseded: true,
        orderIdentifier: fulfillment.orderIdentifier,
        requestId,
      });
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown fulfillment error";
    await updateLicenseFulfillmentDeliveryStatus(
      fulfillment.orderIdentifier,
      claim.processingToken,
      "failed",
      message,
    );
    console.error("[CmdTab Website] webhook delivery failed", { requestId, error });
    return json(
      {
        ok: false,
        code: "delivery_failed",
        message: "License delivery is temporarily unavailable.",
        requestId,
      },
      502,
    );
  }

  return json({
    ok: true,
    handled: true,
    orderIdentifier: fulfillment.orderIdentifier,
    requestId,
  });
}

export async function POST(request: Request) {
  const requestId = randomUUID();

  try {
    return await handleWebhook(request, requestId);
  } catch (error) {
    console.error("[CmdTab Website] webhook processing failed", { requestId, error });
    return json(
      {
        ok: false,
        code: "processing_failed",
        message: "Webhook processing failed.",
        requestId,
      },
      500,
    );
  }
}
