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
import { contentSecurityPolicy } from "@/lib/content-security-policy";

const PUBLIC_DASHBOARD_PATHS = new Set([
  "/dashboard/login",
  "/dashboard/login/submit",
  "/dashboard/auth/login",
  "/dashboard/auth/callback",
]);

function getProxySessionPolicy() {
  return getProxyAdminSessionPolicy();
}

function responseWithSecurityHeaders(
  response: NextResponse,
  policy: string,
) {
  response.headers.set("Content-Security-Policy", policy);
  return response;
}

function nextResponse(requestHeaders: Headers, policy: string) {
  return responseWithSecurityHeaders(
    NextResponse.next({
      request: {
        headers: requestHeaders,
      },
    }),
    policy,
  );
}

function redirectToLogin(request: NextRequest, policy: string) {
  return responseWithSecurityHeaders(
    NextResponse.redirect(new URL("/dashboard/login", request.url)),
    policy,
  );
}

export async function proxy(request: NextRequest) {
  const nonce = btoa(crypto.randomUUID());
  const policy = contentSecurityPolicy(nonce);
  const requestHeaders = new Headers(request.headers);
  requestHeaders.set("x-nonce", nonce);
  requestHeaders.set("Content-Security-Policy", policy);

  const { pathname } = request.nextUrl;
  if (!pathname.startsWith("/dashboard")) {
    return nextResponse(requestHeaders, policy);
  }
  if (PUBLIC_DASHBOARD_PATHS.has(pathname)) {
    return nextResponse(requestHeaders, policy);
  }

  const sessionPolicy = getProxySessionPolicy();
  const raw = request.cookies.get(ADMIN_SESSION_COOKIE)?.value;
  if (!sessionPolicy || !raw) return redirectToLogin(request, policy);

  const nowSeconds = Math.floor(Date.now() / 1000);
  const session = await validateAdminSessionToken(raw, sessionPolicy, nowSeconds);
  if (!session) return redirectToLogin(request, policy);

  const refreshed = refreshedAdminSessionClaims(session, nowSeconds);
  const response = nextResponse(requestHeaders, policy);
  response.cookies.set(
    ADMIN_SESSION_COOKIE,
    await createAdminSessionToken(refreshed, sessionPolicy.secret),
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
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|robots.txt|sitemap.xml|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico|mp4|woff|woff2)$).*)",
  ],
};
