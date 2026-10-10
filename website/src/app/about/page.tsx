import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { productFacts } from "@/content/product-facts";
import { siteConfig } from "@/content/site";
import { createPageMetadata } from "@/lib/seo";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "About CmdTab and its developer";
const description =
  "Learn why CmdTab was built, who develops it, how it approaches individual macOS window switching, and where to verify its product, source, privacy, security, and support information.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "About", path: "/about" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/about",
  imageAlt: "About the CmdTab macOS window switcher and its developer",
});

export default function AboutPage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/about",
        })}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow="About"
        title="CmdTab is built to make individual Mac windows easier to reach"
        description="The product focuses on the shortest reliable path to the exact app window a user intended to open. It is developed by Siew Hean and documented publicly on this site."
        className="pt-14"
      >
        <div className="mb-8">
          <LastReviewed date={productFacts.reviewedAt} />
        </div>
        <div className="grid gap-6 lg:grid-cols-2">
          <article className="surface-panel p-7 lg:col-span-2">
            <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">Why I built CmdTab</h2>
            <div className="mt-4 max-w-3xl space-y-4 text-base leading-8 text-muted">
              <p>
                I switch between a lot of windows on my Mac every day, and Cmd+Tab only switches apps. I tried the existing window switchers, but each had problems I couldn’t fix or add to myself. So I built CmdTab, with the features I wanted.
              </p>
              <p>
                It’s still in private beta and I’m improving it often. I’m sharing it with other Mac users in the hope it solves the same frustrations for them. If something doesn’t work for you, tell me at{" "}
                <a className="text-cyan underline underline-offset-4 hover:text-text" href={`mailto:${siteConfig.contactEmail}`}>
                  {siteConfig.contactEmail}
                </a>{" "}
                and I’ll fix it.
              </p>
              <p className="text-sm text-subdued">Siew Hean, developer of CmdTab</p>
            </div>
          </article>
          <article className="surface-panel p-7">
            <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">Product approach</h2>
            <p className="mt-4 text-base leading-8 text-muted">
              CmdTab replaces an app-only switching view with individual window entries, real previews, search, quick actions, and multiple presentation modes. The current implementation treats exact windows as one global recent-use sequence instead of forcing windows from one app into a group.
            </p>
          </article>
          <article className="surface-panel p-7">
            <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">Developer and official sources</h2>
            <p className="mt-4 text-base leading-8 text-muted">
              Siew Hean develops CmdTab. This website is the canonical public source for product information, release notes, and current project metadata.
            </p>
            <div className="mt-6 flex flex-col gap-3 sm:flex-row">
              <Button href={productFacts.developerProfile} target="_blank" rel="noreferrer" variant="ghost">
                Developer profile
              </Button>
            </div>
          </article>
          <article className="surface-panel p-7 lg:col-span-2">
            <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">Contact and verification</h2>
            <p className="mt-4 max-w-3xl text-base leading-8 text-muted">
              Product behavior, compatibility, permissions, telemetry, trial terms, purchase information, privacy, security, and support should be verified against the dedicated pages linked from this site rather than inferred from a promotional screenshot.
            </p>
            <p className="mt-4 text-sm leading-7 text-subdued">
              Contact: <a className="text-cyan underline underline-offset-4 hover:text-text" href={`mailto:${siteConfig.contactEmail}`}>{siteConfig.contactEmail}</a>
            </p>
          </article>
        </div>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
