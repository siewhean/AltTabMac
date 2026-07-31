import { getBetaReleaseManifest } from "@/lib/stable-release";

export const dynamic = "force-dynamic";

export function GET() {
  const manifest = getBetaReleaseManifest();
  if (!manifest) {
    return Response.json(
      {
        error: "beta_release_unavailable",
        message: "No signed and notarized CmdTab beta release is published.",
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
