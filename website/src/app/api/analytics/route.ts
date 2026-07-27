import { NextResponse } from "next/server";
import { z, ZodError } from "zod";

import {
  enforceIngestRateLimit,
  IngestRequestError,
  ingestJsonResponse,
  isAllowedIngestRequest,
  readBoundedJson,
} from "@/lib/ingest-request";
import { recordSiteAnalyticsEvent } from "@/lib/site-analytics-store";

const MAX_REQUEST_BODY_BYTES = 8 * 1024;
const identifierSchema = z.string().trim().min(8).max(80).regex(/^[A-Za-z0-9_-]+$/);
const analyticsValueSchema = z.union([
  z.string().max(160),
  z.number().finite(),
  z.boolean(),
  z.null(),
]);
const eventDataSchema = z
  .record(z.string().min(1).max(40).regex(/^[A-Za-z][A-Za-z0-9_-]*$/), analyticsValueSchema)
  .refine((value) => Object.keys(value).length <= 12, "eventData has too many properties");
const sharedFields = {
  path: z.string().trim().min(1).max(300).regex(/^\/(?!\/)/),
  referrer: z.string().trim().url().max(500).optional(),
  visitorId: identifierSchema.optional(),
  sessionId: identifierSchema.optional(),
  occurredAt: z.string().datetime({ offset: true }).optional(),
  eventData: eventDataSchema.optional(),
};
const analyticsPayloadSchema = z.discriminatedUnion("eventType", [
  z.object({ eventType: z.literal("pageview"), ...sharedFields }).strict(),
  z
    .object({
      eventType: z.literal("event"),
      eventName: z.string().trim().min(1).max(120).regex(/^[A-Za-z0-9][A-Za-z0-9_.:-]*$/),
      context: z.string().trim().min(1).max(160).optional(),
      ...sharedFields,
    })
    .strict(),
]);

export async function POST(request: Request) {
  if (!isAllowedIngestRequest(request)) {
    return ingestJsonResponse({ ok: false, code: "forbidden" }, 403);
  }

  const rateLimit = await enforceIngestRateLimit(request, "analytics");
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
    const body = await readBoundedJson(request, MAX_REQUEST_BODY_BYTES);
    const payload = analyticsPayloadSchema.parse(body);

    if (payload.path.startsWith("/api/")) {
      return ingestJsonResponse({ ok: false, code: "invalid_request" }, 400);
    }

    await recordSiteAnalyticsEvent(payload);
    return new NextResponse(null, { status: 204 });
  } catch (error) {
    if (error instanceof IngestRequestError) {
      return ingestJsonResponse({ ok: false, code: error.code, message: error.message }, error.status);
    }
    if (error instanceof ZodError) {
      return ingestJsonResponse({ ok: false, code: "invalid_request" }, 400);
    }
    console.error("[CmdTab Website] analytics ingest failed", error);
    return ingestJsonResponse({ ok: false, code: "service_unavailable" }, 503);
  }
}
