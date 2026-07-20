import { commerceContent } from "@/content/commerce";
import { productFacts } from "@/content/product-facts";
import { siteConfig } from "@/content/site";
import { getSiteUrl } from "@/lib/env";

export function createHomeStructuredData() {
  const siteUrl = getSiteUrl();

  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        "@id": `${siteUrl}/#organization`,
        name: siteConfig.name,
        url: siteUrl,
        logo: `${siteUrl}/brand/cmdtab.png`,
        email: productFacts.contactEmail,
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
      {
        "@type": "SoftwareApplication",
        "@id": `${siteUrl}/#software`,
        name: siteConfig.name,
        url: siteUrl,
        applicationCategory: "UtilitiesApplication",
        operatingSystem: productFacts.minimumMacOS,
        description: siteConfig.description,
        image: `${siteUrl}/opengraph-image`,
        publisher: {
          "@id": `${siteUrl}/#organization`,
        },
        offers: [
          {
            "@type": "Offer",
            name: productFacts.trialLength,
            price: "0",
            priceCurrency: "USD",
            availability: "https://schema.org/InStock",
            url: `${siteUrl}/trial`,
          },
          {
            "@type": "Offer",
            name: commerceContent.founder.note,
            price: commerceContent.founder.price.replace(/[^0-9.]/g, ""),
            priceCurrency: "USD",
            availability: "https://schema.org/InStock",
            url: `${siteUrl}/buy`,
          },
        ],
      },
    ],
  };
}

export function createBreadcrumbStructuredData(
  items: ReadonlyArray<{ name: string; path: "/" | `/${string}` }>,
) {
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
