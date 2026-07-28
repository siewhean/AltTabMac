import { NextResponse } from "next/server";

import { getAdminSession } from "@/lib/admin-auth";
import { recordAdminAuditEvent } from "@/lib/admin-store";
import { escapeCsvCell } from "@/lib/csv";
import { listWaitlistSubmissions } from "@/lib/waitlist-store";

export async function GET(request: Request) {
  const session = await getAdminSession();
  if (!session) {
    return NextResponse.redirect(new URL("/dashboard/login", request.url), 303);
  }

  const rows = await listWaitlistSubmissions(5000);
  await recordAdminAuditEvent({
    actorSubject: session.sub,
    authMode: session.auth,
    action: "export_waitlist",
    outcome: "success",
    metadata: { rowCount: rows.length },
  });
  const csv = [
    ["email", "name", "source", "notification_status", "updated_at"].join(","),
    ...rows.map((row) =>
      [
        escapeCsvCell(row.email),
        escapeCsvCell(row.name ?? ""),
        escapeCsvCell(row.source ?? ""),
        escapeCsvCell(row.notificationStatus),
        escapeCsvCell(row.updatedAt),
      ].join(","),
    ),
  ].join("\n");

  return new NextResponse(csv, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": 'attachment; filename="cmdtab-waitlist.csv"',
      "Cache-Control": "no-store",
    },
  });
}
