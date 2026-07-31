export const dynamic = "force-dynamic";

export function GET() {
  return Response.json(
    {
      error: "stable_release_unavailable",
      message: "No signed and notarized stable CmdTab release is published.",
    },
    {
      status: 503,
      headers: {
        "Cache-Control": "no-store",
        "Retry-After": "3600",
        "X-Robots-Tag": "noindex, nofollow, noarchive",
      },
    },
  );
}
