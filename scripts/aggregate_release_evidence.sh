#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=release_metadata.sh
source "${ROOT_DIR}/scripts/release_metadata.sh"

fail() {
    echo "$1" >&2
    exit 1
}

validate_release_metadata_against_source || fail "Release metadata is not canonical"
SOURCE_COMMIT="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
[ -z "$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=all)" ] \
    || fail "Evidence aggregation requires a clean source tree"
[ "$(git -C "${ROOT_DIR}" rev-list -n 1 "${CMDTAB_RELEASE_TAG}" 2>/dev/null || true)" = \
    "${SOURCE_COMMIT}" ] || fail "${CMDTAB_RELEASE_TAG} must point to HEAD"

OUTPUT_DIR="${CMDTAB_RELEASE_DIR:-${ROOT_DIR}/dist}"
APP_RECEIPT="${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-release-receipt.json"
PREVIEW_RECEIPT="${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-preview-deployment.json"
PREVIEW_SMOKE_RECEIPT="${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-preview-smoke.json"
PRODUCTION_RECEIPT="${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-production-staging-deployment.json"
MIGRATION_RECEIPT="${CMDTAB_MIGRATION_RECEIPT:-${OUTPUT_DIR}/production-migration-receipt.json}"
NEON_RECOVERY_RECEIPT="${CMDTAB_NEON_RECOVERY_RECEIPT:-${OUTPUT_DIR}/neon-recovery-receipt.json}"
RUNTIME_QA_RECEIPT="${CMDTAB_RUNTIME_QA_RECEIPT:-${OUTPUT_DIR}/runtime-qa-receipt.json}"
APPLE_SILICON_QA_RECEIPT="${CMDTAB_APPLE_SILICON_QA_RECEIPT:-${OUTPUT_DIR}/clean-mac-arm64-qa-receipt.json}"
INTEL_QA_RECEIPT="${CMDTAB_INTEL_QA_RECEIPT:-${OUTPUT_DIR}/clean-mac-x86_64-qa-receipt.json}"
BACKUP_RESTORE_RECEIPT="${CMDTAB_BACKUP_RESTORE_RECEIPT:-${OUTPUT_DIR}/backup-restore-receipt.json}"
ENVIRONMENT_RECEIPT="${CMDTAB_ENVIRONMENT_RECEIPT:-${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-environment-validation.json}"
FINAL_QA_RECEIPT="${CMDTAB_FINAL_QA_RECEIPT:-${OUTPUT_DIR}/final-qa-receipt.json}"
for receipt in "${APP_RECEIPT}" "${PREVIEW_RECEIPT}" "${PREVIEW_SMOKE_RECEIPT}" \
    "${PRODUCTION_RECEIPT}" "${MIGRATION_RECEIPT}" "${NEON_RECOVERY_RECEIPT}" "${RUNTIME_QA_RECEIPT}" \
    "${APPLE_SILICON_QA_RECEIPT}" "${INTEL_QA_RECEIPT}" \
    "${BACKUP_RESTORE_RECEIPT}" "${ENVIRONMENT_RECEIPT}" "${FINAL_QA_RECEIPT}"; do
    [ -s "${receipt}" ] || fail "Missing release evidence: ${receipt}"
done

"${CMDTAB_RELEASE_VERIFIER:-${ROOT_DIR}/scripts/verify_release_artifacts.sh}" \
    --release --output-dir "${OUTPUT_DIR}"

