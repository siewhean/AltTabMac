import { ingestJsonResponse } from "@/lib/ingest-request";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Public enrollment stays closed regardless of checkout or signing configuration.
export async function POST() {
  return ingestJsonResponse({
    ok: false,
    code: "trial_unavailable",
    message: "CmdTab is accepting waitlist signups only. Join at /waitlist.",
  }, 403);
}
