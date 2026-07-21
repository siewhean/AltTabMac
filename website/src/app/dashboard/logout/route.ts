import { NextResponse } from "next/server";

import { clearAdminSession } from "@/lib/admin-auth";
import { isSameOriginAdminRequest } from "@/lib/admin-request-security";

export async function POST(request: Request) {
  if (!isSameOriginAdminRequest(request)) {
    return new NextResponse("Forbidden", { status: 403 });
  }
  await clearAdminSession();
  return NextResponse.redirect(new URL("/dashboard/login", request.url), 303);
}
