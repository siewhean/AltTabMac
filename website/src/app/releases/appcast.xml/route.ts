export const dynamic = "force-dynamic";

export function GET() {
  return new Response("Stable CmdTab updates are not published.", {
    status: 503,
    headers: {
      "Cache-Control": "no-store",
      "Content-Type": "application/xml; charset=utf-8",
      "Retry-After": "3600",
      "X-Robots-Tag": "noindex, nofollow, noarchive",
    },
  });
}
