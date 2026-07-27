import type { AdminSessionPolicy } from "./admin-session-token.js";
import { getAuth0Configuration } from "./auth0-config";

export function isLegacyAdminAuthAllowed(environment: NodeJS.ProcessEnv = process.env) {
  return (
    environment.NODE_ENV !== "production" &&
    environment.ADMIN_ENABLE_LEGACY_PASSWORD?.trim() === "true"
  );
}

export function getAdminSessionPolicyConfiguration(
  environment: NodeJS.ProcessEnv,
  ownerSubject: string | null,
): AdminSessionPolicy | null {
  const secret = environment.ADMIN_DASHBOARD_SECRET?.trim();
  const generation = environment.ADMIN_DASHBOARD_SESSION_GENERATION?.trim();
  if (
    !secret ||
    secret.length < 32 ||
    !generation ||
    !/^[A-Za-z0-9._:-]{1,128}$/.test(generation)
  ) {
    return null;
  }
  return {
    secret,
    generation,
    ownerSubject,
    legacyEnabled: isLegacyAdminAuthAllowed(environment),
  };
}

export function getProxyAdminSessionPolicy(environment: NodeJS.ProcessEnv = process.env) {
  const auth0Configuration = getAuth0Configuration(environment);
  if (environment.NODE_ENV === "production" && !auth0Configuration) return null;
  return getAdminSessionPolicyConfiguration(
    environment,
    auth0Configuration?.ownerSubject ?? null,
  );
}
