import { describe, expect, it, vi } from "vitest";

import { parseStatusArguments, runStatus, statusExitCode } from "./status.mjs";

describe("database migration status", () => {
  it("fails on pending migrations by default", () => {
    expect(statusExitCode({ changed: [], missing: [], pending: [{}] })).toBe(1);
  });

  it("allows pending migrations only when explicitly requested", () => {
    expect(statusExitCode(
      { changed: [], missing: [], pending: [{}] },
      { allowPending: true },
    )).toBe(0);
  });

  it("never allows changed or missing migration history", () => {
    expect(statusExitCode(
      { changed: [{}], missing: [], pending: [] },
      { allowPending: true },
    )).toBe(1);
    expect(statusExitCode(
      { changed: [], missing: [{}], pending: [] },
      { allowPending: true },
    )).toBe(1);
  });

  it("rejects unknown arguments", () => {
    expect(() => parseStatusArguments(["--unexpected"])).toThrow("Unknown argument");
  });

  it("returns a nonzero process result for a pending live status", async () => {
    const output = vi.fn();
    const sql = vi.fn()
      .mockResolvedValueOnce([{ connected: true }])
      .mockResolvedValueOnce([{ exists: false }]);
    const connect = vi.fn(async (callback, variable) => {
      expect(variable).toBe("DATABASE_MAINTENANCE_URL");
      return callback(sql);
    });

    await expect(runStatus({ connect, write: output })).resolves.toBe(1);
    expect(output).toHaveBeenCalledOnce();
    expect(JSON.parse(output.mock.calls[0][0])).toMatchObject({
      connected: true,
      applied: [],
      pending: ["0001_baseline.sql"],
    });
  });
});
