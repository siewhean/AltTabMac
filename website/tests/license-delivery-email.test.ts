import assert from "node:assert/strict";
import test from "node:test";

import { renderLicenseDeliveryEmail } from "../src/content/license-delivery-email.js";
import { issuePurchaseActivationCredential } from "../src/lib/license-lifecycle-contract.js";

test("purchase email carries the exact activation credential and one-click deep link", () => {
  const licenseKey = issuePurchaseActivationCredential();
  const message = renderLicenseDeliveryEmail({
    email: "buyer@example.com",
    name: "Test Buyer",
    licenseKey,
    productName: "CmdTab",
    receiptUrl: "https://example.com/receipt/123",
    orderNumber: 123,
    siteUrl: "https://cmdtab.net",
    testMode: true,
  });
  const activationUrl = `cmdtab://activate?code=${encodeURIComponent(licenseKey)}`;

  assert.equal(message.subject, "[Test Mode] Your CmdTab activation code");
  assert.match(message.text, /your CmdTab license is ready/i);
  assert.ok(message.text.includes(activationUrl));
  assert.ok(message.text.includes(licenseKey));
  assert.ok(message.text.includes("https://example.com/receipt/123"));
  assert.ok(message.html.includes(`href="${activationUrl}"`));
  assert.ok(message.html.includes(licenseKey));
  assert.ok(message.html.includes("Activate CmdTab"));
});

test("purchase email escapes customer-controlled text in HTML", () => {
  const message = renderLicenseDeliveryEmail({
    email: "buyer@example.com",
    name: '<img src=x onerror="alert(1)">',
    licenseKey: issuePurchaseActivationCredential(),
    productName: "CmdTab <script>alert(1)</script>",
    siteUrl: "https://cmdtab.net",
  });

  assert.doesNotMatch(message.html, /<script>alert\(1\)<\/script>/);
  assert.doesNotMatch(message.html, /<img src=x/);
  assert.match(message.html, /&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
  assert.match(message.html, /&lt;img/);
});
