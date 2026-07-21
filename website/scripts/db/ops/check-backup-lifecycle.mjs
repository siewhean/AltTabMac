import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

export function validateLifecycle(expected, actual) {
  const actualById = new Map((actual.Rules ?? []).map((rule) => [rule.ID, rule]));
  const mismatches = [];
  for (const rule of expected.Rules ?? []) {
    const installed = actualById.get(rule.ID);
    if (
      !installed ||
      installed.Status !== "Enabled" ||
      installed.Filter?.Prefix !== rule.Filter?.Prefix ||
      installed.Expiration?.Days !== rule.Expiration?.Days
    ) {
      mismatches.push(rule.ID);
    }
  }
  return mismatches;
}

async function main() {
  const [expectedPath, actualPath] = process.argv.slice(2);
  if (!expectedPath || !actualPath) {
    throw new Error("Expected and actual lifecycle JSON paths are required");
  }
  const expected = JSON.parse(await readFile(expectedPath, "utf8"));
  const actual = JSON.parse(await readFile(actualPath, "utf8"));
  const mismatches = validateLifecycle(expected, actual);
  console.log(JSON.stringify({
    ok: mismatches.length === 0,
    operation: "backup-lifecycle-check",
    mismatches,
  }));
  if (mismatches.length > 0) process.exitCode = 1;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(() => {
    console.error(JSON.stringify({
      ok: false,
      operation: "backup-lifecycle-check",
      code: "invalid_lifecycle_configuration",
    }));
    process.exitCode = 1;
  });
}
