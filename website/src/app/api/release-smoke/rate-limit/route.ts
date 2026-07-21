import { NextResponse } from "next/server";

import { checkRateLimit } from "@/lib/rate-limit";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const noncePattern = /^[a-zA-Z0-9-]{16,80}$/;

export async function POST(request: Request) {
  if (process.env.VERCEL_ENV !== "preview") {
    return NextResponse.json({ ok: false, message: "Not found" }, { status: 404 });
  }
  const secret = process.env.HEALTHCHECK_SECRET?.trim();
  if (!secret || request.headers.get("authorization") !== `Bearer ${secret}`) {
    return NextResponse.json({ ok: false, message: "Unauthorized" }, { status: 401 });
  }

  let nonce = "";
  try {
    nonce = String((await request.json() as { nonce?: unknown }).nonce ?? "");
  } catch {
    return NextResponse.json({ ok: false, message: "Invalid request" }, { status: 400 });
  }
  if (!noncePattern.test(nonce)) {
    return NextResponse.json({ ok: false, message: "Invalid request" }, { status: 400 });
  }

  try {
    const decisions = [];
    for (let attempt = 0; attempt < 7; attempt += 1) {
      decisions.push(await checkRateLimit({ email: `release-smoke-${nonce}@invalid.example` }));
    }
    const allowedCount = decisions.filter((decision) => decision.allowed).length;
    const blocked = decisions.at(-1)?.allowed === false;
    if (allowedCount !== 6 || !blocked) {
      return NextResponse.json({ ok: false, message: "Rate-limit contract failed" }, { status: 503 });
    }
    return NextResponse.json({ ok: true, backend: "redis", allowedCount, blocked });
  } catch (error) {
    console.error("[CmdTab Website] release smoke rate-limit probe failed", error);
    return NextResponse.json({ ok: false, message: "Rate-limit backend unavailable" }, { status: 503 });
  }
}
