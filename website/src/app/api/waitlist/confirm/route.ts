import { randomUUID } from "node:crypto";

import { getClientIp } from "@/lib/client-ip";
import { sendWaitlistOwnerNotification } from "@/lib/waitlist-owner-notification";
import { verifyWaitlistConfirmToken } from "@/lib/waitlist-confirm";
import { hashNetwork } from "@/lib/waitlist-signals";
import { waitlistUnsubscribeSecret } from "@/lib/waitlist-unsubscribe";
import { confirmWaitlistSignup, isWaitlistStoreConfigured } from "@/lib/waitlist-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// GET only renders a button: mail scanners prefetch links, so a GET must never
// confirm anything. POST confirms the address and records the network it was
// confirmed from (hashed) for referral abuse checks. Responses never reveal
// whether an address is on the list.

const PAGE_STYLE =
  "margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;" +
  "background:#05070C;color:#E8EEF9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;";
const CARD_STYLE =
  "max-width:440px;margin:24px;padding:32px;border:1px solid #1C2433;border-radius:24px;background:#0E1421;";
const BUTTON_STYLE =
  "margin-top:20px;padding:12px 20px;border:0;border-radius:999px;background:#79AFFF;color:#08111E;" +
  "font-weight:700;font-size:15px;cursor:pointer;";
const TEXT_STYLE = "margin:0;line-height:1.7;color:#B7C3D9;";

function htmlPage(title: string, body: string, status = 200) {
  return new Response(
    `<!doctype html><html lang="en"><head><meta charset="utf-8">` +
      `<meta name="viewport" content="width=device-width, initial-scale=1">` +
      `<meta name="robots" content="noindex, nofollow"><title>${title} | CmdTab</title></head>` +
      `<body style="${PAGE_STYLE}"><main style="${CARD_STYLE}"><h1 style="margin:0 0 12px;font-size:24px;">${title}</h1>` +
      `${body}<p style="margin:24px 0 0;font-size:13px;color:#8A97B0;"><a href="/" style="color:#A9D2FF;">cmdtab.net</a></p></main></body></html>`,
    {
      status,
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-store, max-age=0",
        "Referrer-Policy": "no-referrer",
        "X-Robots-Tag": "noindex, nofollow",
      },
    },
  );
}

function invalidLink() {
  return htmlPage(
    "This link is not valid",
    `<p style="${TEXT_STYLE}">The confirmation link is invalid or has expired. Join the beta list again from cmdtab.net to get a new one.</p>`,
    400,
  );
}

function unavailable() {
  return htmlPage(
    "Please try again later",
    `<p style="${TEXT_STYLE}">Confirmation is temporarily unavailable. Please try the link again in a few minutes.</p>`,
    503,
  );
}

function tokenFrom(request: Request) {
  return new URL(request.url).searchParams.get("token");
}

export async function GET(request: Request) {
  const secret = waitlistUnsubscribeSecret();
  if (!secret) return unavailable();
  const token = tokenFrom(request);
  if (!verifyWaitlistConfirmToken(token, secret)) return invalidLink();

  const action = `/api/waitlist/confirm?token=${encodeURIComponent(token ?? "")}`;
  return htmlPage(
    "Confirm your email",
    `<p style="${TEXT_STYLE}">One click to confirm this address for the CmdTab private beta list.</p>` +
      `<form method="post" action="${action}"><button type="submit" style="${BUTTON_STYLE}">Confirm my email</button></form>`,
  );
}

export async function POST(request: Request) {
  const secret = waitlistUnsubscribeSecret();
  if (!secret || !isWaitlistStoreConfigured()) return unavailable();
  const email = verifyWaitlistConfirmToken(tokenFrom(request), secret);
  if (!email) return invalidLink();

  const requestId = randomUUID();
  try {
    const result = await confirmWaitlistSignup(email, {
      networkHash: hashNetwork(getClientIp(request)),
    });

    // Notify the owner once, when the address is first confirmed. A failed
    // notice must never undo or hide a successful confirmation.
    if (result.found && result.firstConfirmation) {
      try {
        const sent = await sendWaitlistOwnerNotification({
          email: result.submission.email,
          name: result.submission.name,
          source: result.submission.source,
          metadata: result.submission.metadata,
          requestId,
        });
        if (sent.error) {
          console.error("[CmdTab Website] waitlist owner notification failed", {
            requestId,
            errorName: sent.error.name,
          });
        }
      } catch (notificationError) {
        console.error("[CmdTab Website] waitlist owner notification failed", {
          requestId,
          error: notificationError instanceof Error ? notificationError.message : "Unknown error",
        });
      }
    }
  } catch (error) {
    console.error("[CmdTab Website] waitlist confirmation failed", {
      requestId,
      error: error instanceof Error ? error.message : "Unknown error",
    });
    return unavailable();
  }

  // Same answer whether or not the address is still on the list.
  return htmlPage(
    "Email confirmed",
    `<p style="${TEXT_STYLE}">Thanks. If this address is on the CmdTab beta list, it is now confirmed.</p>`,
  );
}
