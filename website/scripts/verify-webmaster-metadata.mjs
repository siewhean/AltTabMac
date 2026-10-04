#!/usr/bin/env node
import { pathToFileURL } from "node:url";

export function verificationInputs(env = process.env) {
  const inputs = {};
  for (const key of ["GOOGLE_SITE_VERIFICATION", "BING_SITE_VERIFICATION"]) {
    const value = env[key]?.trim();
    if (!value) throw new Error(`${key} must be configured for webmaster verification`);
    if (/^(?:cmdtab-(?:google|bing)-verification-ci|placeholder|example|replace[-_ ]?me|your[-_ ].*)$/i.test(value)) {
      throw new Error(`${key} must contain the provider-issued value, not a placeholder`);
    }
    inputs[key] = value;
  }
  return inputs;
}

export function verifyMetadata(html, inputs) {
  const metadata = [...html.matchAll(/<meta\b[^>]*>/gi)].map(([tag]) => {
    const attributes = new Map();
    for (const match of tag.matchAll(/([^\s=]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/g)) {
      attributes.set(match[1].toLowerCase(), match[2] ?? match[3]);
    }
    return attributes;
  });
  for (const [key, name] of [
    ["GOOGLE_SITE_VERIFICATION", "google-site-verification"],
    ["BING_SITE_VERIFICATION", "msvalidate.01"],
  ]) {
    // Avoid assertion output containing the rendered page or configured values.
    if (!metadata.some((tag) => tag.get("name") === name && tag.get("content") === inputs[key])) {
      throw new Error(`rendered homepage is missing the configured ${name} meta tag`);
    }
  }
}

async function main() {
  const inputs = verificationInputs();
  if (process.argv.includes("--config-only")) {
    console.log("Google and Bing webmaster verification inputs are configured.");
    return;
  }
  const baseUrl = (process.env.VERIFY_BASE_URL || "http://127.0.0.1:3000").replace(/\/$/, "");
  const response = await fetch(`${baseUrl}/`, {
    headers: { "User-Agent": "CmdTabWebmasterMetadataVerifier/1.0" },
  });
  if (response.status !== 200) throw new Error(`homepage returned HTTP ${response.status}`);
  verifyMetadata(await response.text(), inputs);
  console.log("Rendered Google and Bing webmaster verification metadata passed.");
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
