import { NextResponse } from "next/server";

import { createAdminSession, validateAdminPassword } from "@/lib/admin-auth";

export async function POST(request: Request) {
  const formData = await request.formData();
  const password = formData.get("password");

  if (typeof password !== "string" || !(await validateAdminPassword(password))) {
    return NextResponse.redirect(new URL("/dashboard/login?error=invalid", request.url), 303);
  }

  await createAdminSession();
  return NextResponse.redirect(new URL("/dashboard", request.url), 303);
}
