import { CommerceOfferGrid } from "@/components/commerce/commerce-offer-grid";
import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { commercePageContent } from "@/content/commerce-pages";
import { productFacts } from "@/content/product-facts";
import { createPageMetadata } from "@/lib/seo";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "Buy CmdTab: 14-day trial and one-time Mac license";
const description =
  "Try CmdTab for 14 days, then buy one US$12 perpetual personal license for up to three personally owned Macs, with all 1.x updates and no subscription.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Buy", path: "/buy" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/buy",
  imageAlt: "CmdTab trial and one-time macOS license",
});

export default function BuyPage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/buy",
        })}
      />
      <SiteHeader />

      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow={commercePageContent.buy.eyebrow}
        title={commercePageContent.buy.title}
        description={commercePageContent.buy.description}
        className="pt-14"
      >
        <div className="mb-8">
          <LastReviewed date={productFacts.reviewedAt} label="Pricing reviewed" />
        </div>
        <CommerceOfferGrid context="buy_page" />
        <p className="mt-6 max-w-3xl text-sm leading-7 text-subdued">
          US$12 is a one-time perpetual personal license for up to three personally owned Macs
          and all CmdTab 1.x updates. It is not a recurring subscription. A full refund can be
          requested within 14 days of purchase.
        </p>
      </SectionShell>

      <SectionShell
        eyebrow="How it works"
        title="Three clear steps"
        description="Start the trial, buy if it earns a place in your workflow, and use Help if you need support later."
        className="pt-0"
      >
        <div className="grid gap-6 lg:grid-cols-3">
          {commercePageContent.buy.process.map((step, index) => (
            <MotionReveal key={step.title} direction="up" delay={index * 90} className="surface-panel p-6">
              <p className="type-eyebrow text-cyan">Step {index + 1}</p>
              <h2 className="mt-4 text-xl font-medium tracking-[-0.03em] text-text">
                {step.title}
              </h2>
              <p className="mt-3 text-sm leading-7 text-muted">{step.body}</p>
            </MotionReveal>
          ))}
        </div>
      </SectionShell>

      <FooterSection />
    </main>
  );
}
