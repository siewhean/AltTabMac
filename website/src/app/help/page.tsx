import type { Metadata } from "next";

import { HelpJourney } from "@/components/commerce/help-journey";
import { LicenseRequestForm } from "@/components/commerce/license-request-form";
import { FooterSection } from "@/components/sections/footer-section";
import { Button } from "@/components/ui/button";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { StructuredData } from "@/components/seo/structured-data";
import { commercePageContent } from "@/content/commerce-pages";
import { getSiteUrl } from "@/lib/env";
import { analyticsAttributes } from "@/lib/analytics";
import { getCommerceConfig } from "@/lib/commerce";
import { buildBreadcrumbSchema } from "@/lib/seo";

export const metadata: Metadata = {
  title: "CmdTab help | Purchase, activation, and recovery",
  description: "Get help with CmdTab purchase recovery, activation, billing, and post-purchase support.",
  alternates: {
    canonical: "/help",
  },
};

export default function HelpPage() {
  const commerce = getCommerceConfig();
  const siteUrl = getSiteUrl();
  const breadcrumbSchema = buildBreadcrumbSchema(siteUrl, [
    { name: "Home", path: "/" },
    { name: "Help", path: "/help" },
  ]);

  return (
    <main>
      <StructuredData id="cmdtab-help-breadcrumb" data={breadcrumbSchema} />
      <SiteHeader />

      <SectionShell
        eyebrow={commercePageContent.help.eyebrow}
        title={commercePageContent.help.title}
        description={commercePageContent.help.description}
        className="pt-14"
      >
        <div className="grid gap-6 xl:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)]">
          <MotionReveal direction="left" className="space-y-6">
            <HelpJourney />

            <div className="surface-panel p-6">
              <p className="type-eyebrow text-cyan">Quick links</p>
              <div className="mt-5 space-y-4">
                <div className="space-y-3">
                  {commercePageContent.help.supportPoints.map((item) => (
                    <div key={item} className="flex items-start gap-3 text-sm leading-7 text-muted">
                      <span className="mt-2 h-2 w-2 rounded-full bg-cyan" />
                      <span>{item}</span>
                    </div>
                  ))}
                </div>
                <div className="flex flex-col gap-3 border-t border-white/8 pt-4">
                <Button href="/buy" variant="secondary" {...analyticsAttributes("help_page_buy_click", "help_page")}>
                  Review pricing
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
        title="Simple terms, clear support."
        description="One-time purchase terms and support paths in one place."
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
