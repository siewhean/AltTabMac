import { NextResponse } from "next/server";

import { renderTrialReminderEmail } from "@/content/trial-email";
import {
  getServerEnv,
  getSiteUrl,
  isCommerceLaunchEnabled,
  optionalStrongInternalSecret,
} from "@/lib/env";
import { isAuthorizedInternalWorker } from "@/lib/internal-worker-auth";
import {
  listTrialClaimsDueForReminder,
  markTrialReminderSent,
} from "@/lib/trial-claim-store";
import { getResendClient } from "@/lib/resend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function isAuthorized(request: Request) {
  return isAuthorizedInternalWorker(
    request,
    optionalStrongInternalSecret(process.env.CRON_SECRET),
  );
}

export async function GET(request: Request) {
  if (!isCommerceLaunchEnabled()) {
    return NextResponse.json(
      { ok: false, code: "commerce_disabled", message: "Trial reminders are disabled." },
      { status: 503 },
    );
  }

  if (!isAuthorized(request)) {
    return NextResponse.json({ ok: false, message: "Unauthorized" }, { status: 401 });
  }

  try {
    const env = getServerEnv();
    const resend = getResendClient(env.resendApiKey);
    const dueClaims = await listTrialClaimsDueForReminder(200);
    let sent = 0;
    let failed = 0;

    for (const claim of dueClaims) {
      try {
        const message = renderTrialReminderEmail({
          email: claim.email,
          startedAt: claim.startedAt,
          endsAt: claim.endsAt,
          siteUrl: getSiteUrl(),
        });

        await resend.emails.send({
          from: env.licenseDeliveryFromEmail ?? env.waitlistFromEmail,
          to: claim.email,
          replyTo: env.waitlistReplyToEmail,
          subject: message.subject,
          text: message.text,
          html: message.html,
        });

        await markTrialReminderSent(claim.id);
        sent += 1;
      } catch (error) {
        failed += 1;
        console.error("[CmdTab Website] trial reminder email failed", {
          claimId: claim.id,
          errorType: error instanceof Error ? error.name : "unknown",
        });
      }
    }

    return NextResponse.json({
      ok: true,
      due: dueClaims.length,
      sent,
      failed,
    });
  } catch (error) {
    console.error("[CmdTab Website] trial reminder run failed", {
      errorType: error instanceof Error ? error.name : "unknown",
    });
    return NextResponse.json(
      { ok: false, message: "Reminder run failed" },
      { status: 500 },
    );
  }
}
