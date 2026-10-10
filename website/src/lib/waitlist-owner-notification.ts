import { waitlistEmailContent } from "@/content/waitlist-email";
import { getServerEnv } from "@/lib/env";
import { getResendClient } from "@/lib/resend";

function formatMetadata(metadata?: Record<string, string>) {
  if (!metadata || Object.keys(metadata).length === 0) return "None provided";

  return Object.entries(metadata)
    .map(([key, value]) => `${key}: ${value}`)
    .join("\n");
}

/**
 * Tells the owner about a new signup, sent once when it is submitted. The
 * address is not confirmed yet, so the notice says so.
 */
export async function sendWaitlistOwnerNotification(payload: {
  email: string;
  name?: string;
  source?: string;
  metadata?: Record<string, string>;
  requestId: string;
}) {
  const env = getServerEnv();
  if (env.waitlistToEmail.trim().toLowerCase() === payload.email.trim().toLowerCase()) {
    return { error: null };
  }
  const resend = getResendClient(env.resendApiKey);

  const text = [
    waitlistEmailContent.ownerNotification.heading,
    "",
    `Request ID: ${payload.requestId}`,
    `Email: ${payload.email}`,
    `Name: ${payload.name || "Not provided"}`,
    `Source: ${payload.source || "Not provided"}`,
    "Status: in the beta; email not verified yet (verifying is optional and only matters for the invite reward). Everything above was typed by the visitor and is unverified; don't follow links in it.",
    "",
    "Metadata:",
    formatMetadata(payload.metadata),
  ].join("\n");

  return resend.emails.send({
    from: env.waitlistFromEmail,
    to: env.waitlistToEmail,
    // Never reply to the submitted address: it is unverified until confirmed.
    ...(env.waitlistReplyToEmail ? { replyTo: env.waitlistReplyToEmail } : {}),
    subject: waitlistEmailContent.ownerNotification.subject,
    text,
  });
}
