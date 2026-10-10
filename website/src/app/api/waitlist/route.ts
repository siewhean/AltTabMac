import { randomUUID } from "node:crypto";

import { after, NextResponse } from "next/server";
import { ZodError } from "zod";

import { getClientIp } from "@/lib/client-ip";
import {
  renderApplicantWaitlistEmail,
  waitlistEmailContent,
} from "@/content/waitlist-email";
import { getServerEnv, getSiteUrl } from "@/lib/env";
import {
  checkRateLimit,
  createFingerprint,
  markSubmittedAll,
  recentlySubmittedAny,
} from "@/lib/rate-limit";
import { getResendClient } from "@/lib/resend";
import {
  IngestRequestError,
  readBoundedJson,
} from "@/lib/ingest-request";
import {
  isWaitlistStoreConfigured,
  markWaitlistConfirmationSent,
  updateWaitlistNotificationStatus,
  upsertWaitlistSubmission,
} from "@/lib/waitlist-store";
import { waitlistPayloadSchema } from "@/lib/validation";
import { sendWaitlistOwnerNotification } from "@/lib/waitlist-owner-notification";
import { referralUrl } from "@/lib/waitlist-referral";
import { createWaitlistProfileToken, waitlistConfirmUrl } from "@/lib/waitlist-confirm";
import { hashDeviceId, hashNetwork } from "@/lib/waitlist-signals";
import { waitlistUnsubscribeSecret, waitlistUnsubscribeUrl } from "@/lib/waitlist-unsubscribe";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const MAX_REQUEST_BODY_BYTES = 4 * 1024;

class PayloadTooLargeError extends Error {
  constructor() {
    super("Payload too large.");
    this.name = "PayloadTooLargeError";
  }
}

class InvalidJsonError extends Error {
  constructor() {
    super("Invalid JSON.");
    this.name = "InvalidJsonError";
  }
}

class EmptyBodyError extends Error {
  constructor() {
    super("Request body is required.");
    this.name = "EmptyBodyError";
  }
}

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
  headers: HeadersInit = {},
) {
  return NextResponse.json(body, {
    status,
    headers: {
      "Cache-Control": "no-store, max-age=0",
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Resource-Policy": "same-origin",
      "Origin-Agent-Cluster": "?1",
      Pragma: "no-cache",
      "X-Content-Type-Options": "nosniff",
      "X-DNS-Prefetch-Control": "off",
      "X-Permitted-Cross-Domain-Policies": "none",
      ...headers,
    },
  });
}

function methodNotAllowed() {
  return jsonResponse(
    {
      ok: false,
      code: "method_not_allowed",
      message: "Only POST is supported.",
      requestId: randomUUID(),
    },
    405,
    { Allow: "POST" },
  );
}

function optionsResponse() {
  return new NextResponse(null, {
    status: 204,
    headers: {
      Allow: "POST, OPTIONS",
      "Accept-Post": "application/json",
      "Cache-Control": "no-store, max-age=0",
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Resource-Policy": "same-origin",
      "Origin-Agent-Cluster": "?1",
      Pragma: "no-cache",
      "X-Content-Type-Options": "nosniff",
      "X-DNS-Prefetch-Control": "off",
      "X-Permitted-Cross-Domain-Policies": "none",
    },
  });
}

function isSameOrigin(request: Request) {
  const requestOrigin = new URL(request.url).origin;
  const origin = request.headers.get("origin");
  const referer = request.headers.get("referer");

  if (origin) {
    return origin === requestOrigin;
  }

  if (referer) {
    try {
      return new URL(referer).origin === requestOrigin;
    } catch {
      return false;
    }
  }

  return true;
}

function passesFetchSiteProtection(request: Request) {
  const fetchSite = request.headers.get("sec-fetch-site")?.trim().toLowerCase();
  if (!fetchSite) return true;
  return fetchSite === "same-origin" || fetchSite === "same-site" || fetchSite === "none";
}


function getUserAgent(request: Request) {
  return request.headers.get("user-agent")?.trim() ?? "unknown";
}

function getContentLength(request: Request) {
  const value = request.headers.get("content-length");
  if (!value) return null;

  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
}

async function sendApplicantConfirmationEmail(payload: {
  email: string;
  name?: string;
  alreadyRegistered: boolean;
  referral?: { code: string; qualified: number; target: number };
}) {
  const env = getServerEnv();
  const resend = getResendClient(env.resendApiKey);
  const siteUrl = getSiteUrl();
  const unsubscribeUrl = waitlistUnsubscribeUrl(siteUrl, payload.email);
  const message = renderApplicantWaitlistEmail({
    email: payload.email,
    name: payload.name,
    siteUrl,
    variant: payload.alreadyRegistered ? "existing" : "new",
    unsubscribeUrl,
    referralUrl: payload.referral ? referralUrl(siteUrl, payload.referral.code) : undefined,
    confirmUrl: waitlistConfirmUrl(siteUrl, payload.email),
    referralTarget: payload.referral?.target,
  });

  return resend.emails.send({
    from: env.waitlistFromEmail,
    to: payload.email,
    replyTo: env.waitlistReplyToEmail,
    subject: message.subject,
    text: message.text,
    html: message.html,
    // RFC 8058 one-click unsubscribe: mail clients show a native control.
    ...(unsubscribeUrl
      ? {
          headers: {
            "List-Unsubscribe": `<${unsubscribeUrl}>`,
            "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
          },
        }
      : {}),
  });
}

