import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

const ADMIN_COOKIE = "cmdtab_admin_session";
const SESSION_TTL_SECONDS = 60 * 60 * 12;

function base64UrlToUint8Array(value: string) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const decoded = atob(padded);
  return Uint8Array.from(decoded, (char) => char.charCodeAt(0));
}

async function signValue(value: string, secret: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value));
  return btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

async function hasValidAdminSession(request: NextRequest) {
  const secret =
    process.env.ADMIN_DASHBOARD_SECRET?.trim() || process.env.ADMIN_DASHBOARD_PASSWORD?.trim();
  if (!secret) return false;

  const raw = request.cookies.get(ADMIN_COOKIE)?.value;
  if (!raw) return false;

  const [issuedAt, signature] = raw.split(".");
  if (!issuedAt || !signature) return false;

  const expectedSignature = await signValue(issuedAt, secret);
  const providedBytes = base64UrlToUint8Array(signature);
  const expectedBytes = base64UrlToUint8Array(expectedSignature);

  if (providedBytes.length !== expectedBytes.length) return false;

  let mismatch = 0;
  for (let index = 0; index < providedBytes.length; index += 1) {
    mismatch |= providedBytes[index] ^ expectedBytes[index];
  }
  if (mismatch !== 0) return false;

  const issuedAtSeconds = Number.parseInt(issuedAt, 10);
  if (!Number.isFinite(issuedAtSeconds)) return false;

  const age = Math.floor(Date.now() / 1000) - issuedAtSeconds;
  return age >= 0 && age <= SESSION_TTL_SECONDS;
}

function redirectToLogin(request: NextRequest) {
  return NextResponse.redirect(new URL("/dashboard/login", request.url));
}

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;

  if (pathname === "/dashboard/login" || pathname === "/dashboard/login/submit") {
    return NextResponse.next();
  }

  if (!(await hasValidAdminSession(request))) {
    return redirectToLogin(request);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/dashboard/:path*"],
};
