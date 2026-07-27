import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

import { getProxyAdminSessionPolicy } from "@/lib/admin-auth-config";
import {
  ADMIN_SESSION_COOKIE,
  adminSessionCookieMaxAge,
  createAdminSessionToken,
  refreshedAdminSessionClaims,
  validateAdminSessionToken,
} from "@/lib/admin-session-token";

const PUBLIC_DASHBOARD_PATHS = new Set([
  "/dashboard/login",
  "/dashboard/login/submit",
  "/dashboard/auth/login",
  "/dashboard/auth/callback",
]);

function getProxySessionPolicy() {
  return getProxyAdminSessionPolicy();
}

function redirectToLogin(request: NextRequest) {
  return NextResponse.redirect(new URL("/dashboard/login", request.url));
}

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  if (PUBLIC_DASHBOARD_PATHS.has(pathname)) return NextResponse.next();

  const policy = getProxySessionPolicy();
  const raw = request.cookies.get(ADMIN_SESSION_COOKIE)?.value;
  if (!policy || !raw) return redirectToLogin(request);

  const nowSeconds = Math.floor(Date.now() / 1000);
  const session = await validateAdminSessionToken(raw, policy, nowSeconds);
  if (!session) return redirectToLogin(request);

  const refreshed = refreshedAdminSessionClaims(session, nowSeconds);
  const response = NextResponse.next();
  response.cookies.set(
    ADMIN_SESSION_COOKIE,
    await createAdminSessionToken(refreshed, policy.secret),
    {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "strict",
      path: "/dashboard",
      maxAge: adminSessionCookieMaxAge(refreshed, nowSeconds),
    },
  );
  return response;
}

export const config = {
  matcher: ["/dashboard/:path*"],
};
