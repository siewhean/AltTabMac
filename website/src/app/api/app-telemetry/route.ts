import { NextResponse } from "next/server";
import { z } from "zod";

import { recordAppUsageEvent } from "@/lib/app-usage-store";

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

export async function POST(request: Request) {
  try {
    const payload = payloadSchema.parse(await request.json());
    await recordAppUsageEvent(payload);
    return new NextResponse(null, { status: 204 });
  } catch (error) {
    console.error("[CmdTab Website] app telemetry ingest failed", error);
    return new NextResponse(null, { status: 204 });
  }
}
