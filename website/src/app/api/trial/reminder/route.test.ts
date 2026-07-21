import { afterEach, describe, expect, it, vi } from "vitest";

import { GET } from "./route";

describe("trial reminder authorization", () => {
  afterEach(() => vi.unstubAllEnvs());

  it("fails closed when CRON_SECRET is missing", async () => {
    vi.stubEnv("CRON_SECRET", "");

    const response = await GET(
      new Request("https://cmdtab.example/api/trial/reminder"),
    );

    expect(response.status).toBe(401);
    await expect(response.json()).resolves.toMatchObject({ ok: false });
  });

  it("rejects an incorrect bearer token", async () => {
    vi.stubEnv("CRON_SECRET", "expected-secret");

    const response = await GET(
      new Request("https://cmdtab.example/api/trial/reminder", {
        headers: { authorization: "Bearer wrong-secret" },
      }),
    );

    expect(response.status).toBe(401);
  });
});
