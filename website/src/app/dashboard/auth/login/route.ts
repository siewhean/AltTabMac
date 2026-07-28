import { cookies } from "next/headers";
import { NextResponse } from "next/server";

import {
  buildAuth0AuthorizeUrl,
  createAuth0Transaction,
  getAuth0Configuration,
} from "@/lib/auth0-oidc";

const TRANSACTION_TTL_SECONDS = 10 * 60;

export async function GET(request: Request) {
  const configuration = getAuth0Configuration();
  if (!configuration) {
    return NextResponse.redirect(new URL("/dashboard/login?error=unavailable", request.url), 303);
  }

  const transaction = createAuth0Transaction();
  const cookieStore = await cookies();
  const options = {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax" as const,
    path: "/dashboard/auth/callback",
    maxAge: TRANSACTION_TTL_SECONDS,
  };
  cookieStore.set("cmdtab_auth_state", transaction.state, options);
  cookieStore.set("cmdtab_auth_nonce", transaction.nonce, options);
  cookieStore.set("cmdtab_auth_verifier", transaction.verifier, options);

  return NextResponse.redirect(buildAuth0AuthorizeUrl(configuration, transaction));
}
