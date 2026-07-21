import { StructuredData } from "@/components/seo/structured-data";
import { FeatureBandsSection } from "@/components/sections/feature-bands-section";
import { FooterSection } from "@/components/sections/footer-section";
import { HeroSection } from "@/components/sections/hero-section";
import { StylesSection } from "@/components/sections/styles-section";
import { WalkthroughSection } from "@/components/sections/walkthrough-section";
import { SectionShell } from "@/components/ui/section-shell";
import { getSiteUrl } from "@/lib/env";
import { buildBreadcrumbSchema } from "@/lib/seo";

export default function HomePage() {
  const siteUrl = getSiteUrl();
  const breadcrumbSchema = buildBreadcrumbSchema(siteUrl, [{ name: "Home", path: "/" }]);

  return (
    <main id="top">
      <StructuredData id="cmdtab-home-breadcrumb" data={breadcrumbSchema} />
        <HeroSection />
      <SectionShell
        id="about"
        eyebrow="Who this fits"
        title="A macOS switcher with live window previews."
        description="CmdTab keeps your existing shortcut and adds real-window context."
      >
        <div className="grid gap-6 md:grid-cols-3">
          <div className="surface-muted p-5">
            <p className="type-eyebrow text-cyan">What it is</p>
            <h3 className="mt-4 text-xl font-medium tracking-[-0.03em] text-text">Your Cmd+Tab replacement</h3>
            <p className="mt-4 text-sm leading-7 text-muted">
              It shows live window thumbnails, so you confirm before you switch.
            </p>
          </div>

          <div className="surface-muted p-5">
            <p className="type-eyebrow text-cyan">Who it is for</p>
            <h3 className="mt-4 text-xl font-medium tracking-[-0.03em] text-text">People who switch often</h3>
            <p className="mt-4 text-sm leading-7 text-muted">
              If your workflow has many open windows, this keeps each switch obvious.
            </p>
          </div>

          <div className="surface-muted p-5">
            <p className="type-eyebrow text-cyan">How to start</p>
            <h3 className="mt-4 text-xl font-medium tracking-[-0.03em] text-text">Start with the trial</h3>
            <p className="mt-4 text-sm leading-7 text-muted">
              Install, grant permissions, then test in your real workflow.
            </p>
          </div>
        </div>
      </SectionShell>
      <StylesSection />
      <WalkthroughSection />
      <FeatureBandsSection />
      <FooterSection />
    </main>
  );
}