/**
 * Sends the welcome email and the owner notice after the signup response has
 * gone out. Runs both sends at once, records the outcome on the signup row,
 * and never throws: a mail problem must not undo or hide a stored signup.
 */
async function deliverWaitlistEmails(input: {
  email: string;
  name?: string;
  source?: string;
  metadata?: Record<string, string>;
  alreadyRegistered: boolean;
  referral?: { code: string; qualified: number; target: number; confirmed: boolean };
  requestId: string;
}) {
  try {
    const [applicant, owner] = await Promise.allSettled([
      sendApplicantConfirmationEmail({
        email: input.email,
        name: input.name,
        alreadyRegistered: input.alreadyRegistered,
        referral: input.referral,
      }),
      // One owner notice per new signup; repeat submissions send none.
      input.alreadyRegistered
        ? Promise.resolve(null)
        : sendWaitlistOwnerNotification({
            email: input.email,
            name: input.name,
            source: input.source,
            metadata: input.metadata,
            requestId: input.requestId,
          }),
    ]);

    const applicantError =
      applicant.status === "rejected"
        ? { name: "Error", message: applicant.reason instanceof Error ? applicant.reason.message : "Unknown error" }
        : applicant.value.error;

    if (applicantError) {
      console.error("[CmdTab Website] waitlist delivery failed", {
        requestId: input.requestId,
        errorName: applicantError.name,
        errorMessage: applicantError.message,
      });
      await updateWaitlistNotificationStatus(input.email, "failed", applicantError.message);
    } else {
      await Promise.all([
        updateWaitlistNotificationStatus(input.email, "delivered"),
        markWaitlistConfirmationSent(input.email),
      ]);
    }

    const ownerError =
      owner.status === "rejected"
        ? { name: "Error" }
        : owner.value && "error" in owner.value
          ? owner.value.error
          : null;
    if (ownerError) {
      console.error("[CmdTab Website] waitlist owner notification failed", {
        requestId: input.requestId,
        errorName: ownerError.name,
      });
    }
  } catch (error) {
    console.error("[CmdTab Website] waitlist background delivery failed", {
      requestId: input.requestId,
      error: error instanceof Error ? error.message : "Unknown error",
    });
  }
}

/**
 * The one success response for every non-error outcome: new signup, address
 * already on the list, another spelling of a registered mailbox, and a repeat
 * within 24 hours. Same keys in every case, and nothing in it depends on the
 * address except an opaque token that is valid for whatever was typed, so it
 * reveals nothing about the address (the form must never say who is on the
 * list). The token only authorizes one optional write, see /api/waitlist/profile.
 */
function signupSuccess(requestId: string, typedEmail: string) {
  const secret = waitlistUnsubscribeSecret();
  return jsonResponse({
    ok: true,
    code: "waitlist_submitted",
    message: waitlistEmailContent.applicant.onPageMessage,
    requestId,
    submittedAt: new Date().toISOString(),
    notificationQueued: true,
    profileToken: secret ? createWaitlistProfileToken(typedEmail, secret) : undefined,
  });
}

/** Signup needs a durable store, a way to email, and the secret that signs links. */
function waitlistSignupReady() {
  if (!isWaitlistStoreConfigured() || !waitlistUnsubscribeSecret()) return false;
  try {
    getServerEnv();
    return true;
  } catch {
    return false;
  }
}

async function parseRequestBody(request: Request) {
  try {
    return await readBoundedJson(request, MAX_REQUEST_BODY_BYTES);
  } catch (error) {
    if (error instanceof IngestRequestError) {
      if (error.code === "payload_too_large") throw new PayloadTooLargeError();
      if (error.message.includes("required")) throw new EmptyBodyError();
    }
    throw new InvalidJsonError();
  }
}

