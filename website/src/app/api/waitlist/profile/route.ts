import { randomUUID } from "node:crypto";

import { NextResponse } from "next/server";
import { z } from "zod";

import { getClientIp } from "@/lib/client-ip";
import { readBoundedJson } from "@/lib/ingest-request";
import { verifyWaitlistProfileToken } from "@/lib/waitlist-confirm";
import { waitlistUnsubscribeSecret } from "@/lib/waitlist-unsubscribe";
import { checkRateLimit } from "@/lib/rate-limit";
import {
  isWaitlistStoreConfigured,
  setWaitlistUseCaseByEmail,
  WAITLIST_USE_CASES,
} from "@/lib/waitlist-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// One optional answer ("what will you use it for?") for the address a visitor
// just typed. The signed token from the signup response is the only credential
// and authorizes this single write; the answer never reveals whether the
// address exists, and only one enumerated value is accepted.

const bodySchema = z
  .object({
    token: z.string().min(10).max(700),
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
    const body = bodySchema.parse(await readBoundedJson(request, 1024));
    const secret = waitlistUnsubscribeSecret();
    const email = secret ? verifyWaitlistProfileToken(body.token, secret) : null;
    if (!email) {
      return NextResponse.json({ ok: false, code: "validation_error", requestId }, { status: 400, headers: HEADERS });
    }
    const limit = await checkRateLimit({
      email,
      ip: getClientIp(request),
      userAgent: request.headers.get("user-agent")?.trim() ?? "unknown",
    });
    if (!limit.allowed) {
      return NextResponse.json({ ok: false, code: "rate_limited", requestId }, { status: 429, headers: HEADERS });
    }
    if (!isWaitlistStoreConfigured()) {
      return NextResponse.json({ ok: false, code: "service_unavailable", requestId }, { status: 503, headers: HEADERS });
    }
    await setWaitlistUseCaseByEmail(email, body.useCase);
    // Same answer whether or not the address exists.
    return NextResponse.json({ ok: true, requestId }, { headers: HEADERS });
  } catch {
    return NextResponse.json({ ok: false, code: "validation_error", requestId }, { status: 400, headers: HEADERS });
  }
}

export async function GET() {
  return NextResponse.json({ ok: false, code: "method_not_allowed" }, { status: 405, headers: { ...HEADERS, Allow: "POST" } });
}
