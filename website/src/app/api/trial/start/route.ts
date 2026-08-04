import { createHash } from "node:crypto";

import { NextResponse } from "next/server";
import { z, ZodError } from "zod";

import { renderTrialStartedEmail } from "@/content/trial-email";
import { createOrGetTrialClaim } from "@/lib/trial-claim-store";
import { getServerEnv, getSiteUrl, isCommerceLaunchEnabled } from "@/lib/env";
import { getResendClient } from "@/lib/resend";
import { getTrialTokenSigner } from "@/lib/aws-kms-p256";
import {
  enforceIngestRateLimit,
  IngestRequestError,
  ingestJsonResponse,
  readBoundedJson,
} from "@/lib/ingest-request";
import { issueCmdTabTokenV2 } from "@/lib/license-signing";

const MAX_REQUEST_BODY_BYTES = 4 * 1024;
const optionalEmailSchema = z.union([
  z.string().trim().email().max(320),
  z.literal(""),
]).optional();
const payloadSchema = z.object({
  email: optionalEmailSchema,
  installId: z.string().trim().regex(/^[a-f0-9]{64}$/),
  appVersion: z.string().trim().max(80).optional(),
  osVersion: z.string().trim().max(80).optional(),
});

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function anonymousTrialSubject(installId: string) {
  const digest = createHash("sha256")
    .update(`cmdtab-anonymous-trial:${installId}`)
    .digest("hex")
    .slice(0, 32);
  return `anonymous+${digest}@trial.cmdtab.invalid`;
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
  if (!isCommerceLaunchEnabled()) {
    return ingestJsonResponse(
      {
        ok: false,
        code: "commerce_disabled",
        message: "Trials are unavailable during this beta.",
      },
      503,
    );
  }

  const rateLimit = await enforceIngestRateLimit(request, "trial-start");
  if (!rateLimit.allowed) {
    if ("unavailable" in rateLimit) {
      return ingestJsonResponse({ ok: false, code: "service_unavailable" }, 503);
    }
    return ingestJsonResponse(
      { ok: false, code: "rate_limited" },
      429,
      { "Retry-After": String(rateLimit.retryAfterSeconds) },
    );
  }

  try {
    const payload = payloadSchema.parse(
      await readBoundedJson(request, MAX_REQUEST_BODY_BYTES),
    );
    const contactEmail = payload.email?.trim().toLowerCase() || undefined;
    const claimSubject = contactEmail ?? anonymousTrialSubject(payload.installId);
    const result = await createOrGetTrialClaim({
      email: claimSubject,
      installId: payload.installId,
      appVersion: payload.appVersion,
      osVersion: payload.osVersion,
      trialLengthDays: 14,
    });

    if (result.kind === "blocked") {
      return NextResponse.json(
        {
          ok: false,
          code: "trial_unavailable",
          message: "A CmdTab trial is already registered for this Mac or email.",
        },
        { status: 409 },
      );
    }

    const entitlement = await issueCmdTabTokenV2({
      signer: getTrialTokenSigner(),
      typ: "trial",
      subjectIdentifier: result.claim.email,
      orderIdentifier: result.claim.id,
      binding: {
        typ: "install",
        value: result.claim.installId,
      },
      issuedAt: new Date(result.claim.startedAt),
    });

    let notificationDelivered = false;
    if (result.kind === "created" && contactEmail) {
      try {
        await sendTrialStartedEmail({
          email: contactEmail,
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
      anonymous: !contactEmail,
      notificationDelivered,
      claim: result.claim,
      entitlementToken: entitlement.token,
      serverTime: new Date().toISOString(),
    });
  } catch (error) {
    if (error instanceof IngestRequestError) {
      return ingestJsonResponse(
        { ok: false, code: error.code, message: error.message },
        error.status,
      );
    }
    if (error instanceof ZodError) {
      return ingestJsonResponse(
        {
          ok: false,
          code: "invalid_request",
          message: "We could not start the trial with those details.",
        },
        400,
      );
    }
    console.error("[CmdTab Website] trial start failed", error);
    return NextResponse.json(
      {
        ok: false,
        code: "invalid_request",
        message: "We could not start the trial right now.",
      },
      { status: 400 },
    );
  }
}
