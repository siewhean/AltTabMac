import { CommerceOfferGrid } from "@/components/commerce/commerce-offer-grid";
import { JsonLd } from "@/components/seo/json-ld";
import { FooterSection } from "@/components/sections/footer-section";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { commercePageContent } from "@/content/commerce-pages";
import { createPageMetadata } from "@/lib/seo";
import { createBreadcrumbStructuredData } from "@/lib/structured-data";

export const metadata = createPageMetadata({
  title: "Buy CmdTab: 14-day trial and one-time Mac license",
  description:
    "Try CmdTab for 14 days, then buy a one-time macOS license if it improves your window-switching workflow.",
  path: "/buy",
  imageAlt: "CmdTab trial and one-time macOS license",
});

export default function BuyPage() {
  return (
    <main>
      <JsonLd
        data={createBreadcrumbStructuredData([
          { name: "Home", path: "/" },
          { name: "Buy", path: "/buy" },
        ])}
      />
      <SiteHeader />

      <SectionShell
        headingAs="h1"
        eyebrow={commercePageContent.buy.eyebrow}
        title={commercePageContent.buy.title}
        description={commercePageContent.buy.description}
        className="pt-14"
      >
        <CommerceOfferGrid context="buy_page" />
      </SectionShell>

      <SectionShell
        eyebrow="How it works"
        title="Three clear steps."
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
