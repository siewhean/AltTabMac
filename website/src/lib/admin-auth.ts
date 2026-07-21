import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";

import { getDashboardAuthSummary, validateStoredDashboardPassword } from "@/lib/admin-store";

const ADMIN_COOKIE = "cmdtab_admin_session";
const SESSION_TTL_SECONDS = 60 * 60 * 2;

function getDashboardPassword() {
  return process.env.ADMIN_DASHBOARD_PASSWORD?.trim() || null;
}

function getDashboardSecret() {
  return process.env.ADMIN_DASHBOARD_SECRET?.trim() || getDashboardPassword();
}

function signValue(value: string, secret: string) {
  return createHmac("sha256", secret).update(value).digest("base64url");
}

function safeEqual(a: string, b: string) {
  const aBuffer = Buffer.from(a);
  const bBuffer = Buffer.from(b);
  if (aBuffer.length !== bBuffer.length) return false;
  return timingSafeEqual(aBuffer, bBuffer);
}

export async function isAdminAuthConfigured() {
  const authSummary = await getDashboardAuthSummary();
  return authSummary.source !== "missing" && Boolean(getDashboardSecret());
}

export async function createAdminSession() {
  const secret = getDashboardSecret();
  if (!secret) {
    throw new Error("Admin dashboard secret is not configured.");
  }

  const issuedAt = Math.floor(Date.now() / 1000).toString();
  const nonce = randomBytes(18).toString("base64url");
  const payload = `${issuedAt}.${nonce}`;
  const signature = signValue(payload, secret);
  const cookieStore = await cookies();

  cookieStore.set(ADMIN_COOKIE, `${payload}.${signature}`, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: SESSION_TTL_SECONDS,
  });
}

export async function clearAdminSession() {
  const cookieStore = await cookies();
  cookieStore.delete(ADMIN_COOKIE);
}

export async function hasAdminSession() {
  const secret = getDashboardSecret();
  if (!secret) return false;

  const cookieStore = await cookies();
  const raw = cookieStore.get(ADMIN_COOKIE)?.value;
  if (!raw) return false;

  const [issuedAt, nonce, signature] = raw.split(".");
  if (!issuedAt || !nonce || !signature || nonce.length < 20 || nonce.length > 40) return false;

  const expectedSignature = signValue(`${issuedAt}.${nonce}`, secret);
  if (!safeEqual(signature, expectedSignature)) return false;

  const age = Math.floor(Date.now() / 1000) - Number.parseInt(issuedAt, 10);
  return Number.isFinite(age) && age >= 0 && age <= SESSION_TTL_SECONDS;
}

export async function requireAdminSession() {
  if (!(await hasAdminSession())) {
    redirect("/dashboard/login");
  }
}

export async function validateAdminPassword(input: string) {
  if (input.length < 12 || input.length > 256) return false;
  const databaseMatch = await validateStoredDashboardPassword(input);
  const expected = getDashboardPassword();
  const environmentMatch = expected ? safeEqual(input, expected) : false;

  if (databaseMatch !== null) {
    return databaseMatch;
  }

  return environmentMatch;
}
