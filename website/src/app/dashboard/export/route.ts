import { NextResponse } from "next/server";

import { hasAdminSession } from "@/lib/admin-auth";
import { listWaitlistSubmissions } from "@/lib/waitlist-store";

function escapeCsv(value: string | number | null | undefined | Date) {
  return `"${String(value ?? "").replace(/"/g, '""')}"`;
}

export async function GET(request: Request) {
  if (!(await hasAdminSession())) {
    return NextResponse.redirect(new URL("/dashboard/login", request.url), 303);
  }

  const rows = await listWaitlistSubmissions(5000);
  const csv = [
    ["email", "name", "source", "notification_status", "updated_at"].join(","),
    ...rows.map((row) =>
      [
        escapeCsv(row.email),
        escapeCsv(row.name ?? ""),
        escapeCsv(row.source ?? ""),
        escapeCsv(row.notificationStatus),
        escapeCsv(row.updatedAt),
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
