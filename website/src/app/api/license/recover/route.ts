import { randomUUID } from "node:crypto";
import { ZodError } from "zod";

import {
  licenseApiErrorResponse,
  licenseJson,
  readBoundedJson,
} from "@/lib/license-api";
import {
  genericRecoveryResponse,
  recoverLicenseSchema,
} from "@/lib/license-lifecycle-contract";
import {
  enqueueLicenseEmail,
  findRecoverableLicenses,
  isLicenseLifecycleStoreConfigured,
} from "@/lib/license-lifecycle-store";
import { getLicenseLifecycleEnv, isCommerceLaunchEnabled } from "@/lib/env";
import { checkRateLimit, createFingerprint } from "@/lib/rate-limit";
import {
  enforceIngestRateLimit,
  getIngestClient,
} from "@/lib/ingest-request";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  if (!isCommerceLaunchEnabled()) {
    return licenseJson(
      {
        ok: false,
        code: "commerce_disabled",
        message: "License recovery is unavailable during this beta.",
      },
      503,
    );
  }

  const sharedRateLimit = await enforceIngestRateLimit(
    request,
    "license-recovery",
  );
  if (!sharedRateLimit.allowed) {
    return licenseJson(
      { ...genericRecoveryResponse, requestId: randomUUID() },
      202,
    );
  }

  try {
    const payload = recoverLicenseSchema.parse(await readBoundedJson(request));
    const rateLimit = await checkRateLimit({
      email: payload.email,
      ip: getIngestClient(request).ip,
      userAgent: request.headers.get("user-agent") ?? "unknown",
    });
    if (!rateLimit.allowed) {
      return licenseJson(
        { ...genericRecoveryResponse, requestId: randomUUID() },
        202,
      );
    }

    const env = getLicenseLifecycleEnv();
    if (env.lookupPepper && isLicenseLifecycleStoreConfigured()) {
      const recoverable = await findRecoverableLicenses({
        email: payload.email,
        pepper: env.lookupPepper,
        requestFingerprint: rateLimit.fingerprint,
      });
      for (const license of recoverable) {
        await enqueueLicenseEmail({
          dedupeKey: `recovery:${license.order_identifier}:${createFingerprint(
            `${payload.email}:${new Date().toISOString().slice(0, 10)}`,
          )}`,
          kind: "license_recovery",
          recipientEmail: license.purchaser_email,
          payload: {
            licenseKey: license.license_token,
            productName: license.product_name,
            receiptUrl: license.receipt_url,
            orderIdentifier: license.order_identifier,
          },
        });
      }
    }

    return licenseJson(
      { ...genericRecoveryResponse, requestId: randomUUID() },
      202,
    );
  } catch (error) {
    if (error instanceof ZodError) {
      return licenseJson(
        { ok: false, code: "validation_error", message: "Enter a valid email address." },
        400,
      );
    }
    const response = licenseApiErrorResponse(error);
    console.error("[CmdTab Website] license recovery enqueue failed", error);
    // Do not disclose whether a purchase or database record exists.
    if (response.status >= 500) {
      return licenseJson(
        { ...genericRecoveryResponse, requestId: randomUUID() },
        202,
      );
    }
    return response;
  }
}
