import type { Metadata, Viewport } from "next";

import { siteConfig } from "@/content/site";
import { getSiteUrl } from "@/lib/env";

import "./globals.css";

const siteUrl = getSiteUrl();

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: `${siteConfig.name} | A faster Mac app switcher with real window previews`,
  description: siteConfig.description,
  keywords: [...siteConfig.keywords],
  alternates: {
    canonical: "/",
  },
  openGraph: {
    type: "website",
    title: `${siteConfig.name} | A faster Mac app switcher with real window previews`,
    description: siteConfig.description,
    url: siteUrl,
    siteName: siteConfig.name,
    images: [{ url: "/opengraph-image" }],
  },
  twitter: {
    card: "summary_large_image",
    title: `${siteConfig.name} | A faster Mac app switcher with real window previews`,
    description: siteConfig.description,
    images: ["/twitter-image"],
  },
  icons: {
    icon: "/brand/cmdtab.png",
    apple: "/brand/cmdtab.png",
  },
};

export const viewport: Viewport = {
  colorScheme: "dark",
  themeColor: "#05070C",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
