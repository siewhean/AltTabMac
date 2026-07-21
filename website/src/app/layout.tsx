import type { Metadata, Viewport } from "next";
import { Analytics } from "@vercel/analytics/next";
import { SpeedInsights } from "@vercel/speed-insights/next";

import { StructuredData } from "@/components/seo/structured-data";
import { SiteEventTracker } from "@/components/site-event-tracker";
import { SitePageTracker } from "@/components/site-page-tracker";
import { siteConfig } from "@/content/site";
import { getSiteUrl } from "@/lib/env";
import { buildSoftwareApplicationSchema, buildWebsiteSchema } from "@/lib/seo";

import "./globals.css";

const siteUrl = getSiteUrl();

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: `${siteConfig.name} | macOS app switching with real window previews`,
  description: siteConfig.description,
  keywords: [...siteConfig.keywords],
  alternates: {
    canonical: "/",
  },
  openGraph: {
    type: "website",
    title: `${siteConfig.name} | macOS app switching with real window previews`,
    description: siteConfig.description,
    url: siteUrl,
    siteName: siteConfig.name,
    images: [{ url: "/opengraph-image" }],
  },
  twitter: {
    card: "summary_large_image",
    title: `${siteConfig.name} | macOS app switching with real window previews`,
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
  const websiteSchema = buildWebsiteSchema(siteUrl);
  const softwareApplicationSchema = buildSoftwareApplicationSchema(siteUrl);

  return (
    <html lang="en">
      <body>
        <StructuredData id="cmdtab-website-schema" data={websiteSchema} />
        <StructuredData id="cmdtab-software-application-schema" data={softwareApplicationSchema} />
        {children}
        <SitePageTracker />
        <SiteEventTracker />
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  );
}
