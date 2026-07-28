import assert from "node:assert/strict";
import test from "node:test";

import { constantTimeEqual } from "../src/lib/constant-time.js";
import { contentSecurityPolicy } from "../src/lib/content-security-policy.js";
import { escapeCsvCell } from "../src/lib/csv.js";
import { demoNavigationDirection } from "../src/lib/demo-keyboard-navigation.js";
import { optionalStrongInternalSecret } from "../src/lib/env.js";
import { isAuthorizedInternalWorker } from "../src/lib/internal-worker-auth.js";
import { parseStableReleaseManifest } from "../src/lib/stable-release.js";

test("Tab and Shift-Tab escape the switcher demo", () => {
  assert.equal(demoNavigationDirection({ key: "Tab", shiftKey: false }), null);
  assert.equal(demoNavigationDirection({ key: "Tab", shiftKey: true }), null);
});

test("arrow keys preserve forward and backward demo navigation", () => {
  assert.equal(demoNavigationDirection({ key: "ArrowRight", shiftKey: false }), "next");
  assert.equal(demoNavigationDirection({ key: "ArrowDown", shiftKey: false }), "next");
  assert.equal(demoNavigationDirection({ key: "ArrowLeft", shiftKey: false }), "previous");
  assert.equal(demoNavigationDirection({ key: "ArrowUp", shiftKey: false }), "previous");
});

test("constant-time secret comparison handles unequal lengths without an early return", () => {
  assert.equal(constantTimeEqual("correct horse", "correct horse"), true);
  assert.equal(constantTimeEqual("short", "a considerably longer secret"), false);
  assert.equal(constantTimeEqual("same-length-a", "same-length-b"), false);
});

test("internal workers require an exact Bearer secret", () => {
  const secret = "a-secure-random-worker-secret-value-1234";
  assert.equal(
    isAuthorizedInternalWorker(
      new Request("https://cmdtab.net/api/internal/license-outbox", {
        headers: { authorization: `Bearer ${secret}` },
      }),
      secret,
    ),
    true,
  );
  assert.equal(
    isAuthorizedInternalWorker(
      new Request("https://cmdtab.net/api/internal/license-outbox", {
        headers: { authorization: "Bearer wrong" },
      }),
      secret,
    ),
    false,
  );
  assert.equal(
    isAuthorizedInternalWorker(
      new Request("https://cmdtab.net/api/internal/license-outbox"),
      secret,
    ),
    false,
  );
  assert.equal(
    isAuthorizedInternalWorker(
      new Request("https://cmdtab.net/api/internal/license-outbox", {
        headers: { authorization: `Bearer ${secret}` },
      }),
      undefined,
    ),
    false,
  );
});

test("production CSP uses a nonce instead of unsafe-inline scripts", () => {
  const policy = contentSecurityPolicy("testNonce123=", true);
  assert.match(policy, /script-src 'self' 'nonce-testNonce123=' 'strict-dynamic'/);
  assert.doesNotMatch(policy, /script-src[^;]*'unsafe-inline'/);
  assert.doesNotMatch(policy, /script-src[^;]*'unsafe-eval'/);
  assert.match(policy, /style-src-elem 'self' 'nonce-testNonce123='/);
  assert.match(policy, /style-src-attr 'unsafe-inline'/);
});

test("development CSP allows eval only for the framework toolchain", () => {
  const policy = contentSecurityPolicy("developmentNonce", false);
  assert.match(policy, /script-src[^;]*'unsafe-eval'/);
  assert.doesNotMatch(policy, /script-src[^;]*'unsafe-inline'/);
  assert.match(policy, /connect-src 'self' ws: wss:/);
});

test("CSP rejects attacker-controlled nonce characters", () => {
  assert.throws(
    () => contentSecurityPolicy("nonce'; script-src *", true),
    /unsupported characters/,
  );
});

test("CSV export neutralizes spreadsheet formula prefixes", () => {
  for (const prefix of ["=", "+", "-", "@", "\t", "\r"]) {
    assert.equal(escapeCsvCell(`${prefix}payload`), `"'${prefix}payload"`);
  }
});

test("CSV export keeps ordinary values intact and escapes quotes", () => {
  assert.equal(escapeCsvCell("ordinary"), '"ordinary"');
  assert.equal(escapeCsvCell('say "hello"'), '"say ""hello"""');
  assert.equal(escapeCsvCell(null), '""');
  assert.equal(escapeCsvCell(42), '"42"');
});

test("internal worker secrets reject weak and documented placeholder values", () => {
  assert.equal(optionalStrongInternalSecret("short"), undefined);
  assert.equal(
    optionalStrongInternalSecret("replace_with_a_random_internal_worker_secret"),
    undefined,
  );
  assert.equal(
    optionalStrongInternalSecret("a-secure-random-worker-secret-value-1234"),
    "a-secure-random-worker-secret-value-1234",
  );
});

const stableRelease = {
  schemaVersion: 1,
  channel: "stable",
  version: "1.0.0",
  build: 2,
  minimumMacOS: "13.0",
  dmgURL: "https://cdn.cmdtab.net/releases/0123456789abcdef0123456789abcdef01234567/CmdTab-1.0.0-2.dmg",
  bytes: 123456,
  sha256: "a".repeat(64),
  releaseDate: "2026-07-27",
  sourceSHA: "0123456789abcdef0123456789abcdef01234567",
  appcastURL: "https://cmdtab.net/releases/appcast.xml",
} as const;

test("stable release parser accepts the canonical immutable contract", () => {
  assert.deepEqual(parseStableReleaseManifest(stableRelease), stableRelease);
});

test("stable release parser rejects mutable or mismatched downloads", () => {
  assert.throws(() => parseStableReleaseManifest({
    ...stableRelease,
    dmgURL: "https://cdn.cmdtab.net/releases/latest/CmdTab.dmg",
  }));
  assert.throws(() => parseStableReleaseManifest({
    ...stableRelease,
    appcastURL: "https://cmdtab.net/releases/beta.xml",
  }));
  assert.throws(() => parseStableReleaseManifest({
    ...stableRelease,
    releaseDate: "2026-02-31",
  }));
});
