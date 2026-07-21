import { getSiteUrl } from "@/lib/env";
import { siteConfig } from "@/content/site";

import type { FAQItem } from "@/content/faq";

type BreadcrumbItem = {
  name: string;
  path: string;
};

function asAbsoluteUrl(siteUrl: string, path: string): string {
  const normalizedBase = siteUrl.replace(/\/$/, "");
  if (path.startsWith("http://") || path.startsWith("https://")) {
    return path;
  }

  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  return `${normalizedBase}${normalizedPath}`;
}

export function buildWebsiteSchema(siteUrl = getSiteUrl()) {
  return {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: siteConfig.name,
    url: siteUrl,
    description: siteConfig.description,
    inLanguage: "en-US",
  };
}

export function buildSoftwareApplicationSchema(siteUrl = getSiteUrl()) {
  return {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: siteConfig.name,
    applicationCategory: "ProductivityApplication",
    operatingSystem: "macOS 13.0 or later",
    processorRequirements: "Apple Silicon or Intel",
    memoryRequirements: "< 20MB RAM",
    url: siteUrl,
    image: `${siteUrl}/screenshots/captures/classic-grid.png`,
    description: siteConfig.description,
    featureList: [
      "macOS app switcher with real window previews",
      "command palette style search",
      "hot-swap selection without leaving the app",
      "quick actions for selected windows",
      "space-aware and display-aware overlay placement",
      "radial menu quick switcher mode",
    ],
    permissions: "Accessibility and Screen Recording",
    offers: [
      {
        "@type": "Offer",
        name: "14-day free trial",
        price: "0",
        priceCurrency: "USD",
        availability: "https://schema.org/InStock",
        url: `${siteUrl}/trial`,
      },
      {
        "@type": "Offer",
        name: "One-time macOS license",
        price: "19",
        priceCurrency: "USD",
        availability: "https://schema.org/InStock",
        url: `${siteUrl}/buy`,
      },
    ],
  };
}

export function buildProductSchema(siteUrl = getSiteUrl()) {
  return {
    "@context": "https://schema.org",
    "@type": "Product",
    name: siteConfig.name,
    description: "A macOS window switcher with real thumbnails and one-time licensing.",
    url: `${siteUrl}/buy`,
    image: `${siteUrl}/screenshots/captures/classic-grid.png`,
    brand: {
      "@type": "Organization",
      name: siteConfig.name,
    },
    offers: [
      {
        "@type": "Offer",
        name: "14-day free trial",
        price: "0",
        priceCurrency: "USD",
        availability: "https://schema.org/InStock",
        url: `${siteUrl}/trial`,
      },
      {
        "@type": "Offer",
        name: "One-time macOS license",
        price: "19",
        priceCurrency: "USD",
        availability: "https://schema.org/InStock",
        url: `${siteUrl}/buy`,
      },
    ],
  };
}

export function buildFaqSchema(path: string, items: ReadonlyArray<FAQItem>, siteUrl = getSiteUrl()) {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: items.map((item) => ({
      "@type": "Question",
      name: item.question,
      acceptedAnswer: {
        "@type": "Answer",
        text: item.answer,
      },
    })),
    isPartOf: {
      "@type": "WebPage",
      url: asAbsoluteUrl(siteUrl, path),
    },
  };
}

export function buildBreadcrumbSchema(siteUrl: string, items: BreadcrumbItem[]) {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: items.map((item, index) => ({
      "@type": "ListItem",
      position: index + 1,
      name: item.name,
      item: asAbsoluteUrl(siteUrl, item.path),
    })),
  };
}
