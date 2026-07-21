import type { Metadata } from "next";

import { siteConfig } from "@/content/site";
import { getSiteUrl } from "@/lib/env";

type PageMetadataInput = {
  title: string;
  description: string;
  path: "/" | `/${string}`;
  image?: string;
  imageAlt?: string;
  imageWidth?: number;
  imageHeight?: number;
  noIndex?: boolean;
};

export function createPageMetadata({
  title,
  description,
  path,
  image = "/opengraph-image",
  imageAlt = `${siteConfig.name} macOS window switcher`,
  imageWidth = 1200,
  imageHeight = 630,
  noIndex = false,
}: PageMetadataInput): Metadata {
  const siteUrl = getSiteUrl();
  const absoluteUrl = new URL(path, `${siteUrl}/`).toString();

  return {
    title,
    description,
    alternates: {
      canonical: path,
    },
    robots: noIndex
      ? {
          index: false,
          follow: false,
          nocache: true,
        }
      : {
          index: true,
          follow: true,
          googleBot: {
            index: true,
            follow: true,
            "max-image-preview": "large",
            "max-snippet": -1,
            "max-video-preview": -1,
          },
        },
    openGraph: {
      type: "website",
      title,
      description,
      url: absoluteUrl,
      siteName: siteConfig.name,
      images: [
        {
          url: image,
          width: imageWidth,
          height: imageHeight,
          alt: imageAlt,
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: [image],
    },
  };
}
