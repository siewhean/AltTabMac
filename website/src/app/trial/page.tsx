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

const title = "Download the CmdTab 14-day Mac trial";
const description =
  "Start the CmdTab 14-day macOS trial, confirm the current download and system requirements, enable Accessibility and Screen Recording, and test individual-window switching in your own workflow.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Trial", path: "/trial" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/trial",
  imageAlt: "Download the CmdTab 14-day macOS trial",
});

export default function TrialPage() {
  const commerce = getCommerceConfig();

  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/trial",
        })}
      />
      <SiteHeader />

      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow={commercePageContent.trial.eyebrow}
        title={commercePageContent.trial.title}
        description={commercePageContent.trial.description}
        className="pt-14"
      >
        <div className="mb-8 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <LastReviewed date={productFacts.reviewedAt} label="Trial information reviewed" />
          <p className="text-sm text-subdued">
            Version {productFacts.currentVersion} · {productFacts.minimumMacOS}
          </p>
        </div>
        <div className="grid gap-6 xl:grid-cols-[minmax(0,1.1fr)_minmax(300px,0.9fr)]">
          <MotionReveal direction="left" className="surface-panel p-6">
            <p className="type-eyebrow text-cyan">Trial checklist</p>
            <div className="mt-5 space-y-4">
              {commercePageContent.trial.checklist.map((item) => (
                <div key={item} className="flex items-start gap-3 text-sm leading-7 text-muted">
                  <span aria-hidden="true" className="mt-2 h-2 w-2 rounded-full bg-success" />
                  <span>{item}</span>
                </div>
              ))}
            </div>
            <p className="mt-5 border-t border-white/8 pt-5 text-sm leading-7 text-subdued">
              The app requires Accessibility for switching and exact focus. Screen Recording enables live previews; eligible windows remain represented with an icon or placeholder if capture is unavailable.
            </p>
          </MotionReveal>

          <MotionReveal direction="right" delay={120} className="surface-panel p-6">
            <p className="type-eyebrow text-cyan">Download</p>
            <div className="mt-4 space-y-4 text-sm leading-7 text-muted">
              <p>{commercePageContent.trial.note}</p>
            </div>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              {commerce.trialDownloadUrl ? (
                <Button
                  href={commerce.trialDownloadUrl}
                  target="_blank"
                  rel="noreferrer"
                  {...analyticsAttributes("trial_page_download_click", "trial_page")}
                >
                  Download the trial
                </Button>
              ) : (
                <Button href="/help" variant="secondary" {...analyticsAttributes("trial_page_support_click", "trial_page")}>
                  Ask for access
                </Button>
              )}
              <Button href="/buy" variant="secondary" {...analyticsAttributes("trial_page_buy_click", "trial_page")}>
                Review pricing
              </Button>
            </div>
          </MotionReveal>
        </div>
      </SectionShell>

      <FooterSection />
    </main>
  );
}
