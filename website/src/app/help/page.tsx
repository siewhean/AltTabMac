import { HelpJourney } from "@/components/commerce/help-journey";
import { LicenseRequestForm } from "@/components/commerce/license-request-form";
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
import { getCommerceConfig } from "@/lib/commerce";
import { createPageMetadata } from "@/lib/seo";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "CmdTab help: installation, activation, and purchase recovery";
const description =
  "Get CmdTab help with trial access, installation, macOS permissions, activation, purchase recovery, billing, refunds, and moving a license to another Mac.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Help", path: "/help" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/help",
  imageAlt: "CmdTab installation, activation, and purchase help",
});

export default function HelpPage() {
  const commerce = getCommerceConfig();

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
        <div className="grid gap-6 xl:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)]">
          <MotionReveal direction="left" className="space-y-6">
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
                  <Button href="/permissions" variant="secondary">
                    Diagnose permissions
                  </Button>
                  <Button href="/faq" variant="secondary">
                    Read common answers
                  </Button>
                  <Button href="/waitlist" variant="secondary" {...analyticsAttributes("help_page_waitlist_click", "help_page")}>
                    Join the beta list
                  </Button>
                  {commerce.licensePortalUrl ? (
                    <Button
                      href={commerce.licensePortalUrl}
                      target="_blank"
                      rel="noreferrer"
                      {...analyticsAttributes("help_page_portal_click", "help_page")}
                    >
                      Open license portal
                    </Button>
                  ) : null}
                </div>
              </div>
            </div>
          </MotionReveal>

          <MotionReveal direction="right" delay={120}>
            <LicenseRequestForm />
          </MotionReveal>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="How the buy path works"
        title="Simple terms, clear support"
        description="This is the practical explanation of how the one-time buy flow is presented today."
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
