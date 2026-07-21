import { NextResponse } from "next/server";
import { z } from "zod";

import { getLicenseFulfillmentStatusByLicenseID } from "@/lib/license-fulfillment-store";
import {
  checkEndpointRateLimit,
  readRequestBody,
  RequestBodyTooLargeError,
} from "@/lib/rate-limit";

const MAX_REQUEST_BODY_BYTES = 4 * 1024;

const payloadSchema = z.object({
  licenseId: z.string().trim().min(8).max(120),
  installId: z.string().trim().min(8).max(120),
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

function normalizeLookup(input: string) {
  return input.trim().toLowerCase();
}

export async function POST(request: Request) {
  if (!isJsonRequest(request)) {
    return NextResponse.json(
      { ok: false, code: "unsupported_media_type", message: "Content-Type must be application/json." },
      { status: 415 },
    );
  }

  let body: unknown;
  try {
    const rawBody = await readRequestBody(request, MAX_REQUEST_BODY_BYTES);
    body = JSON.parse(rawBody) as unknown;
  } catch (error) {
    if (error instanceof RequestBodyTooLargeError) {
      return NextResponse.json(
        { ok: false, code: "payload_too_large", message: "The request is too large." },
        { status: 413 },
      );
    }

    return NextResponse.json(
      { ok: false, code: "invalid_payload", message: "The request is not valid JSON." },
      { status: 400 },
    );
  }

  const parsed = payloadSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { ok: false, code: "invalid_payload", message: "The request is invalid." },
      { status: 400 },
    );
  }

  const payload = parsed.data;
  const ip = getClientIp(request);

  try {
    const rateLimit = await checkEndpointRateLimit({
      endpoint: "license-status",
      identifiers: [
        `license:${normalizeLookup(payload.licenseId)}`,
        `install:${normalizeLookup(payload.installId)}`,
        ...(ip === "unknown" ? [] : [`ip:${ip}`]),
      ],
    });
    if (!rateLimit.allowed) {
      return NextResponse.json(
        {
          ok: false,
          code: "rate_limited",
          message: "Too many requests. Please try again shortly.",
        },
        { status: 429, headers: { "Retry-After": String(rateLimit.retryAfterSeconds) } },
      );
    }
  } catch (error) {
    console.error("[CmdTab Website] license status rate limit failed", error);
    return NextResponse.json(
      { ok: false, code: "service_unavailable", message: "The license status service is temporarily unavailable." },
      { status: 503 },
    );
  }

  try {
    const fulfillment = await getLicenseFulfillmentStatusByLicenseID(payload.licenseId);
    const deliveryStatus = fulfillment?.deliveryStatus ?? "not_found";
    const revoked = deliveryStatus === "refunded";

    return NextResponse.json({
      ok: true,
      revoked,
      status: fulfillment ? deliveryStatus : "not_found",
      deliveryStatus,
      licenseId: payload.licenseId,
    });
  } catch (error) {
    console.error("[CmdTab Website] license status lookup failed", {
      licenseId: payload.licenseId,
      error,
    });
    return NextResponse.json(
      {
        ok: false,
        code: "lookup_failed",
        message: "Unable to check license status right now.",
      },
      { status: 503 },
    );
  }
}
