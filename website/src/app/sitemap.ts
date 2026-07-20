import type { MetadataRoute } from "next";

import publicRoutes from "@/content/public-routes.json";
import { getSiteUrl } from "@/lib/env";

export default function sitemap(): MetadataRoute.Sitemap {
  const siteUrl = getSiteUrl();

  return publicRoutes.map(({ path, lastModified }) => ({
    url: new URL(path, `${siteUrl}/`).toString(),
    lastModified,
  }));
}
