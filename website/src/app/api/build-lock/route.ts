import resolvedLock from "../../../../package-lock.json";

export const dynamic = "force-static";

export function GET() {
  return Response.json(resolvedLock, {
    headers: {
      "Cache-Control": "no-store",
      "X-Robots-Tag": "noindex, nofollow, noarchive",
    },
  });
}
