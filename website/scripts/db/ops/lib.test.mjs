import { readFile } from "node:fs/promises";

import { afterEach, describe, expect, it, vi } from "vitest";

import {
  compareMigrations,
  databaseUrl,
  loadMigrations,
  normalizeConstraintDefinition,
  requiredConstraintDefinitions,
  requiredTables,
} from "./lib.mjs";
import { validateLifecycle } from "./check-backup-lifecycle.mjs";

describe("database migrations", () => {
  afterEach(() => vi.unstubAllEnvs());

  it("baselines every application table", async () => {
    const [baseline] = await loadMigrations();
    expect(baseline.name).toBe("0001_baseline.sql");
    for (const table of requiredTables) {
      expect(baseline.sql).toContain(`create table if not exists ${table}`);
    }
  });

  it("detects checksum drift and pending migrations", () => {
    const files = [
      { name: "0001_baseline.sql", checksum: "new" },
      { name: "0002_next.sql", checksum: "next" },
    ];
    const result = compareMigrations(files, [
      { name: "0001_baseline.sql", checksum: "old" },
    ]);
    expect(result.changed.map((item) => item.name)).toEqual(["0001_baseline.sql"]);
    expect(result.pending.map((item) => item.name)).toEqual(["0002_next.sql"]);
  });

  it("normalizes and distinguishes constraint definitions", () => {
    const expected = requiredConstraintDefinitions.license_fulfillments_processing_token_check;
    expect(normalizeConstraintDefinition(`CHECK ((${expected.slice(7, -1)}))`))
      .toBe(normalizeConstraintDefinition(expected));
    expect(normalizeConstraintDefinition("check (processing_token is not null)"))
      .not.toBe(normalizeConstraintDefinition(expected));
  });

  it("does not fall back from privileged role URLs to runtime credentials", () => {
    vi.stubEnv("DATABASE_URL", "postgresql://runtime.example/database");
    vi.stubEnv("DATABASE_MIGRATOR_URL", "");
    vi.stubEnv("DATABASE_MAINTENANCE_URL", "");
    expect(databaseUrl("DATABASE_MIGRATOR_URL")).toBeNull();
    expect(databaseUrl("DATABASE_MAINTENANCE_URL")).toBeNull();
    expect(databaseUrl()).toBe("postgresql://runtime.example/database");
  });

  it("keeps runtime stores free of DDL", async () => {
    const stores = requiredTables.map((table) => {
      const names = {
        admin_settings: "admin-store.ts",
        app_usage_events: "app-usage-store.ts",
        license_fulfillments: "license-fulfillment-store.ts",
        license_requests: "license-request-store.ts",
        site_analytics_events: "site-analytics-store.ts",
        trial_claims: "trial-claim-store.ts",
        waitlist_signups: "waitlist-store.ts",
      };
      return names[table];
    });
    for (const store of stores) {
      const source = await readFile(new URL(`../../../src/lib/${store}`, import.meta.url), "utf8");
      expect(source).not.toMatch(/\b(create|alter|drop)\s+(table|index)\b/i);
    }
  });

  it("guards fulfillment completion with a processing ownership token", async () => {
    const [baseline] = await loadMigrations();
    const source = await readFile(
      new URL("../../../src/lib/license-fulfillment-store.ts", import.meta.url),
      "utf8",
    );

    expect(baseline.sql).toContain("license_fulfillments_processing_token_check");
    expect(baseline.sql).toContain("delivery_status <> 'processing' or processing_token is not null");
    expect(source).toContain("and delivery_status = 'processing'");
    expect(source).toContain("and processing_token = ${processingToken}");
    expect(source).toContain("processing_token = null");
  });

  it("uses the approved bounded retention windows", async () => {
    const source = await readFile(new URL("./retention.mjs", import.meta.url), "utf8");
    expect(source).toContain("interval '90 days'");
    expect(source).toContain("interval '180 days'");
    expect(source.match(/interval '24 months'/g)).toHaveLength(3);
    expect(source).toContain("interval '12 months'");
    expect(source).toContain("interval '7 years'");
    expect(source).toContain("limit ${batchSize}");
    expect(source).toContain("anonymized_at = now()");
    expect(source).toContain("fulfillmentsDeleted");
  });

  it("enforces the approved backup retention classes", async () => {
    const expected = JSON.parse(await readFile(
      new URL("../../../db/backup-lifecycle.json", import.meta.url),
      "utf8",
    ));
    expect(expected.Rules.map((rule) => rule.Expiration.Days)).toEqual([14, 56, 365]);
    expect(validateLifecycle(expected, expected)).toEqual([]);
    const changed = structuredClone(expected);
    changed.Rules[1].Expiration.Days = 55;
    expect(validateLifecycle(expected, changed)).toEqual(["cmdtab-postgres-weekly-8w"]);
  });

  it("bootstraps isolated production roles without exposing credentials", async () => {
    const source = await readFile(new URL("./configure-roles.mjs", import.meta.url), "utf8");
    const roles = [
      "cmdtab_migrator",
      "cmdtab_runtime",
      "cmdtab_maintenance",
      "cmdtab_backup",
    ];
    const passwordVariables = [
      "CMDTAB_MIGRATOR_PASSWORD",
      "CMDTAB_RUNTIME_PASSWORD",
      "CMDTAB_MAINTENANCE_PASSWORD",
      "CMDTAB_BACKUP_PASSWORD",
    ];

    expect(source).toContain('requiredEnvironment("DATABASE_ADMIN_URL")');
    for (const role of roles) expect(source).toContain(role);
    for (const variable of passwordVariables) expect(source).toContain(variable);
    expect(source).toContain("requiredSecret(variable)");
    expect(source).toContain("password %L");
    expect(source).toContain("[format, ...parameters]");
    expect(source).toContain("grant cmdtab_migrator to %I with admin option");
    expect(source).toContain("revoke all privileges on database %I from public");
    expect(source).toContain("revoke all privileges on database %I from %I");
    expect(source).toContain("revoke %I from %I");
    expect(source).toContain("alter schema public owner to cmdtab_migrator");
    expect(source).toContain(
      "revoke all on schema public from cmdtab_runtime, cmdtab_maintenance, cmdtab_backup",
    );
    expect(source).toContain("alter table public.${quoteIdentifier(table)} owner to cmdtab_migrator");
    expect(source).toContain(
      "grant select, insert, update, delete on table ${appTableList} to cmdtab_runtime",
    );
    expect(source).toContain(
      "grant select, update, delete on table ${appTableList} to cmdtab_maintenance",
    );
    expect(source).toContain(
      "grant select on table public.schema_migrations to cmdtab_runtime, cmdtab_maintenance",
    );
    expect(source).toContain("to cmdtab_backup");
    expect(source).toContain("alter default privileges for role cmdtab_migrator");

    const outputStatements = source
      .split("\n")
      .filter((line) => /console\.(log|error)/.test(line));
    for (const line of outputStatements) {
      expect(line).not.toMatch(/password|CMDTAB_.*_PASSWORD/i);
    }
  });
});
