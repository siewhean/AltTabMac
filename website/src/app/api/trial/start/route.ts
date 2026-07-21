import { NextResponse } from "next/server";
import { z } from "zod";

import { renderTrialStartedEmail } from "@/content/trial-email";
import { createOrGetTrialClaim } from "@/lib/trial-claim-store";
import { getServerEnv, getSiteUrl } from "@/lib/env";
import {
  checkEndpointRateLimit,
  readRequestBody,
  RequestBodyTooLargeError,
} from "@/lib/rate-limit";
import { getResendClient } from "@/lib/resend";

const MAX_REQUEST_BODY_BYTES = 4 * 1024;

const payloadSchema = z.object({
  email: z.string().trim().email().max(320),
  installId: z.string().trim().min(8).max(120),
  appVersion: z.string().trim().max(80).optional(),
  osVersion: z.string().trim().max(80).optional(),
});

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function isJsonRequest(request: Request) {
  const mediaType = request.headers.get("content-type")?.split(";", 1)[0];
  return mediaType?.trim().toLowerCase() === "application/json";
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

function errorResponse(message: string, status: number, code = "invalid_request") {
  return NextResponse.json({ ok: false, code, message }, { status });
}

async function sendTrialStartedEmail(input: {
  email: string;
  startedAt: string;
  endsAt: string;
}) {
  const env = getServerEnv();
  const resend = getResendClient(env.resendApiKey);
  const message = renderTrialStartedEmail({
    email: input.email,
    startedAt: input.startedAt,
    endsAt: input.endsAt,
    siteUrl: getSiteUrl(),
  });

  return resend.emails.send({
    from: env.licenseDeliveryFromEmail ?? env.waitlistFromEmail,
    to: input.email,
    replyTo: env.waitlistReplyToEmail,
    subject: message.subject,
    text: message.text,
    html: message.html,
  });
}

export async function POST(request: Request) {
  if (!isJsonRequest(request)) {
    return errorResponse("Content-Type must be application/json.", 415);
  }

  let body: unknown;
  try {
    const rawBody = await readRequestBody(request, MAX_REQUEST_BODY_BYTES);
    body = JSON.parse(rawBody) as unknown;
  } catch (error) {
    if (error instanceof RequestBodyTooLargeError) {
      return errorResponse("The request is too large.", 413);
    }
    return errorResponse("The request is not valid JSON.", 400);
  }

  const parsed = payloadSchema.safeParse(body);
  if (!parsed.success) {
    return errorResponse("The request is invalid.", 400);
  }

  const payload = parsed.data;
  const ip = getClientIp(request);
  let rateLimit;
  try {
    rateLimit = await checkEndpointRateLimit({
      endpoint: "trial-start",
      identifiers: [
        `email:${payload.email.toLowerCase()}`,
        `install:${payload.installId}`,
        ...(ip === "unknown" ? [] : [`ip:${ip}`]),
      ],
    });
  } catch (error) {
    console.error("[CmdTab Website] trial rate limit failed", error);
    return errorResponse("The trial service is temporarily unavailable.", 503, "service_unavailable");
  }

  if (!rateLimit.allowed) {
    return NextResponse.json(
      {
        ok: false,
        code: "rate_limited",
        message: "Too many requests. Please try again shortly.",
      },
      {
        status: 429,
        headers: { "Retry-After": String(rateLimit.retryAfterSeconds) },
      },
    );
  }

  try {
    const result = await createOrGetTrialClaim({
      email: payload.email,
      installId: payload.installId,
      appVersion: payload.appVersion,
      osVersion: payload.osVersion,
      trialLengthDays: 14,
    });

    if (result.kind === "blocked") {
      return NextResponse.json(
        {
          ok: false,
          code: result.reason,
          message:
            result.reason === "email_already_used"
              ? "This email has already started a CmdTab trial."
              : "This Mac already has a trial registered with another email.",
        },
        { status: 409 },
      );
    }

    let notificationDelivered = false;
    if (result.kind === "created") {
      try {
        await sendTrialStartedEmail({
          email: result.claim.email,
          startedAt: result.claim.startedAt,
          endsAt: result.claim.endsAt,
        });
        notificationDelivered = true;
      } catch (error) {
        console.error("[CmdTab Website] trial start email failed", error);
      }
    }

    return NextResponse.json({
      ok: true,
      alreadyRegistered: result.kind === "existing",
      notificationDelivered,
      claim: result.claim,
    });
  } catch (error) {
    console.error("[CmdTab Website] trial start failed", error);
    return errorResponse("We could not start the trial right now.", 500);
  }
}
