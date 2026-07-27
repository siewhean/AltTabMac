import { renderLicenseDeliveryEmail } from "@/content/license-delivery-email";
import { getServerEnv, getSiteUrl } from "@/lib/env";
import {
  claimDueOutboxJobs,
  completeOutboxJob,
  failOutboxJob,
} from "@/lib/license-lifecycle-store";
import { getResendClient } from "@/lib/resend";
import { updateLicenseFulfillmentDeliveryStatus } from "@/lib/license-fulfillment-store";
import { requireAcceptedDelivery } from "@/lib/license-delivery-result";

function optionalString(payload: Record<string, unknown>, key: string) {
  const value = payload[key];
  return typeof value === "string" && value.trim() ? value : undefined;
}

export async function processLicenseOutbox(limit = 10) {
  const jobs = await claimDueOutboxJobs(limit);
  const env = getServerEnv();
  const resend = getResendClient(env.resendApiKey);
  let delivered = 0;
  let failed = 0;

  for (const job of jobs) {
    try {
      const licenseKey = optionalString(job.payload, "licenseKey");
      if (!licenseKey) throw new Error("Outbox payload is missing a license key.");
      const message = renderLicenseDeliveryEmail({
        email: job.recipientEmail,
        licenseKey,
        productName: optionalString(job.payload, "productName"),
        receiptUrl: optionalString(job.payload, "receiptUrl"),
        siteUrl: getSiteUrl(),
        recovery: job.kind === "license_recovery",
      });
      const delivery = await resend.emails.send({
        from: env.licenseDeliveryFromEmail ?? env.waitlistFromEmail,
        to: job.recipientEmail,
        replyTo: env.waitlistReplyToEmail,
        subject: message.subject,
        text: message.text,
        html: message.html,
      });
      requireAcceptedDelivery(delivery);
      await completeOutboxJob(job.id, job.claimToken);
      const orderIdentifier = optionalString(job.payload, "orderIdentifier");
      if (job.kind === "license_delivery" && orderIdentifier) {
        await updateLicenseFulfillmentDeliveryStatus(orderIdentifier, "delivered");
      }
      delivered += 1;
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown delivery error";
      await failOutboxJob(job.id, job.claimToken, job.attempts, message);
      const orderIdentifier = optionalString(job.payload, "orderIdentifier");
      if (job.kind === "license_delivery" && orderIdentifier) {
        await updateLicenseFulfillmentDeliveryStatus(orderIdentifier, "failed", message);
      }
      failed += 1;
    }
  }

  return { claimed: jobs.length, delivered, failed };
}
