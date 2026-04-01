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
