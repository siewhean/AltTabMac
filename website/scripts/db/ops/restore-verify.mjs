import { readFile } from "node:fs/promises";
import { basename, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import postgres from "postgres";

import { fail } from "./lib.mjs";
import { sha256 } from "./backup.mjs";
import { runProcess } from "./process.mjs";

function requiredEnvironment(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

async function assertEmptyRestoreTarget(databaseUrl) {
  const sql = postgres(databaseUrl, {
    max: 1,
    connect_timeout: 10,
    idle_timeout: 5,
    prepare: false,
    onnotice: () => {},
  });
  try {
    const [target] = await sql`
      select
        current_database() as database_name,
        (
          select count(*)::int
          from information_schema.tables
          where table_schema = 'public'
            and table_type = 'BASE TABLE'
        ) as table_count
    `;
    if (!target?.database_name) throw new Error("Restore target is unavailable");
    if (target.table_count !== 0) {
      throw new Error("Restore verification requires an empty isolated database");
    }
  } finally {
    await sql.end({ timeout: 5 });
  }
}

export async function verifyChecksum(dumpPath, checksumPath) {
  const checksumLine = (await readFile(checksumPath, "utf8")).trim();
  const match = /^([0-9a-f]{64})\s+[*]?(.+)$/.exec(checksumLine);
  if (!match) throw new Error("Backup checksum file is invalid");
  if (basename(match[2]) !== basename(dumpPath)) {
    throw new Error("Backup checksum filename does not match dump");
  }
  const actual = await sha256(dumpPath);
  if (actual !== match[1]) throw new Error("Backup checksum verification failed");
  return actual;
}

export async function restoreAndVerify({
  databaseUrl,
  dumpPath,
  checksumPath,
  run = runProcess,
  checkTarget = assertEmptyRestoreTarget,
}) {
  const dump = resolve(dumpPath);
  const checksum = await verifyChecksum(dump, resolve(checksumPath));
  const target = new URL(databaseUrl);
  if (!target.pathname.slice(1)) throw new Error("Restore target database name is missing");
  const password = decodeURIComponent(target.password);
  const passwordParameters = [...target.searchParams.entries()]
    .filter(([name]) => name.toLowerCase() === "password");
  if (passwordParameters.length > 0) {
    throw new Error("Restore target password must use URI authority credentials");
  }
  target.password = "";
  const safeConnectionUrl = target.toString();
  await checkTarget(databaseUrl);
  const databaseEnvironment = {
    ...process.env,
    PGDATABASE: safeConnectionUrl,
    ...(password ? { PGPASSWORD: password } : {}),
    DATABASE_MAINTENANCE_URL: databaseUrl,
  };
  await run("pg_restore", ["--list", dump], {
    env: databaseEnvironment,
    stdio: "ignore",
  });
  await run("pg_restore", [
    "--exit-on-error",
    "--no-owner",
    "--no-privileges",
    "--dbname",
    safeConnectionUrl,
    dump,
  ], { env: databaseEnvironment });
  await run(process.execPath, [fileURLToPath(new URL("./check.mjs", import.meta.url))], {
    env: databaseEnvironment,
  });
  return checksum;
}

async function main() {
  const [dumpPath, checksumPath] = process.argv.slice(2);
  if (!dumpPath || !checksumPath) {
    throw new Error("Dump and checksum paths are required");
  }
  if (process.env.DB_RESTORE_VERIFY_CONFIRM !== "isolated-empty-target") {
    throw new Error("DB_RESTORE_VERIFY_CONFIRM must confirm an isolated empty target");
  }
  const checksum = await restoreAndVerify({
    databaseUrl: requiredEnvironment("DATABASE_RESTORE_URL"),
    dumpPath,
    checksumPath,
  });
  console.log(JSON.stringify({
    ok: true,
    operation: "database-restore-verify",
    checksum,
  }));
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => fail(error, "database-restore-verify"));
}
