import { z } from "zod";

const metadataKeySchema = z
  .string()
  .trim()
  .min(1)
  .max(40)
  .regex(/^[a-z0-9_-]+$/i, {
    message: "Metadata keys must use letters, numbers, underscores, or hyphens.",
  });

const metadataSchema = z
  .record(metadataKeySchema, z.string().trim().max(120))
  .refine((value) => Object.keys(value).length <= 8, {
    message: "Too many metadata fields.",
  });

export const waitlistPayloadSchema = z
  .object({
    email: z.string().trim().email().transform((value) => value.toLowerCase()),
    name: z.string().trim().max(80).optional(),
    source: z
      .string()
      .trim()
      .max(60)
      .regex(/^[a-z0-9._-]+$/i, {
        message: "Source must use letters, numbers, periods, underscores, or hyphens.",
      })
      .optional(),
    metadata: metadataSchema.optional(),
    // Invite code from a friend's link. Validated for shape only; the store
    // decides whether it belongs to a real signup.
    referralCode: z
      .string()
      .trim()
      .toLowerCase()
      .regex(/^[a-z0-9]{6,12}$/)
      .optional(),
    // Random id the browser keeps to recognise repeat signups from one device.
    // Only its salted hash is stored (see waitlist-signals).
    deviceId: z
      .string()
      .trim()
      .regex(/^[A-Za-z0-9_-]{16,64}$/)
      .optional(),
    // Optional, unchecked by default: occasional product updates beyond the beta,
    // trial and launch notices. Effective only once the address is confirmed.
    marketingConsent: z.boolean().optional(),
    honeypot: z.string().max(0).optional(),
  })
  .strict();

export type WaitlistPayload = z.infer<typeof waitlistPayloadSchema>;

export const licenseHelpPayloadSchema = z
  .object({
    email: z.string().trim().email().transform((value) => value.toLowerCase()),
    name: z.string().trim().max(80).optional(),
    purchaseEmail: z
      .string()
      .trim()
      .email()
      .transform((value) => value.toLowerCase())
      .optional(),
    reason: z.enum([
      "license_recovery",
      "activation_help",
      "billing_question",
      "refund_request",
      "general",
    ]),
    message: z.string().trim().min(12).max(1000),
    metadata: metadataSchema.optional(),
    honeypot: z.string().max(0).optional(),
  })
  .strict();

export type LicenseHelpPayload = z.infer<typeof licenseHelpPayloadSchema>;
