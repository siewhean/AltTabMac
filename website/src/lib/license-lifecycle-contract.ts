import { createHmac, randomBytes } from "node:crypto";
import { z } from "zod";

const opaqueIdentifier = z
  .string()
  .trim()
  .min(32)
  .max(128)
  .regex(/^[A-Za-z0-9_-]+$/);

export const activateLicenseSchema = z
  .object({
    licenseKey: z.string().trim().min(32).max(16_384),
    deviceId: opaqueIdentifier,
    deviceName: z.string().trim().min(1).max(80),
  })
  .strict();

export const deactivateLicenseSchema = z
  .object({
    licenseKey: z.string().trim().min(32).max(16_384),
    deviceId: opaqueIdentifier,
  })
  .strict();

export const recoverLicenseSchema = z
  .object({
    email: z.string().trim().email().max(320).transform((value) => value.toLowerCase()),
  })
  .strict();

export function lookupHash(kind: "license" | "order" | "email" | "device", value: string, pepper: string) {
  return createHmac("sha256", pepper)
    .update(`cmdtab:${kind}:v1\0${value.trim().toLowerCase()}`)
    .digest("hex");
}

export type RefundClassification = "none" | "partial" | "full";

export function classifyOrderRefund(input: {
  status?: string;
  refunded?: boolean | null;
  refundedAmount?: number | string | null;
  total?: number | string | null;
}): RefundClassification {
  const status = input.status?.trim().toLowerCase();
  if (status === "partial_refund") return "partial";
  if (status === "refunded" || input.refunded === true) return "full";

  const refundedAmount = Number(input.refundedAmount ?? 0);
  const total = Number(input.total ?? 0);
  if (Number.isFinite(refundedAmount) && refundedAmount > 0) {
    if (Number.isFinite(total) && total > 0 && refundedAmount >= total) return "full";
    return "partial";
  }
  return "none";
}

export const genericRecoveryResponse = {
  ok: true,
  message:
    "If a matching CmdTab purchase exists, recovery instructions will be sent shortly.",
} as const;

export function issuePurchaseActivationCredential() {
  return `CMDTAB-ACT-${randomBytes(32).toString("base64url")}`;
}
