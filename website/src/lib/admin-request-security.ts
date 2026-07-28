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
  const expectedOrigin = normalizedOrigin(trustedOrigin || request.url);
  if (!expectedOrigin || normalizedOrigin(requestOrigin) !== expectedOrigin) return false;

  const fetchSite = request.headers.get("sec-fetch-site")?.trim().toLowerCase();
  return !fetchSite || fetchSite === "same-origin";
}
