import { constantTimeEqual } from "@/lib/constant-time";

function bearerToken(request: Request) {
  const authorization = request.headers.get("authorization") ?? "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() ?? "";
}

/**
 * Authorizes internal workers and Vercel Cron requests without leaking secret
 * length or returning early from the cryptographic comparison.
 */
export function isAuthorizedInternalWorker(
  request: Request,
  expectedSecret: string | null | undefined,
) {
  if (!expectedSecret) return false;
  return constantTimeEqual(bearerToken(request), expectedSecret);
}
