import { CommerceOfferGrid } from "@/components/commerce/commerce-offer-grid";
import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { TrialWaitlistForm } from "@/components/sections/trial-waitlist-form";
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

const title = "CmdTab pricing plan for general availability";
const description =
  "CmdTab plans a US$12 personal licence for general availability. The public beta has no checkout, purchase, or payment CTA.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Pricing plan", path: "/buy" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/buy",
  imageAlt: "CmdTab general-availability pricing plan",
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
          A US$12 personal licence is planned for general availability. The public beta is
          non-transactional: CmdTab does not publish checkout, payment, fulfilment, or refund
          actions during this phase.
        </p>
      </SectionShell>

      <SectionShell
        id="waitlist"
        eyebrow="Public beta"
        title="Join the CmdTab beta waitlist"
        description="Sign up below to receive an email notification when a signed beta download is available for your Mac."
        className="pt-0"
      >
        <MotionReveal className="surface-panel p-6 max-w-2xl">
          <TrialWaitlistForm />
        </MotionReveal>
      </SectionShell>

      <SectionShell
        eyebrow="How it works"
        title="Beta, then general availability"
        description="Use the beta, report issues through the documented support paths, and watch for general-availability details later."
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
