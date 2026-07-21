import type { BreadcrumbItem } from "@/components/seo/breadcrumbs";
import { commerceContent } from "@/content/commerce";
import { productFacts } from "@/content/product-facts";
import type { ShowcaseAsset } from "@/content/showcase";
import { showcaseUploadDate } from "@/content/showcase";
import { siteConfig } from "@/content/site";
import { getCommerceConfig } from "@/lib/commerce";
import { getSiteUrl } from "@/lib/env";

const featureList = [
  "Individual macOS window entries",
  "Exact-window recent-use ordering",
  "Live window previews with icon fallback",
  "Classic Grid, Command Palette, and Radial Menu",
  "Current Space, Visible Spaces, and All Spaces scopes",
  "Active display, cursor display, and all-display placement",
  "Hide, minimize, close, and quit quick actions",
];

function configuredOffers(siteUrl: string) {
  const commerce = getCommerceConfig();
  const offers: Array<Record<string, string>> = [];

  if (commerce.trialDownloadUrl) {
    offers.push({
      "@type": "Offer",
      name: productFacts.trialLength,
      price: "0",
      priceCurrency: "USD",
      availability: "https://schema.org/InStock",
      url: `${siteUrl}/trial`,
    });
  }

  if (commerce.checkoutUrl) {
    offers.push({
      "@type": "Offer",
      name: commerceContent.founder.title,
      price: commerceContent.founder.price.replace(/[^0-9.]/g, ""),
      priceCurrency: "USD",
      availability: "https://schema.org/InStock",
      url: `${siteUrl}/buy`,
    });
  }

  if (commerce.standardCheckoutUrl) {
    offers.push({
      "@type": "Offer",
      name: commerceContent.standard.title,
      price: commerceContent.standard.price.replace(/[^0-9.]/g, ""),
      priceCurrency: "USD",
      availability: "https://schema.org/InStock",
      url: `${siteUrl}/buy`,
    });
  }

  return offers;
}

function softwareApplicationEntity(siteUrl: string) {
  const offers = configuredOffers(siteUrl);

  return {
    "@type": "SoftwareApplication",
    "@id": `${siteUrl}/#software`,
    name: siteConfig.name,
    alternateName: ["CmdTab for macOS", "CmdTab window switcher"],
    disambiguatingDescription:
      "CmdTab is a standalone macOS window-switcher application, not Apple’s built-in Command-Tab shortcut.",
    url: siteUrl,
    sameAs: [productFacts.sourceRepository],
    applicationCategory: "UtilitiesApplication",
    applicationSubCategory: "Window switching utility",
    operatingSystem: productFacts.minimumMacOS,
    softwareVersion: productFacts.currentVersion,
    softwareRequirements:
      `${productFacts.minimumMacOS}; Accessibility permission; Screen Recording permission for live window previews`,
    permissions: productFacts.permissions.map(
      (permission) => `${permission.name}: ${permission.reason}`,
    ),
    description: siteConfig.description,
    image: `${siteUrl}/showcase/overview-poster.png`,
    screenshot: [
      `${siteUrl}/showcase/classic-grid-poster.png`,
      `${siteUrl}/showcase/command-palette-poster.png`,
      `${siteUrl}/showcase/radial-menu-poster.png`,
      `${siteUrl}/showcase/quick-actions-poster.png`,
    ],
    featureList,
    releaseNotes: `${siteUrl}/changelog`,
    publisher: {
      "@id": `${siteUrl}/#organization`,
    },
    ...(offers.length > 0 ? { offers } : {}),
  };
}

