import { HelpJourney } from "@/components/commerce/help-journey";
import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { Button } from "@/components/ui/button";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { commercePageContent } from "@/content/commerce-pages";
import { productFacts } from "@/content/product-facts";
import { analyticsAttributes } from "@/lib/analytics";
import { createPageMetadata } from "@/lib/seo";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "CmdTab beta availability, privacy, and security";
const description =
  "Review CmdTab's unpublished beta boundary, permission requirements, privacy path, and private security-reporting contact. No beta installation, update, licensing, recovery, or operational-support service is available.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Help", path: "/help" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/help",
  imageAlt: "CmdTab beta availability, privacy, and security information",
});

export default function HelpPage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/help",
        })}
      />
      <SiteHeader />

      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow={commercePageContent.help.eyebrow}
        title={commercePageContent.help.title}
        description={commercePageContent.help.description}
        className="pt-14"
      >
        <div className="mb-8 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <LastReviewed date={productFacts.reviewedAt} />
          <p className="text-sm text-subdued">Current documented version: {productFacts.currentVersion}</p>
        </div>
        <div className="grid grid-cols-1 gap-6 xl:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)]">
          <MotionReveal direction="left" className="min-w-0 space-y-6">
            <HelpJourney />

            <div className="surface-panel p-6">
              <p className="type-eyebrow text-cyan">Quick links</p>
              <div className="mt-5 space-y-4">
                <div className="space-y-3">
                  {commercePageContent.help.supportPoints.map((item) => (
                    <div key={item} className="flex items-start gap-3 text-sm leading-7 text-muted">
                      <span aria-hidden="true" className="mt-2 h-2 w-2 rounded-full bg-cyan" />
                      <span>{item}</span>
                    </div>
                  ))}
                </div>
                <div className="flex flex-col gap-3 border-t border-white/8 pt-4">
                  <Button href="/permissions" variant="secondary" className="whitespace-normal text-center">
                    Review permission requirements
                  </Button>
                  <Button href="/faq" variant="secondary" className="whitespace-normal text-center">
                    Read common answers
                  </Button>
                  <Button
                    href="/buy"
                    variant="secondary"
                    className="whitespace-normal text-center"
                    {...analyticsAttributes("help_page_buy_click", "help_page")}
                  >
                    Review pricing
                  </Button>
                  <Button href="/privacy" variant="secondary" className="whitespace-normal text-center">
                    Read privacy policy
                  </Button>
                </div>
              </div>
            </div>
          </MotionReveal>

          <MotionReveal direction="right" delay={120} className="min-w-0 surface-panel p-6">
            <p className="type-eyebrow text-cyan">Contact boundary</p>
            <h2 className="mt-4 text-2xl font-medium tracking-[-0.04em] text-text">
              Privacy and security reports only
            </h2>
            <p className="mt-3 text-sm leading-7 text-muted">
              Email support@cmdtab.net for privacy or security reports. CmdTab does not promise a
              response time and does not currently provide beta installation, update, licence,
              recovery, or general-support operations.
            </p>
            <div className="mt-6">
              <Button href="/security" variant="secondary" className="whitespace-normal text-center">
                Read security reporting guidance
              </Button>
            </div>
          </MotionReveal>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Beta boundary"
        title="Clear limits before publication"
        description="No beta download, trial, checkout, payment, fulfilment, licensing, recovery, or operational-support action is currently available."
        className="pt-0"
      >
        <div className="grid gap-6 lg:grid-cols-3">
          {commercePageContent.help.terms.map((item, index) => (
            <MotionReveal key={item.title} direction="up" delay={index * 90} className="surface-panel p-6">
              <h2 className="text-xl font-medium tracking-[-0.03em] text-text">{item.title}</h2>
              <p className="mt-3 text-sm leading-7 text-muted">{item.body}</p>
            </MotionReveal>
          ))}
        </div>
      </SectionShell>

      <FooterSection />
    </main>
  );
}
