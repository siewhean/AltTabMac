const DEFAULT_SITE_URL = "https://cmdtab.app";

type ServerEnv = {
  resendApiKey: string;
  waitlistFromEmail: string;
  waitlistToEmail: string;
  waitlistReplyToEmail?: string;
};

export function getSiteUrl() {
  const candidate =
    process.env.NEXT_PUBLIC_SITE_URL?.trim() ||
    process.env.SITE_URL?.trim() ||
    DEFAULT_SITE_URL;

  try {
    return new URL(candidate).toString().replace(/\/$/, "");
  } catch {
    return DEFAULT_SITE_URL;
  }
}

export function getServerEnv(): ServerEnv {
  const required = {
    resendApiKey: process.env.RESEND_API_KEY?.trim(),
    waitlistFromEmail: process.env.WAITLIST_FROM_EMAIL?.trim(),
    waitlistToEmail: process.env.WAITLIST_TO_EMAIL?.trim(),
    waitlistReplyToEmail: process.env.WAITLIST_REPLY_TO_EMAIL?.trim() || undefined,
  };

  if (!required.resendApiKey || !required.waitlistFromEmail || !required.waitlistToEmail) {
    throw new Error("Missing required waitlist email environment variables.");
  }

  return {
    resendApiKey: required.resendApiKey,
    waitlistFromEmail: required.waitlistFromEmail,
    waitlistToEmail: required.waitlistToEmail,
    waitlistReplyToEmail: required.waitlistReplyToEmail,
  };
}
