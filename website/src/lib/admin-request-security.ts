function normalizedOrigin(value: string) {
  try {
    const parsed = new URL(value);
    return parsed.origin.toLowerCase();
  } catch {
    return null;
  }
}

export function isSameOriginAdminMutation(
  request: Request,
  trustedOrigin =
    process.env.AUTH0_BASE_URL?.trim() ||
    process.env.SITE_URL?.trim() ||
    process.env.NEXT_PUBLIC_SITE_URL?.trim(),
) {
  const requestOrigin = request.headers.get("origin");
  if (!requestOrigin) return false;

  if (process.env.NODE_ENV === "production" && !trustedOrigin) return false;

  const normalizedReqOrigin = normalizedOrigin(requestOrigin);
  if (!normalizedReqOrigin) return false;

  const expectedUrlOrigin = normalizedOrigin(request.url);
  const expectedConfiguredOrigin = trustedOrigin ? normalizedOrigin(trustedOrigin) : null;

  // The request's own origin is only a convenience for local development. In
  // production a deployment also answers on aliases (e.g. *.vercel.app), so
  // only the configured canonical origin is trusted.
  const matchesUrl =
    process.env.NODE_ENV !== "production" &&
    Boolean(expectedUrlOrigin && normalizedReqOrigin === expectedUrlOrigin);
  const matchesConfigured = Boolean(
    expectedConfiguredOrigin && normalizedReqOrigin === expectedConfiguredOrigin,
  );

  if (!matchesUrl && !matchesConfigured) return false;

  const fetchSite = request.headers.get("sec-fetch-site")?.trim().toLowerCase();
  return !fetchSite || fetchSite === "same-origin";
}
