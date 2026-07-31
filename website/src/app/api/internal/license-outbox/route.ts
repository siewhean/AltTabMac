import {
  getLicenseLifecycleEnv,
  isCommerceLaunchEnabled,
  optionalStrongInternalSecret,
} from "@/lib/env";
import { isAuthorizedInternalWorker } from "@/lib/internal-worker-auth";
import { licenseJson } from "@/lib/license-api";
import { processLicenseOutbox } from "@/lib/license-outbox";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

async function runOutbox(request: Request, secret: string | null | undefined) {
  if (!isAuthorizedInternalWorker(request, secret)) {
    return licenseJson(
      { ok: false, code: "unauthorized", message: "Unauthorized." },
      401,
    );
  }

  if (!isCommerceLaunchEnabled()) {
    return licenseJson({
      ok: true,
      skipped: true,
      reason: "commerce_disabled",
      claimed: 0,
      delivered: 0,
      failed: 0,
    });
  }

  const result = await processLicenseOutbox(25);
  return licenseJson({ ok: true, ...result });
}

/**
 * Vercel Cron invokes configured paths with GET and sends CRON_SECRET as a
 * Bearer token. This keeps failed purchase/recovery emails moving without
 * relying on Lemon Squeezy to retry the original webhook.
 */
export async function GET(request: Request) {
  return runOutbox(
    request,
    optionalStrongInternalSecret(process.env.CRON_SECRET),
  );
}

/**
 * Manual/operational worker invocation remains available behind its separate
 * high-entropy secret.
 */
export async function POST(request: Request) {
  return runOutbox(request, getLicenseLifecycleEnv().outboxSecret);
}
