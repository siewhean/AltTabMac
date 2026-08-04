import { z } from "zod";

export const APP_TELEMETRY_EVENT_NAMES = [
  "app_activation",
  "app_heartbeat",
  "license_activated",
  "trial_started",
] as const;

export const APP_TELEMETRY_LICENSE_STATES = [
  "unregistered",
  "trial_active",
  "trial_expired",
  "licensed",
] as const;

// This is deliberately a closed, aggregate-only contract. Do not add metadata
// or a stable identifier: native telemetry must not make events linkable to an
// install, license, device, account, window, or local content.
export const appTelemetryPayloadSchema = z.object({
  eventName: z.enum(APP_TELEMETRY_EVENT_NAMES),
  licenseState: z.enum(APP_TELEMETRY_LICENSE_STATES),
  appVersion: z.string().trim().min(1).max(40).regex(/^[A-Za-z0-9.+_-]+$/),
  osVersion: z.string().trim().min(1).max(40).regex(/^[A-Za-z0-9 .()_-]+$/),
  occurredAt: z.string().datetime({ offset: true }),
}).strict();

export type AppTelemetryEventInput = z.infer<typeof appTelemetryPayloadSchema>;

export function parseAppTelemetryPayload(input: unknown): AppTelemetryEventInput {
  return appTelemetryPayloadSchema.parse(input);
}
