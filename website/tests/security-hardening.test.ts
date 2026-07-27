import assert from "node:assert/strict";
import test from "node:test";

import { escapeCsvCell } from "../src/lib/csv.js";
import { demoNavigationDirection } from "../src/lib/demo-keyboard-navigation.js";
import { optionalStrongInternalSecret } from "../src/lib/env.js";
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
