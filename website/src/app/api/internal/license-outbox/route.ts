import { timingSafeEqual } from "node:crypto";

import { getLicenseLifecycleEnv } from "@/lib/env";
import { licenseJson } from "@/lib/license-api";
import { processLicenseOutbox } from "@/lib/license-outbox";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function authorized(request: Request, secret: string) {
  const provided = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  const expectedBytes = Buffer.from(secret);
  const providedBytes = Buffer.from(provided);
  return (
    expectedBytes.length === providedBytes.length &&
    timingSafeEqual(expectedBytes, providedBytes)
  );
}

export async function POST(request: Request) {
  const secret = getLicenseLifecycleEnv().outboxSecret;
  if (!secret || !authorized(request, secret)) {
    return licenseJson(
      { ok: false, code: "unauthorized", message: "Unauthorized." },
      401,
    );
  }
  const result = await processLicenseOutbox(25);
  return licenseJson({ ok: true, ...result });
}
