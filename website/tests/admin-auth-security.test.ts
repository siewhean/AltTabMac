import assert from "node:assert/strict";
import { generateKeyPairSync, sign } from "node:crypto";
import test from "node:test";

import {
  getAdminSessionPolicyConfiguration,
  getProxyAdminSessionPolicy,
  isLegacyAdminAuthAllowed,
} from "../src/lib/admin-auth-config.js";
import { completeAdminLogout } from "../src/lib/admin-logout.js";
import { isSameOriginAdminMutation } from "../src/lib/admin-request-security.js";
import {
  buildAuth0AuthorizeUrl,
  buildAuth0LogoutUrl,
  createAuth0Transaction,
  getAuth0Configuration,
  verifyAuth0IdToken,
  type Auth0Configuration,
} from "../src/lib/auth0-oidc.js";
import {
  ADMIN_SESSION_ABSOLUTE_SECONDS,
  ADMIN_SESSION_IDLE_SECONDS,
  createAdminSessionToken,
  validateAdminSessionToken,
} from "../src/lib/admin-session-token.js";

const secret = "s".repeat(64);
const basePolicy = {
  secret,
  generation: "generation-1",
  ownerSubject: "auth0|owner",
  legacyEnabled: false,
};

async function token(overrides: Partial<Parameters<typeof createAdminSessionToken>[0]> = {}) {
  return createAdminSessionToken(
    {
      sub: "auth0|owner",
      auth: "auth0",
      iat: 1_000,
      lst: 1_000,
      gen: "generation-1",
      ...overrides,
    },
    secret,
  );
}

test("admin sessions enforce idle, absolute, generation, and owner boundaries", async () => {
  const valid = await token();
  assert.ok(await validateAdminSessionToken(valid, basePolicy, 999 + ADMIN_SESSION_IDLE_SECONDS));
  assert.equal(
    await validateAdminSessionToken(valid, basePolicy, 1_000 + ADMIN_SESSION_IDLE_SECONDS),
    null,
  );
  const activeNearAbsolute = await token({ lst: 999 + ADMIN_SESSION_ABSOLUTE_SECONDS });
  assert.ok(
    await validateAdminSessionToken(
      activeNearAbsolute,
      basePolicy,
      999 + ADMIN_SESSION_ABSOLUTE_SECONDS,
    ),
  );
  assert.equal(
    await validateAdminSessionToken(
      activeNearAbsolute,
      basePolicy,
      1_000 + ADMIN_SESSION_ABSOLUTE_SECONDS,
    ),
    null,
  );
  assert.equal(
    await validateAdminSessionToken(valid, { ...basePolicy, generation: "generation-2" }, 1_001),
    null,
  );
  assert.equal(
    await validateAdminSessionToken(valid, { ...basePolicy, ownerSubject: "auth0|other" }, 1_001),
    null,
  );
});

test("admin sessions reject tampering and disabled legacy sessions", async () => {
  const valid = await token();
  assert.equal(
    await validateAdminSessionToken(`${valid.slice(0, -1)}x`, basePolicy, 1_001),
    null,
  );
  const legacy = await token({ sub: "legacy-development-owner", auth: "legacy" });
  assert.equal(await validateAdminSessionToken(legacy, basePolicy, 1_001), null);
  assert.ok(
    await validateAdminSessionToken(legacy, { ...basePolicy, legacyEnabled: true }, 1_001),
  );
});

test("admin mutations require the exact trusted origin", () => {
  const allowed = new Request("https://cmdtab.net/dashboard/logout", {
    method: "POST",
    headers: { origin: "https://cmdtab.net", "sec-fetch-site": "same-origin" },
  });
  const crossSite = new Request("https://cmdtab.net/dashboard/logout", {
    method: "POST",
    headers: { origin: "https://attacker.example", "sec-fetch-site": "cross-site" },
  });
  const missing = new Request("https://cmdtab.net/dashboard/logout", { method: "POST" });
  assert.equal(isSameOriginAdminMutation(allowed, "https://cmdtab.net"), true);
  assert.equal(isSameOriginAdminMutation(crossSite, "https://cmdtab.net"), false);
  assert.equal(isSameOriginAdminMutation(missing, "https://cmdtab.net"), false);
});

test("production never enables the shared-password fallback", () => {
  const production = {
    NODE_ENV: "production",
    ADMIN_ENABLE_LEGACY_PASSWORD: "true",
    ADMIN_DASHBOARD_PASSWORD: "should-not-enable-production-access",
    ADMIN_DASHBOARD_SECRET: secret,
    ADMIN_DASHBOARD_SESSION_GENERATION: "generation-1",
  } satisfies NodeJS.ProcessEnv;
  assert.equal(isLegacyAdminAuthAllowed(production), false);
  assert.equal(
    getAdminSessionPolicyConfiguration(production, "auth0|owner")?.legacyEnabled,
    false,
  );
  assert.equal(isLegacyAdminAuthAllowed({ ...production, NODE_ENV: "test" }), true);
  assert.equal(getProxyAdminSessionPolicy(production), null);
});

