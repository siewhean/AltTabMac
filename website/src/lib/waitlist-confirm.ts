import { createHmac, timingSafeEqual } from "node:crypto";

import { waitlistUnsubscribeSecret } from "./waitlist-unsubscribe";

// Signed, stateless, single-purpose tokens: the email, the issue time, and an
// HMAC over both. The purpose is part of the MAC context, so a token made for
// one purpose (or for the unsubscribe link) can never be used for another.
export type WaitlistTokenPurpose = "confirm" | "profile";

const MAX_TOKEN_LENGTH = 700;
const MAX_EMAIL_LENGTH = 320;
export const CONFIRM_TOKEN_TTL_SECONDS = 7 * 24 * 60 * 60;
export const PROFILE_TOKEN_TTL_SECONDS = 24 * 60 * 60;

function signature(purpose: WaitlistTokenPurpose, email: string, issuedAt: number, secret: string) {
  return createHmac("sha256", secret)
    .update(`cmdtab-waitlist-${purpose}:v1:${email}\0${issuedAt}`)
    .digest("base64url");
}

function createToken(
  purpose: WaitlistTokenPurpose,
  email: string,
  secret: string,
  nowSeconds: number,
) {
  const normalized = email.trim().toLowerCase();
  return [
    Buffer.from(normalized, "utf8").toString("base64url"),
    String(nowSeconds),
    signature(purpose, normalized, nowSeconds, secret),
  ].join(".");
}

/** Returns the email the token was issued for, or null if invalid, expired or for another purpose. */
function verifyToken(
  purpose: WaitlistTokenPurpose,
  ttlSeconds: number,
  token: string | null | undefined,
  secret: string,
  nowSeconds: number,
): string | null {
  if (!token || token.length > MAX_TOKEN_LENGTH) return null;
  const parts = token.split(".");
  if (parts.length !== 3 || parts.some((part) => !part)) return null;

  const email = Buffer.from(parts[0], "base64url").toString("utf8");
  if (!email.includes("@") || email.length > MAX_EMAIL_LENGTH || email !== email.trim().toLowerCase()) {
    return null;
  }
  if (!/^\d{1,12}$/.test(parts[1])) return null;
  const issuedAt = Number(parts[1]);
  if (issuedAt > nowSeconds + 300 || nowSeconds - issuedAt > ttlSeconds) return null;

  const expected = Buffer.from(signature(purpose, email, issuedAt, secret));
  const provided = Buffer.from(parts[2]);
  if (expected.length !== provided.length || !timingSafeEqual(expected, provided)) return null;
  return email;
}

/** Link token for the optional email verification (7 days). */
export function createWaitlistConfirmToken(
  email: string,
  secret: string,
  nowSeconds = Math.floor(Date.now() / 1000),
) {
  return createToken("confirm", email, secret, nowSeconds);
}

export function verifyWaitlistConfirmToken(
  token: string | null | undefined,
  secret: string,
  nowSeconds = Math.floor(Date.now() / 1000),
) {
  return verifyToken("confirm", CONFIRM_TOKEN_TTL_SECONDS, token, secret, nowSeconds);
}

/**
 * Token the signup response hands to the browser so it can send one optional
 * answer about how the person will use CmdTab. It authorizes only that single
 * write for the typed address, and every signup response carries one, so it
 * reveals nothing about the address.
 */
export function createWaitlistProfileToken(
  email: string,
  secret: string,
  nowSeconds = Math.floor(Date.now() / 1000),
) {
  return createToken("profile", email, secret, nowSeconds);
}

export function verifyWaitlistProfileToken(
  token: string | null | undefined,
  secret: string,
  nowSeconds = Math.floor(Date.now() / 1000),
) {
  return verifyToken("profile", PROFILE_TOKEN_TTL_SECONDS, token, secret, nowSeconds);
}

/** Verification URL for an applicant, or undefined when no secret is configured. */
export function waitlistConfirmUrl(siteUrl: string, email: string) {
  const secret = waitlistUnsubscribeSecret();
  if (!secret) return undefined;
  return `${siteUrl}/api/waitlist/confirm?token=${encodeURIComponent(createWaitlistConfirmToken(email, secret))}`;
}
