import {
  getBearerLicense,
  licenseApiErrorResponse,
  licenseJson,
} from "@/lib/license-api";
import {
  ensureEntitlementForVerifiedLicense,
  listLicensedDevices,
} from "@/lib/license-lifecycle-store";
import { lookupHash } from "@/lib/license-lifecycle-contract";
import { isCommerceLaunchEnabled } from "@/lib/env";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  if (!isCommerceLaunchEnabled()) {
    return licenseJson(
      {
        ok: false,
        code: "commerce_disabled",
        message: "License device status is unavailable during this beta.",
      },
      503,
    );
  }

  try {
    const { verified, pepper } = await getBearerLicense(request);
    if (
      !(await ensureEntitlementForVerifiedLicense({
        licenseId: verified.payload.licenseID,
        pepper,
      }))
    ) {
      return licenseJson(
        {
          ok: false,
          code: "license_revoked",
          message: "This license has been revoked.",
        },
        403,
      );
    }
    const deviceId = request.headers.get("x-cmdtab-device-id")?.trim() ?? "";
    const currentHandle = /^[a-f0-9]{64}$/.test(deviceId)
      ? lookupHash("device", deviceId, pepper)
      : null;
    const devices = await listLicensedDevices({
      licenseId: verified.payload.licenseID,
      pepper,
    });
    return licenseJson({
      ok: true,
      limit: 3,
      devices: devices.map((device) => ({
        ...device,
        isCurrent: currentHandle !== null && device.deviceId === currentHandle,
      })),
      currentActivationActive:
        currentHandle === null
          ? null
          : devices.some((device) => device.deviceId === currentHandle),
    });
  } catch (error) {
    return licenseApiErrorResponse(error);
  }
}
