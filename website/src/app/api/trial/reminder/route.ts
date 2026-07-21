import { NextResponse } from "next/server";

import { renderTrialReminderEmail } from "@/content/trial-email";
import { getServerEnv, getSiteUrl } from "@/lib/env";
import {
  listTrialClaimsDueForReminder,
  markTrialReminderSent,
} from "@/lib/trial-claim-store";
import { getResendClient } from "@/lib/resend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function isAuthorized(request: Request) {
  const secret = process.env.CRON_SECRET?.trim();
  if (!secret) return false;

  const header = request.headers.get("authorization");
  return header === `Bearer ${secret}`;
}

export async function GET(request: Request) {
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
          email: claim.email,
          error,
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
    console.error("[CmdTab Website] trial reminder run failed", error);
    return NextResponse.json(
      { ok: false, message: "Reminder run failed" },
      { status: 500 },
    );
  }
}
