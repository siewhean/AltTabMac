import { FooterSection } from "@/components/sections/footer-section";
import { WaitlistForm } from "@/components/sections/waitlist-form";
import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { Button } from "@/components/ui/button";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { betaHonestyPoints } from "@/content/beta-honesty";
import { commercePageContent } from "@/content/commerce-pages";
import { productFacts } from "@/content/product-facts";
import { analyticsAttributes } from "@/lib/analytics";
import { createPageMetadata } from "@/lib/seo";
import { getStableReleaseManifest } from "@/lib/stable-release";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "Join the CmdTab Private Beta | Mac Window Switcher";
const description =
  "Join the CmdTab private beta for a Mac window switcher with window previews, search, and quick actions. No payment required to join.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Waitlist", path: "/waitlist" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/waitlist",
  imageAlt: "Join the CmdTab private beta waitlist",
});

export default function WaitlistPage() {
  // When a signed build is published, the same page offers the download.
  const release = getStableReleaseManifest();

  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd data={createWebPageStructuredData({ name: title, description, path: "/waitlist" })} />
      <SiteHeader />

      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow={release ? "Early access" : "Private beta"}
        title={release ? "Get early access to CmdTab" : "Join the CmdTab private beta"}
        description={
          release
            ? "Download the current build and try CmdTab in your daily Mac workflow."
            : "Cmd+Tab switches apps. CmdTab switches windows. Leave your email and we’ll invite you when the next beta opens. No payment needed."
        }
        className="pt-14"
      >
        <div className="grid gap-6 xl:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)]">
          {/* The form leads on small screens: one goal per page, no competing buttons. */}
          <MotionReveal direction="right" className="surface-panel order-1 min-w-0 p-6 sm:p-8 xl:order-2">
            <p className="type-eyebrow text-cyan">{release ? "Or join the list" : "Save your spot"}</p>
            <div className="mb-5 mt-3 space-y-2 text-sm leading-6 text-muted">
              <p>
                Enter your email and you’re in. We’ll send beta invitations in waves, and you can invite friends to earn a
                free license.
              </p>
            </div>
            <WaitlistForm source="waitlist_page" variant="page" />
          </MotionReveal>

          <MotionReveal direction="left" className="surface-panel order-2 min-w-0 p-6 xl:order-1">
            <p className="type-eyebrow text-cyan">{release ? "Trial checklist" : "Before you join"}</p>
            <dl className="mt-5 space-y-5">
              {betaHonestyPoints.map((point) => (
                <div key={point.title} className="border-t border-white/10 pt-4 first:border-t-0 first:pt-0">
                  <dt className="text-sm font-semibold text-text">{point.title}</dt>
                  <dd className="mt-2 text-sm leading-6 text-muted">{point.body}</dd>
                </div>
              ))}
            </dl>
            {release ? (
              <ul className="mt-5 space-y-3 border-t border-white/8 pt-5">
                {commercePageContent.trial.checklist.map((item) => (
                  <li key={item} className="flex items-start gap-3 text-sm leading-7 text-muted">
                    <span aria-hidden="true" className="mt-2 h-2 w-2 rounded-full bg-success" />
                    <span>{item}</span>
                  </li>
                ))}
              </ul>
            ) : null}
            <div className="mt-6 flex flex-col gap-3 border-t border-white/8 pt-5 sm:flex-row sm:items-center sm:justify-between">
              <Button
                href="/#demo"
                variant="secondary"
                className="w-full whitespace-normal text-center text-xs sm:w-auto"
                {...analyticsAttributes("waitlist_page_demo_click", "waitlist_page")}
              >
                Try the switcher in your browser
              </Button>
              <p className="text-xs text-subdued">
                Needs {productFacts.minimumMacOS}.{" "}
                <a href="/permissions" className="underline underline-offset-2 hover:text-text">
                  Permissions explained
                </a>
              </p>
            </div>
            {release ? (
              <div className="mt-5 border-t border-white/8 pt-4">
                <Button
                  href={release.dmgURL}
                  target="_blank"
                  rel="noreferrer"
                  className="w-full text-xs"
                  {...analyticsAttributes("waitlist_page_download_click", "waitlist_page")}
                >
                  Download CmdTab {release.version} (.dmg)
                </Button>
                <p className="mt-2 text-xs leading-5 text-subdued">
                  Build {release.build} · {release.bytes.toLocaleString("en-US")} bytes
                </p>
              </div>
            ) : null}
          </MotionReveal>
        </div>
        {release ? (
          <div className="mt-8">
            <LastReviewed date={productFacts.reviewedAt} label="Release information reviewed" />
          </div>
        ) : null}
      </SectionShell>

      <FooterSection />
    </main>
  );
}
