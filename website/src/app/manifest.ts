import type { MetadataRoute } from "next";

import { siteConfig } from "@/content/site";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: siteConfig.name,
    short_name: siteConfig.name,
    description: siteConfig.description,
    start_url: "/",
    display: "standalone",
    background_color: "#05070C",
    theme_color: "#05070C",
    icons: [
      {
        src: "/brand/cmdtab.png",
        sizes: "512x512",
        type: "image/png",
      },
    ],
  };
}
