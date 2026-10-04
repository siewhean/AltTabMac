import assert from "node:assert/strict";
import test from "node:test";
import { verificationInputs, verifyMetadata } from "../scripts/verify-webmaster-metadata.mjs";

// Synthetic values prove validator behavior; they are not ownership evidence.
const configured = {
  GOOGLE_SITE_VERIFICATION: "synthetic-google-token-a.b+c",
  BING_SITE_VERIFICATION: "synthetic-bing-token-123456",
};

test("missing or known placeholder ownership inputs block the gate", () => {
  for (const key of Object.keys(configured)) {
    for (const value of [undefined, "", "   ", "placeholder", "replace-me", "your-token", `cmdtab-${key.startsWith("GOOGLE") ? "google" : "bing"}-verification-ci`]) {
      assert.throws(() => verificationInputs({ ...configured, [key]: value }), new RegExp(key));
    }
  }
});

test("rendered values must match both configured inputs exactly", () => {
  const inputs = verificationInputs(configured);
  const html = `<meta name="google-site-verification" content="${inputs.GOOGLE_SITE_VERIFICATION}"><meta content='${inputs.BING_SITE_VERIFICATION}' name='msvalidate.01'>`;
  assert.doesNotThrow(() => verifyMetadata(html, inputs));
  assert.throws(() => verifyMetadata(html.replace("synthetic-google", "SYNTHETIC-google"), inputs), /google-site-verification/);
  assert.throws(() => verifyMetadata(html.replace("a.b+c", "axb+c"), inputs), /google-site-verification/);
  assert.throws(() => verifyMetadata(html.replace(inputs.BING_SITE_VERIFICATION, "different-value"), inputs), /msvalidate/);
  assert.throws(() => verifyMetadata("<html></html>", inputs), /missing/);
});

test("mismatch errors do not expose configured values or rendered content", () => {
  assert.throws(() => verifyMetadata("private rendered content", configured), (error) => {
    assert.ok(!error.message.includes(configured.GOOGLE_SITE_VERIFICATION));
    assert.ok(!error.message.includes("private rendered content"));
    return true;
  });
});
