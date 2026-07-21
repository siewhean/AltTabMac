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

async function readReceipt(path, label) {
  try {
    return JSON.parse(await readFile(path, "utf8"));
  } catch {
    fail(`Invalid ${label} receipt: ${path}`);
  }
}

async function sha256(path) {
  return createHash("sha256").update(await readFile(path)).digest("hex");
}

function timestamp(value, label) {
  const milliseconds = Date.parse(value);
  if (!Number.isFinite(milliseconds)) fail(`${label} receipt timestamp is invalid`);
  return milliseconds;
}

const [backupArgument, restoreArgument, recoveryArgument, outputArgument] = process.argv.slice(2);
if (!backupArgument || !restoreArgument || !recoveryArgument) {
  fail("Usage: generate_backup_restore_release_receipt.mjs BACKUP_RECEIPT RESTORE_RECEIPT NEON_RECOVERY_RECEIPT [OUTPUT]");
}

const infoPlist = await readFile(resolve(root, "Resources/Info.plist"), "utf8");
const version = infoPlist.match(/<key>CFBundleShortVersionString<\/key>\s*<string>([^<]+)<\/string>/)?.[1];
if (!version) fail("Unable to read the canonical release version");
const releaseTag = `v${version}`;
const sourceCommit = git("rev-parse", "HEAD");
if (git("status", "--porcelain", "--untracked-files=all")) {
  fail("Backup/restore evidence generation requires a clean source tree");
}
try {
  if (git("rev-parse", `refs/tags/${releaseTag}^{commit}`) !== sourceCommit) {
    fail(`${releaseTag} must point to HEAD`);
  }
} catch {
  fail(`Missing canonical release tag: ${releaseTag}`);
}

const backupPath = resolve(backupArgument);
const restorePath = resolve(restoreArgument);
const recoveryPath = resolve(recoveryArgument);
const backup = await readReceipt(backupPath, "backup");
const restore = await readReceipt(restorePath, "restore");
const recovery = await readReceipt(recoveryPath, "Neon recovery");
const checksumPattern = /^[0-9a-f]{64}$/;
const providerHashNames = ["project", "productionBranch", "checkpointCreate", "checkpointBranch", "operations"];
const recoveryProviderHashes = recovery.providerResponseSha256 ?? {};
if (recovery.ok !== true || recovery.provider !== "neon" ||
    recovery.apiBase !== "https://console.neon.tech/api/v2" ||
    recovery.generator !== "scripts/capture_neon_recovery_evidence.mjs" ||
    recovery.sourceCommit !== sourceCommit || recovery.releaseTag !== releaseTag ||
    !String(recovery.projectId ?? "") || !String(recovery.productionBranchId ?? "") ||
    !String(recovery.recoveryBranchId ?? "") ||
    recovery.recoveryBranchId === recovery.productionBranchId ||
    !Number.isInteger(recovery.historyRetentionSeconds) || recovery.historyRetentionSeconds < 604800 ||
    !Number.isFinite(recovery.pitrDays) || recovery.pitrDays < 7 ||
    !Array.isArray(recovery.operationIds) || recovery.operationIds.length < 1 ||
    recovery.operationIds.some((id) => !String(id ?? "").trim()) ||
    new Set(recovery.operationIds).size !== recovery.operationIds.length ||
    !checksumPattern.test(recovery.checkpointLsnSha256 ?? "") ||
    Object.keys(recoveryProviderHashes).sort().join(",") !== providerHashNames.sort().join(",") ||
    providerHashNames.some((name) => !checksumPattern.test(recoveryProviderHashes[name] ?? ""))) {
  fail("Neon recovery receipt is not provider-verified or does not match this release");
}
if (backup.ok !== true || backup.operation !== "database-backup" ||
    backup.status !== "succeeded" || !String(backup.runId ?? "") ||
    backup.workflow !== "CmdTab Database Backup" ||
    !String(backup.repository ?? "").includes("/") ||
    !Number.isInteger(backup.runAttempt) || backup.runAttempt < 1 ||
    !Array.isArray(backup.retentionClasses) || !backup.retentionClasses.includes("daily") ||
    !checksumPattern.test(backup.backupSha256 ?? "")) {
  fail("Backup workflow receipt is not successful and checksum-verified");
}
if (restore.ok !== true || restore.operation !== "database-restore-drill" ||
    restore.status !== "succeeded" || !String(restore.runId ?? "") ||
    restore.workflow !== "CmdTab Database Restore Drill" ||
    restore.repository !== backup.repository ||
    !Number.isInteger(restore.runAttempt) || restore.runAttempt < 1 ||
    restore.backupRunId !== backup.runId || restore.backupSha256 !== backup.backupSha256) {
  fail("Restore workflow receipt is not successful or does not reference the backup run");
}
const backupCompletedAt = timestamp(backup.completedAt, "Backup");
const restoreCompletedAt = timestamp(restore.completedAt, "Restore");
const recoveryCreatedAt = timestamp(recovery.evidenceCreatedAt, "Neon recovery");
const checkpointCreatedAt = timestamp(recovery.checkpointCreatedAt, "Neon checkpoint");
if (checkpointCreatedAt > recoveryCreatedAt || recoveryCreatedAt > Date.now()) {
  fail("Neon recovery evidence timestamps are invalid");
}
if (backupCompletedAt < recoveryCreatedAt) fail("Backup receipt predates Neon recovery evidence");
if (restoreCompletedAt < backupCompletedAt) fail("Restore receipt predates its backup receipt");
if (restoreCompletedAt > Date.now()) fail("Restore receipt timestamp is in the future");

const outputPath = resolve(outputArgument ?? resolve(root, "dist/backup-restore-receipt.json"));
await mkdir(dirname(outputPath), { recursive: true, mode: 0o700 });
const evidenceCreatedAt = new Date().toISOString();
const receipt = {
  version: 1,
  generator: "scripts/generate_backup_restore_release_receipt.mjs",
  ok: true,
  sourceCommit,
  releaseTag,
  backupVerified: true,
  restoreVerified: true,
  pitrDays: recovery.pitrDays,
  historyRetentionSeconds: recovery.historyRetentionSeconds,
  backupSha256: backup.backupSha256,
  backupRunId: String(backup.runId),
  restoreRunId: String(restore.runId),
  workflowRepository: backup.repository,
  neonRecoveryEvidence: {
    file: basename(recoveryPath),
    sha256: await sha256(recoveryPath),
    projectId: recovery.projectId,
    productionBranchId: recovery.productionBranchId,
    recoveryBranchId: recovery.recoveryBranchId,
    checkpointLsnSha256: recovery.checkpointLsnSha256,
  },
  inputReceipts: {
    backup: {
      file: basename(backupPath),
      sha256: await sha256(backupPath),
      runId: String(backup.runId),
    },
    restore: {
      file: basename(restorePath),
      sha256: await sha256(restorePath),
      runId: String(restore.runId),
    },
  },
  evidenceCreatedAt,
};
await writeFile(outputPath, `${JSON.stringify(receipt, null, 2)}\n`, { mode: 0o600 });
await chmod(outputPath, 0o600);
console.log(`Generated backup/restore release evidence: ${outputPath}`);
