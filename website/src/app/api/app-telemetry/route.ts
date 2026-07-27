import { NextResponse } from "next/server";
import { z, ZodError } from "zod";

import { recordAppUsageEvent } from "@/lib/app-usage-store";
import {
  enforceIngestRateLimit,
  IngestRequestError,
  ingestJsonResponse,
  isAllowedIngestRequest,
  readBoundedJson,
} from "@/lib/ingest-request";

const MAX_REQUEST_BODY_BYTES = 4 * 1024;
const metadataValueSchema = z.union([
  z.string().max(160),
  z.number().finite(),
  z.boolean(),
  z.null(),
]);
const payloadSchema = z.object({
  installId: z.string().trim().min(8).max(120).regex(/^[A-Za-z0-9_-]+$/),
  eventName: z.enum(["app_activation", "app_heartbeat", "license_activated", "trial_started"]),
  licenseState: z.enum(["unregistered", "trial_active", "trial_expired", "licensed"]),
  licenseId: z
    .string()
    .trim()
    .min(1)
    .max(120)
    .regex(/^[A-Za-z0-9_-]+$/)
    .nullable()
    .optional()
    .transform((value) => value ?? undefined),
  appVersion: z.string().trim().min(1).max(40).regex(/^[A-Za-z0-9.+_-]+$/).optional(),
  osVersion: z.string().trim().min(1).max(40).regex(/^[A-Za-z0-9 .()_-]+$/).optional(),
  occurredAt: z.string().datetime({ offset: true }).optional(),
  metadata: z
    .record(z.string().min(1).max(40).regex(/^[A-Za-z][A-Za-z0-9_-]*$/), metadataValueSchema)
    .refine((value) => Object.keys(value).length <= 8, "metadata has too many properties")
    .optional(),
}).strict();

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  if (!isAllowedIngestRequest(request)) {
    return ingestJsonResponse({ ok: false, code: "forbidden" }, 403);
  }

  const rateLimit = await enforceIngestRateLimit(request, "app-telemetry");
  if (!rateLimit.allowed) {
    if ("unavailable" in rateLimit) {
      return ingestJsonResponse({ ok: false, code: "service_unavailable" }, 503);
    }
    return ingestJsonResponse(
      { ok: false, code: "rate_limited" },
      429,
      { "Retry-After": String(rateLimit.retryAfterSeconds) },
    );
  }

  try {
    const payload = payloadSchema.parse(await readBoundedJson(request, MAX_REQUEST_BODY_BYTES));
    await recordAppUsageEvent(payload);
    return new NextResponse(null, { status: 204 });
  } catch (error) {
    if (error instanceof IngestRequestError) {
      return ingestJsonResponse({ ok: false, code: error.code, message: error.message }, error.status);
    }
    if (error instanceof ZodError) {
      return ingestJsonResponse({ ok: false, code: "invalid_request" }, 400);
    }
    console.error("[CmdTab Website] app telemetry ingest failed", error);
    return ingestJsonResponse({ ok: false, code: "service_unavailable" }, 503);
  }
}
