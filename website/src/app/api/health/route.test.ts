import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";

import { afterEach, describe, expect, it, vi } from "vitest";

import {
  expectedMigrations,
  requiredConstraintDefinitions,
  requiredCoreColumns,
  requiredIndexDefinitions,
} from "@/lib/database-schema";

const query = vi.fn();

vi.mock("@/lib/postgres", () => ({
  getSql: () => query,
}));

import { GET } from "./route";

function request(token = "health-secret") {
  return new Request("https://cmdtab.example/api/health", {
    headers: { authorization: `Bearer ${token}` },
  });
}

type HealthCatalogMock = {
  migrations_present: boolean;
  fulfillments_present: boolean;
  table_count: number;
  index_count: number;
  constraint_count: number;
  migration_column_count: number;
  fulfillment_column_count: number;
  core_columns: string[];
  index_definitions: Record<string, string>;
  constraint_definitions: Record<string, string>;
};

const healthyCatalog: HealthCatalogMock = {
  migrations_present: true,
  fulfillments_present: true,
  table_count: 7,
  index_count: 22,
  constraint_count: 21,
  migration_column_count: 3,
  fulfillment_column_count: 7,
  core_columns: Object.entries(requiredCoreColumns).flatMap(([table, columns]) =>
    columns.map((column) => `${table}.${column}`)),
  index_definitions: requiredIndexDefinitions,
  constraint_definitions: requiredConstraintDefinitions,
};

function mockHealthQueries({
  catalog = healthyCatalog,
  migrations = expectedMigrations,
  staleFulfillments = 0,
}: {
  catalog?: typeof healthyCatalog;
  migrations?: readonly { name: string; checksum: string }[];
  staleFulfillments?: number;
} = {}) {
  query
    .mockResolvedValueOnce([{ connected: true }])
    .mockResolvedValueOnce([catalog])
    .mockResolvedValueOnce(migrations)
    .mockResolvedValueOnce([{ count: staleFulfillments }]);
}

describe("health check", () => {
  afterEach(() => {
    query.mockReset();
    vi.unstubAllEnvs();
  });

  it("fails closed when HEALTHCHECK_SECRET is not configured", async () => {
    vi.stubEnv("HEALTHCHECK_SECRET", "");
    const response = await GET(request());
    expect(response.status).toBe(401);
    expect(query).not.toHaveBeenCalled();
  });

  it("rejects an incorrect bearer token", async () => {
    vi.stubEnv("HEALTHCHECK_SECRET", "health-secret");
    const response = await GET(request("wrong-secret"));
    expect(response.status).toBe(401);
    expect(query).not.toHaveBeenCalled();
  });

  it("returns only minimal healthy status", async () => {
    vi.stubEnv("HEALTHCHECK_SECRET", "health-secret");
    mockHealthQueries();

    const response = await GET(request());
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      ok: true,
      connectivity: "ok",
      schema: "current",
      staleFulfillment: false,
    });
  });

  it("reports stored fulfillment older than 15 minutes", async () => {
    vi.stubEnv("HEALTHCHECK_SECRET", "health-secret");
    mockHealthQueries({ staleFulfillments: 2 });

    const response = await GET(request());
    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({
      ok: false,
      connectivity: "ok",
      schema: "current",
      staleFulfillment: true,
    });

    const staleQuery = query.mock.calls[3][0].join(" ");
    expect(staleQuery).toContain("delivery_status = 'stored'");
    expect(staleQuery).toContain("and created_at < now()");
    expect(staleQuery).toContain("delivery_status = 'processing'");
    expect(staleQuery).toContain("and updated_at < now()");
  });

  it("reports checksum drift for the expected migration name", async () => {
    vi.stubEnv("HEALTHCHECK_SECRET", "health-secret");
    mockHealthQueries({
      migrations: [{ name: "0001_baseline.sql", checksum: "unexpected-checksum" }],
    });

    const response = await GET(request());
    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({
      ok: false,
      connectivity: "ok",
      schema: "outdated",
      staleFulfillment: false,
    });
  });

  it("reports an unexpected applied migration as drift", async () => {
    vi.stubEnv("HEALTHCHECK_SECRET", "health-secret");
    mockHealthQueries({
      migrations: [
        ...expectedMigrations,
        { name: "9999_unknown.sql", checksum: "unknown" },
      ],
    });

    const response = await GET(request());
    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({
      ok: false,
      connectivity: "ok",
      schema: "outdated",
      staleFulfillment: false,
    });
  });

  it("reports required structural drift without exposing its details", async () => {
    vi.stubEnv("HEALTHCHECK_SECRET", "health-secret");
    mockHealthQueries({
      catalog: { ...healthyCatalog, constraint_count: 20 },
    });

    const response = await GET(request());
    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({
      ok: false,
      connectivity: "ok",
      schema: "outdated",
      staleFulfillment: false,
    });
  });

  it("reports changed index and constraint definitions as drift", async () => {
    vi.stubEnv("HEALTHCHECK_SECRET", "health-secret");
    mockHealthQueries({
      catalog: {
        ...healthyCatalog,
        index_definitions: {
          ...requiredIndexDefinitions,
          license_fulfillments_order_hash_key:
            "create index license_fulfillments_order_hash_key on license_fulfillments using btree (order_hash)",
        },
        constraint_definitions: {
          ...requiredConstraintDefinitions,
          "trial_claims.trial_claims_window_check": "check (true)",
        },
      },
    });

    const response = await GET(request());
    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toMatchObject({
      ok: false,
      schema: "outdated",
    });
  });

  it("reports a missing core application column as drift", async () => {
    vi.stubEnv("HEALTHCHECK_SECRET", "health-secret");
    mockHealthQueries({
      catalog: {
        ...healthyCatalog,
        core_columns: healthyCatalog.core_columns.filter(
          (column) => column !== "trial_claims.ends_at",
        ),
      },
    });

    const response = await GET(request());
    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toMatchObject({
      ok: false,
      schema: "outdated",
    });
  });

  it("keeps the complete expected migration manifest synchronized", async () => {
    const directory = new URL("../../../../db/migrations/", import.meta.url);
    const names = (await readdir(directory))
      .filter((name) => /^\d{4}_[a-z0-9_-]+\.sql$/.test(name))
      .sort();
    const manifest = await Promise.all(names.map(async (name) => {
      const migration = await readFile(new URL(name, directory), "utf8");
      return {
        name,
        checksum: createHash("sha256").update(migration).digest("hex"),
      };
    }));
    expect(expectedMigrations).toEqual(manifest);
  });
});
