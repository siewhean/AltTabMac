import { NextResponse } from "next/server";

import { setDashboardPassword } from "@/lib/admin-store";
import { hasAdminSession, validateAdminPassword } from "@/lib/admin-auth";

export async function POST(request: Request) {
  if (!(await hasAdminSession())) {
    return NextResponse.redirect(new URL("/dashboard/login", request.url), 303);
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
  return NextResponse.redirect(new URL("/dashboard/settings?status=updated", request.url), 303);
}
