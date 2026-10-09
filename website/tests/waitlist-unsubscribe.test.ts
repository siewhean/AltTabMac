import assert from "node:assert/strict";
import test from "node:test";

import {
  createWaitlistUnsubscribeToken,
  verifyWaitlistUnsubscribeToken,
} from "../src/lib/waitlist-unsubscribe.js";

const secret = "a".repeat(48);

test("unsubscribe token round-trips to the normalized address", () => {
  const token = createWaitlistUnsubscribeToken("  Person@Example.COM ", secret);
  assert.equal(verifyWaitlistUnsubscribeToken(token, secret), "person@example.com");
});

test("unsubscribe token cannot be forged or redirected to another address", () => {
  const token = createWaitlistUnsubscribeToken("person@example.com", secret);
  const [, signature] = token.split(".");
  const otherAddress = Buffer.from("victim@example.com").toString("base64url");

  assert.equal(verifyWaitlistUnsubscribeToken(`${otherAddress}.${signature}`, secret), null);
  assert.equal(verifyWaitlistUnsubscribeToken(token, "b".repeat(48)), null);
  assert.equal(verifyWaitlistUnsubscribeToken(`${token}x`, secret), null);
  assert.equal(verifyWaitlistUnsubscribeToken(`${token}.extra`, secret), null);
  assert.equal(verifyWaitlistUnsubscribeToken("", secret), null);
  assert.equal(verifyWaitlistUnsubscribeToken(null, secret), null);
  assert.equal(verifyWaitlistUnsubscribeToken("x".repeat(601), secret), null);
});

test("unsubscribe token rejects non-normalized or non-email payloads", () => {
  const sign = (value: string) =>
    createWaitlistUnsubscribeToken(value, secret).split(".")[1];
  const upper = Buffer.from("Person@Example.com").toString("base64url");
  assert.equal(verifyWaitlistUnsubscribeToken(`${upper}.${sign("Person@Example.com")}`, secret), null);
  const notEmail = Buffer.from("not-an-email").toString("base64url");
  assert.equal(verifyWaitlistUnsubscribeToken(`${notEmail}.${sign("not-an-email")}`, secret), null);
});
