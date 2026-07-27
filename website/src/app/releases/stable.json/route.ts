import { getStableReleaseManifest } from "@/lib/stable-release";

export const dynamic = "force-static";

export function GET() {
  const manifest = getStableReleaseManifest();
  if (!manifest) {
    return Response.json(
      {
        error: "release_unavailable",
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

  return Response.json(manifest, {
    headers: {
      "Cache-Control": "public, max-age=300, s-maxage=300",
      "X-Robots-Tag": "noindex, nofollow, noarchive",
    },
  });
}
