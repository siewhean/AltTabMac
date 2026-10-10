import assert from "node:assert/strict";
import test from "node:test";

import { getClientIp } from "../src/lib/client-ip.js";

function requestWith(headers: Record<string, string>) {
  return new Request("https://cmdtab.net/api/waitlist", { method: "POST", headers });
}

function withVercel<T>(value: string | undefined, run: () => T): T {
  const previous = process.env.VERCEL;
  if (value === undefined) delete process.env.VERCEL;
  else process.env.VERCEL = value;
  try {
    return run();
  } finally {
    if (previous === undefined) delete process.env.VERCEL;
    else process.env.VERCEL = previous;
  }
}

test("off Vercel, caller-supplied IP headers are ignored", () => {
  withVercel(undefined, () => {
    const spoofed = requestWith({
      "x-real-ip": "203.0.113.7",
      "x-forwarded-for": "198.51.100.9, 10.0.0.1",
      "x-vercel-id": "fra1::fake",
    });
    assert.equal(getClientIp(spoofed), "unknown");
  });
  withVercel("0", () => {
    assert.equal(getClientIp(requestWith({ "x-real-ip": "203.0.113.7" })), "unknown");
  });
});

test("on Vercel, the platform-set headers are used", () => {
  withVercel("1", () => {
    assert.equal(getClientIp(requestWith({ "x-real-ip": " 203.0.113.7 " })), "203.0.113.7");
    assert.equal(
      getClientIp(requestWith({ "x-forwarded-for": "198.51.100.9, 10.0.0.1" })),
      "198.51.100.9",
    );
    assert.equal(getClientIp(requestWith({})), "unknown");
  });
});
