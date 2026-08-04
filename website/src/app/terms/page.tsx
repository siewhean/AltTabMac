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

const title = "CmdTab planned public beta terms and support boundaries";
const description =
  "Review CmdTab's planned public-beta access, Apple-silicon compatibility, unavailable beta operations, privacy, security reporting, and support boundaries.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Terms", path: "/terms" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/terms",
  imageAlt: "CmdTab public beta terms and support boundaries",
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
        title="Clear terms for the planned CmdTab public beta"
        description="The planned beta is non-transactional and unpublished: no download, checkout, payment, fulfilment, refund, or licence-sale action is available."
        className="pt-14"
      >
        <div className="mb-8 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <LastReviewed date={termsReviewedAt} label="Terms reviewed" />
          <p className="text-sm text-subdued">
            {productFacts.licensePrice} · Apple silicon beta only
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
            <Button href="/trial">Join beta waitlist</Button>
            <Button href="/privacy" variant="secondary">Privacy policy</Button>
            <Button href="/help" variant="secondary">Support or recovery help</Button>
          </div>
        </div>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
