const SESSION_VERSION = 1;

export const ADMIN_SESSION_COOKIE = "cmdtab_admin_session";
export const ADMIN_SESSION_IDLE_SECONDS = 15 * 60;
export const ADMIN_SESSION_ABSOLUTE_SECONDS = 2 * 60 * 60;

export type AdminAuthMode = "auth0" | "legacy";

export type AdminSessionClaims = {
  v: 1;
  sub: string;
  auth: AdminAuthMode;
  iat: number;
  lst: number;
  gen: string;
};

export type AdminSessionPolicy = {
  secret: string;
  generation: string;
  ownerSubject: string | null;
  legacyEnabled: boolean;
};

function encodeBase64Url(value: Uint8Array) {
  let binary = "";
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function decodeBase64Url(value: string) {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) return null;
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  try {
    const decoded = atob(padded);
    return Uint8Array.from(decoded, (character) => character.charCodeAt(0));
  } catch {
    return null;
  }
}

function encodeJson(value: unknown) {
  return encodeBase64Url(new TextEncoder().encode(JSON.stringify(value)));
}

function decodeJson<T>(value: string) {
  const bytes = decodeBase64Url(value);
  if (!bytes) return null;
  try {
    return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)) as T;
  } catch {
    return null;
  }
}

async function signValue(value: string, secret: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return encodeBase64Url(
    new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value))),
  );
}

function constantTimeEqual(first: Uint8Array, second: Uint8Array) {
  if (first.length !== second.length) return false;
  let mismatch = 0;
  for (let index = 0; index < first.length; index += 1) {
    mismatch |= first[index] ^ second[index];
  }
  return mismatch === 0;
}

function hasValidShape(claims: unknown): claims is AdminSessionClaims {
  if (!claims || typeof claims !== "object") return false;
  const value = claims as Partial<AdminSessionClaims>;
  return (
    value.v === SESSION_VERSION &&
    typeof value.sub === "string" &&
    value.sub.length > 0 &&
    (value.auth === "auth0" || value.auth === "legacy") &&
    Number.isSafeInteger(value.iat) &&
    Number.isSafeInteger(value.lst) &&
    typeof value.gen === "string" &&
    value.gen.length > 0
  );
}

export async function createAdminSessionToken(
  input: Omit<AdminSessionClaims, "v">,
  secret: string,
) {
  const payload = encodeJson({ v: SESSION_VERSION, ...input });
  return `${payload}.${await signValue(payload, secret)}`;
}

export async function validateAdminSessionToken(
  token: string,
  policy: AdminSessionPolicy,
  nowSeconds = Math.floor(Date.now() / 1000),
) {
  const parts = token.split(".");
  if (parts.length !== 2) return null;
  const [payload, signature] = parts;
  const providedSignature = decodeBase64Url(signature);
  const expectedSignature = decodeBase64Url(await signValue(payload, policy.secret));
  if (
    !providedSignature ||
    !expectedSignature ||
    !constantTimeEqual(providedSignature, expectedSignature)
  ) {
    return null;
  }

  const claims = decodeJson<unknown>(payload);
  if (!hasValidShape(claims)) return null;
  if (claims.gen !== policy.generation) return null;
  if (claims.iat > nowSeconds || claims.lst < claims.iat || claims.lst > nowSeconds) return null;
  if (nowSeconds - claims.iat >= ADMIN_SESSION_ABSOLUTE_SECONDS) return null;
  if (nowSeconds - claims.lst >= ADMIN_SESSION_IDLE_SECONDS) return null;

  if (claims.auth === "auth0" && claims.sub !== policy.ownerSubject) return null;
  if (claims.auth === "legacy" && !policy.legacyEnabled) return null;
  return claims;
}

export function refreshedAdminSessionClaims(claims: AdminSessionClaims, nowSeconds: number) {
  return { ...claims, lst: nowSeconds };
}

export function adminSessionCookieMaxAge(claims: AdminSessionClaims, nowSeconds: number) {
  return Math.max(
    0,
    Math.min(ADMIN_SESSION_IDLE_SECONDS, ADMIN_SESSION_ABSOLUTE_SECONDS - (nowSeconds - claims.iat)),
  );
}
