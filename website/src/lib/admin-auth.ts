import { cookies } from "next/headers";
import { redirect } from "next/navigation";

import {
  getAdminSessionPolicyConfiguration,
  isLegacyAdminAuthAllowed,
} from "@/lib/admin-auth-config";
import { getDashboardAuthSummary, validateStoredDashboardPassword } from "@/lib/admin-store";
import { getAuth0Configuration } from "@/lib/auth0-oidc";
import { constantTimeEqual } from "@/lib/constant-time";
import {
  ADMIN_SESSION_COOKIE,
  ADMIN_SESSION_IDLE_SECONDS,
  adminSessionCookieMaxAge,
  createAdminSessionToken,
  type AdminAuthMode,
  validateAdminSessionToken,
} from "@/lib/admin-session-token";

function isProduction() {
  return process.env.NODE_ENV === "production";
}

function getDashboardPassword() {
  return process.env.ADMIN_DASHBOARD_PASSWORD?.trim() || null;
}

export function isLegacyAdminAuthEnabled() {
  return isLegacyAdminAuthAllowed();
}

export function getAdminSessionPolicy() {
  const ownerSubject = getAuth0Configuration()?.ownerSubject ?? null;
  return getAdminSessionPolicyConfiguration(process.env, ownerSubject);
}

export function getAdminAuthMode(): AdminAuthMode | null {
  if (getAuth0Configuration() && getAdminSessionPolicy()) return "auth0";
  if (isLegacyAdminAuthEnabled() && getAdminSessionPolicy() && getDashboardPassword()) {
    return "legacy";
  }
  return null;
}

export async function isAdminAuthConfigured() {
  const mode = getAdminAuthMode();
  if (mode === "auth0") return true;
  if (mode !== "legacy") return false;
  const authSummary = await getDashboardAuthSummary();
  return authSummary.source !== "missing";
}

export async function createAdminSession(subject: string, auth: AdminAuthMode) {
  const policy = getAdminSessionPolicy();
  if (!policy) throw new Error("Admin dashboard session configuration is incomplete.");
  if (auth === "auth0" && subject !== policy.ownerSubject) {
    throw new Error("Admin dashboard subject is not authorized.");
  }
  if (auth === "legacy" && !policy.legacyEnabled) {
    throw new Error("Legacy dashboard authentication is disabled.");
  }

  const nowSeconds = Math.floor(Date.now() / 1000);
  const token = await createAdminSessionToken(
    {
      sub: subject,
      auth,
      iat: nowSeconds,
      lst: nowSeconds,
      gen: policy.generation,
    },
    policy.secret,
  );
  const cookieStore = await cookies();
  cookieStore.set(ADMIN_SESSION_COOKIE, token, {
    httpOnly: true,
    secure: isProduction(),
    sameSite: "strict",
    path: "/dashboard",
    maxAge: ADMIN_SESSION_IDLE_SECONDS,
  });
}

export async function clearAdminSession() {
  const cookieStore = await cookies();
  cookieStore.set(ADMIN_SESSION_COOKIE, "", {
    httpOnly: true,
    secure: isProduction(),
    sameSite: "strict",
    path: "/dashboard",
    maxAge: 0,
  });
}

export async function getAdminSession() {
  const policy = getAdminSessionPolicy();
  if (!policy) return null;
  const cookieStore = await cookies();
  const raw = cookieStore.get(ADMIN_SESSION_COOKIE)?.value;
  if (!raw) return null;
  return validateAdminSessionToken(raw, policy);
}

export async function hasAdminSession() {
  return Boolean(await getAdminSession());
}

export async function requireAdminSession() {
  const session = await getAdminSession();
  if (!session) redirect("/dashboard/login");
  return session;
}

export async function validateAdminPassword(input: string) {
  if (!isLegacyAdminAuthEnabled()) return false;
  const databaseMatch = await validateStoredDashboardPassword(input);
  const expected = getDashboardPassword();
  const environmentMatch = Boolean(expected) && constantTimeEqual(input, expected ?? "");
  if (databaseMatch !== null) return databaseMatch || environmentMatch;
  return environmentMatch;
}

export function adminSessionRemainingMaxAge(
  session: Awaited<ReturnType<typeof getAdminSession>>,
  nowSeconds = Math.floor(Date.now() / 1000),
) {
  return session ? adminSessionCookieMaxAge(session, nowSeconds) : 0;
}
