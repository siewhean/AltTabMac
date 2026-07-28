export type Auth0Configuration = {
  issuer: string;
  clientId: string;
  clientSecret: string;
  ownerSubject: string;
  appBaseUrl: string;
};

function normalizeHttpsUrl(value: string, allowHttpForTest = false) {
  const url = new URL(value);
  const allowedProtocol =
    url.protocol === "https:" || (allowHttpForTest && url.protocol === "http:");
  if (!allowedProtocol || url.username || url.password || url.search || url.hash) {
    throw new Error("Auth0 URL configuration is invalid.");
  }
  return url.toString().replace(/\/+$/, "");
}

export function getAuth0Configuration(
  environment: NodeJS.ProcessEnv = process.env,
): Auth0Configuration | null {
  const issuer = environment.AUTH0_ISSUER_BASE_URL?.trim();
  const clientId = environment.AUTH0_CLIENT_ID?.trim();
  const clientSecret = environment.AUTH0_CLIENT_SECRET?.trim();
  const ownerSubject = environment.AUTH0_OWNER_SUBJECT?.trim();
  const appBaseUrl =
    environment.AUTH0_BASE_URL?.trim() ||
    environment.SITE_URL?.trim() ||
    environment.NEXT_PUBLIC_SITE_URL?.trim();
  if (!issuer || !clientId || !clientSecret || !ownerSubject || !appBaseUrl) return null;

  const allowHttpForTest = environment.NODE_ENV !== "production";
  try {
    return {
      issuer: normalizeHttpsUrl(issuer, allowHttpForTest),
      clientId,
      clientSecret,
      ownerSubject,
      appBaseUrl: normalizeHttpsUrl(appBaseUrl, allowHttpForTest),
    };
  } catch {
    return null;
  }
}
