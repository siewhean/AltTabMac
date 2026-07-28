import assert from "node:assert/strict";
import test from "node:test";

import { getCommerceConfig } from "../src/lib/commerce.js";

test("commerce configuration accepts explicit HTTPS checkout and portal URLs", () => {
  assert.deepEqual(
    getCommerceConfig({
      NEXT_PUBLIC_CHECKOUT_PROVIDER: "lemonsqueezy",
      NEXT_PUBLIC_CHECKOUT_URL: "https://store.example.com/checkout/buy/abc",
      NEXT_PUBLIC_LICENSE_PORTAL_URL: "https://store.example.com/orders",
      NEXT_PUBLIC_SUPPORT_EMAIL: "support@example.com",
    }),
    {
      checkoutProvider: "lemonsqueezy",
      checkoutUrl: "https://store.example.com/checkout/buy/abc",
      licensePortalUrl: "https://store.example.com/orders",
      supportEmail: "support@example.com",
    },
  );
});

test("commerce configuration rejects unsafe, credentialed, or unsupported values", () => {
  assert.deepEqual(
    getCommerceConfig({
      NEXT_PUBLIC_CHECKOUT_PROVIDER: "unknown-provider",
      NEXT_PUBLIC_CHECKOUT_URL: "javascript:alert(1)",
      NEXT_PUBLIC_LICENSE_PORTAL_URL: "https://user:pass@example.com/orders",
      NEXT_PUBLIC_SUPPORT_EMAIL: "",
    }),
    {
      checkoutProvider: undefined,
      checkoutUrl: undefined,
      licensePortalUrl: undefined,
      supportEmail: undefined,
    },
  );
});

test("commerce configuration normalizes provider casing and URL serialization", () => {
  const config = getCommerceConfig({
    NEXT_PUBLIC_CHECKOUT_PROVIDER: " LemonSqueezy ",
    NEXT_PUBLIC_CHECKOUT_URL: " https://store.example.com/checkout ",
  });

  assert.equal(config.checkoutProvider, "lemonsqueezy");
  assert.equal(config.checkoutUrl, "https://store.example.com/checkout");
});
