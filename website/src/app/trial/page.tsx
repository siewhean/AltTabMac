import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { TrialWaitlistForm } from "@/components/sections/trial-waitlist-form";
import { Button } from "@/components/ui/button";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { commercePageContent } from "@/content/commerce-pages";
import { productFacts } from "@/content/product-facts";
import { analyticsAttributes } from "@/lib/analytics";
import { createPageMetadata } from "@/lib/seo";
import { getBetaReleaseManifest } from "@/lib/stable-release";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "CmdTab public beta — Join the Mac waitlist";
const description =
  "Sign up for the CmdTab public-beta waitlist. Receive an email notification when a signed Apple-silicon beta download is available.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Beta waitlist", path: "/trial" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/trial",
  imageAlt: "Join the CmdTab public beta waitlist",
});

export default function TrialPage() {
  const release = getBetaReleaseManifest();

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
        title="Get notified about the CmdTab public beta"
        description="CmdTab is preparing a signed Apple-silicon public beta. Sign up for an email when the beta download is ready; no payment is collected during beta."
        className="pt-14"
      >
        <div className="mb-8 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <LastReviewed date={productFacts.reviewedAt} label="Beta information reviewed" />
          <p className="text-sm text-subdued">
            Version {productFacts.currentVersion} · {productFacts.minimumMacOS}
          </p>
        </div>
        <div className="grid gap-6 xl:grid-cols-[minmax(0,1.1fr)_minmax(320px,0.9fr)]">
          <MotionReveal direction="left" className="surface-panel p-6">
            <p className="type-eyebrow text-cyan">Beta checklist &amp; features</p>
            <div className="mt-5 space-y-4">
              {commercePageContent.trial.checklist.map((item) => (
                <div key={item} className="flex items-start gap-3 text-sm leading-7 text-muted">
                  <span aria-hidden="true" className="mt-2 h-2 w-2 rounded-full bg-success" />
                  <span>{item}</span>
                </div>
              ))}
            </div>
            <p className="mt-5 border-t border-white/8 pt-5 text-sm leading-7 text-subdued">
              The app requires Accessibility for window-level switching and exact focus. Screen Recording enables live previews.
            </p>

            <div className="mt-6 pt-4 border-t border-white/8 flex items-center justify-between">
              <span className="text-xs text-muted">Planned US$12 at general availability</span>
              <Button href="/buy" variant="secondary" className="text-xs" {...analyticsAttributes("trial_page_buy_click", "trial_page")}>
                Read pricing plan
              </Button>
            </div>

            {release ? (
              <div className="mt-4 pt-3 border-t border-white/8">
                <Button
                  href={release.dmgURL}
                  target="_blank"
                  rel="noreferrer"
                  className="w-full text-xs"
                  {...analyticsAttributes("trial_page_download_click", "trial_page")}
                >
                  Download CmdTab beta {release.version} (.dmg)
                </Button>
                <p className="mt-2 text-xs leading-5 text-subdued">
                  Build {release.build} · {release.bytes.toLocaleString("en-US")} bytes
                </p>
              </div>
            ) : null}
          </MotionReveal>

          <MotionReveal direction="right" delay={120} className="surface-panel p-6">
            <p className="type-eyebrow text-cyan">Join the beta waitlist</p>
            <div className="mt-3 mb-5 space-y-2 text-sm leading-6 text-muted">
              <p>
                Sign up with your email to receive beta access. We will notify you directly as soon as a signed beta download is ready.
              </p>
            </div>

            <TrialWaitlistForm />
          </MotionReveal>
        </div>
      </SectionShell>

      <FooterSection />
    </main>
  );
}
