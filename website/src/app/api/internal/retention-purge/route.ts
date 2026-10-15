import { NextResponse } from "next/server";

import { optionalStrongInternalSecret } from "@/lib/env";
import { isAuthorizedInternalWorker } from "@/lib/internal-worker-auth";
import { isDatabaseConfigured } from "@/lib/postgres";
import { runRetentionPurge } from "@/lib/retention-purge";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
// The purge works in bounded batches inside a 40-second budget.
export const maxDuration = 60;

const noStore = { "Cache-Control": "no-store" };

/**
 * Daily data-retention purge (docs/operations/data-retention.md). Vercel Cron
 * invokes it with GET and sends CRON_SECRET as a Bearer token. A missing, weak
 * or placeholder secret rejects every request (same contract as the trial
 * reminder and license outbox crons). Only row counts are logged or returned.
 */
export async function GET(request: Request) {
  if (
    !isAuthorizedInternalWorker(
      request,
      optionalStrongInternalSecret(process.env.CRON_SECRET),
    )
  ) {
    return NextResponse.json(
      { ok: false, code: "unauthorized", message: "Unauthorized." },
      { status: 401, headers: noStore },
    );
  }

  if (!isDatabaseConfigured()) {
    return NextResponse.json(
      { ok: false, code: "database_unavailable" },
      { status: 503, headers: noStore },
    );
  }

  try {
    const result = await runRetentionPurge();
    console.info("[CmdTab Website] retention purge", result);
    return NextResponse.json({ ok: true, ...result }, { headers: noStore });
  } catch (error) {
    // Log only the error class and message; never row contents.
    console.error(
      "[CmdTab Website] retention purge failed",
      error instanceof Error ? `${error.name}: ${error.message}` : "unknown error",
    );
    return NextResponse.json(
      { ok: false, code: "purge_failed" },
      { status: 500, headers: noStore },
    );
  }
}
