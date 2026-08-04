import { NextResponse } from "next/server";
import { ZodError } from "zod";

import { parseAppTelemetryPayload } from "@/lib/app-telemetry-contract";
import { recordAppUsageEvent } from "@/lib/app-usage-store";
import {
  enforceIngestRateLimit,
  IngestRequestError,
  ingestJsonResponse,
  isAllowedIngestRequest,
  readBoundedJson,
} from "@/lib/ingest-request";

const MAX_REQUEST_BODY_BYTES = 4 * 1024;

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
    const payload = parseAppTelemetryPayload(
      await readBoundedJson(request, MAX_REQUEST_BODY_BYTES),
    );
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
