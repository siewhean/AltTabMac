import { NextResponse } from "next/server";

import { getAdminSession, isLegacyAdminAuthEnabled, validateAdminPassword } from "@/lib/admin-auth";
import { isSameOriginAdminMutation } from "@/lib/admin-request-security";
import { recordAdminAuditEvent, setDashboardPassword } from "@/lib/admin-store";

export async function POST(request: Request) {
  if (!isSameOriginAdminMutation(request)) {
    return NextResponse.json({ ok: false, message: "Invalid request origin." }, { status: 403 });
  }
  const session = await getAdminSession();
  if (!session) {
    return NextResponse.redirect(new URL("/dashboard/login", request.url), 303);
  }
  if (!isLegacyAdminAuthEnabled() || session.auth !== "legacy") {
    return NextResponse.json({ ok: false, message: "Legacy authentication is disabled." }, { status: 404 });
  }

  const formData = await request.formData();
  const currentPassword = formData.get("currentPassword");
  const newPassword = formData.get("newPassword");
  const confirmPassword = formData.get("confirmPassword");

  if (
    typeof currentPassword !== "string" ||
    typeof newPassword !== "string" ||
    typeof confirmPassword !== "string"
  ) {
    return NextResponse.redirect(new URL("/dashboard/settings?error=current", request.url), 303);
  }

  if (!(await validateAdminPassword(currentPassword))) {
    return NextResponse.redirect(new URL("/dashboard/settings?error=current", request.url), 303);
  }

  if (newPassword.length < 12) {
    return NextResponse.redirect(new URL("/dashboard/settings?error=length", request.url), 303);
  }

  if (newPassword !== confirmPassword) {
    return NextResponse.redirect(new URL("/dashboard/settings?error=mismatch", request.url), 303);
  }

  await setDashboardPassword(newPassword);
  await recordAdminAuditEvent({
    actorSubject: session.sub,
    authMode: session.auth,
    action: "change_legacy_password",
    outcome: "success",
  });
  return NextResponse.redirect(new URL("/dashboard/settings?status=updated", request.url), 303);
}
