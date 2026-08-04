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
import { isCommerceLaunchEnabled } from "@/lib/env";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  if (!isCommerceLaunchEnabled()) {
    return licenseJson(
      {
        ok: false,
        code: "commerce_disabled",
        message: "License deactivation is unavailable during this beta.",
      },
      503,
    );
  }

  try {
    const payload = deactivateLicenseSchema.parse(await readBoundedJson(request));
    const { verified, pepper } = await getVerifiedLicense(payload.licenseKey);
    await deactivateDevice({
      licenseId: verified.payload.licenseID,
      deviceId: payload.deviceId,
      pepper,
    });
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
