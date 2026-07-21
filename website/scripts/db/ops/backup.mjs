import { createHash } from "node:crypto";
import { createReadStream } from "node:fs";
import { chmod, mkdir, open, writeFile } from "node:fs/promises";
import { basename, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { fail } from "./lib.mjs";
import { runProcess } from "./process.mjs";

function requiredEnvironment(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

export async function sha256(path) {
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(path)) hash.update(chunk);
  return hash.digest("hex");
}

export async function createBackup({ databaseUrl, outputPath, run = runProcess }) {
  const destination = resolve(outputPath);
  await mkdir(dirname(destination), { recursive: true });
  const destinationHandle = await open(destination, "w", 0o600);
  await destinationHandle.close();
  await chmod(destination, 0o600);
  const databaseEnvironment = { ...process.env, PGDATABASE: databaseUrl };
  await run("pg_dump", [
    "--format=custom",
    "--compress=9",
    "--no-owner",
    "--no-privileges",
    "--file",
    destination,
  ], { env: databaseEnvironment });
  await chmod(destination, 0o600);
  await run("pg_restore", ["--list", destination], {
    env: databaseEnvironment,
    stdio: "ignore",
  });
  const checksum = await sha256(destination);
  const checksumPath = `${destination}.sha256`;
  await writeFile(checksumPath, `${checksum}  ${basename(destination)}\n`, {
    mode: 0o600,
  });
  return { destination, checksumPath, checksum };
}

async function main() {
  const outputPath = process.argv[2] ?? process.env.DB_BACKUP_OUTPUT?.trim();
  if (!outputPath) throw new Error("Backup output path is required");
  const result = await createBackup({
    databaseUrl: requiredEnvironment("DATABASE_BACKUP_URL"),
    outputPath,
  });
  console.log(JSON.stringify({
    ok: true,
    operation: "database-backup",
    backup: result.destination,
    checksum: result.checksum,
  }));
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => fail(error, "database-backup"));
}
