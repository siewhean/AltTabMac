import { createHmac, timingSafeEqual } from "node:crypto";

import { waitlistUnsubscribeSecret } from "./waitlist-unsubscribe";

// Domain-separated so this MAC can never be confused with the unsubscribe MAC.
const TOKEN_CONTEXT = "cmdtab-waitlist-confirm:v1:";
const MAX_TOKEN_LENGTH = 700;
const MAX_EMAIL_LENGTH = 320;
export const CONFIRM_TOKEN_TTL_SECONDS = 7 * 24 * 60 * 60;

function signature(email: string, issuedAt: number, secret: string) {
  return createHmac("sha256", secret)
    .update(`${TOKEN_CONTEXT}${email}\0${issuedAt}`)
    .digest("base64url");
}

/** A stateless confirmation token: email, issue time, and an HMAC over both. */
export function createWaitlistConfirmToken(
  email: string,
  secret: string,
  nowSeconds = Math.floor(Date.now() / 1000),
) {
  const normalized = email.trim().toLowerCase();
  return [
    Buffer.from(normalized, "utf8").toString("base64url"),
    String(nowSeconds),
    signature(normalized, nowSeconds, secret),
  ].join(".");
}

/** Returns the email the token was issued for, or null if invalid or expired. */
export function verifyWaitlistConfirmToken(
  token: string | null | undefined,
  secret: string,
  nowSeconds = Math.floor(Date.now() / 1000),
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
  if (issuedAt > nowSeconds + 300 || nowSeconds - issuedAt > CONFIRM_TOKEN_TTL_SECONDS) return null;

  const expected = Buffer.from(signature(email, issuedAt, secret));
  const provided = Buffer.from(parts[2]);
  if (expected.length !== provided.length || !timingSafeEqual(expected, provided)) return null;
  return email;
}

/** Confirmation URL for an applicant, or undefined when no secret is configured. */
export function waitlistConfirmUrl(siteUrl: string, email: string) {
  const secret = waitlistUnsubscribeSecret();
  if (!secret) return undefined;
  return `${siteUrl}/api/waitlist/confirm?token=${encodeURIComponent(createWaitlistConfirmToken(email, secret))}`;
}
