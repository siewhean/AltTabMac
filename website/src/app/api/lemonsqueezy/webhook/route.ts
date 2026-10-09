import { randomUUID } from "node:crypto";

import { NextResponse } from "next/server";

import { getServerEnv, isCommerceLaunchEnabled } from "@/lib/env";
import {
  IngestRequestError,
  readBoundedText,
} from "@/lib/ingest-request";
import {
  findLicenseFulfillmentByOrder,
  markLicenseFulfillmentRefunded,
} from "@/lib/license-fulfillment-store";
import { classifyOrderRefund } from "@/lib/license-lifecycle-contract";
import { recordOrderAccessState } from "@/lib/license-lifecycle-store";
import {
  getOrderAttributes,
  isExpectedLemonOrder,
  isPaidLemonOrderStatus,
  type LemonSqueezyOrderWebhook,
  verifyLemonSqueezySignature,
} from "@/lib/lemonsqueezy";
import { fulfillPaidPurchase } from "@/lib/purchase-fulfillment";
import { createOrGetLicenseFulfillment } from "@/lib/license-fulfillment-store";
import {
  enqueueLicenseEmail,
  ensureActiveEntitlement,
} from "@/lib/license-lifecycle-store";
import { processLicenseOutbox } from "@/lib/license-outbox";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
const MAX_WEBHOOK_BODY_BYTES = 256 * 1024;

function json(body: Record<string, unknown>, status = 200) {
  return NextResponse.json(body, {
    status,
    headers: {
      "Cache-Control": "no-store, max-age=0",
    },
  });
}

export async function POST(request: Request) {
  const requestId = randomUUID();

  if (!isCommerceLaunchEnabled()) {
    return json(
      {
        ok: false,
        code: "commerce_disabled",
        message: "Commerce webhook fulfillment is not enabled.",
        requestId,
      },
      503,
    );
  }

  const env = getServerEnv();

  if (
    !env.lemonsqueezyWebhookSecret ||
    !env.licenseLookupPepper ||
    !env.lemonsqueezyStoreId ||
    !env.lemonsqueezyProductId ||
    !env.lemonsqueezyVariantId ||
    env.lemonsqueezyExpectedTestMode === undefined
  ) {
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

  let rawBody: string;
  try {
    rawBody = await readBoundedText(request, MAX_WEBHOOK_BODY_BYTES);
  } catch (error) {
    if (error instanceof IngestRequestError) {
      return json(
        { ok: false, code: error.code, message: error.message, requestId },
        error.status,
      );
    }
    throw error;
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
  const isExpectedOffer = isExpectedLemonOrder(payload, {
    storeId: env.lemonsqueezyStoreId,
    productId: env.lemonsqueezyProductId,
    variantId: env.lemonsqueezyVariantId,
    testMode: env.lemonsqueezyExpectedTestMode,
  });

  if (!isExpectedOffer) {
    return json({
      ok: true,
      handled: false,
      eventName,
      reason: "unrecognized_offer",
      requestId,
    });
  }

  if (
    eventName === "order_refunded" &&
    attributes?.identifier
  ) {
    const existingFulfillment = await findLicenseFulfillmentByOrder(
      attributes.identifier,
    );
    const classification = classifyOrderRefund({
      status: attributes.status,
      refunded: attributes.refunded,
      refundedAmount: attributes.refunded_amount,
      total: attributes.total,
    });
    if (classification === "partial") {
      await recordOrderAccessState({
        orderIdentifier: attributes.identifier,
        licenseId: existingFulfillment?.licenseId,
        pepper: env.licenseLookupPepper,
        state: "partial_refund",
        reason: "partial_refund",
        refundedAmount: Number(attributes.refunded_amount ?? 0),
        total: Number(attributes.total ?? 0),
      });
    } else if (classification === "full") {
      await recordOrderAccessState({
        orderIdentifier: attributes.identifier,
        licenseId: existingFulfillment?.licenseId,
        pepper: env.licenseLookupPepper,
        state: "revoked",
        reason: "full_refund",
        refundedAmount: Number(attributes.refunded_amount ?? attributes.total ?? 0),
        total: Number(attributes.total ?? 0),
      });
      await markLicenseFulfillmentRefunded(attributes.identifier);
    }
    return json({
      ok: true,
      handled: classification !== "none",
      eventName,
      refund: classification,
      requestId,
    });
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

  if (!isPaidLemonOrderStatus(payload)) {
    return json({ ok: true, handled: false, eventName, requestId, status: attributes.status });
  }

  const result = await fulfillPaidPurchase(
    {
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
      testMode: Boolean(attributes.test_mode),
      lookupPepper: env.licenseLookupPepper,
    },
    {
      createOrGetFulfillment: createOrGetLicenseFulfillment,
      ensureActiveEntitlement,
      enqueueLicenseEmail,
      processLicenseOutbox,
      reportInlineDeliveryFailure(error) {
        console.error("[CmdTab Website] inline fulfillment attempt failed", error);
      },
    },
  );

  if (result.kind === "duplicate") {
    return json({
      ok: true,
      handled: true,
      duplicate: true,
      orderIdentifier: result.orderIdentifier,
      requestId,
    });
  }

  return json({
    ok: true,
    handled: true,
    deliveryQueued: true,
    delivery: result.delivery,
    orderIdentifier: result.orderIdentifier,
    requestId,
  });
}
