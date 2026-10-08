import { ingestJsonResponse } from "@/lib/ingest-request";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Trial enrollment and promotional trial reminders remain closed in waitlist mode.
// License recovery and existing customer support use their separate endpoints.
export async function GET() {
  return ingestJsonResponse({ ok: false, code: "waitlist_only", message: "Public trial reminders are paused while CmdTab accepts waitlist signups only." }, 403);
}
