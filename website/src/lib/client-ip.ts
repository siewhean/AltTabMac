/**
 * Client IP for rate limits and abuse signals.
 *
 * On Vercel the platform overwrites `x-real-ip` and `x-forwarded-for` with the
 * connecting client's address, so they can be trusted there. Anywhere else
 * (local `next start`, CI, or a different host) a caller controls every header,
 * including `x-vercel-id`, so none of them are trusted and the IP is "unknown".
 * `VERCEL=1` is a system environment variable the platform sets at runtime
 * (the project exposes system environment variables).
 */
export function isTrustedProxyRuntime() {
  return process.env.VERCEL === "1";
}

export function getClientIp(request: Request) {
  if (!isTrustedProxyRuntime()) return "unknown";

  const realIp = request.headers.get("x-real-ip")?.trim();
  if (realIp) return realIp;

  const forwardedFor = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  return forwardedFor || "unknown";
}
