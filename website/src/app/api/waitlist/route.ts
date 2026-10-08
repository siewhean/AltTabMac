import { randomUUID } from "node:crypto";

import { NextResponse } from "next/server";
import { ZodError } from "zod";

import {
  renderApplicantWaitlistEmail,
  waitlistEmailContent,
} from "@/content/waitlist-email";
import { getServerEnv, getSiteUrl } from "@/lib/env";
import {
  checkRateLimit,
} from "@/lib/rate-limit";
import { getResendClient } from "@/lib/resend";
import {
  IngestRequestError,
  readBoundedJson,
} from "@/lib/ingest-request";
import {
  isWaitlistStoreConfigured,
  updateWaitlistNotificationStatus,
  upsertWaitlistSubmission,
} from "@/lib/waitlist-store";
import { waitlistPayloadSchema } from "@/lib/validation";
import { isSameOriginFormRequest } from "@/lib/form-request-origin";

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

function passesFetchSiteProtection(request: Request) {
  const fetchSite = request.headers.get("sec-fetch-site")?.trim().toLowerCase();
  if (!fetchSite) return true;
  return fetchSite === "same-origin" || fetchSite === "same-site" || fetchSite === "none";
}

function getClientIp(request: Request) {
  const realIp = request.headers.get("x-real-ip")?.trim();
  if (realIp) return realIp;

  const forwardedFor = request.headers.get("x-forwarded-for");
  if (request.headers.has("x-vercel-id") && forwardedFor) {
    return forwardedFor.split(",")[0]?.trim() ?? "unknown";
  }

  return "unknown";
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

function formatMetadata(metadata?: Record<string, string>) {
  if (!metadata || Object.keys(metadata).length === 0) return "None provided";

  return Object.entries(metadata)
    .map(([key, value]) => `${key}: ${value}`)
    .join("\n");
}

async function sendApplicantConfirmationEmail(payload: {
  email: string;
  name?: string;
  alreadyRegistered: boolean;
}) {
  const env = getServerEnv();
  const resend = getResendClient(env.resendApiKey);
  const message = renderApplicantWaitlistEmail({
    email: payload.email,
    name: payload.name,
    siteUrl: getSiteUrl(),
    variant: payload.alreadyRegistered ? "existing" : "new",
  });

  return resend.emails.send({
    from: env.waitlistFromEmail,
    to: payload.email,
    replyTo: env.waitlistReplyToEmail,
    subject: message.subject,
    text: message.text,
    html: message.html,
  });
}

function shouldSendOwnerNotification(applicantEmail: string) {
  const env = getServerEnv();
  return env.waitlistToEmail.trim().toLowerCase() !== applicantEmail.trim().toLowerCase();
}

async function submitWaitlistNotification(payload: {
  email: string;
  name?: string;
  source?: string;
  metadata?: Record<string, string>;
  requestId: string;
}) {
  const env = getServerEnv();
  const resend = getResendClient(env.resendApiKey);

  const text = [
    waitlistEmailContent.ownerNotification.heading,
    "",
    `Request ID: ${payload.requestId}`,
    `Email: ${payload.email}`,
    `Name: ${payload.name || "Not provided"}`,
    `Source: ${payload.source || "Not provided"}`,
    "",
    "Metadata:",
    formatMetadata(payload.metadata),
  ].join("\n");

  return resend.emails.send({
    from: env.waitlistFromEmail,
    to: env.waitlistToEmail,
    replyTo: env.waitlistReplyToEmail ?? payload.email,
    subject: waitlistEmailContent.ownerNotification.subject,
    text,
  });
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

  if (!isSameOriginFormRequest(request) || !passesFetchSiteProtection(request)) {
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

    const ip = getClientIp(request);
    const userAgent = getUserAgent(request);
    const rateLimit = await checkRateLimit({
      email: payload.email,
      ip,
      userAgent,
    });

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

    if (!isWaitlistStoreConfigured()) {
      return jsonResponse({ ok: false, code: "service_unavailable", message: "The waitlist is temporarily unavailable. Please try again shortly.", requestId }, 503);
    }
    const upsertResult = await upsertWaitlistSubmission({
      email: payload.email,
      name: payload.name,
      source: payload.source,
      metadata: { ...payload.metadata, consent: "waitlist_updates_v1", consent_at: new Date().toISOString() },
      requestId,
    });
    const storedSubmission = upsertResult.submission;
    const alreadyRegistered = upsertResult.alreadyRegistered;

    // Enrollment depends on durable storage, not a third-party email provider.
    // Keep notification state available for operator follow-up without sending duplicates.
    if (alreadyRegistered) {
      return jsonResponse({ ok: true, code: "waitlist_submitted", message: waitlistEmailContent.applicant.onPageMessage.existing, requestId, submittedAt: storedSubmission.createdAt, notificationDelivered: storedSubmission.notificationStatus === "delivered" });
    }
    let notificationDelivered = false;
    try {
      // Validate configuration before starting promises, avoiding unhandled rejections.
      getServerEnv();
      const deliveryTasks = [
        sendApplicantConfirmationEmail({
          email: payload.email,
          name: payload.name,
          alreadyRegistered,
        }),
      ];

      if (shouldSendOwnerNotification(payload.email)) {
        deliveryTasks.push(
          submitWaitlistNotification({
            email: payload.email,
            name: payload.name,
            source: payload.source,
            metadata: payload.metadata,
            requestId,
          }),
        );
      }

      const deliveryResults = await Promise.all(deliveryTasks);
      const deliveryError = deliveryResults.find((result) => result.error)?.error;
      if (deliveryError) throw new Error("Email provider rejected waitlist notification.");
      await updateWaitlistNotificationStatus(storedSubmission.email, "delivered");
      notificationDelivered = true;
    } catch {
      console.error("[CmdTab Website] waitlist notification pending", { requestId });
      await updateWaitlistNotificationStatus(storedSubmission.email, "failed", "Notification unavailable; enrollment stored.").catch(() => undefined);
    }

    return jsonResponse({
      ok: true,
      code: "waitlist_submitted",
      message: alreadyRegistered
        ? waitlistEmailContent.applicant.onPageMessage.existing
        : waitlistEmailContent.applicant.onPageMessage.new,
      requestId,
      submittedAt: new Date().toISOString(),
      notificationDelivered,
    });
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
