import { NextResponse } from "next/server";
import { z } from "zod";

import { recordSiteAnalyticsEvent } from "@/lib/site-analytics-store";
import {
  checkEndpointRateLimit,
  readRequestBody,
  RequestBodyTooLargeError,
} from "@/lib/rate-limit";

const MAX_REQUEST_BODY_BYTES = 16 * 1024;

const analyticsPayloadSchema = z.object({
  eventType: z.enum(["pageview", "event"]),
  eventName: z.string().trim().min(1).max(120).optional(),
  path: z.string().trim().min(1).max(300),
  referrer: z.string().trim().max(500).optional(),
  context: z.string().trim().max(160).optional(),
  visitorId: z.string().trim().max(80).optional(),
  sessionId: z.string().trim().max(80).optional(),
  occurredAt: z.string().trim().max(80).optional(),
  eventData: z.record(z.string(), z.unknown()).optional(),
}).strict();

function isAllowedOrigin(request: Request) {
  const origin = request.headers.get("origin");
  const host = request.headers.get("host");

  if (!origin || !host) return false;

  try {
    const originUrl = new URL(origin);
    return originUrl.host === host;
  } catch {
    return false;
  }
}

export async function POST(request: Request) {
  if (!isAllowedOrigin(request)) {
    return NextResponse.json({ error: "forbidden" }, { status: 403 });
  }

  let body: unknown;
  try {
    body = JSON.parse(await readRequestBody(request, MAX_REQUEST_BODY_BYTES));
  } catch (error) {
    return new NextResponse(null, {
      status: error instanceof RequestBodyTooLargeError ? 413 : 400,
    });
  }

  const parsed = analyticsPayloadSchema.safeParse(body);
  if (!parsed.success) return new NextResponse(null, { status: 400 });
  const payload = parsed.data;
  const forwarded = request.headers.has("x-vercel-id")
    ? request.headers.get("x-forwarded-for")?.split(",")[0]?.trim()
    : undefined;
  const identifiers = [
    payload.visitorId ? `visitor:${payload.visitorId}` : undefined,
    forwarded ? `ip:${forwarded}` : undefined,
  ].filter((value): value is string => Boolean(value));
  if (identifiers.length === 0) return new NextResponse(null, { status: 400 });

  try {
    const rateLimit = await checkEndpointRateLimit({ endpoint: "analytics", identifiers });
    if (!rateLimit.allowed) {
      return new NextResponse(null, {
        status: 429,
        headers: { "Retry-After": String(rateLimit.retryAfterSeconds) },
      });
    }

    if (payload.path.startsWith("/api/")) {
      return new NextResponse(null, { status: 204 });
    }

    await recordSiteAnalyticsEvent(payload);
    return new NextResponse(null, { status: 204 });
  } catch (error) {
    console.error("[CmdTab Website] analytics ingest failed", error);
    return new NextResponse(null, { status: 503 });
  }
}
