import type { Metadata, Viewport } from "next";
import { Analytics } from "@vercel/analytics/next";
import { SpeedInsights } from "@vercel/speed-insights/next";

import { JsonLd } from "@/components/seo/json-ld";
import { SiteEventTracker } from "@/components/site-event-tracker";
import { SitePageTracker } from "@/components/site-page-tracker";
import { siteConfig } from "@/content/site";
import { getSiteUrl } from "@/lib/env";
import { createHomeStructuredData } from "@/lib/structured-data";

import "./globals.css";

const siteUrl = getSiteUrl();
const defaultTitle = `${siteConfig.name} — Mac window switcher with real previews`;

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: defaultTitle,
    template: `%s | ${siteConfig.name}`,
  },
  description: siteConfig.description,
  applicationName: siteConfig.name,
  authors: [{ name: siteConfig.name, url: siteUrl }],
  creator: siteConfig.name,
  publisher: siteConfig.name,
  alternates: {
    canonical: "/",
  },
  robots: {
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
    title: defaultTitle,
    description: siteConfig.description,
    url: siteUrl,
    siteName: siteConfig.name,
    images: [
      {
        url: "/opengraph-image",
        width: 1200,
        height: 630,
        alt: "CmdTab macOS window switcher showing individual window previews",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: defaultTitle,
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
      <body>
        <JsonLd data={createHomeStructuredData()} />
        {children}
        <SitePageTracker />
        <SiteEventTracker />
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  );
}
