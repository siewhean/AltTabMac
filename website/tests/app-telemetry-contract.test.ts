import assert from "node:assert/strict";
import test from "node:test";

import {
  parseAppTelemetryPayload,
} from "../src/lib/app-telemetry-contract.js";

const validPayload = {
  eventName: "app_activation",
  licenseState: "trial_active",
  appVersion: "1.0.0",
  osVersion: "14.6.0",
  occurredAt: "2026-08-04T12:00:00Z",
} as const;

test("native telemetry accepts only the five aggregate wire fields", () => {
  const parsed = parseAppTelemetryPayload(validPayload);
  assert.deepEqual(
    Object.keys(parsed).sort(),
    ["appVersion", "eventName", "licenseState", "occurredAt", "osVersion"],
  );
});

test("native telemetry rejects persistent IDs, local content, and secrets", () => {
  for (const forbiddenField of [
    "installId",
    "licenseId",
    "deviceId",
    "windowTitle",
    "windowTitles",
    "preview",
    "screenshot",
    "token",
    "secret",
    "metadata",
  ]) {
    assert.throws(() => parseAppTelemetryPayload({
      ...validPayload,
      [forbiddenField]: "must-not-be-accepted",
    }));
  }
});

test("native telemetry rejects an incomplete or invalid aggregate event", () => {
  assert.throws(() => parseAppTelemetryPayload({ ...validPayload, occurredAt: undefined }));
  assert.throws(() => parseAppTelemetryPayload({ ...validPayload, eventName: "window_focused" }));
  assert.throws(() => parseAppTelemetryPayload({ ...validPayload, licenseState: "licensed:secret" }));
});
