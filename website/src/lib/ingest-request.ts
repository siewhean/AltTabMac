import { NextResponse } from "next/server";

import {
  checkIngestRateLimit,
  type IngestEndpoint,
} from "@/lib/rate-limit";

export class IngestRequestError extends Error {
  constructor(
    readonly code: "invalid_request" | "payload_too_large" | "unsupported_media_type",
    readonly status: 400 | 413 | 415,
    message: string,
  ) {
    super(message);
    this.name = "IngestRequestError";
  }
}

export function ingestJsonResponse(
  body: Record<string, unknown>,
  status: number,
  headers: HeadersInit = {},
) {
  return NextResponse.json(body, {
    status,
    headers: {
      "Cache-Control": "no-store, max-age=0",
      "Cross-Origin-Resource-Policy": "same-origin",
      Pragma: "no-cache",
      "X-Content-Type-Options": "nosniff",
      ...headers,
    },
  });
}

export function isAllowedIngestRequest(request: Request) {
  const origin = request.headers.get("origin");
  const host = request.headers.get("host")?.trim().toLowerCase();
  const fetchSite = request.headers.get("sec-fetch-site")?.trim().toLowerCase();

  if (origin) {
    try {
      if (!host || new URL(origin).host.toLowerCase() !== host) return false;
    } catch {
      return false;
    }
  }

  return !fetchSite || fetchSite === "same-origin" || fetchSite === "same-site" || fetchSite === "none";
}

export function getIngestClient(request: Request) {
  const isVercelRequest = request.headers.has("x-vercel-id");
  const realIp = isVercelRequest ? request.headers.get("x-real-ip")?.trim() : undefined;
  const forwardedFor = isVercelRequest
    ? request.headers.get("x-forwarded-for")?.split(",")[0]?.trim()
    : undefined;

  return {
    ip: realIp || forwardedFor || "unknown",
    userAgent: request.headers.get("user-agent")?.trim() || "unknown",
  };
}

export function enforceIngestRateLimit(
  request: Request,
  endpoint: IngestEndpoint,
) {
  return checkIngestRateLimit({ endpoint, ...getIngestClient(request) });
}

export async function readBoundedText(request: Request, maxBytes: number) {
  const contentType = request.headers.get("content-type")?.toLowerCase() ?? "";
  const mediaType = contentType.split(";", 1)[0]?.trim();
  if (mediaType !== "application/json") {
    throw new IngestRequestError(
      "unsupported_media_type",
      415,
      "Content-Type must be application/json.",
    );
  }

  const declaredLength = Number.parseInt(request.headers.get("content-length") ?? "", 10);
  if (Number.isFinite(declaredLength) && declaredLength > maxBytes) {
    throw new IngestRequestError("payload_too_large", 413, "Request body is too large.");
  }

  if (!request.body) {
    throw new IngestRequestError("invalid_request", 400, "Request body is required.");
  }

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    totalBytes += value.byteLength;
    if (totalBytes > maxBytes) {
      await reader.cancel();
      throw new IngestRequestError("payload_too_large", 413, "Request body is too large.");
    }
    chunks.push(value);
  }

  if (totalBytes === 0) {
    throw new IngestRequestError("invalid_request", 400, "Request body is required.");
  }

  const body = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    body.set(chunk, offset);
    offset += chunk.byteLength;
  }

  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(body);
  } catch {
    throw new IngestRequestError("invalid_request", 400, "Request body must be valid UTF-8 JSON.");
  }
}

export async function readBoundedJson(request: Request, maxBytes: number) {
  try {
    return JSON.parse(await readBoundedText(request, maxBytes)) as unknown;
  } catch (error) {
    if (error instanceof IngestRequestError) throw error;
    throw new IngestRequestError("invalid_request", 400, "Request body must be valid JSON.");
  }
}