export function createHomeStructuredData() {
  const siteUrl = getSiteUrl();

  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Person",
        "@id": `${siteUrl}/#founder`,
        name: "Siew Hean",
        url: productFacts.developerProfile,
        sameAs: [productFacts.developerProfile],
      },
      {
        "@type": "Organization",
        "@id": `${siteUrl}/#organization`,
        name: siteConfig.name,
        url: siteUrl,
        logo: `${siteUrl}/brand/cmdtab.png`,
        email: productFacts.contactEmail,
        founder: {
          "@id": `${siteUrl}/#founder`,
        },
        sameAs: [productFacts.sourceRepository, productFacts.developerProfile],
      },
      {
        "@type": "WebSite",
        "@id": `${siteUrl}/#website`,
        url: siteUrl,
        name: siteConfig.name,
        alternateName: ["CmdTab for macOS", "CmdTab window switcher"],
        description: siteConfig.description,
        publisher: {
          "@id": `${siteUrl}/#organization`,
        },
        inLanguage: "en",
      },
      softwareApplicationEntity(siteUrl),
    ],
  };
}

export function createBreadcrumbStructuredData(items: ReadonlyArray<BreadcrumbItem>) {
  const siteUrl = getSiteUrl();

  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: items.map((item, index) => ({
      "@type": "ListItem",
      position: index + 1,
      name: item.name,
      item: new URL(item.path, `${siteUrl}/`).toString(),
    })),
  };
}

export function createWebPageStructuredData({
  name,
  description,
  path,
  dateModified = productFacts.reviewedAt,
  mainEntity = `${getSiteUrl()}/#software`,
}: {
  name: string;
  description: string;
  path: "/" | `/${string}`;
  dateModified?: string;
  mainEntity?: string;
}) {
  const siteUrl = getSiteUrl();
  const url = new URL(path, `${siteUrl}/`).toString();

  return {
    "@context": "https://schema.org",
    "@type": "WebPage",
    "@id": `${url}#webpage`,
    url,
    name,
    description,
    dateModified,
    inLanguage: "en",
    isPartOf: { "@id": `${siteUrl}/#website` },
    about: { "@id": mainEntity },
    mainEntity: { "@id": mainEntity },
    publisher: { "@id": `${siteUrl}/#organization` },
  };
}

export function createFaqStructuredData(
  items: ReadonlyArray<{ question: string; answer: string }>,
) {
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
  };
}

export function createArticleStructuredData({
  headline,
  description,
  path,
  about,
  citation = [],
  datePublished = "2026-07-20",
  dateModified = productFacts.reviewedAt,
}: {
  headline: string;
  description: string;
  path: `/${string}`;
  about: ReadonlyArray<string>;
  citation?: ReadonlyArray<string>;
  datePublished?: string;
  dateModified?: string;
}) {
  const siteUrl = getSiteUrl();
  const url = new URL(path, `${siteUrl}/`).toString();

  return {
    "@context": "https://schema.org",
    "@type": "TechArticle",
    headline,
    description,
    url,
    mainEntityOfPage: url,
    datePublished,
    dateModified,
    inLanguage: "en",
    about,
    ...(citation.length > 0 ? { citation } : {}),
    author: { "@id": `${siteUrl}/#organization` },
    publisher: { "@id": `${siteUrl}/#organization` },
    image: `${siteUrl}/opengraph-image`,
  };
}

export function createVideoStructuredData(assets: ReadonlyArray<ShowcaseAsset>) {
  const siteUrl = getSiteUrl();

  return {
    "@context": "https://schema.org",
    "@graph": assets.map((asset) => ({
      "@type": "VideoObject",
      "@id": `${siteUrl}/showcase#video-${asset.id}`,
      name: asset.title,
      description: asset.description,
      thumbnailUrl: new URL(asset.poster, `${siteUrl}/`).toString(),
      uploadDate: showcaseUploadDate,
      contentUrl: new URL(asset.video, `${siteUrl}/`).toString(),
      duration: `PT${asset.durationSeconds}S`,
      width: asset.width,
      height: asset.height,
      encodingFormat: "video/mp4",
      inLanguage: "en",
      isFamilyFriendly: true,
      isPartOf: { "@id": `${siteUrl}/showcase#webpage` },
      about: { "@id": `${siteUrl}/#software` },
      publisher: { "@id": `${siteUrl}/#organization` },
    })),
  };
}
