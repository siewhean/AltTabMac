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
const defaultTitle = `${siteConfig.name} macOS window switcher for individual windows and search`;
const defaultShowcasePoster = "/showcase/overview-poster.png";

function webmasterVerification(): Metadata["verification"] {
  const google = process.env.GOOGLE_SITE_VERIFICATION?.trim();
  const bing = process.env.BING_SITE_VERIFICATION?.trim();

  if (!google && !bing) return undefined;

  return {
    ...(google ? { google } : {}),
    ...(bing
      ? {
          other: {
            "msvalidate.01": bing,
          },
        }
      : {}),
  };
}

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
  verification: webmasterVerification(),
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
        url: defaultShowcasePoster,
        width: 1280,
        height: 800,
        alt: "Real CmdTab production window-switcher render using controlled fixture windows",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: defaultTitle,
    description: siteConfig.description,
    images: [defaultShowcasePoster],
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
        <a href="#main-content" className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-cyan focus:p-3 focus:font-semibold focus:text-slate-950">
          Skip to main content
        </a>
        <JsonLd data={createHomeStructuredData()} />
        <div id="main-content">{children}</div>
        <SitePageTracker />
        <SiteEventTracker />
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  );
}
