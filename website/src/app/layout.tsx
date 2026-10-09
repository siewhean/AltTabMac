import type { Metadata, Viewport } from "next";

import {
  AnalyticsConsentBanner,
  OptionalAnalytics,
} from "@/components/analytics-consent-controls";
import { JsonLd } from "@/components/seo/json-ld";
import { SiteEventTracker } from "@/components/site-event-tracker";
import { SitePageTracker } from "@/components/site-page-tracker";
import { siteConfig } from "@/content/site";
import { getSiteUrl } from "@/lib/env";
import { createHomeStructuredData } from "@/lib/structured-data";

import "./globals.css";

// Marketing pages are statically prerendered under the static CSP from
// proxy.ts; the dashboard renders per request with a strict nonce policy.

const siteUrl = getSiteUrl();
const defaultTitle = `${siteConfig.name} macOS window switcher for individual windows and search`;
const defaultShowcasePoster = "/showcase/overview-poster.webp";

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
        width: 1920,
        height: 1200,
        alt: "CmdTab HD product showcase using controlled fixture windows",
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
        <JsonLd data={createHomeStructuredData()} />
        {children}
        <SitePageTracker />
        <SiteEventTracker />
        <AnalyticsConsentBanner />
        <OptionalAnalytics />
      </body>
    </html>
  );
}
