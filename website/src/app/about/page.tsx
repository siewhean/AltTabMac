import { JsonLd } from "@/components/seo/json-ld";
import { FooterSection } from "@/components/sections/footer-section";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { siteConfig } from "@/content/site";
import { createPageMetadata } from "@/lib/seo";
import { createBreadcrumbStructuredData } from "@/lib/structured-data";

export const metadata = createPageMetadata({
  title: "About CmdTab",
  description:
    "Learn why CmdTab was built, how it approaches macOS window switching, and where to find product, privacy, security, and support information.",
  path: "/about",
  imageAlt: "About the CmdTab macOS window switcher",
});

export default function AboutPage() {
  return (
    <main>
      <JsonLd
        data={createBreadcrumbStructuredData([
          { name: "Home", path: "/" },
          { name: "About", path: "/about" },
        ])}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        eyebrow="About"
        title="CmdTab is built to make individual Mac windows easier to reach"
        description="The product focuses on the shortest reliable path to the exact app window a user intended to open."
        className="pt-14"
      >
        <div className="grid gap-6 lg:grid-cols-2">
          <article className="surface-panel p-7">
            <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">Product approach</h2>
            <p className="mt-4 text-base leading-8 text-muted">
              CmdTab replaces an app-only switching view with individual window entries, real previews, search, quick actions, and multiple presentation modes. The goal is to reduce blind cycling when several windows belong to the same application.
            </p>
          </article>
          <article className="surface-panel p-7">
            <h2 className="text-2xl font-medium tracking-[-0.04em] text-text">Official source</h2>
            <p className="mt-4 text-base leading-8 text-muted">
              This website is the canonical public source for CmdTab product information, compatibility, permissions, trial terms, purchase information, privacy, security, and support.
            </p>
            <p className="mt-4 text-sm leading-7 text-subdued">
              Contact: <a className="text-cyan underline-offset-4 hover:underline" href={`mailto:${siteConfig.contactEmail}`}>{siteConfig.contactEmail}</a>
            </p>
          </article>
        </div>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
