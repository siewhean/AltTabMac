import { randomUUID } from "node:crypto";
import { ZodError } from "zod";

import {
  LicenseApiError,
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
  rotateActivationCredential,
} from "@/lib/license-lifecycle-store";
import { getLicenseLifecycleEnv } from "@/lib/env";
import { checkRateLimit } from "@/lib/rate-limit";
import {
  enforceIngestRateLimit,
  getIngestClient,
} from "@/lib/ingest-request";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
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
        const rotated = await rotateActivationCredential({
          orderIdentifier: license.order_identifier,
          pepper: env.lookupPepper,
        });
        await enqueueLicenseEmail({
          dedupeKey: `recovery:${license.order_identifier}:${rotated.generation}`,
          kind: "license_recovery",
          recipientEmail: license.purchaser_email,
          payload: {
            licenseKey: rotated.credential,
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
    // Malformed request bodies are rejected before any lookup, so their
    // errors cannot depend on whether a purchase exists.
    if (error instanceof LicenseApiError && error.status < 500) {
      return licenseApiErrorResponse(error);
    }
    console.error("[CmdTab Website] license recovery enqueue failed", error);
    // Store failures can occur only after a purchase was found (credential
    // rotation, outbox enqueue), so answer generically: do not disclose
    // whether a purchase or database record exists.
    return licenseJson(
      { ...genericRecoveryResponse, requestId: randomUUID() },
      202,
    );
  }
}
