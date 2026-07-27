import { NextResponse } from "next/server";

import { createAdminSession, validateAdminPassword } from "@/lib/admin-auth";
import { isSameOriginAdminMutation } from "@/lib/admin-request-security";
import { recordAdminAuditEvent } from "@/lib/admin-store";

export async function POST(request: Request) {
  if (!isSameOriginAdminMutation(request)) {
    return NextResponse.json({ ok: false, message: "Invalid request origin." }, { status: 403 });
  }

  const formData = await request.formData();
  const password = formData.get("password");

  if (typeof password !== "string" || !(await validateAdminPassword(password))) {
    return NextResponse.redirect(new URL("/dashboard/login?error=invalid", request.url), 303);
  }

  await createAdminSession("legacy-development-owner", "legacy");
  await recordAdminAuditEvent({
    actorSubject: "legacy-development-owner",
    authMode: "legacy",
    action: "login",
    outcome: "success",
  });
  return NextResponse.redirect(new URL("/dashboard", request.url), 303);
}
