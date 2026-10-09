import { ZodError } from "zod";

import {
  licenseApiErrorResponse,
  licenseJson,
  LicenseApiError,
  readBoundedJson,
} from "@/lib/license-api";
import { renewLicenseSchema } from "@/lib/license-lifecycle-contract";
import { findRenewableActivation } from "@/lib/license-lifecycle-store";
import { getLicenseLifecycleEnv } from "@/lib/env";
import { getLicenseTokenSigner, loadCmdTabPublicKeyrings } from "@/lib/aws-kms-p256";
import { verifyCmdTabTokenV2 } from "@/lib/entitlement-token";
import { issueCmdTabTokenV2 } from "@/lib/license-signing";
import { enforceIngestRateLimit } from "@/lib/ingest-request";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Renews a device's 30-day license lease. The signed, device-bound token is
 * the credential, so renewal keeps working after the purchase activation code
 * is rotated by recovery. An expired lease may still be renewed; the server
 * state (active slot, license not revoked) is what authorizes it.
 */
export async function POST(request: Request) {
  const rateLimit = await enforceIngestRateLimit(request, "license-renewal");
  if (!rateLimit.allowed) {
    return licenseJson(
      { ok: false, code: "rate_limited", message: "Too many renewal attempts. Try again later." },
      "unavailable" in rateLimit ? 503 : 429,
    );
  }

  try {
    const payload = renewLicenseSchema.parse(await readBoundedJson(request));
    const env = getLicenseLifecycleEnv();
    if (!env.lookupPepper) throw new LicenseApiError("not_configured", 503);

    let keyring: Readonly<Record<string, string>>;
    try {
      keyring = loadCmdTabPublicKeyrings().license;
    } catch {
      throw new LicenseApiError("not_configured", 503);
    }
    const verified = verifyCmdTabTokenV2({
      token: payload.entitlementToken,
      keyring,
      expectedType: "license",
      expectedBinding: { typ: "activation", value: payload.deviceId },
      allowExpired: true,
    });
    if (!verified || verified.tokenVersion !== 2) {
      throw new LicenseApiError("invalid_license", 401);
    }

    const activation = await findRenewableActivation({
      entitlementOrderHash: verified.payload.order,
      deviceId: payload.deviceId,
      pepper: env.lookupPepper,
    });
    if (activation.kind === "revoked") {
      return licenseJson(
        { ok: false, code: "license_revoked", message: "This license has been revoked." },
        403,
      );
    }
    if (activation.kind === "inactive") {
      return licenseJson(
        {
          ok: false,
          code: "device_inactive",
          message: "This Mac is no longer activated for this license.",
        },
        403,
      );
    }

    const entitlement = await issueCmdTabTokenV2({
      signer: getLicenseTokenSigner(),
      typ: "license",
      subjectIdentifier: { hash: activation.subjectHash },
      orderIdentifier: { hash: verified.payload.order },
      binding: { typ: "activation", value: payload.deviceId },
    });
    return licenseJson({ ok: true, entitlementToken: entitlement.token });
  } catch (error) {
    if (error instanceof ZodError) {
      return licenseJson(
        { ok: false, code: "validation_error", message: "Check the renewal details." },
        400,
      );
    }
    return licenseApiErrorResponse(error);
  }
}