SOURCE_COMMIT="${SOURCE_COMMIT}" RELEASE_TAG="${CMDTAB_RELEASE_TAG}" \
APP_RECEIPT="${APP_RECEIPT}" PREVIEW_RECEIPT="${PREVIEW_RECEIPT}" \
PREVIEW_SMOKE_RECEIPT="${PREVIEW_SMOKE_RECEIPT}" PRODUCTION_RECEIPT="${PRODUCTION_RECEIPT}" \
MIGRATION_RECEIPT="${MIGRATION_RECEIPT}" RUNTIME_QA_RECEIPT="${RUNTIME_QA_RECEIPT}" \
NEON_RECOVERY_RECEIPT="${NEON_RECOVERY_RECEIPT}" \
APPLE_SILICON_QA_RECEIPT="${APPLE_SILICON_QA_RECEIPT}" INTEL_QA_RECEIPT="${INTEL_QA_RECEIPT}" \
BACKUP_RESTORE_RECEIPT="${BACKUP_RESTORE_RECEIPT}" ENVIRONMENT_RECEIPT="${ENVIRONMENT_RECEIPT}" \
FINAL_QA_RECEIPT="${FINAL_QA_RECEIPT}" node <<'NODE'
const { createHash } = require("node:crypto");
const { readFileSync } = require("node:fs");
const receiptNames = [
  "APP_RECEIPT", "PREVIEW_RECEIPT", "PREVIEW_SMOKE_RECEIPT", "PRODUCTION_RECEIPT",
  "MIGRATION_RECEIPT", "NEON_RECOVERY_RECEIPT", "RUNTIME_QA_RECEIPT", "APPLE_SILICON_QA_RECEIPT",
  "INTEL_QA_RECEIPT", "BACKUP_RESTORE_RECEIPT", "ENVIRONMENT_RECEIPT",
  "FINAL_QA_RECEIPT",
];
const receipts = Object.fromEntries(
  receiptNames
    .map((name) => [name, require(process.env[name])]),
);
const failures = [];
for (const [name, receipt] of Object.entries(receipts)) {
  if (receipt.sourceCommit !== process.env.SOURCE_COMMIT) failures.push(`${name} source commit`);
  if (receipt.releaseTag !== process.env.RELEASE_TAG) failures.push(`${name} release tag`);
}
if (receipts.PREVIEW_RECEIPT.environment !== "preview" || receipts.PREVIEW_RECEIPT.healthStatus !== "passed") failures.push("Preview health evidence");
const smoke = receipts.PREVIEW_SMOKE_RECEIPT;
const smokeChecks = smoke.checks ?? {};
if (smoke.generator !== "scripts/run_preview_smoke.sh" || smoke.ok !== true ||
    smoke.nonDestructive !== true || smoke.deploymentId !== receipts.PREVIEW_RECEIPT.deploymentId ||
    smoke.privacySafe !== true || smokeChecks.unauthorizedCron?.status !== 401 ||
    smokeChecks.invalidWebhook?.status !== 401 || smokeChecks.webhookReplay?.firstStatus !== 200 ||
    smokeChecks.webhookReplay?.secondStatus !== 200 || smokeChecks.webhookReplay?.persistedRows !== 1 ||
    smokeChecks.webhookReplay?.fixtureCleaned !== true || smokeChecks.trialPath?.pageStatus !== 200 ||
    smokeChecks.trialPath?.apiValidationStatus !== 400 || smokeChecks.checkoutPath?.pageStatus !== 200 ||
    smokeChecks.licensePath?.redirectStatus !== 307 || smokeChecks.licensePath?.helpStatus !== 200 ||
    smokeChecks.dashboardAuthentication?.redirectStatus !== 307 ||
    smokeChecks.dashboardAuthentication?.loginPageStatus !== 200 ||
    smokeChecks.sharedRedisRateLimit?.status !== 200 ||
    smokeChecks.sharedRedisRateLimit?.allowedCount !== 6 ||
    smokeChecks.sharedRedisRateLimit?.blocked !== true ||
    Object.values(smokeChecks).some((check) => check?.passed !== true)) failures.push("Preview live smoke evidence");
if (receipts.PRODUCTION_RECEIPT.environment !== "production" ||
    receipts.PRODUCTION_RECEIPT.releasePhase !== "staging" ||
    receipts.PRODUCTION_RECEIPT.aliasStatus !== "unaliased" ||
    receipts.PRODUCTION_RECEIPT.accessControlVerified !== true ||
    receipts.PRODUCTION_RECEIPT.healthStatus !== "passed") failures.push("Production staging health evidence");
