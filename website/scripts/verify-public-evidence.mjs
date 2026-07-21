#!/usr/bin/env node
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const baseUrl = (process.env.VERIFY_BASE_URL || "http://127.0.0.1:3000").replace(/\/$/, "");
const root = process.cwd();
const artifacts = [
  {
    route: "/evidence/switcher-model-results.json",
    canonicalPath: "../docs/qa/AltTabMac_model_results.json",
  },
  {
    route: "/evidence/switcher-test-matrix.csv",
    canonicalPath: "../docs/qa/AltTabMac_comprehensive_test_matrix.csv",
  },
  {
    route: "/evidence/switcher-test-plan.md",
    canonicalPath: "../docs/qa/AltTabMac_implementation_review_and_test_plan.md",
  },
];

for (const artifact of artifacts) {
  const response = await fetch(`${baseUrl}${artifact.route}`, {
    headers: {
      "User-Agent": "CmdTabPublicEvidenceVerifier/1.0",
      Accept: "*/*",
    },
  });
  assert.equal(response.status, 200, `${artifact.route} returned HTTP ${response.status}`);
  const contentType = response.headers.get("content-type") || "";
  assert.ok(
    !contentType.toLowerCase().includes("text/html"),
    `${artifact.route} unexpectedly returned HTML (${contentType})`,
  );

  const [served, canonical] = await Promise.all([
    response.arrayBuffer().then((value) => Buffer.from(value)),
    readFile(resolve(root, artifact.canonicalPath)),
  ]);
  assert.deepEqual(served, canonical, `${artifact.route} does not match ${artifact.canonicalPath}`);
}

console.log(`Public evidence verification passed for ${artifacts.length} byte-matched artifacts.`);
