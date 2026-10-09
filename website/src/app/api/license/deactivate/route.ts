import { ZodError } from "zod";

import {
  getVerifiedLicense,
  licenseApiErrorResponse,
  licenseJson,
  readBoundedJson,
} from "@/lib/license-api";
import { deactivateLicenseSchema } from "@/lib/license-lifecycle-contract";
import {
  deactivateDevice,
  listLicensedDevices,
} from "@/lib/license-lifecycle-store";
import { enforceIngestRateLimit } from "@/lib/ingest-request";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const rateLimit = await enforceIngestRateLimit(request, "license-deactivation");
  if (!rateLimit.allowed) {
    return licenseJson(
      {
        ok: false,
        code: "rate_limited",
        message: "Too many deactivation attempts. Try again later.",
      },
      "unavailable" in rateLimit ? 503 : 429,
    );
  }

  try {
    const payload = deactivateLicenseSchema.parse(await readBoundedJson(request));
    const { verified, pepper } = await getVerifiedLicense(payload.licenseKey);
    const result = await deactivateDevice({
      licenseId: verified.payload.licenseID,
      deviceId: payload.deviceId,
      pepper,
    });
    if (result.kind === "limit_reached") {
      return licenseJson(
        {
          ok: false,
          code: "deactivation_limit",
          message:
            "This license has freed too many device slots recently. Try again later or contact support.",
        },
        429,
      );
    }
    return licenseJson({
      ok: true,
      devices: await listLicensedDevices({
        licenseId: verified.payload.licenseID,
        pepper,
      }),
    });
  } catch (error) {
    if (error instanceof ZodError) {
      return licenseJson(
        { ok: false, code: "validation_error", message: "Check the device details." },
        400,
      );
    }
    return licenseApiErrorResponse(error);
  }
}
