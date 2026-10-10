/**
 * Client IP as seen by the platform. `x-forwarded-for` is only trusted on
 * Vercel, where the platform sets it; elsewhere a caller could spoof it.
 */
export function getClientIp(request: Request) {
  const realIp = request.headers.get("x-real-ip")?.trim();
  if (realIp) return realIp;

  const forwardedFor = request.headers.get("x-forwarded-for");
  if (request.headers.has("x-vercel-id") && forwardedFor) {
    return forwardedFor.split(",")[0]?.trim() ?? "unknown";
  }

  return "unknown";
}
