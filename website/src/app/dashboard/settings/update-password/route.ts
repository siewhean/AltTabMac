import { NextResponse } from "next/server";

import { setDashboardPassword } from "@/lib/admin-store";
import { clearAdminSession, hasAdminSession, validateAdminPassword } from "@/lib/admin-auth";
import { isSameOriginAdminRequest, readAdminForm } from "@/lib/admin-request-security";

export async function POST(request: Request) {
  if (!(await hasAdminSession())) {
    return NextResponse.redirect(new URL("/dashboard/login", request.url), 303);
  }

  if (!isSameOriginAdminRequest(request)) {
    return new NextResponse("Forbidden", { status: 403 });
  }

  let formData: URLSearchParams;
  try {
    formData = await readAdminForm(request);
  } catch {
    return new NextResponse("Invalid request", { status: 400 });
  }
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

  if (newPassword.length < 12 || newPassword.length > 256) {
    return NextResponse.redirect(new URL("/dashboard/settings?error=length", request.url), 303);
  }

  if (newPassword !== confirmPassword) {
    return NextResponse.redirect(new URL("/dashboard/settings?error=mismatch", request.url), 303);
  }

  await setDashboardPassword(newPassword);
  await clearAdminSession();
  return NextResponse.redirect(new URL("/dashboard/login?status=password-updated", request.url), 303);
}