const recovery = receipts.NEON_RECOVERY_RECEIPT;
const recoveryBytes = readFileSync(process.env.NEON_RECOVERY_RECEIPT);
const recoverySha256 = createHash("sha256").update(recoveryBytes).digest("hex");
const providerHashes = recovery.providerResponseSha256 ?? {};
const requiredProviderHashes = ["project", "productionBranch", "checkpointCreate", "checkpointBranch", "operations"];
const neonIdentifier = /^[a-z0-9-]{1,60}$/;
const checkpointCreatedMilliseconds = Date.parse(recovery.checkpointCreatedAt);
const recoveryEvidenceMilliseconds = Date.parse(recovery.evidenceCreatedAt);
if (recovery.ok !== true || recovery.provider !== "neon" ||
    recovery.generator !== "scripts/capture_neon_recovery_evidence.mjs" ||
    recovery.apiBase !== "https://console.neon.tech/api/v2" ||
    !neonIdentifier.test(recovery.projectId ?? "") ||
    !neonIdentifier.test(recovery.productionBranchId ?? "") ||
    !neonIdentifier.test(recovery.recoveryBranchId ?? "") ||
    recovery.recoveryBranchId === recovery.productionBranchId || !String(recovery.checkpointName ?? "") ||
    !Array.isArray(recovery.operationIds) || recovery.operationIds.length < 1 ||
    recovery.operationIds.some((id) => !String(id ?? "").trim()) ||
    new Set(recovery.operationIds).size !== recovery.operationIds.length ||
    !Number.isFinite(checkpointCreatedMilliseconds) ||
    checkpointCreatedMilliseconds > recoveryEvidenceMilliseconds ||
    !Number.isInteger(recovery.historyRetentionSeconds) || recovery.historyRetentionSeconds < 604800 ||
    recovery.pitrDays !== recovery.historyRetentionSeconds / 86400 ||
    !/^[0-9a-f]{64}$/.test(recovery.checkpointLsnSha256 ?? "") ||
    Object.keys(providerHashes).sort().join(",") !== requiredProviderHashes.sort().join(",") ||
    requiredProviderHashes.some((name) => !/^[0-9a-f]{64}$/.test(providerHashes[name] ?? ""))) {
  failures.push("provider-verified Neon recovery evidence");
}
const migrationRecovery = receipts.MIGRATION_RECEIPT.neonRecoveryEvidence;
if (receipts.MIGRATION_RECEIPT.ok !== true || migrationRecovery?.sha256 !== recoverySha256 ||
    migrationRecovery?.file !== process.env.NEON_RECOVERY_RECEIPT.split("/").at(-1) ||
    migrationRecovery?.projectId !== recovery.projectId ||
    migrationRecovery?.productionBranchId !== recovery.productionBranchId ||
    migrationRecovery?.recoveryBranchId !== recovery.recoveryBranchId ||
    migrationRecovery?.checkpointLsnSha256 !== recovery.checkpointLsnSha256) failures.push("migration/Neon recovery binding");
const runtime = receipts.RUNTIME_QA_RECEIPT;
const finiteInRange = (value, minimum, maximum, maximumExclusive = false) =>
  Number.isFinite(value) && value >= minimum &&
    (maximumExclusive ? value < maximum : value <= maximum);
const integerAtLeast = (value, minimum) => Number.isInteger(value) && value >= minimum;
if (runtime.passed !== true || (runtime.failures?.length ?? 1) !== 0 ||
    !integerAtLeast(runtime.warmSessions, 100) || !integerAtLeast(runtime.coldSessions, 20) ||
    !integerAtLeast(runtime.exactWindowActivations, 100) || !integerAtLeast(runtime.multiWindowSessions, 100) ||
    !integerAtLeast(runtime.forwardSteps, 200) || !integerAtLeast(runtime.reverseSteps, 200) ||
    !integerAtLeast(runtime.callbackSamples, 1) ||
    !finiteInRange(runtime.warmPostDeadlineP95Milliseconds, 0, 50) ||
    !finiteInRange(runtime.warmPostDeadlineMaximumMilliseconds, 0, 100) ||
    !finiteInRange(runtime.callbackP95Milliseconds, 0, 5) ||
    !finiteInRange(runtime.callbackMaximumMilliseconds, 0, 20, true) ||
    !finiteInRange(runtime.coldTotalP95Milliseconds, 0, 250)) failures.push("runtime performance/MRU evidence");
