import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { productFacts } from "@/content/product-facts";
import { termsReviewedAt, termsSections } from "@/content/terms";
import { createPageMetadata } from "@/lib/seo";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "CmdTab license terms, refunds, devices, and updates";
const description =
  "Review the CmdTab personal-license terms, three-Mac device policy, 14-day refund policy, recovery, 1.x updates, support, and retention disclosures.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Terms", path: "/terms" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/terms",
  imageAlt: "CmdTab license and refund terms",
});

export default function TermsPage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/terms",
          dateModified: termsReviewedAt,
        })}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow="Terms"
        title="Clear terms for buying and using CmdTab"
        description="One personal license, one public price, and explicit rules for devices, refunds, recovery, updates, and retention."
        className="pt-14"
      >
        <div className="mb-8 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <LastReviewed date={termsReviewedAt} label="Terms reviewed" />
          <p className="text-sm text-subdued">
            {productFacts.licensePrice} once · {productFacts.licensedMacs} personal Macs
          </p>
        </div>
        <div className="space-y-10">
          {termsSections.map((section) => (
            <section key={section.title} className="border-t border-white/8 pt-6">
              <h2 className="text-2xl font-medium tracking-[-0.03em] text-text">
                {section.title}
              </h2>
              <div className="mt-4 space-y-4">
                {section.body.map((paragraph) => (
                  <p key={paragraph} className="max-w-3xl text-base leading-8 text-muted">
                    {paragraph}
                  </p>
                ))}
              </div>
            </section>
          ))}
          <div className="flex flex-col gap-3 border-t border-white/8 pt-8 sm:flex-row">
            <Button href="/waitlist">Join the beta list</Button>
            <Button href="/privacy" variant="secondary">Privacy policy</Button>
            <Button href="/help" variant="secondary">Purchase or recovery help</Button>
          </div>
        </div>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
