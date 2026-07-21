import { describe, expect, it } from "vitest";

import {
  InvalidAdminRequestError,
  isSameOriginAdminRequest,
  readAdminForm,
} from "./admin-request-security";

const requestUrl = "https://cmdtab.example/dashboard/login/submit";

function formRequest(body: string, headers: HeadersInit = {}) {
  return new Request(requestUrl, {
    method: "POST",
    body,
    headers: {
      "content-type": "application/x-www-form-urlencoded; charset=utf-8",
      ...headers,
    },
  });
}

describe("isSameOriginAdminRequest", () => {
  it("accepts a matching Origin and rejects a cross-origin Origin", () => {
    expect(
      isSameOriginAdminRequest(
        new Request(requestUrl, { headers: { origin: "https://cmdtab.example" } }),
      ),
    ).toBe(true);
    expect(
      isSameOriginAdminRequest(
        new Request(requestUrl, { headers: { origin: "https://attacker.example" } }),
      ),
    ).toBe(false);
  });

  it("falls back to a same-origin Referer when Origin is absent", () => {
    expect(
      isSameOriginAdminRequest(
        new Request(requestUrl, {
          headers: { referer: "https://cmdtab.example/dashboard/login" },
        }),
      ),
    ).toBe(true);
    expect(
      isSameOriginAdminRequest(
        new Request(requestUrl, { headers: { referer: "not a url" } }),
      ),
    ).toBe(false);
  });

  it("accepts only same-origin fetch metadata when Origin and Referer are absent", () => {
    expect(
      isSameOriginAdminRequest(
        new Request(requestUrl, { headers: { "sec-fetch-site": "same-origin" } }),
      ),
    ).toBe(true);
    expect(
      isSameOriginAdminRequest(
        new Request(requestUrl, { headers: { "sec-fetch-site": "same-site" } }),
      ),
    ).toBe(false);
    expect(isSameOriginAdminRequest(new Request(requestUrl))).toBe(false);
  });
});

describe("readAdminForm", () => {
  it("parses URL-encoded forms with a charset", async () => {
    const form = await readAdminForm(formRequest("password=correct-horse"));
    expect(form.get("password")).toBe("correct-horse");
  });

  it("rejects unsupported content types", async () => {
    const request = new Request(requestUrl, {
      method: "POST",
      body: "{}",
      headers: { "content-type": "application/json" },
    });
    await expect(readAdminForm(request)).rejects.toBeInstanceOf(InvalidAdminRequestError);
  });

  it("rejects an oversized declared content length without reading the body", async () => {
    const request = formRequest("password=x", { "content-length": "4097" });
    await expect(readAdminForm(request)).rejects.toThrow("Form is too large.");
  });

  it("rejects an oversized body when content length is absent or untrusted", async () => {
    const request = formRequest(`password=${"x".repeat(4_097)}`);
    request.headers.delete("content-length");
    await expect(readAdminForm(request)).rejects.toThrow("Form is too large.");
  });
});