for (const [name, architecture] of [["APPLE_SILICON_QA_RECEIPT", "arm64"], ["INTEL_QA_RECEIPT", "x86_64"]]) {
  const receipt = receipts[name];
  const checks = receipt.checks ?? {};
  const requiredChecks = ["gatekeeper", "dragInstall", "permissionGrantDenyRevokeRecovery", "launchAtLogin", "secureInput", "spaces", "fullscreen", "multipleDisplays", "licensing", "telemetryOptOut"];
  if (receipt.ok !== true || receipt.cleanMac !== true || receipt.architecture !== architecture ||
      !finiteInRange(receipt.macOSMajor, 13, 99) || requiredChecks.some((check) => checks[check] !== true) ||
      receipt.artifactSha256 !== receipts.APP_RECEIPT.sha256) failures.push(`${architecture} clean-Mac evidence`);
}
const backup = receipts.BACKUP_RESTORE_RECEIPT;
if (backup.ok !== true || backup.backupVerified !== true || backup.restoreVerified !== true ||
    backup.generator !== "scripts/generate_backup_restore_release_receipt.mjs" ||
    !finiteInRange(backup.pitrDays, 7, 3650) || !/^[0-9a-f]{64}$/.test(backup.backupSha256 ?? "") ||
    !String(backup.backupRunId ?? "") || !String(backup.restoreRunId ?? "") ||
    backup.inputReceipts?.backup?.runId !== backup.backupRunId ||
    backup.inputReceipts?.restore?.runId !== backup.restoreRunId ||
    !String(backup.workflowRepository ?? "").includes("/") ||
    !/^[0-9a-f]{64}$/.test(backup.inputReceipts?.backup?.sha256 ?? "") ||
    !/^[0-9a-f]{64}$/.test(backup.inputReceipts?.restore?.sha256 ?? "") ||
    backup.historyRetentionSeconds !== recovery.historyRetentionSeconds ||
    backup.pitrDays !== recovery.pitrDays ||
    backup.neonRecoveryEvidence?.file !== process.env.NEON_RECOVERY_RECEIPT.split("/").at(-1) ||
    backup.neonRecoveryEvidence?.sha256 !== recoverySha256 ||
    backup.neonRecoveryEvidence?.projectId !== recovery.projectId ||
    backup.neonRecoveryEvidence?.productionBranchId !== recovery.productionBranchId ||
    backup.neonRecoveryEvidence?.recoveryBranchId !== recovery.recoveryBranchId ||
    backup.neonRecoveryEvidence?.checkpointLsnSha256 !== recovery.checkpointLsnSha256) failures.push("generated backup/restore/Neon recovery evidence");
const environment = receipts.ENVIRONMENT_RECEIPT;
if (environment.ok !== true || environment.previewProductionSeparated !== true || environment.wafEnforced !== true) failures.push("environment/WAF evidence");
const projectIds = [receipts.PREVIEW_RECEIPT.projectId, receipts.PRODUCTION_RECEIPT.projectId, environment.projectId];
if (projectIds.some((value) => !String(value ?? "").trim()) || new Set(projectIds).size !== 1) failures.push("Vercel project correlation");
const finalQa = receipts.FINAL_QA_RECEIPT;
if (finalQa.ok !== true || finalQa.findings !== 0 ||
    finalQa.generator !== "scripts/generate_final_qa_receipt.mjs" ||
    !String(finalQa.reviewer ?? "").trim() || !String(finalQa.reviewReportId ?? "").trim()) {
  failures.push("generated final zero-findings QA evidence");
}

