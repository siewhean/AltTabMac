import { cookies } from "next/headers";
import { NextResponse } from "next/server";

import { createAdminSession } from "@/lib/admin-auth";
import {
  exchangeAuth0Code,
  getAuth0Configuration,
  verifyAuth0IdToken,
} from "@/lib/auth0-oidc";
import { recordAdminAuditEvent } from "@/lib/admin-store";

/**
 * The admin session cookie is SameSite=Strict. A redirect issued in reply to
 * the cross-site navigation from Auth0 inherits that cross-site context, so the
 * browser would withhold the new cookie from /dashboard and loop back to login.
 * Hand over with a same-origin page instead: the navigation it starts is
 * same-site, so the Strict cookie is sent. No script, so CSP is unaffected.
 */
function continueToDashboard() {
  return new NextResponse(
    '<!doctype html><html lang="en"><head><meta charset="utf-8">' +
      '<meta http-equiv="refresh" content="0;url=/dashboard">' +
      "<title>Signing in…</title></head><body>" +
      '<p><a href="/dashboard">Continue to the dashboard</a></p></body></html>',
    {
      status: 200,
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-store",
        "Referrer-Policy": "no-referrer",
      },
    },
  );
}

function loginError(request: Request) {
  return NextResponse.redirect(new URL("/dashboard/login?error=invalid", request.url), 303);
}

export async function GET(request: Request) {
  const configuration = getAuth0Configuration();
  if (!configuration) return loginError(request);

  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const state = url.searchParams.get("state");
  const cookieStore = await cookies();
  const expectedState = cookieStore.get("cmdtab_auth_state")?.value;
  const expectedNonce = cookieStore.get("cmdtab_auth_nonce")?.value;
  const verifier = cookieStore.get("cmdtab_auth_verifier")?.value;
  const expiredTransactionCookie = {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax" as const,
    path: "/dashboard/auth/callback",
    maxAge: 0,
  };
  cookieStore.set("cmdtab_auth_state", "", expiredTransactionCookie);
  cookieStore.set("cmdtab_auth_nonce", "", expiredTransactionCookie);
  cookieStore.set("cmdtab_auth_verifier", "", expiredTransactionCookie);

  if (!code || !state || !expectedState || state !== expectedState || !expectedNonce || !verifier) {
    return loginError(request);
  }

  try {
    const idToken = await exchangeAuth0Code(configuration, code, verifier);
    const identity = await verifyAuth0IdToken(idToken, configuration, expectedNonce);
    await recordAdminAuditEvent({
      actorSubject: identity.subject,
      authMode: "auth0",
      action: "login",
      outcome: "success",
    });
    await createAdminSession(identity.subject, "auth0");
    return continueToDashboard();
  } catch {
    return loginError(request);
  }
}
