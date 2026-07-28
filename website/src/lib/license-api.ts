import { NextResponse } from "next/server";

import { getLicenseLifecycleEnv } from "@/lib/env";
import {
  IngestRequestError,
  readBoundedJson as readBoundedIngestJson,
} from "@/lib/ingest-request";
import { verifyCmdTabLicenseToken } from "@/lib/license-token";
import { findLicenseByActivationCredential } from "@/lib/license-lifecycle-store";

const MAX_BODY_BYTES = 20 * 1024;

export function licenseJson(body: Record<string, unknown>, status = 200) {
  return NextResponse.json(body, {
    status,
    headers: {
      "Cache-Control": "no-store, max-age=0",
      "Content-Type": "application/json; charset=utf-8",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

export async function readBoundedJson(request: Request) {
  try {
    return await readBoundedIngestJson(request, MAX_BODY_BYTES);
  } catch (error) {
    if (error instanceof IngestRequestError) {
      throw new LicenseApiError(
        error.code === "invalid_request" ? "invalid_json" : error.code,
        error.status,
      );
    }
    throw error;
  }
}

export class LicenseApiError extends Error {
  constructor(
    readonly code: string,
    readonly status: number,
  ) {
    super(code);
  }
}

export async function getVerifiedLicense(licenseKey: string) {
  const env = getLicenseLifecycleEnv();
  if (!env.lookupPepper) {
    throw new LicenseApiError("not_configured", 503);
  }
  if (licenseKey.trim().startsWith("CMDTAB-ACT-")) {
    const purchase = await findLicenseByActivationCredential({
      credential: licenseKey,
      pepper: env.lookupPepper,
    });
    if (!purchase) throw new LicenseApiError("invalid_license", 401);
    return {
      verified: {
        tokenVersion: 0 as const,
        payload: {
          version: 0,
          product: "cmdtab",
          email: purchase.email,
          licenseID: purchase.licenseId,
          issuedAt: new Date(0).toISOString(),
        },
      },
      pepper: env.lookupPepper,
    };
  }
  if (!env.verificationKeyPem) {
    throw new LicenseApiError("not_configured", 503);
  }
  const verified = verifyCmdTabLicenseToken({
    token: licenseKey,
    publicKeyPem: env.verificationKeyPem,
  });
  if (!verified) throw new LicenseApiError("invalid_license", 401);
  return { verified, pepper: env.lookupPepper };
}

export async function getBearerLicense(request: Request) {
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    throw new LicenseApiError("missing_authorization", 401);
  }
  return getVerifiedLicense(authorization.slice("Bearer ".length));
}

export function licenseApiErrorResponse(error: unknown) {
  if (error instanceof LicenseApiError) {
    return licenseJson(
      {
        ok: false,
        code: error.code,
        message:
          error.status === 503
            ? "License services are temporarily unavailable."
            : "The license request could not be authorized.",
      },
      error.status,
    );
  }
  return licenseJson(
    {
      ok: false,
      code: "invalid_request",
      message: "The license request was not valid.",
    },
    400,
  );
}