function requiredEvidenceId(name, receipt) {
  const nonempty = (...values) => values.every((value) => String(value ?? "").trim());
  switch (name) {
    case "APP_RECEIPT":
      return nonempty(receipt.notarizationSubmissionIds?.app, receipt.notarizationSubmissionIds?.dmg)
        ? `notary:${receipt.notarizationSubmissionIds.app}:${receipt.notarizationSubmissionIds.dmg}` : null;
    case "PREVIEW_RECEIPT":
    case "PRODUCTION_RECEIPT":
      return nonempty(receipt.deploymentId) ? `deployment:${receipt.deploymentId}` : null;
    case "PREVIEW_SMOKE_RECEIPT":
      return nonempty(receipt.deploymentId) ? `preview-smoke:${receipt.deploymentId}` : null;
    case "MIGRATION_RECEIPT":
      return nonempty(receipt.neonRecoveryEvidence?.sha256, receipt.neonRecoveryEvidence?.recoveryBranchId)
        ? `migration:${receipt.neonRecoveryEvidence.sha256}:${receipt.neonRecoveryEvidence.recoveryBranchId}` : null;
    case "NEON_RECOVERY_RECEIPT":
      return nonempty(receipt.projectId, receipt.productionBranchId, receipt.recoveryBranchId,
        receipt.checkpointLsnSha256)
        ? `neon-recovery:${receipt.projectId}:${receipt.recoveryBranchId}:${receipt.checkpointLsnSha256}` : null;
    case "RUNTIME_QA_RECEIPT":
      return [receipt.warmSessions, receipt.coldSessions, receipt.exactWindowActivations,
        receipt.forwardSteps, receipt.reverseSteps].every(Number.isInteger)
        ? `runtime:${receipt.warmSessions}:${receipt.coldSessions}:${receipt.exactWindowActivations}:${receipt.forwardSteps}:${receipt.reverseSteps}` : null;
    case "APPLE_SILICON_QA_RECEIPT":
    case "INTEL_QA_RECEIPT":
      return nonempty(receipt.architecture, receipt.artifactSha256)
        ? `clean-mac:${receipt.architecture}:${receipt.artifactSha256}` : null;
    case "BACKUP_RESTORE_RECEIPT":
      return nonempty(receipt.backupRunId, receipt.restoreRunId, receipt.backupSha256)
        ? `backup-restore:${receipt.backupRunId}:${receipt.restoreRunId}:${receipt.backupSha256}` : null;
    case "ENVIRONMENT_RECEIPT":
      return nonempty(receipt.projectId) ? `environment:${receipt.projectId}` : null;
    default:
      return null;
  }
}

const precedingNames = receiptNames.filter((name) => name !== "FINAL_QA_RECEIPT");
const expectedBindings = {};
let latestEvidenceTimestamp = 0;
for (const name of precedingNames) {
  const receipt = receipts[name];
  const evidenceCreatedMilliseconds = Date.parse(receipt.evidenceCreatedAt);
  if (!Number.isFinite(evidenceCreatedMilliseconds)) {
    failures.push(`${name} evidence timestamp`);
    continue;
  }
  if (evidenceCreatedMilliseconds > Date.now()) failures.push(`${name} future evidence timestamp`);
  latestEvidenceTimestamp = Math.max(latestEvidenceTimestamp, evidenceCreatedMilliseconds);
  const id = requiredEvidenceId(name, receipt);
  if (!id) failures.push(`${name} evidence identifier`);
  const path = process.env[name];
  expectedBindings[path.split("/").at(-1)] = {
    sha256: createHash("sha256").update(readFileSync(path)).digest("hex"),
    evidenceId: id,
    evidenceCreatedAt: receipt.evidenceCreatedAt,
  };
}
const actualBindings = finalQa.reviewedEvidence;
const expectedBindingNames = Object.keys(expectedBindings).sort();
const actualBindingNames = actualBindings && typeof actualBindings === "object"
  ? Object.keys(actualBindings).sort() : [];