test("Auth0 production configuration requires HTTPS and an exact owner subject", () => {
  const complete = {
    NODE_ENV: "production",
    AUTH0_ISSUER_BASE_URL: "https://tenant.example.auth0.com",
    AUTH0_CLIENT_ID: "client",
    AUTH0_CLIENT_SECRET: "secret",
    AUTH0_OWNER_SUBJECT: "auth0|owner",
    AUTH0_BASE_URL: "https://cmdtab.net",
  } satisfies NodeJS.ProcessEnv;
  assert.equal(getAuth0Configuration(complete)?.ownerSubject, "auth0|owner");
  assert.equal(getAuth0Configuration({ ...complete, AUTH0_OWNER_SUBJECT: "" }), null);
  assert.equal(
    getAuth0Configuration({ ...complete, AUTH0_ISSUER_BASE_URL: "http://tenant.example" }),
    null,
  );
  assert.equal(
    getProxyAdminSessionPolicy({
      ...complete,
      AUTH0_CLIENT_SECRET: "",
      ADMIN_DASHBOARD_SECRET: secret,
      ADMIN_DASHBOARD_SESSION_GENERATION: "generation-1",
    }),
    null,
  );
});

test("Auth0 login and logout destinations are fixed to configured URLs", () => {
  const configuration: Auth0Configuration = {
    issuer: "https://tenant.example.auth0.com",
    clientId: "client",
    clientSecret: "secret",
    ownerSubject: "auth0|owner",
    appBaseUrl: "https://cmdtab.net",
  };
  const login = buildAuth0AuthorizeUrl(configuration, createAuth0Transaction());
  assert.equal(login.origin, configuration.issuer);
  assert.equal(login.searchParams.get("redirect_uri"), "https://cmdtab.net/dashboard/auth/callback");
  assert.equal(login.searchParams.get("prompt"), "login");
  const logout = buildAuth0LogoutUrl(configuration);
  assert.equal(logout.origin, configuration.issuer);
  assert.equal(logout.searchParams.get("client_id"), configuration.clientId);
  assert.equal(logout.searchParams.get("returnTo"), "https://cmdtab.net/dashboard/login");
});

test("logout clears the local session even when audit storage fails", async () => {
  const actions: string[] = [];
  await completeAdminLogout(
    async () => {
      actions.push("clear");
    },
    async () => {
      actions.push("audit");
      throw new Error("database unavailable");
    },
    () => {
      actions.push("report");
    },
  );
  assert.deepEqual(actions, ["clear", "audit", "report"]);
});

function createIdToken(
  configuration: Auth0Configuration,
  nonce: string,
  claims: Record<string, unknown> = {},
) {
  const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const jwk = publicKey.export({ format: "jwk" });
  const header = Buffer.from(JSON.stringify({ alg: "RS256", kid: "test-key" })).toString(
    "base64url",
  );
  const payload = Buffer.from(
    JSON.stringify({
      iss: `${configuration.issuer}/`,
      aud: configuration.clientId,
      sub: configuration.ownerSubject,
      exp: 2_000,
      iat: 1_000,
      nonce,
      amr: ["pwd", "mfa"],
      ...claims,
    }),
  ).toString("base64url");
  const signature = sign("RSA-SHA256", Buffer.from(`${header}.${payload}`), privateKey).toString(
    "base64url",
  );
  return {
    token: `${header}.${payload}.${signature}`,
    fetch: async () =>
      new Response(
        JSON.stringify({ keys: [{ ...jwk, kid: "test-key", use: "sig", alg: "RS256" }] }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
  };
}

test("Auth0 ID tokens require signature, nonce, MFA, and exact owner subject", async () => {
  const configuration: Auth0Configuration = {
    issuer: "https://tenant.example.auth0.com",
    clientId: "client",
    clientSecret: "secret",
    ownerSubject: "auth0|owner",
    appBaseUrl: "https://cmdtab.net",
  };
  const valid = createIdToken(configuration, "nonce");
  assert.deepEqual(
    await verifyAuth0IdToken(
      valid.token,
      configuration,
      "nonce",
      valid.fetch as typeof fetch,
      1_100,
    ),
    { subject: "auth0|owner" },
  );
  const wrongOwner = createIdToken(configuration, "nonce", { sub: "auth0|other" });
  await assert.rejects(
    verifyAuth0IdToken(
      wrongOwner.token,
      configuration,
      "nonce",
      wrongOwner.fetch as typeof fetch,
      1_100,
    ),
  );
  const noMfa = createIdToken(configuration, "nonce", { amr: ["pwd"] });
  await assert.rejects(
    verifyAuth0IdToken(noMfa.token, configuration, "nonce", noMfa.fetch as typeof fetch, 1_100),
  );
  const misleadingAcr = createIdToken(configuration, "nonce", {
    amr: ["pwd"],
    acr: "urn:test:not-multi-factor",
  });
  await assert.rejects(
    verifyAuth0IdToken(
      misleadingAcr.token,
      configuration,
      "nonce",
      misleadingAcr.fetch as typeof fetch,
      1_100,
    ),
  );
  await assert.rejects(
    verifyAuth0IdToken(valid.token, configuration, "wrong-nonce", valid.fetch as typeof fetch, 1_100),
  );
});
