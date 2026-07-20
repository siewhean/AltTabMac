import type { MetadataRoute } from "next";

import { getSiteUrl } from "@/lib/env";

const publicRoutes = [
  "/",
  "/about",
  "/buy",
  "/changelog",
  "/compatibility",
  "/help",
  "/permissions",
  "/privacy",
  "/security",
  "/trial",
] as const;

export default function sitemap(): MetadataRoute.Sitemap {
  const siteUrl = getSiteUrl();

  return publicRoutes.map((path) => ({
    url: new URL(path, `${siteUrl}/`).toString(),
  }));
}
