import {
  createHash,
  createPublicKey,
  randomBytes,
  verify,
  type JsonWebKey as NodeJsonWebKey,
} from "node:crypto";

import type { Auth0Configuration } from "./auth0-config";
export { getAuth0Configuration, type Auth0Configuration } from "./auth0-config";

type IdTokenClaims = {
  iss?: unknown;
  aud?: unknown;
  sub?: unknown;
  exp?: unknown;
  iat?: unknown;
  nonce?: unknown;
  amr?: unknown;
  acr?: unknown;
  "https://cmdtab.net/mfa"?: unknown;
};

type Auth0Jwk = JsonWebKey & { kid?: string; use?: string; alg?: string };

export function createAuth0Transaction() {
  const state = randomBytes(32).toString("base64url");
  const nonce = randomBytes(32).toString("base64url");
  const verifier = randomBytes(48).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  return { state, nonce, verifier, challenge };
}

export function buildAuth0AuthorizeUrl(
  configuration: Auth0Configuration,
  transaction: ReturnType<typeof createAuth0Transaction>,
) {
  const url = new URL("/authorize", configuration.issuer);
  url.search = new URLSearchParams({
    response_type: "code",
    client_id: configuration.clientId,
    redirect_uri: `${configuration.appBaseUrl}/dashboard/auth/callback`,
    scope: "openid profile",
    state: transaction.state,
    nonce: transaction.nonce,
    code_challenge: transaction.challenge,
    code_challenge_method: "S256",
    prompt: "login",
  }).toString();
  return url;
}

export function buildAuth0LogoutUrl(configuration: Auth0Configuration) {
  const url = new URL("/v2/logout", configuration.issuer);
  url.search = new URLSearchParams({
    client_id: configuration.clientId,
    returnTo: `${configuration.appBaseUrl}/dashboard/login`,
  }).toString();
  return url;
}

export async function exchangeAuth0Code(
  configuration: Auth0Configuration,
  code: string,
  verifier: string,
  fetchImplementation: typeof fetch = fetch,
) {
  const response = await fetchImplementation(new URL("/oauth/token", configuration.issuer), {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      client_id: configuration.clientId,
      client_secret: configuration.clientSecret,
      code,
      code_verifier: verifier,
      redirect_uri: `${configuration.appBaseUrl}/dashboard/auth/callback`,
    }),
    signal: AbortSignal.timeout(5_000),
    cache: "no-store",
  });
  if (!response.ok) throw new Error("Auth0 token exchange failed.");
  const body = (await response.json()) as { id_token?: unknown };
  if (typeof body.id_token !== "string") throw new Error("Auth0 response did not include an ID token.");
  return body.id_token;
}

function decodeJwtPart<T>(value: string): T {
  return JSON.parse(Buffer.from(value, "base64url").toString("utf8")) as T;
}

function hasMfaEvidence(claims: IdTokenClaims) {
  return (
    claims["https://cmdtab.net/mfa"] === true ||
    (Array.isArray(claims.amr) && claims.amr.some((method) => method === "mfa"))
  );
}

export async function verifyAuth0IdToken(
  token: string,
  configuration: Auth0Configuration,
  expectedNonce: string,
  fetchImplementation: typeof fetch = fetch,
  nowSeconds = Math.floor(Date.now() / 1000),
) {
  if (token.length > 16_384) throw new Error("Auth0 ID token is too large.");
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("Auth0 ID token is malformed.");
  const [encodedHeader, encodedClaims, encodedSignature] = parts;
  const header = decodeJwtPart<{ alg?: unknown; kid?: unknown }>(encodedHeader);
  const claims = decodeJwtPart<IdTokenClaims>(encodedClaims);
  if (header.alg !== "RS256" || typeof header.kid !== "string") {
    throw new Error("Auth0 ID token algorithm is not allowed.");
  }

  const response = await fetchImplementation(new URL("/.well-known/jwks.json", configuration.issuer), {
    headers: { Accept: "application/json" },
    signal: AbortSignal.timeout(5_000),
    cache: "no-store",
  });
  if (!response.ok) throw new Error("Auth0 signing keys are unavailable.");
  const body = (await response.json()) as { keys?: Auth0Jwk[] };
  const key = body.keys?.find((candidate) => candidate.kid === header.kid);
  if (
    !key ||
    key.kty !== "RSA" ||
    (key.use && key.use !== "sig") ||
    (key.alg && key.alg !== "RS256")
  ) {
    throw new Error("Auth0 signing key is not trusted.");
  }

  const signingInput = `${encodedHeader}.${encodedClaims}`;
  const signatureValid = verify(
    "RSA-SHA256",
    Buffer.from(signingInput),
    createPublicKey({ key: key as NodeJsonWebKey, format: "jwk" }),
    Buffer.from(encodedSignature, "base64url"),
  );
  if (!signatureValid) throw new Error("Auth0 ID token signature is invalid.");

  if (
    claims.iss !== `${configuration.issuer}/` ||
    claims.aud !== configuration.clientId ||
    claims.sub !== configuration.ownerSubject ||
    claims.nonce !== expectedNonce ||
    typeof claims.exp !== "number" ||
    claims.exp <= nowSeconds ||
    typeof claims.iat !== "number" ||
    claims.iat > nowSeconds + 60 ||
    !hasMfaEvidence(claims)
  ) {
    throw new Error("Auth0 ID token claims are not authorized.");
  }

  return { subject: claims.sub };
}
