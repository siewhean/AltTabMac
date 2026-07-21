#!/usr/bin/env node

import { readFileSync } from "node:fs";

const [runPath, expectedWorkflow, expectedSha] = process.argv.slice(2);
if (!runPath || !expectedWorkflow || !/^[0-9a-f]{40}$/.test(expectedSha ?? "")) {
  console.error("Usage: verify_workflow_run_provenance.mjs <run.json> <workflow-path> <40-char-sha>");
  process.exit(2);
}

const run = JSON.parse(readFileSync(runPath, "utf8"));
const failures = [];
if (run.path !== expectedWorkflow) failures.push("workflow path");
if (run.status !== "completed") failures.push("completed status");
if (run.conclusion !== "success") failures.push("successful conclusion");
if (run.head_sha !== expectedSha) failures.push("tagged source SHA");
if (run.event !== "workflow_dispatch") failures.push("workflow_dispatch event");

if (failures.length > 0) {
  console.error(`Untrusted workflow run: ${failures.join(", ")}`);
  process.exit(1);
}
