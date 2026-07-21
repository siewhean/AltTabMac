import { pathToFileURL } from "node:url";

import { compareMigrations, fail, loadMigrations, readAppliedMigrations, withConnection } from "./lib.mjs";

export function parseStatusArguments(argumentsList) {
  const unknown = argumentsList.filter((argument) => argument !== "--allow-pending");
  if (unknown.length) throw new Error(`Unknown argument: ${unknown[0]}`);
  return { allowPending: argumentsList.includes("--allow-pending") };
}

export function statusExitCode(result, options = {}) {
  if (result.changed.length || result.missing.length) return 1;
  if (result.pending.length && !options.allowPending) return 1;
  return 0;
}

export async function runStatus({
  argumentsList = process.argv.slice(2),
  connect = withConnection,
  write = (value) => console.log(value),
} = {}) {
  const options = parseStatusArguments(argumentsList);
  return connect(async (sql) => {
    await sql`select 1`;
    const files = await loadMigrations();
    const applied = await readAppliedMigrations(sql);
    const result = compareMigrations(files, applied);
    write(JSON.stringify({
      connected: true,
      applied: applied.map((item) => item.name),
      pending: result.pending.map((item) => item.name),
      changed: result.changed.map((item) => item.name),
      missing: result.missing.map((item) => item.name),
    }, null, 2));
    return statusExitCode(result, options);
  }, "DATABASE_MAINTENANCE_URL");
}

const isEntrypoint = process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url;
if (isEntrypoint) {
  try {
    process.exitCode = await runStatus();
  } catch (error) {
    fail(error, "database-status");
  }
}
