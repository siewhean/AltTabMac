import { NextResponse } from "next/server";
import { z } from "zod";

import { renderTrialStartedEmail } from "@/content/trial-email";
import { createOrGetTrialClaim } from "@/lib/trial-claim-store";
import { getServerEnv, getSiteUrl } from "@/lib/env";
import { getResendClient } from "@/lib/resend";

const payloadSchema = z.object({
  email: z.string().trim().email().max(320),
  installId: z.string().trim().min(8).max(120),
  appVersion: z.string().trim().max(80).optional(),
  osVersion: z.string().trim().max(80).optional(),
});

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

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
  try {
    const payload = payloadSchema.parse(await request.json());
    const result = await createOrGetTrialClaim({
      email: payload.email,
      installId: payload.installId,
      appVersion: payload.appVersion,
      osVersion: payload.osVersion,
      trialLengthDays: 14,
    });

    if (result.kind === "blocked") {
      return NextResponse.json(
        {
          ok: false,
          code: result.reason,
          message:
            result.reason === "email_already_used"
              ? "This email has already started a CmdTab trial."
              : "This Mac already has a trial registered with another email.",
        },
        { status: 409 },
      );
    }

    let notificationDelivered = false;
    if (result.kind === "created") {
      try {
        await sendTrialStartedEmail({
          email: result.claim.email,
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
      notificationDelivered,
      claim: result.claim,
    });
  } catch (error) {
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
