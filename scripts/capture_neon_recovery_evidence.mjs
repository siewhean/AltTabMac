#!/usr/bin/env node
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { chmod, mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const checksumPattern = /^[0-9a-f]{64}$/;
const identifierPattern = /^[a-z0-9-]{1,60}$/;

function fail(message) {
  console.error(message);
  process.exit(1);
}

function git(...argumentsList) {
  return execFileSync("git", ["-C", root, ...argumentsList], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function requiredEnvironment(name, pattern) {
  const value = String(process.env[name] ?? "").trim();
  if (!value || (pattern && !pattern.test(value))) fail(`Missing or invalid ${name}`);
  return value;
}

async function request(path, options = {}) {
  const response = await fetch(`${apiBase}${path}`, {
    ...options,
    headers: {
      authorization: `Bearer ${apiKey}`,
      accept: "application/json",
      ...(options.body ? { "content-type": "application/json" } : {}),
    },
    signal: AbortSignal.timeout(20_000),
  }).catch(() => fail(`Neon API request failed: ${options.method ?? "GET"} ${path}`));
  const raw = await response.text();
  if (!response.ok) fail(`Neon API returned HTTP ${response.status}: ${options.method ?? "GET"} ${path}`);
  let body;
  try {
    body = JSON.parse(raw);
  } catch {
    fail(`Neon API returned invalid JSON: ${options.method ?? "GET"} ${path}`);
  }
  return { body, sha256: sha256(raw) };
}

async function waitForOperation(operationId, expectedBranchId) {
  let last;
  for (let attempt = 0; attempt < 30; attempt += 1) {
    last = await request(`/projects/${projectId}/operations/${operationId}`);
    const operation = last.body?.operation;
    if (operation?.status === "finished") {
      if (operation.id !== operationId || operation.failures_count !== 0 ||
          operation.project_id !== projectId ||
          operation.branch_id !== expectedBranchId) {
        fail(`Neon recovery operation did not finish successfully: ${operationId}`);
      }
      return last;
    }
    if (operation?.status === "failed" || operation?.status === "cancelled") {
      fail(`Neon recovery operation failed: ${operationId}`);
    }
    await new Promise((resolvePromise) => setTimeout(resolvePromise, 2_000));
  }
  fail(`Timed out waiting for Neon recovery operation: ${operationId}`);
}

const [outputArgument] = process.argv.slice(2);
const outputPath = resolve(outputArgument ?? resolve(root, "dist/neon-recovery-receipt.json"));
const apiKey = requiredEnvironment("NEON_API_KEY");
const projectId = requiredEnvironment("NEON_PROJECT_ID", identifierPattern);
const productionBranchId = requiredEnvironment("NEON_PRODUCTION_BRANCH_ID", identifierPattern);
const configuredBase = String(process.env.NEON_API_BASE_URL ?? "https://console.neon.tech/api/v2").replace(/\/$/, "");
if (configuredBase !== "https://console.neon.tech/api/v2" &&
    process.env.CMDTAB_ALLOW_TEST_NEON_API_BASE_URL !== "1") {
  fail("NEON_API_BASE_URL overrides are allowed only in explicit test mode");
}
const apiBase = configuredBase;

const infoPlist = await readFile(resolve(root, "Resources/Info.plist"), "utf8");
const version = infoPlist.match(/<key>CFBundleShortVersionString<\/key>\s*<string>([^<]+)<\/string>/)?.[1];
if (!version) fail("Unable to read the canonical release version");
const releaseTag = `v${version}`;
const sourceCommit = git("rev-parse", "HEAD");
if (git("status", "--porcelain", "--untracked-files=all")) {
  fail("Neon recovery evidence capture requires a clean source tree");
}
try {
  if (git("rev-parse", `refs/tags/${releaseTag}^{commit}`) !== sourceCommit) {
    fail(`${releaseTag} must point to HEAD`);
  }
} catch {
  fail(`Missing canonical release tag: ${releaseTag}`);
}

const projectResponse = await request(`/projects/${projectId}`);
const project = projectResponse.body?.project;
const historyRetentionSeconds = project?.history_retention_seconds;
if (project?.id !== projectId || !Number.isInteger(historyRetentionSeconds) ||
    historyRetentionSeconds < 7 * 24 * 60 * 60) {
  fail("Neon project does not prove at least seven days of history retention");
}

const sourceResponse = await request(`/projects/${projectId}/branches/${productionBranchId}`);
const sourceBranch = sourceResponse.body?.branch;
if (sourceBranch?.id !== productionBranchId || sourceBranch?.project_id !== projectId ||
    sourceBranch?.current_state !== "ready") {
  fail("Neon production branch is not a ready branch in the configured project");
}

const runSuffix = String(process.env.GITHUB_RUN_ID ?? Date.now()).replace(/[^0-9]/g, "").slice(-12);
const checkpointName = `cmdtab-${releaseTag.replace(/[^a-z0-9-]/gi, "-").toLowerCase()}-${sourceCommit.slice(0, 12)}-${runSuffix}`.slice(0, 256);
const createResponse = await request(`/projects/${projectId}/branches`, {
  method: "POST",
  body: JSON.stringify({
    branch: {
      parent_id: productionBranchId,
      name: checkpointName,
      protected: true,
      init_source: "parent-data",
    },
  }),
});
const createdBranch = createResponse.body?.branch;
if (!identifierPattern.test(createdBranch?.id ?? "") || createdBranch?.project_id !== projectId ||
    createdBranch?.parent_id !== productionBranchId || createdBranch?.name !== checkpointName) {
  fail("Neon did not create the requested recovery checkpoint branch");
}
const operations = createResponse.body?.operations;
if (!Array.isArray(operations) || operations.length < 1 ||
    operations.some((operation) => !String(operation?.id ?? "")) ||
    new Set(operations.map((operation) => operation.id)).size !== operations.length) {
  fail("Neon recovery checkpoint response did not include operation evidence");
}
const operationResponses = [];
for (const operation of operations) {
  operationResponses.push(await waitForOperation(operation.id, createdBranch.id));
}
if (!operationResponses.some((response) => response.body?.operation?.action === "create_branch")) {
  fail("Neon recovery checkpoint did not complete a create_branch operation");
}

const recoveryResponse = await request(`/projects/${projectId}/branches/${createdBranch.id}`);
const recoveryBranch = recoveryResponse.body?.branch;
if (recoveryBranch?.id !== createdBranch.id || recoveryBranch?.project_id !== projectId ||
    recoveryBranch?.parent_id !== productionBranchId || recoveryBranch?.name !== checkpointName ||
    recoveryBranch?.current_state !== "ready" || recoveryBranch?.protected !== true ||
    !String(recoveryBranch?.parent_lsn ?? "").trim()) {
  fail("Neon recovery checkpoint is not a protected ready branch with a provider-assigned parent LSN");
}
const checkpointCreatedAt = Date.parse(recoveryBranch.created_at);
if (!Number.isFinite(checkpointCreatedAt) || checkpointCreatedAt > Date.now() + 60_000) {
  fail("Neon recovery checkpoint has an invalid creation timestamp");
}

const evidenceCreatedAt = new Date().toISOString();
const receipt = {
  version: 1,
  generator: "scripts/capture_neon_recovery_evidence.mjs",
  ok: true,
  provider: "neon",
  apiBase: "https://console.neon.tech/api/v2",
  sourceCommit,
  releaseTag,
  projectId,
  productionBranchId,
  recoveryBranchId: recoveryBranch.id,
  checkpointName,
  checkpointCreatedAt: recoveryBranch.created_at,
  checkpointLsnSha256: sha256(recoveryBranch.parent_lsn),
  historyRetentionSeconds,
  pitrDays: historyRetentionSeconds / 86_400,
  operationIds: operations.map((operation) => String(operation.id)),
  providerResponseSha256: {
    project: projectResponse.sha256,
    productionBranch: sourceResponse.sha256,
    checkpointCreate: createResponse.sha256,
    checkpointBranch: recoveryResponse.sha256,
    operations: sha256(operationResponses.map((response) => response.sha256).join("\n")),
  },
  evidenceCreatedAt,
};
if (Object.values(receipt.providerResponseSha256).some((value) => !checksumPattern.test(value))) {
  fail("Neon provider response hashes are invalid");
}
await mkdir(dirname(outputPath), { recursive: true, mode: 0o700 });
await writeFile(outputPath, `${JSON.stringify(receipt, null, 2)}\n`, { mode: 0o600 });
await chmod(outputPath, 0o600);
console.log(`Captured provider-verified Neon recovery evidence: ${outputPath}`);
