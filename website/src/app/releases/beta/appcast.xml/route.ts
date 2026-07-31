import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { getBetaReleaseManifest, validateBetaAppcast } from "@/lib/stable-release";

export const dynamic = "force-dynamic";

function unavailable() {
  return new Response("CmdTab beta updates are not published.", {
    status: 503,
    headers: {
      "Cache-Control": "no-store",
      "Content-Type": "application/xml; charset=utf-8",
      "Retry-After": "3600",
      "X-Robots-Tag": "noindex, nofollow, noarchive",
    },
  });
}

export function GET() {
  const manifest = getBetaReleaseManifest();
  if (!manifest) {
    return unavailable();
  }

  try {
    const appcast = readFileSync(resolve(process.cwd(), "..", "release", "beta-appcast.xml"), "utf8");
    validateBetaAppcast(appcast, manifest);
    return new Response(appcast, {
      headers: {
        "Cache-Control": "public, max-age=300, s-maxage=300",
        "Content-Type": "application/xml; charset=utf-8",
        "X-Robots-Tag": "noindex, nofollow, noarchive",
      },
    });
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") return unavailable();
    return unavailable();
  }
}
