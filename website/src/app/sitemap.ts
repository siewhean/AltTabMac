import type { MetadataRoute } from "next";

import publicRoutes from "@/content/public-routes.json";
import { betaRoutes } from "@/content/beta";
import { getSiteUrl } from "@/lib/env";
import { getBetaReleaseManifest } from "@/lib/stable-release";

export const dynamic = "force-dynamic";

export default function sitemap(): MetadataRoute.Sitemap {
  const siteUrl = getSiteUrl();

  const routes = publicRoutes.map(({ path, lastModified }) => ({
    url: new URL(path, `${siteUrl}/`).toString(),
    lastModified,
  }));
  const beta = getBetaReleaseManifest();
  if (!beta) return routes;
  return [
    ...routes,
    ...betaRoutes.map((path) => ({
      url: new URL(path, `${siteUrl}/`).toString(),
      lastModified: beta.releaseDate,
    })),
  ];
}