export async function POST(request: Request) {
  const requestId = randomUUID();

  if (!isSameOrigin(request) || !passesFetchSiteProtection(request)) {
    return jsonResponse(
      {
        ok: false,
        code: "validation_error",
        message: "Cross-site submissions are not allowed.",
        requestId,
      },
      403,
    );
  }

  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.includes("application/json")) {
    return jsonResponse(
      {
        ok: false,
        code: "validation_error",
        message: "JSON submissions are required.",
        requestId,
      },
      415,
    );
  }

  const declaredLength = getContentLength(request);
  if (declaredLength !== null && declaredLength > MAX_REQUEST_BODY_BYTES) {
    return jsonResponse(
      {
        ok: false,
        code: "validation_error",
        message: "Submission too large.",
        requestId,
      },
      413,
    );
  }

  try {
    const body = await parseRequestBody(request);
    const payload = waitlistPayloadSchema.parse(body);

    if (payload.honeypot) {
      return jsonResponse(
        {
          ok: true,
          code: "waitlist_submitted",
          requestId,
          submittedAt: new Date().toISOString(),
        },
        200,
      );
    }

    // Local, free checks first: with no store, mail key or link secret the
    // signup cannot be honoured, so refuse before doing any network work.
    if (!waitlistSignupReady()) {
      return jsonResponse(
        {
          ok: false,
          code: "service_unavailable",
          message: "The waitlist is temporarily unavailable. Please try again shortly.",
          requestId,
        },
        503,
      );
    }

    const ip = getClientIp(request);
    const userAgent = getUserAgent(request);
    const emailFingerprint = createFingerprint(payload.email);
    const requestFingerprint = createFingerprint(
      `${payload.email}|${payload.source ?? "homepage"}|${ip}`,
    );

    // The abuse check and the duplicate lookups are independent reads/writes,
    // so run them together. Nothing is stored unless the limiter allows it.
    const [rateLimit, alreadySubmitted] = await Promise.all([
      checkRateLimit({ email: payload.email, ip, userAgent }),
      recentlySubmittedAny([emailFingerprint, requestFingerprint]),
    ]);

    if (!rateLimit.allowed) {
      if ("unavailable" in rateLimit) {
        return jsonResponse(
          {
            ok: false,
            code: "service_unavailable",
            message: "Abuse protection is temporarily unavailable. Please try again shortly.",
            requestId,
          },
          503,
          { "Retry-After": String(rateLimit.retryAfterSeconds) },
        );
      }
      return jsonResponse(
        {
          ok: false,
          code: "rate_limited",
          message: "Please wait a moment before trying again.",
          retryAfterSeconds: rateLimit.retryAfterSeconds,
          requestId,
        },
        429,
        { "Retry-After": String(rateLimit.retryAfterSeconds) },
      );
    }

    if (alreadySubmitted) {
      // A repeat within 24 hours: answer exactly like a first signup, so the
      // response cannot be used to learn who recently signed up.
      return signupSuccess(requestId, payload.email);
    }

    const upsertResult = await upsertWaitlistSubmission({
      email: payload.email,
      name: payload.name,
      source: payload.source,
      metadata: payload.metadata,
      referralCode: payload.referralCode,
      marketingConsent: payload.marketingConsent,
      deviceHash: hashDeviceId(payload.deviceId),
      networkHash: hashNetwork(ip),
      requestId,
    });

    // The web response never carries anything about the address: no invite
    // code, no progress, no verification or reward state, and nothing that says
    // whether it was already on the list. The personal invite link goes only to
    // the mailbox, by email (below).
    const referral = upsertResult.referral
      ? {
          code: upsertResult.referral.code,
          qualified: upsertResult.referral.qualified,
          target: upsertResult.referral.target,
          confirmed: upsertResult.referral.confirmed,
        }
      : undefined;

    // Remember the submission before replying, so a double click or a retry
    // cannot send a second welcome email.
    await markSubmittedAll([emailFingerprint, requestFingerprint]);

    // A different spelling of an already-registered mailbox is not a new
    // signup: send nothing and answer exactly like a normal success.
    if (!upsertResult.aliasOfExisting) {
      // The person is in the beta as soon as the signup is stored. Email goes
      // out after the response, both messages at once, so the page never waits
      // on the mail provider.
      after(() =>
        deliverWaitlistEmails({
          email: upsertResult.submission.email,
          name: payload.name,
          source: payload.source,
          metadata: payload.metadata,
          alreadyRegistered: upsertResult.alreadyRegistered,
          referral,
          requestId,
        }),
      );
    }

    return signupSuccess(requestId, payload.email);
  } catch (error) {
    if (error instanceof PayloadTooLargeError) {
      return jsonResponse(
        {
          ok: false,
          code: "validation_error",
          message: "Submission too large.",
          requestId,
        },
        413,
      );
    }

    if (error instanceof ZodError) {
      const fieldErrors = error.flatten().fieldErrors;
      return jsonResponse(
        {
          ok: false,
          code: "validation_error",
          message: "Please check the highlighted fields and try again.",
          fieldErrors,
          requestId,
        },
        400,
      );
    }

    if (error instanceof InvalidJsonError) {
      return jsonResponse(
        {
          ok: false,
          code: "validation_error",
          message: "Malformed JSON payload.",
          requestId,
        },
        400,
      );
    }

    if (error instanceof EmptyBodyError) {
      return jsonResponse(
        {
          ok: false,
          code: "validation_error",
          message: "Request body is required.",
          requestId,
        },
        400,
      );
    }

    console.error("[CmdTab Website] waitlist request failed", {
      requestId,
      error: error instanceof Error ? error.message : "Unknown error",
    });

    return jsonResponse(
      {
        ok: false,
        code: "service_unavailable",
        message: "The waitlist is temporarily unavailable. Please try again shortly.",
        requestId,
      },
      503,
    );
  }
}

export async function GET() {
  return methodNotAllowed();
}

export async function PUT() {
  return methodNotAllowed();
}

export async function PATCH() {
  return methodNotAllowed();
}

export async function DELETE() {
  return methodNotAllowed();
}

export async function HEAD() {
  return methodNotAllowed();
}

export async function OPTIONS() {
  return optionsResponse();
}
