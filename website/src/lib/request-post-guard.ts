const trustedFetchSite = "same-origin";

export function isTrustedPostRequest(request: Request) {
  const requestOrigin = new URL(request.url).origin;
  const origin = request.headers.get("origin");
  const referer = request.headers.get("referer");

  if (origin) {
    return origin === requestOrigin;
  }

  if (referer) {
    try {
      return new URL(referer).origin === requestOrigin;
    } catch {
      return false;
    }
  }

  const fetchSite = request.headers.get("sec-fetch-site")?.trim().toLowerCase();
  return fetchSite === trustedFetchSite;
}
