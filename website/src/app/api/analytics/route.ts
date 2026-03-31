import { NextResponse } from "next/server";
import { z } from "zod";

import { recordSiteAnalyticsEvent } from "@/lib/site-analytics-store";

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
});

function isAllowedOrigin(request: Request) {
  const origin = request.headers.get("origin");
  const host = request.headers.get("host");

  if (!origin || !host) return true;

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

  try {
    const body = await request.json();
    const payload = analyticsPayloadSchema.parse(body);

    if (payload.path.startsWith("/api/")) {
      return new NextResponse(null, { status: 204 });
    }

    await recordSiteAnalyticsEvent(payload);
    return new NextResponse(null, { status: 204 });
  } catch (error) {
    console.error("[CmdTab Website] analytics ingest failed", error);
    return new NextResponse(null, { status: 204 });
  }
}
