import { ZodError } from "zod";

import {
  licenseApiErrorResponse,
  licenseJson,
  getVerifiedLicense,
  readBoundedJson,
} from "@/lib/license-api";
import { activateLicenseSchema } from "@/lib/license-lifecycle-contract";
import {
  activateDevice,
  ensureEntitlementForVerifiedLicense,
} from "@/lib/license-lifecycle-store";
import { getLicenseTokenSigner } from "@/lib/aws-kms-p256";
import { issueCmdTabTokenV2 } from "@/lib/license-signing";
import { enforceIngestRateLimit } from "@/lib/ingest-request";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const rateLimit = await enforceIngestRateLimit(
    request,
    "license-activation",
  );
  if (!rateLimit.allowed) {
    return licenseJson(
      {
        ok: false,
        code: "rate_limited",
        message: "Too many activation attempts. Try again later.",
      },
      "unavailable" in rateLimit ? 503 : 429,
    );
  }

  try {
    const payload = activateLicenseSchema.parse(await readBoundedJson(request));
    const { verified, pepper } = await getVerifiedLicense(payload.licenseKey);
    const exists = await ensureEntitlementForVerifiedLicense({
      licenseId: verified.payload.licenseID,
      pepper,
    });
    if (!exists) {
      return licenseJson(
        {
          ok: false,
          code: "license_unavailable",
          message: "This license cannot be activated. Use recovery or contact support.",
        },
        403,
      );
    }

    // Sign before entering the serialized allocation transaction. A concurrent
    // refund that linearizes first is then observed by activateDevice and the
    // already-created token is discarded rather than returned after revocation.
    const entitlement = await issueCmdTabTokenV2({
      signer: getLicenseTokenSigner(),
      typ: "license",
      subjectIdentifier: verified.payload.email,
      orderIdentifier: verified.payload.licenseID,
      binding: {
        typ: "activation",
        value: payload.deviceId,
      },
    });
    const result = await activateDevice({
      licenseId: verified.payload.licenseID,
      deviceId: payload.deviceId,
      deviceName: payload.deviceName,
      pepper,
    });
    if (result.kind === "slot_full") {
      return licenseJson(
        {
          ok: false,
          code: "slot_full",
          message: "All three CmdTab device slots are in use.",
          devices: result.devices,
        },
        409,
      );
    }
    if (result.kind === "revoked" || result.kind === "unknown_license") {
      return licenseJson(
        {
          ok: false,
          code: "license_unavailable",
          message: "This license cannot be activated.",
        },
        403,
      );
    }
    if (result.kind === "activated" || result.kind === "existing") {
      return licenseJson({
        ok: true,
        alreadyActivated: result.kind === "existing",
        devices: result.devices,
        entitlementToken: entitlement.token,
      });
    }
    return licenseJson(
      { ok: false, code: "license_unavailable", message: "This license cannot be activated." },
      403,
    );
  } catch (error) {
    if (error instanceof ZodError) {
      return licenseJson(
        { ok: false, code: "validation_error", message: "Check the activation details." },
        400,
      );
    }
    return licenseApiErrorResponse(error);
  }
}
