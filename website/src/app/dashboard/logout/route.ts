import { NextResponse } from "next/server";

import { clearAdminSession, getAdminSession } from "@/lib/admin-auth";
import { completeAdminLogout } from "@/lib/admin-logout";
import { isSameOriginAdminMutation } from "@/lib/admin-request-security";
import { recordAdminAuditEvent } from "@/lib/admin-store";
import { buildAuth0LogoutUrl, getAuth0Configuration } from "@/lib/auth0-oidc";

export async function POST(request: Request) {
  if (!isSameOriginAdminMutation(request)) {
    return NextResponse.json({ ok: false, message: "Invalid request origin." }, { status: 403 });
  }

  const session = await getAdminSession();
  if (!session) {
    return NextResponse.redirect(new URL("/dashboard/login", request.url), 303);
  }
  await completeAdminLogout(clearAdminSession, () =>
    recordAdminAuditEvent({
      actorSubject: session.sub,
      authMode: session.auth,
      action: "logout",
      outcome: "success",
    }),
  );
  if (session.auth === "auth0") {
    const configuration = getAuth0Configuration();
    if (configuration) return NextResponse.redirect(buildAuth0LogoutUrl(configuration), 303);
  }
  return NextResponse.redirect(new URL("/dashboard/login", request.url), 303);
}