if (JSON.stringify(actualBindingNames) !== JSON.stringify(expectedBindingNames) ||
    expectedBindingNames.some((name) => {
      const actual = actualBindings?.[name];
      const expected = expectedBindings[name];
      return actual?.sha256 !== expected.sha256 || actual?.evidenceId !== expected.evidenceId ||
        actual?.evidenceCreatedAt !== expected.evidenceCreatedAt;
    })) {
  failures.push("final QA receipt bindings");
}
const reviewedAtMilliseconds = Date.parse(finalQa.reviewedAt);
if (!Number.isFinite(reviewedAtMilliseconds) || reviewedAtMilliseconds > Date.now() ||
    reviewedAtMilliseconds <= latestEvidenceTimestamp ||
    finalQa.evidenceCreatedAt !== finalQa.reviewedAt) failures.push("final QA review ordering");
if (finalQa.artifactSha256 !== receipts.APP_RECEIPT.sha256) failures.push("final QA artifact binding");
if (failures.length) {
  console.error(`Release evidence mismatch: ${failures.join(", ")}`);
  process.exit(1);
}
NODE

SUMMARY="${OUTPUT_DIR}/${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-production-evidence.json"
SOURCE_COMMIT="${SOURCE_COMMIT}" RELEASE_TAG="${CMDTAB_RELEASE_TAG}" \
SUMMARY="${SUMMARY}" APP_RECEIPT="${APP_RECEIPT}" PREVIEW_RECEIPT="${PREVIEW_RECEIPT}" \
PREVIEW_SMOKE_RECEIPT="${PREVIEW_SMOKE_RECEIPT}" PRODUCTION_RECEIPT="${PRODUCTION_RECEIPT}" \
MIGRATION_RECEIPT="${MIGRATION_RECEIPT}" RUNTIME_QA_RECEIPT="${RUNTIME_QA_RECEIPT}" \
NEON_RECOVERY_RECEIPT="${NEON_RECOVERY_RECEIPT}" \
APPLE_SILICON_QA_RECEIPT="${APPLE_SILICON_QA_RECEIPT}" INTEL_QA_RECEIPT="${INTEL_QA_RECEIPT}" \
BACKUP_RESTORE_RECEIPT="${BACKUP_RESTORE_RECEIPT}" ENVIRONMENT_RECEIPT="${ENVIRONMENT_RECEIPT}" \
FINAL_QA_RECEIPT="${FINAL_QA_RECEIPT}" node <<'NODE'
const { createHash } = require("node:crypto");
const { readFileSync, writeFileSync } = require("node:fs");
const evidence = [
  "APP_RECEIPT", "PREVIEW_RECEIPT", "PREVIEW_SMOKE_RECEIPT", "PRODUCTION_RECEIPT",
  "MIGRATION_RECEIPT", "NEON_RECOVERY_RECEIPT", "RUNTIME_QA_RECEIPT", "APPLE_SILICON_QA_RECEIPT",
  "INTEL_QA_RECEIPT", "BACKUP_RESTORE_RECEIPT", "ENVIRONMENT_RECEIPT", "FINAL_QA_RECEIPT",
]
  .map((name) => ({
    file: process.env[name].split("/").at(-1),
    sha256: createHash("sha256").update(readFileSync(process.env[name])).digest("hex"),
  }));
writeFileSync(process.env.SUMMARY, JSON.stringify({
  version: 1,
  generator: "scripts/aggregate_release_evidence.sh",
  ok: true,
  releasePhase: "pre-publication",
  sourceCommit: process.env.SOURCE_COMMIT,
  releaseTag: process.env.RELEASE_TAG,
  evidence,
  aggregatedAt: new Date().toISOString(),
}, null, 2) + "\n", { mode: 0o600 });
NODE
chmod 600 "${SUMMARY}"
shasum -a 256 "${SUMMARY}" >"${SUMMARY}.sha256"
chmod 600 "${SUMMARY}.sha256"
echo "Production release evidence aggregated: ${SUMMARY}"
