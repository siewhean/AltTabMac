import { createHmac, timingSafeEqual } from "node:crypto";

import { optionalStrongInternalSecret } from "./env";

// Domain-separated so this MAC can never be confused with another signature.
const TOKEN_CONTEXT = "cmdtab-waitlist-unsubscribe:v1:";
const MAX_TOKEN_LENGTH = 600;
const MAX_EMAIL_LENGTH = 320;

function signature(email: string, secret: string) {
  return createHmac("sha256", secret).update(TOKEN_CONTEXT + email).digest("base64url");
}

/**
 * A stateless unsubscribe token: the normalized email and an HMAC over it.
 * Only someone holding the link from a CmdTab email can remove that address.
 */
export function createWaitlistUnsubscribeToken(email: string, secret: string) {
  const normalized = email.trim().toLowerCase();
  return `${Buffer.from(normalized, "utf8").toString("base64url")}.${signature(normalized, secret)}`;
}

/** Returns the email the token was issued for, or null if it is not genuine. */
export function verifyWaitlistUnsubscribeToken(
  token: string | null | undefined,
  secret: string,
): string | null {
  if (!token || token.length > MAX_TOKEN_LENGTH) return null;
  const parts = token.split(".");
  if (parts.length !== 2 || !parts[0] || !parts[1]) return null;
  const email = Buffer.from(parts[0], "base64url").toString("utf8");
  if (!email.includes("@") || email.length > MAX_EMAIL_LENGTH || email !== email.trim().toLowerCase()) {
    return null;
  }
  const expected = Buffer.from(signature(email, secret));
  const provided = Buffer.from(parts[1]);
  if (expected.length !== provided.length || !timingSafeEqual(expected, provided)) return null;
  return email;
}

export function waitlistUnsubscribeSecret() {
  return optionalStrongInternalSecret(process.env.WAITLIST_UNSUBSCRIBE_SECRET);
}

/** Unsubscribe URL for an applicant, or undefined when no secret is configured. */
export function waitlistUnsubscribeUrl(siteUrl: string, email: string) {
  const secret = waitlistUnsubscribeSecret();
  if (!secret) return undefined;
  const token = createWaitlistUnsubscribeToken(email, secret);
  return `${siteUrl}/api/waitlist/unsubscribe?token=${encodeURIComponent(token)}`;
}
