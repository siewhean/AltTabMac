#!/usr/bin/env node
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { chmod, mkdir, readFile, writeFile } from "node:fs/promises";
import { basename, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");

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

async function sha256(path) {
  return createHash("sha256").update(await readFile(path)).digest("hex");
}

function evidenceId(name, receipt) {
  const nonempty = (...values) => values.every((value) => String(value ?? "").trim());
  switch (name) {
    case "app":
      return nonempty(receipt.notarizationSubmissionIds?.app, receipt.notarizationSubmissionIds?.dmg)
        ? `notary:${receipt.notarizationSubmissionIds.app}:${receipt.notarizationSubmissionIds.dmg}` : null;
    case "preview":
    case "production":
      return nonempty(receipt.deploymentId) ? `deployment:${receipt.deploymentId}` : null;
    case "previewSmoke":
      return nonempty(receipt.deploymentId) ? `preview-smoke:${receipt.deploymentId}` : null;
    case "migration":
      return nonempty(receipt.neonRecoveryEvidence?.sha256, receipt.neonRecoveryEvidence?.recoveryBranchId)
        ? `migration:${receipt.neonRecoveryEvidence.sha256}:${receipt.neonRecoveryEvidence.recoveryBranchId}` : null;
    case "neonRecovery":
      return nonempty(receipt.projectId, receipt.productionBranchId, receipt.recoveryBranchId,
        receipt.checkpointLsnSha256)
        ? `neon-recovery:${receipt.projectId}:${receipt.recoveryBranchId}:${receipt.checkpointLsnSha256}` : null;
    case "runtime":
      return [receipt.warmSessions, receipt.coldSessions, receipt.exactWindowActivations,
        receipt.forwardSteps, receipt.reverseSteps].every(Number.isInteger)
        ? `runtime:${receipt.warmSessions}:${receipt.coldSessions}:${receipt.exactWindowActivations}:${receipt.forwardSteps}:${receipt.reverseSteps}` : null;
    case "arm64":
    case "x86_64":
      return nonempty(receipt.architecture, receipt.artifactSha256)
        ? `clean-mac:${receipt.architecture}:${receipt.artifactSha256}` : null;
    case "backupRestore":
      return nonempty(receipt.backupRunId, receipt.restoreRunId, receipt.backupSha256)
        ? `backup-restore:${receipt.backupRunId}:${receipt.restoreRunId}:${receipt.backupSha256}` : null;
    case "environment":
      return nonempty(receipt.projectId) ? `environment:${receipt.projectId}` : null;
    default:
      return null;
  }
}

const reviewer = process.env.CMDTAB_FINAL_QA_REVIEWER?.trim();
const reviewReportId = process.env.CMDTAB_FINAL_QA_REPORT_ID?.trim();
if (!reviewer || !reviewReportId || process.env.CMDTAB_FINAL_QA_FINDINGS !== "0") {
  fail("CMDTAB_FINAL_QA_REVIEWER, CMDTAB_FINAL_QA_REPORT_ID, and CMDTAB_FINAL_QA_FINDINGS=0 are required");
}

const infoPlist = await readFile(resolve(root, "Resources/Info.plist"), "utf8");
const version = infoPlist.match(/<key>CFBundleShortVersionString<\/key>\s*<string>([^<]+)<\/string>/)?.[1];
if (!version) fail("Unable to read the canonical release version");
const releaseTag = `v${version}`;
const sourceCommit = git("rev-parse", "HEAD");
if (git("status", "--porcelain", "--untracked-files=all")) {
  fail("Final QA receipt generation requires a clean source tree");
}
try {
  if (git("rev-parse", `refs/tags/${releaseTag}^{commit}`) !== sourceCommit) {
    fail(`${releaseTag} must point to HEAD`);
  }
} catch {
  fail(`Missing canonical release tag: ${releaseTag}`);
}

const outputDirectory = resolve(process.env.CMDTAB_RELEASE_DIR ?? resolve(root, "dist"));
const definitions = [
  ["app", `CmdTab-${version}-release-receipt.json`],
  ["preview", `CmdTab-${version}-preview-deployment.json`],
  ["previewSmoke", `CmdTab-${version}-preview-smoke.json`],
  ["production", `CmdTab-${version}-production-staging-deployment.json`],
  ["migration", "production-migration-receipt.json"],
  ["neonRecovery", "neon-recovery-receipt.json"],
  ["runtime", "runtime-qa-receipt.json"],
  ["arm64", "clean-mac-arm64-qa-receipt.json"],
  ["x86_64", "clean-mac-x86_64-qa-receipt.json"],
  ["backupRestore", "backup-restore-receipt.json"],
  ["environment", `CmdTab-${version}-environment-validation.json`],
];
const reviewedEvidence = {};
let latestEvidenceTimestamp = 0;
let artifactSha256 = "";
for (const [name, file] of definitions) {
  const path = resolve(outputDirectory, file);
  let receipt;
  try {
    receipt = JSON.parse(await readFile(path, "utf8"));
  } catch {
    fail(`Missing or invalid evidence receipt: ${path}`);
  }
  if (receipt.sourceCommit !== sourceCommit || receipt.releaseTag !== releaseTag) {
    fail(`${file} does not match the canonical source and tag`);
  }
  const createdMilliseconds = Date.parse(receipt.evidenceCreatedAt);
  if (!Number.isFinite(createdMilliseconds) || createdMilliseconds > Date.now()) {
    fail(`${file} has an invalid or future evidenceCreatedAt timestamp`);
  }
  latestEvidenceTimestamp = Math.max(latestEvidenceTimestamp, createdMilliseconds);
  const id = evidenceId(name, receipt);
  if (!id) fail(`${file} is missing its evidence identifier`);
  reviewedEvidence[file] = {
    sha256: await sha256(path),
    evidenceId: id,
    evidenceCreatedAt: receipt.evidenceCreatedAt,
  };
  if (name === "app") artifactSha256 = receipt.sha256;
}
if (!/^[0-9a-f]{64}$/.test(artifactSha256)) fail("App receipt artifact SHA-256 is invalid");
while (Date.now() <= latestEvidenceTimestamp) {
  await new Promise((resolvePromise) => setTimeout(resolvePromise, 2));
}
const reviewedAt = new Date().toISOString();
const outputPath = resolve(process.env.CMDTAB_FINAL_QA_RECEIPT ?? resolve(outputDirectory, "final-qa-receipt.json"));
await mkdir(dirname(outputPath), { recursive: true, mode: 0o700 });
await writeFile(outputPath, `${JSON.stringify({
  version: 1,
  generator: "scripts/generate_final_qa_receipt.mjs",
  ok: true,
  findings: 0,
  reviewer,
  reviewReportId,
  sourceCommit,
  releaseTag,
  artifactSha256,
  reviewedEvidence,
  reviewedAt,
  evidenceCreatedAt: reviewedAt,
}, null, 2)}\n`, { mode: 0o600 });
await chmod(outputPath, 0o600);
console.log(`Generated bound final QA receipt: ${outputPath}`);
