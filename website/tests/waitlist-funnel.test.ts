import assert from "node:assert/strict";
import test from "node:test";
import { collectWaitlistAttribution } from "../src/lib/waitlist-attribution.js";
import { waitlistRedirectPath } from "../src/lib/waitlist-redirect.js";
import { isSameOriginFormRequest } from "../src/lib/form-request-origin.js";
import { waitlistPayloadSchema } from "../src/lib/validation.js";

test("waitlist enrollment requires explicit consent independent of analytics", () => {
  assert.equal(waitlistPayloadSchema.safeParse({ email: "person@example.com" }).success, false);
  assert.equal(waitlistPayloadSchema.safeParse({ email: "person@example.com", consent: false }).success, false);
  assert.equal(waitlistPayloadSchema.safeParse({ email: "PERSON@example.com", consent: true }).success, true);
  assert.equal(waitlistPayloadSchema.safeParse({ email: "person@example.com", consent: true, honeypot: "bot" }).success, false);
});
test("attribution is absent without optional analytics consent", () => {
  assert.equal(collectWaitlistAttribution("?utm_source=google", "/waitlist", false), undefined);
});
test("campaign attribution only accepts safe labels and excludes queries or personal data", () => {
  assert.deepEqual(collectWaitlistAttribution("?utm_source=GOOGLE&utm_campaign=october&utm_term=private+query&utm_medium=person%40example.com", "/waitlist", true), { path: "/waitlist", utm_source: "google", utm_campaign: "october" });
});
test("legacy access redirects preserve safe campaign labels without open redirects", () => {
  assert.equal(waitlistRedirectPath({ utm_source: "google", next: "https://example.com", email: "person@example.com" }), "/waitlist?utm_source=google");
  assert.equal(waitlistRedirectPath({ utm_source: ["a", "b"], utm_campaign: "private query" }), "/waitlist");
});

test("form origin uses public Host when Next normalizes its internal hostname", () => {
  const request = (headers: Record<string, string>) => new Request("http://localhost:43173/api/waitlist", { headers });
  assert.equal(isSameOriginFormRequest(request({ host: "127.0.0.1:43173", origin: "http://127.0.0.1:43173" })), true);
  assert.equal(isSameOriginFormRequest(request({ host: "127.0.0.1:43173", origin: "https://attacker.invalid" })), false);
  assert.equal(isSameOriginFormRequest(request({ host: "127.0.0.1:43173", origin: "https://127.0.0.1:43173" })), false);
  assert.equal(isSameOriginFormRequest(request({ host: "127.0.0.1:43173", origin: "null" })), false);
  assert.equal(isSameOriginFormRequest(request({ host: "127.0.0.1:43173", referer: "http://127.0.0.1:43173/waitlist" })), true);
  assert.equal(isSameOriginFormRequest(request({ host: "127.0.0.1:43173", referer: "http://attacker.invalid/waitlist" })), false);
  assert.equal(isSameOriginFormRequest(request({ host: "attacker.invalid/path", origin: "http://attacker.invalid" })), false);
});

test("hosted HTTPS form origin retains framework URL protocol and ignores forwarded overrides", () => {
  const request = (headers: Record<string, string>) => new Request("https://internal.example/api/waitlist", { headers });
  assert.equal(isSameOriginFormRequest(request({ host: "cmdtab.net", origin: "https://cmdtab.net" })), true);
  assert.equal(isSameOriginFormRequest(request({ host: "cmdtab.net", origin: "http://cmdtab.net" })), false);
  assert.equal(isSameOriginFormRequest(request({ host: "cmdtab.net", origin: "https://attacker.invalid", "x-forwarded-host": "attacker.invalid" })), false);
  assert.equal(isSameOriginFormRequest(request({ host: "cmdtab.net", origin: "http://cmdtab.net", "x-forwarded-proto": "http" })), false);
});
