import type { BreadcrumbItem } from "@/components/seo/breadcrumbs";
import { commerceContent } from "@/content/commerce";
import { productFacts } from "@/content/product-facts";
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
    alternateName: "CmdTab for macOS",
    url: siteUrl,
    sameAs: [productFacts.sourceRepository],
    applicationCategory: "UtilitiesApplication",
    applicationSubCategory: "Window switching utility",
    operatingSystem: productFacts.minimumMacOS,
    softwareVersion: productFacts.currentVersion,
    softwareRequirements:
      `${productFacts.minimumMacOS}; Accessibility permission; Screen Recording permission for live window previews`,
    description: siteConfig.description,
    image: `${siteUrl}/opengraph-image`,
    screenshot: [
      `${siteUrl}/screenshots/styles/classic-grid.svg`,
      `${siteUrl}/screenshots/styles/command-palette.svg`,
      `${siteUrl}/screenshots/styles/radial-menu.svg`,
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
        alternateName: "CmdTab for macOS",
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
  datePublished = "2026-07-20",
  dateModified = productFacts.reviewedAt,
}: {
  headline: string;
  description: string;
  path: `/${string}`;
  about: ReadonlyArray<string>;
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
    author: { "@id": `${siteUrl}/#organization` },
    publisher: { "@id": `${siteUrl}/#organization` },
    image: `${siteUrl}/opengraph-image`,
  };
}
