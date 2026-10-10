import { randomUUID } from "node:crypto";

import {
  verifyWaitlistUnsubscribeToken,
  waitlistUnsubscribeSecret,
} from "@/lib/waitlist-unsubscribe";
import { deleteWaitlistSignup, isWaitlistStoreConfigured } from "@/lib/waitlist-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// GET only renders a confirmation form: mail scanners prefetch links, so a GET
// must never unsubscribe. POST (the form, or a mail client's RFC 8058
// one-click request) removes the signup. Responses never reveal whether the
// address was on the list.

const PAGE_STYLE =
  "margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;" +
  "background:#05070C;color:#E8EEF9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;";
const CARD_STYLE =
  "max-width:440px;margin:24px;padding:32px;border:1px solid #1C2433;border-radius:24px;background:#0E1421;";
const BUTTON_STYLE =
  "margin-top:20px;padding:12px 20px;border:0;border-radius:999px;background:#79AFFF;color:#08111E;" +
  "font-weight:700;font-size:15px;cursor:pointer;";

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
    `<p style="margin:0;line-height:1.7;color:#B7C3D9;">Use the unsubscribe link from your most recent CmdTab email, or reply to that email and we will remove you.</p>`,
    400,
  );
}

function unavailable() {
  return htmlPage(
    "Please try again later",
    `<p style="margin:0;line-height:1.7;color:#B7C3D9;">Unsubscribe is temporarily unavailable. Reply to any CmdTab email and we will remove you.</p>`,
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
  if (!verifyWaitlistUnsubscribeToken(token, secret)) return invalidLink();

  const action = `/api/waitlist/unsubscribe?token=${encodeURIComponent(token ?? "")}`;
  return htmlPage(
    "Unsubscribe from the CmdTab beta list?",
    `<p style="margin:0;line-height:1.7;color:#B7C3D9;">You will stop receiving beta, trial, and launch emails, and your signup will be deleted. We keep a one-way hash of your address only so we do not email you again if it is submitted later.</p>` +
      `<form method="post" action="${action}"><button type="submit" style="${BUTTON_STYLE}">Unsubscribe</button></form>`,
  );
}

export async function POST(request: Request) {
  const secret = waitlistUnsubscribeSecret();
  if (!secret || !isWaitlistStoreConfigured()) return unavailable();
  const email = verifyWaitlistUnsubscribeToken(tokenFrom(request), secret);
  if (!email) return invalidLink();

  try {
    // Delete everything; a later signup with this address starts over.
    await deleteWaitlistSignup(email);
  } catch (error) {
    console.error("[CmdTab Website] waitlist unsubscribe failed", {
      requestId: randomUUID(),
      error: error instanceof Error ? error.message : "Unknown error",
    });
    return unavailable();
  }

  return htmlPage(
    "You are unsubscribed",
    `<p style="margin:0;line-height:1.7;color:#B7C3D9;">Your CmdTab beta list signup has been deleted. You will not receive further beta emails.</p>`,
  );
}
