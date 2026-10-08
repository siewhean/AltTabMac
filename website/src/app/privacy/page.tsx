import { AnalyticsPrivacyControls } from "@/components/analytics-consent-controls";
import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { privacyContent } from "@/content/legal";
import { productFacts } from "@/content/product-facts";
import { createPageMetadata } from "@/lib/seo";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "CmdTab website and native app privacy";
const description =
  "Review the exact website analytics, native app telemetry, trial, licensing, permissions, excluded window-content fields, third parties, and privacy-request path used by CmdTab.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Privacy", path: "/privacy" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/privacy",
  imageAlt: "CmdTab website and native app privacy policy",
});

export default function PrivacyPage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/privacy",
        })}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow="Privacy"
        title="CmdTab website and native app privacy"
        description={privacyContent.intro}
        className="pt-14"
      >
        <div className="mb-8 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <LastReviewed date={productFacts.reviewedAt} />
          <Button href={productFacts.sourceRepository} target="_blank" rel="noreferrer" variant="ghost">
            Review current implementation
          </Button>
        </div>
        <div className="space-y-10">
          <AnalyticsPrivacyControls />
          {privacyContent.sections.map((section) => (
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

          <div className="flex flex-col gap-3 border-t border-white/8 pt-8 sm:flex-row sm:flex-wrap">
            <Button href="/permissions">Review app permissions</Button>
            <Button href={productFacts.contactPath} variant="secondary">
              Privacy request
            </Button>
            <Button href="/security" variant="secondary">
              View security policy
            </Button>
            <Button href="/terms" variant="secondary">
              License and retention terms
            </Button>
          </div>
        </div>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
