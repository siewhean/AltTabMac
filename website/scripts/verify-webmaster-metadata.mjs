#!/usr/bin/env node
import assert from "node:assert/strict";

const baseUrl = (process.env.VERIFY_BASE_URL || "http://127.0.0.1:3000").replace(/\/$/, "");
const google = process.env.GOOGLE_SITE_VERIFICATION?.trim();
const bing = process.env.BING_SITE_VERIFICATION?.trim();

assert.ok(google, "GOOGLE_SITE_VERIFICATION must be set for the rendered verification");
assert.ok(bing, "BING_SITE_VERIFICATION must be set for the rendered verification");

const response = await fetch(`${baseUrl}/`, {
  headers: {
    "User-Agent": "CmdTabWebmasterMetadataVerifier/1.0",
  },
});
assert.equal(response.status, 200, `homepage returned HTTP ${response.status}`);
const html = await response.text();

function escaped(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

assert.match(
  html,
  new RegExp(
    `<meta[^>]+name=["']google-site-verification["'][^>]+content=["']${escaped(google)}["']|` +
      `<meta[^>]+content=["']${escaped(google)}["'][^>]+name=["']google-site-verification["']`,
    "i",
  ),
  "rendered homepage is missing the configured Google verification meta tag",
);
assert.match(
  html,
  new RegExp(
    `<meta[^>]+name=["']msvalidate\\.01["'][^>]+content=["']${escaped(bing)}["']|` +
      `<meta[^>]+content=["']${escaped(bing)}["'][^>]+name=["']msvalidate\\.01["']`,
    "i",
  ),
  "rendered homepage is missing the configured Bing verification meta tag",
);

console.log("Rendered Google and Bing webmaster verification metadata passed.");
