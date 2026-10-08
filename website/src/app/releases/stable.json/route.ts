export const dynamic = "force-dynamic";

export function GET() {
  // A configured manifest does not reopen public downloads during waitlist mode.
  return Response.json({
    error: "waitlist_only",
    message: "CmdTab is accepting waitlist signups only. Public downloads are closed.",
  }, { status: 503, headers: {
    "Cache-Control": "no-store",
    "Retry-After": "3600",
    "X-Robots-Tag": "noindex, nofollow, noarchive",
  } });
}
