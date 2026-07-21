import { mkdtemp, readFile, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

import { createBackup } from "./backup.mjs";
import { restoreAndVerify, verifyChecksum } from "./restore-verify.mjs";

describe("database backup and restore", () => {
  it("creates a validated custom dump and portable checksum", async () => {
    const directory = await mkdtemp(join(tmpdir(), "cmdtab-backup-"));
    const output = join(directory, "cmdtab.dump");
    const calls = [];
    const run = async (command, args, options) => {
      calls.push({ command, args, options });
      if (command === "pg_dump") {
        expect((await stat(output)).mode & 0o777).toBe(0o600);
        await writeFile(output, "custom-dump");
      }
    };
    const result = await createBackup({
      databaseUrl: "postgresql://backup:secret@database/cmdtab",
      outputPath: output,
      run,
    });

    expect(calls.map((call) => call.command)).toEqual(["pg_dump", "pg_restore"]);
    expect(calls[0].args.join(" ")).not.toContain("secret");
    expect(calls[0].options.env.PGDATABASE).toContain("secret");
    expect(await readFile(result.checksumPath, "utf8"))
      .toMatch(/^[0-9a-f]{64}  cmdtab\.dump\n$/);
  });

  it("rejects a changed dump before invoking restore", async () => {
    const directory = await mkdtemp(join(tmpdir(), "cmdtab-restore-"));
    const dump = join(directory, "cmdtab.dump");
    const checksum = `${dump}.sha256`;
    await writeFile(dump, "changed");
    await writeFile(checksum, `${"0".repeat(64)}  cmdtab.dump\n`);
    const calls = [];
    await expect(restoreAndVerify({
      databaseUrl: "postgresql://restore-only",
      dumpPath: dump,
      checksumPath: checksum,
      run: async (...args) => calls.push(args),
      checkTarget: async () => {},
    })).rejects.toThrow("checksum verification failed");
    expect(calls).toEqual([]);
  });

  it("restores only after checksum verification and keeps credentials out of argv", async () => {
    const directory = await mkdtemp(join(tmpdir(), "cmdtab-restore-"));
    const dump = join(directory, "cmdtab.dump");
    const checksum = `${dump}.sha256`;
    await writeFile(dump, "valid");
    const digest = await import("node:crypto")
      .then(({ createHash }) => createHash("sha256").update("valid").digest("hex"));
    await writeFile(checksum, `${digest}  cmdtab.dump\n`);
    expect(await verifyChecksum(dump, checksum)).toBe(digest);

    const calls = [];
    await restoreAndVerify({
      databaseUrl: "postgresql://restore:secret@database/cmdtab",
      dumpPath: dump,
      checksumPath: checksum,
      run: async (command, args, options) => calls.push({ command, args, options }),
      checkTarget: async () => {},
    });
    expect(calls.map((call) => call.command)).toEqual([
      "pg_restore",
      "pg_restore",
      process.execPath,
    ]);
    expect(calls.flatMap((call) => call.args).join(" ")).not.toContain("secret");
    expect(calls[1].options.env.PGDATABASE).not.toContain("secret");
    expect(calls[1].options.env.PGPASSWORD).toBe("secret");
  });

  it("rejects query-string passwords before invoking restore", async () => {
    const directory = await mkdtemp(join(tmpdir(), "cmdtab-restore-"));
    const dump = join(directory, "cmdtab.dump");
    const checksum = `${dump}.sha256`;
    await writeFile(dump, "valid-query-password");
    const digest = await import("node:crypto")
      .then(({ createHash }) => createHash("sha256").update("valid-query-password").digest("hex"));
    await writeFile(checksum, `${digest}  cmdtab.dump\n`);
    const calls = [];
    await expect(restoreAndVerify({
      databaseUrl: "postgresql://restore@database/cmdtab?sslmode=require&password=a+b%2Bc",
      dumpPath: dump,
      checksumPath: checksum,
      run: async (command, args, options) => calls.push({ command, args, options }),
      checkTarget: async () => {},
    })).rejects.toThrow("password must use URI authority credentials");
    expect(calls).toEqual([]);
  });

  it("keeps backup verification, restore drills, and PostgreSQL integration in CI", async () => {
    const workflow = async (name) => readFile(
      new URL(`../../../../.github/workflows/${name}`, import.meta.url),
      "utf8",
    );
    const backup = await workflow("cmdtab-database-backup.yml");
    expect(backup).toContain("npm --prefix website run db:backup");
    expect(backup).toContain("upload-verification/$retention_class");
    expect(backup).toContain("sha256sum --check cmdtab.dump.sha256");
    expect(backup).toContain("retention_classes=(daily)");
    expect(backup).toContain("get-public-access-block");
    expect(backup).toContain("head-object");
    expect(backup).toContain("complete.json");
    expect(backup).toContain("BETTER_STACK_DB_BACKUP_HEARTBEAT_URL");

    const restore = await workflow("cmdtab-database-restore-drill.yml");
    expect(restore).toContain("npm --prefix website run db:restore:verify");
    expect(restore).toContain("AWS_BACKUP_RESTORE_ROLE_ARN");
    expect(restore).toContain("complete.json");
    expect(restore).toContain("BETTER_STACK_DB_RESTORE_HEARTBEAT_URL");

    const integration = await workflow("cmdtab-database-integration.yml");
    expect(integration).toContain("image: postgres:17");
    expect(integration.match(/run db:migrate\n/g)).toHaveLength(2);
    expect(integration).toContain("Checksum drift was accepted");
    expect(integration).toContain("Runtime role unexpectedly created a table");
    expect(integration).toContain("Backup role unexpectedly modified data");
    expect(integration).toContain("run db:backup");
    expect(integration).toContain("run db:restore:verify");
  });
});
