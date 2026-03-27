import { z } from "zod";

const metadataSchema = z
  .record(z.string(), z.string().trim().max(120))
  .refine((value) => Object.keys(value).length <= 8, {
    message: "Too many metadata fields.",
  });

export const waitlistPayloadSchema = z
  .object({
    email: z.string().trim().email().transform((value) => value.toLowerCase()),
    name: z.string().trim().max(80).optional(),
    source: z.string().trim().max(60).optional(),
    metadata: metadataSchema.optional(),
    honeypot: z.string().max(0).optional(),
  })
  .strict();

export type WaitlistPayload = z.infer<typeof waitlistPayloadSchema>;
