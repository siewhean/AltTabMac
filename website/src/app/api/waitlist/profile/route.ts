import { randomUUID } from "node:crypto";

import { NextResponse } from "next/server";
import { z } from "zod";

import { getClientIp } from "@/lib/client-ip";
import { readBoundedJson } from "@/lib/ingest-request";
import { checkRateLimit } from "@/lib/rate-limit";
import {
  isWaitlistStoreConfigured,
  setWaitlistUseCase,
  WAITLIST_USE_CASES,
} from "@/lib/waitlist-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// One optional answer ("what will you use it for?") saved against the signup's
// own invite code. The code is the only credential, so the endpoint reveals
// nothing about whether a code exists and accepts a single enumerated value.

const bodySchema = z
  .object({
    code: z.string().trim().toLowerCase().regex(/^[a-z0-9]{6,12}$/),
    useCase: z.enum(WAITLIST_USE_CASES),
  })
  .strict();

const HEADERS = {
  "Cache-Control": "no-store, max-age=0",
  "X-Content-Type-Options": "nosniff",
};

function sameOrigin(request: Request) {
  const origin = request.headers.get("origin");
  if (!origin) return false;
  return origin === new URL(request.url).origin;
}

export async function POST(request: Request) {
  const requestId = randomUUID();
  if (!sameOrigin(request)) {
    return NextResponse.json({ ok: false, code: "validation_error", requestId }, { status: 403, headers: HEADERS });
  }
  if (!(request.headers.get("content-type") ?? "").includes("application/json")) {
    return NextResponse.json({ ok: false, code: "validation_error", requestId }, { status: 415, headers: HEADERS });
  }

  try {
    const body = bodySchema.parse(await readBoundedJson(request, 512));
    const limit = await checkRateLimit({
      email: body.code,
      ip: getClientIp(request),
      userAgent: request.headers.get("user-agent")?.trim() ?? "unknown",
    });
    if (!limit.allowed) {
      return NextResponse.json({ ok: false, code: "rate_limited", requestId }, { status: 429, headers: HEADERS });
    }
    if (!isWaitlistStoreConfigured()) {
      return NextResponse.json({ ok: false, code: "service_unavailable", requestId }, { status: 503, headers: HEADERS });
    }
    await setWaitlistUseCase(body.code, body.useCase);
    // Same answer whether or not the code exists.
    return NextResponse.json({ ok: true, requestId }, { headers: HEADERS });
  } catch {
    return NextResponse.json({ ok: false, code: "validation_error", requestId }, { status: 400, headers: HEADERS });
  }
}

export async function GET() {
  return NextResponse.json({ ok: false, code: "method_not_allowed" }, { status: 405, headers: { ...HEADERS, Allow: "POST" } });
}
