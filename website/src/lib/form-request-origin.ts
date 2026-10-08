/** Next can normalize request.url to its internal hostname; Host is the browser's destination. */
export function isSameOriginFormRequest(request: Request) {
  try {
    const requestUrl = new URL(request.url);
    if (!["http:", "https:"].includes(requestUrl.protocol)) return false;
    const host = request.headers.get("host")?.trim() || requestUrl.host;
    if (!host || /[\s/@?#\\]/.test(host)) return false;
    const expected = new URL(`${requestUrl.protocol}//${host}`).origin;
    const origin = request.headers.get("origin");
    if (origin) {
      const parsed = new URL(origin);
      return origin === parsed.origin && parsed.origin === expected;
    }
    const referer = request.headers.get("referer");
    if (referer) {
      const parsed = new URL(referer);
      return !parsed.username && !parsed.password && parsed.origin === expected;
    }
    return true;
  } catch {
    return false;
  }
}
