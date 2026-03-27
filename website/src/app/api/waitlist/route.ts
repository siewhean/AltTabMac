import { randomUUID } from "node:crypto";

import { NextResponse } from "next/server";
import { ZodError } from "zod";

import { getServerEnv } from "@/lib/env";
import {
  checkRateLimit,
  createFingerprint,
  markSubmitted,
  recentlySubmitted,
} from "@/lib/rate-limit";
import { getResendClient } from "@/lib/resend";
import { waitlistPayloadSchema } from "@/lib/validation";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
  headers: HeadersInit = {},
) {
  return NextResponse.json(body, {
    status,
    headers: {
      "Cache-Control": "no-store, max-age=0",
      Pragma: "no-cache",
      "X-Content-Type-Options": "nosniff",
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

function getClientIp(request: Request) {
  const forwardedFor = request.headers.get("x-forwarded-for");
  if (forwardedFor) {
    return forwardedFor.split(",")[0]?.trim() ?? "unknown";
  }

  return request.headers.get("x-real-ip")?.trim() ?? "unknown";
}

function getUserAgent(request: Request) {
  return request.headers.get("user-agent")?.trim() ?? "unknown";
}

function formatMetadata(metadata?: Record<string, string>) {
  if (!metadata || Object.keys(metadata).length === 0) return "None provided";

  return Object.entries(metadata)
    .map(([key, value]) => `${key}: ${value}`)
    .join("\n");
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
    "CmdTab private beta waitlist submission",
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
    subject: "New CmdTab private beta waitlist signup",
    text,
  });
}

export async function POST(request: Request) {
  const requestId = randomUUID();

  if (!isSameOrigin(request)) {
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

  try {
    const body = await request.json();
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

    const ip = getClientIp(request);
    const userAgent = getUserAgent(request);
    const rateLimit = checkRateLimit({
      email: payload.email,
      ip,
      userAgent,
    });

    if (!rateLimit.allowed) {
      return jsonResponse(
        {
          ok: false,
          code: "rate_limited",
          message: "Please wait a moment before trying again.",
          retryAfterSeconds: rateLimit.retryAfterSeconds,
          requestId,
        },
        429,
      );
    }

    const emailFingerprint = createFingerprint(payload.email);
    const requestFingerprint = createFingerprint(
      `${payload.email}|${payload.source ?? "homepage"}|${ip}`,
    );

    if (recentlySubmitted(emailFingerprint) || recentlySubmitted(requestFingerprint)) {
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

    const result = await submitWaitlistNotification({
      email: payload.email,
      name: payload.name,
      source: payload.source,
      metadata: payload.metadata,
      requestId,
    });

    if (result.error) {
      console.error("[CmdTab Website] waitlist delivery failed", {
        requestId,
        errorName: result.error.name,
        errorMessage: result.error.message,
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

    markSubmitted(emailFingerprint);
    markSubmitted(requestFingerprint);

    return jsonResponse({
      ok: true,
      code: "waitlist_submitted",
      requestId,
      submittedAt: new Date().toISOString(),
    });
  } catch (error) {
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
