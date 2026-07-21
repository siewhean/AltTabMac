import { NextResponse } from "next/server";

import { createAdminSession, validateAdminPassword } from "@/lib/admin-auth";
import {
  adminLoginAllowance,
  clearAdminLoginFailures,
  recordAdminLoginFailure,
} from "@/lib/admin-login-rate-limit";
import { isSameOriginAdminRequest, readAdminForm } from "@/lib/admin-request-security";

export async function POST(request: Request) {
  if (!isSameOriginAdminRequest(request)) {
    return new NextResponse("Forbidden", { status: 403 });
  }

  let allowance;
  try {
    allowance = await adminLoginAllowance(request);
  } catch (error) {
    console.error("[CmdTab Website] admin login rate limit failed", error);
    return new NextResponse("Service unavailable", { status: 503 });
  }
  if (!allowance.allowed) {
    return new NextResponse("Too many login attempts", {
      status: 429,
      headers: { "Retry-After": String(allowance.retryAfterSeconds) },
    });
  }

  let password: string | null = null;
  try {
    password = (await readAdminForm(request)).get("password");
  } catch {
    return new NextResponse("Invalid request", { status: 400 });
  }

  if (typeof password !== "string" || !(await validateAdminPassword(password))) {
    try {
      await recordAdminLoginFailure(request);
    } catch (error) {
      console.error("[CmdTab Website] admin login failure tracking failed", error);
      return new NextResponse("Service unavailable", { status: 503 });
    }
    return NextResponse.redirect(new URL("/dashboard/login?error=invalid", request.url), 303);
  }

  try {
    await clearAdminLoginFailures(request);
  } catch (error) {
    console.error("[CmdTab Website] admin login failure clear failed", error);
    return new NextResponse("Service unavailable", { status: 503 });
  }
  await createAdminSession();
  return NextResponse.redirect(new URL("/dashboard", request.url), 303);
}
