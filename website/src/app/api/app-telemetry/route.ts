import { NextResponse } from "next/server";
import { z } from "zod";

import { recordAppUsageEvent } from "@/lib/app-usage-store";
import {
  checkEndpointRateLimit,
  readRequestBody,
  RequestBodyTooLargeError,
} from "@/lib/rate-limit";

const MAX_REQUEST_BODY_BYTES = 16 * 1024;

const payloadSchema = z.object({
  installId: z.string().trim().min(8).max(120),
  eventName: z.enum(["app_activation", "app_heartbeat", "license_activated", "trial_started"]),
  licenseState: z.enum(["unregistered", "trial_active", "trial_expired", "licensed"]),
  licenseId: z.string().trim().max(120).optional(),
  appVersion: z.string().trim().max(80).optional(),
  osVersion: z.string().trim().max(80).optional(),
  occurredAt: z.string().trim().max(80).optional(),
  metadata: z.record(z.string(), z.unknown()).optional(),
});

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function isJsonRequest(request: Request) {
  const mediaType = request.headers.get("content-type")?.split(";", 1)[0];
  return mediaType?.trim().toLowerCase() === "application/json";
}

function getClientIp(request: Request) {
  const realIp = request.headers.get("x-real-ip")?.trim();
  if (realIp) return realIp;

  const forwardedFor = request.headers.get("x-forwarded-for");
  if (request.headers.has("x-vercel-id") && forwardedFor) {
    return forwardedFor.split(",")[0]?.trim() ?? "unknown";
  }

  return "unknown";
}

export async function POST(request: Request) {
  if (!isJsonRequest(request)) {
    return new NextResponse(null, { status: 415 });
  }

  let body: unknown;
  try {
    const rawBody = await readRequestBody(request, MAX_REQUEST_BODY_BYTES);
    body = JSON.parse(rawBody) as unknown;
  } catch (error) {
    const status = error instanceof RequestBodyTooLargeError ? 413 : 400;
    return new NextResponse(null, { status });
  }

  const parsed = payloadSchema.safeParse(body);
  if (!parsed.success) {
    return new NextResponse(null, { status: 400 });
  }

  const payload = parsed.data;
  const ip = getClientIp(request);
  let rateLimit;
  try {
    rateLimit = await checkEndpointRateLimit({
      endpoint: "app-telemetry",
      identifiers: [
        `install:${payload.installId}`,
        ...(ip === "unknown" ? [] : [`ip:${ip}`]),
      ],
    });
  } catch (error) {
    console.error("[CmdTab Website] telemetry rate limit failed", error);
    return new NextResponse(null, { status: 503 });
  }

  if (!rateLimit.allowed) {
    return new NextResponse(null, {
      status: 204,
      headers: { "Retry-After": String(rateLimit.retryAfterSeconds) },
    });
  }

  try {
    await recordAppUsageEvent(payload);
    return new NextResponse(null, { status: 204 });
  } catch (error) {
    console.error("[CmdTab Website] app telemetry ingest failed", error);
    return new NextResponse(null, { status: 204 });
  }
}
