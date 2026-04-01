import type { Metadata } from "next";

import { Button } from "@/components/ui/button";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { FooterSection } from "@/components/sections/footer-section";
import { commercePageContent } from "@/content/commerce-pages";
import { analyticsAttributes } from "@/lib/analytics";
import { getCommerceConfig } from "@/lib/commerce";

export const metadata: Metadata = {
  title: "CmdTab trial | 14-day download path",
  description: "Start the CmdTab trial, understand the setup, and know exactly what happens after the 14-day evaluation ends.",
  alternates: {
    canonical: "/trial",
  },
};

export default function TrialPage() {
  const commerce = getCommerceConfig();

  return (
    <main>
      <SiteHeader />

      <SectionShell
        eyebrow={commercePageContent.trial.eyebrow}
        title={commercePageContent.trial.title}
        description={commercePageContent.trial.description}
        className="pt-14"
      >
        <div className="grid gap-6 xl:grid-cols-[minmax(0,1.1fr)_minmax(300px,0.9fr)]">
          <MotionReveal direction="left" className="surface-panel p-6">
            <p className="type-eyebrow text-cyan">Trial checklist</p>
            <div className="mt-5 space-y-4">
              {commercePageContent.trial.checklist.map((item) => (
                <div key={item} className="flex items-start gap-3 text-sm leading-7 text-muted">
                  <span className="mt-2 h-2 w-2 rounded-full bg-success" />
                  <span>{item}</span>
                </div>
              ))}
            </div>
          </MotionReveal>

          <MotionReveal direction="right" delay={120} className="surface-panel p-6">
            <p className="type-eyebrow text-cyan">Download and next step</p>
            <div className="mt-4 space-y-4 text-sm leading-7 text-muted">
              <p>{commercePageContent.trial.note}</p>
              <p>
                If the trial proves itself, the next step is the one-time buy flow. No account system
                is required just to move from trial to checkout.
              </p>
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
