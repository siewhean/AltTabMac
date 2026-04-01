import { randomUUID } from "node:crypto";

import { NextResponse } from "next/server";
import { ZodError } from "zod";

import {
  licenseEmailContent,
  renderApplicantLicenseEmail,
} from "@/content/license-email";
import { licenseRequestReasonOptions } from "@/content/commerce-pages";
import { getServerEnv, getSiteUrl } from "@/lib/env";
import {
  checkRateLimit,
  createFingerprint,
  markSubmitted,
  recentlySubmitted,
} from "@/lib/rate-limit";
import { getResendClient } from "@/lib/resend";
import {
  createLicenseRequest,
  isLicenseRequestStoreConfigured,
  updateLicenseRequestNotificationStatus,
} from "@/lib/license-request-store";
import { licenseHelpPayloadSchema } from "@/lib/validation";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const MAX_REQUEST_BODY_BYTES = 8 * 1024;

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

function reasonLabel(reason: string) {
  return (
    licenseRequestReasonOptions.find((option) => option.value === reason)?.label ??
    "General license help"
  );
}

function formatMetadata(metadata?: Record<string, string>) {
  if (!metadata || Object.keys(metadata).length === 0) return "None provided";

  return Object.entries(metadata)
    .map(([key, value]) => `${key}: ${value}`)
    .join("\n");
}

async function parseRequestBody(request: Request) {
  const rawBody = await request.text();
  const bodyBytes = Buffer.byteLength(rawBody, "utf8");

  if (bodyBytes === 0) {
    throw new EmptyBodyError();
  }

  if (bodyBytes > MAX_REQUEST_BODY_BYTES) {
    throw new PayloadTooLargeError();
  }

  try {
    return JSON.parse(rawBody) as unknown;
  } catch {
    throw new InvalidJsonError();
  }
}

async function submitOwnerNotification(payload: {
  email: string;
  name?: string;
  purchaseEmail?: string;
  reason: string;
  message: string;
  metadata?: Record<string, string>;
  requestId: string;
}) {
  const env = getServerEnv();
  const resend = getResendClient(env.resendApiKey);

  const text = [
    licenseEmailContent.ownerNotification.heading,
    "",
    `Request ID: ${payload.requestId}`,
    `Email: ${payload.email}`,
    `Name: ${payload.name || "Not provided"}`,
    `Purchase email: ${payload.purchaseEmail || "Not provided"}`,
    `Reason: ${reasonLabel(payload.reason)}`,
    "",
    "Message:",
    payload.message,
    "",
    "Metadata:",
    formatMetadata(payload.metadata),
  ].join("\n");

  return resend.emails.send({
    from: env.waitlistFromEmail,
    to: env.waitlistToEmail,
    replyTo: env.waitlistReplyToEmail ?? payload.email,
    subject: licenseEmailContent.ownerNotification.subject,
    text,
  });
}

async function sendApplicantConfirmationEmail(payload: {
  email: string;
  name?: string;
  reason: string;
}) {
  const env = getServerEnv();
  const resend = getResendClient(env.resendApiKey);
  const message = renderApplicantLicenseEmail({
    name: payload.name,
    reasonLabel: reasonLabel(payload.reason),
    siteUrl: getSiteUrl(),
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
        message: "Content-Type must be application/json.",
        requestId,
      },
      415,
    );
  }

  try {
    const contentLength = request.headers.get("content-length");
    if (contentLength) {
      const parsedLength = Number.parseInt(contentLength, 10);
      if (Number.isFinite(parsedLength) && parsedLength > MAX_REQUEST_BODY_BYTES) {
        throw new PayloadTooLargeError();
      }
    }

    const body = await parseRequestBody(request);
    const payload = licenseHelpPayloadSchema.parse(body);

    const rateLimit = checkRateLimit({
      email: payload.email,
      ip: getClientIp(request),
      userAgent: getUserAgent(request),
    });

    if (!rateLimit.allowed) {
      return jsonResponse(
        {
          ok: false,
          code: "rate_limited",
          message: "Too many requests. Please try again shortly.",
          requestId,
        },
        429,
        { "Retry-After": String(rateLimit.retryAfterSeconds) },
      );
    }

    const duplicateFingerprint = createFingerprint(
      `${payload.email}|${payload.purchaseEmail ?? ""}|${payload.reason}|${payload.message.trim().toLowerCase()}`,
    );

    if (recentlySubmitted(duplicateFingerprint)) {
      return jsonResponse({
        ok: true,
        requestId,
        message: "We already received that request. We’ll reply by email.",
      });
    }

    if (!isLicenseRequestStoreConfigured()) {
      return jsonResponse(
        {
          ok: false,
          code: "service_unavailable",
          message: "License support is not configured yet.",
          requestId,
        },
        503,
      );
    }

    await createLicenseRequest({
      email: payload.email,
      name: payload.name,
      purchaseEmail: payload.purchaseEmail,
      reason: payload.reason,
      message: payload.message,
      metadata: payload.metadata,
      requestId,
    });

    let notificationError: string | undefined;
    try {
      await submitOwnerNotification({
        email: payload.email,
        name: payload.name,
        purchaseEmail: payload.purchaseEmail,
        reason: payload.reason,
        message: payload.message,
        metadata: payload.metadata,
        requestId,
      });
      await sendApplicantConfirmationEmail({
        email: payload.email,
        name: payload.name,
        reason: payload.reason,
      });
      await updateLicenseRequestNotificationStatus(requestId, "delivered");
    } catch (error) {
      notificationError = error instanceof Error ? error.message : "Unknown notification error.";
      await updateLicenseRequestNotificationStatus(requestId, "failed", notificationError);
    }

    markSubmitted(duplicateFingerprint);

    return jsonResponse({
      ok: true,
      requestId,
      message: notificationError
        ? "Your request was saved, but the notification email needs a retry."
        : "Your request is in. We’ll reply by email.",
      notificationDelivered: !notificationError,
    });
  } catch (error) {
    if (error instanceof PayloadTooLargeError) {
      return jsonResponse(
        {
          ok: false,
          code: "payload_too_large",
          message: "The request is too large.",
          requestId,
        },
        413,
      );
    }

    if (error instanceof EmptyBodyError || error instanceof InvalidJsonError) {
      return jsonResponse(
        {
          ok: false,
          code: "validation_error",
          message: error.message,
          requestId,
        },
        400,
      );
    }

    if (error instanceof ZodError) {
      const fieldErrors = error.flatten().fieldErrors;
      const normalizedFieldErrors = Object.fromEntries(
        Object.entries(fieldErrors as Record<string, string[] | undefined>).map(([key, value]) => [
          key,
          value?.[0] ?? "Invalid value.",
        ]),
      );
      return jsonResponse(
        {
          ok: false,
          code: "validation_error",
          message: "Please correct the highlighted fields.",
          requestId,
          fieldErrors: normalizedFieldErrors,
        },
        422,
      );
    }

    const message =
      error instanceof Error &&
      error.message.includes("Missing required waitlist email environment variables")
        ? "Email delivery is not configured yet."
        : "Unexpected error while creating the request.";

    return jsonResponse(
      {
        ok: false,
        code: "service_unavailable",
        message,
        requestId,
      },
      503,
    );
  }
}

export function OPTIONS() {
  return optionsResponse();
}

export function GET() {
  return methodNotAllowed();
}
