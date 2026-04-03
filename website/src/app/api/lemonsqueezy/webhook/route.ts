import { randomUUID } from "node:crypto";

import { NextResponse } from "next/server";

import { renderLicenseDeliveryEmail } from "@/content/license-delivery-email";
import { getSiteUrl, getServerEnv } from "@/lib/env";
import {
  createOrGetLicenseFulfillment,
  markLicenseFulfillmentRefunded,
  updateLicenseFulfillmentDeliveryStatus,
} from "@/lib/license-fulfillment-store";
import { issueCmdTabLicenseToken } from "@/lib/license-token";
import { getOrderAttributes, type LemonSqueezyOrderWebhook, verifyLemonSqueezySignature } from "@/lib/lemonsqueezy";
import { getResendClient } from "@/lib/resend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

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

  return resend.emails.send({
    from: env.licenseDeliveryFromEmail ?? env.waitlistFromEmail,
    to: input.email,
    replyTo: env.waitlistReplyToEmail,
    subject: message.subject,
    text: message.text,
    html: message.html,
  });
}

export async function POST(request: Request) {
  const requestId = randomUUID();
  const env = getServerEnv();

  if (!env.lemonsqueezyWebhookSecret || !env.cmdtabLicensePrivateKeyPem) {
    return json(
      {
        ok: false,
        code: "missing_configuration",
        message: "Webhook fulfillment is not configured.",
        requestId,
      },
      503,
    );
  }

  const rawBody = await request.text();
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

  if (eventName === "order_refunded" && attributes?.identifier) {
    await markLicenseFulfillmentRefunded(attributes.identifier);
    return json({ ok: true, handled: true, eventName, requestId });
  }

  if (eventName !== "order_created") {
    return json({ ok: true, handled: false, eventName, requestId });
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

  if (attributes.status && attributes.status !== "paid") {
    return json({ ok: true, handled: false, eventName, requestId, status: attributes.status });
  }

  const issued = issueCmdTabLicenseToken({
    privateKeyPem: env.cmdtabLicensePrivateKeyPem,
    email: attributes.user_email,
    purchaserName: attributes.user_name,
    licenseID: attributes.identifier,
    issuedAt: attributes.created_at,
  });

  const fulfillment = await createOrGetLicenseFulfillment({
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

  if (fulfillment.deliveryStatus === "delivered") {
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
    });
    await updateLicenseFulfillmentDeliveryStatus(fulfillment.orderIdentifier, "delivered");
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown fulfillment error";
    await updateLicenseFulfillmentDeliveryStatus(fulfillment.orderIdentifier, "failed", message);
    return json(
      {
        ok: false,
        code: "delivery_failed",
        message,
        orderIdentifier: fulfillment.orderIdentifier,
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
