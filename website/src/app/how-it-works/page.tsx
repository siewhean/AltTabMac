import type { Metadata } from "next";

import { FooterSection } from "@/components/sections/footer-section";
import { SiteHeader } from "@/components/ui/site-header";
import { SectionShell } from "@/components/ui/section-shell";
import { StructuredData } from "@/components/seo/structured-data";
import { howItWorksContent } from "@/content/how-it-works";
import { getSiteUrl } from "@/lib/env";
import { buildBreadcrumbSchema } from "@/lib/seo";

export const metadata: Metadata = {
  title: "How it works | CmdTab",
  description: howItWorksContent.description,
  alternates: {
    canonical: "/how-it-works",
  },
};

export default function HowItWorksPage() {
  const siteUrl = getSiteUrl();
  const breadcrumbSchema = buildBreadcrumbSchema(siteUrl, [
    { name: "Home", path: "/" },
    { name: "How it works", path: "/how-it-works" },
  ]);

  return (
    <main>
      <StructuredData id="cmdtab-how-it-works-breadcrumb" data={breadcrumbSchema} />
      <SiteHeader />

      <SectionShell
        eyebrow={howItWorksContent.eyebrow}
        title={howItWorksContent.title}
        description={howItWorksContent.description}
        className="pt-14"
      >
        <div className="grid gap-6 md:grid-cols-3">
          <article className="surface-panel p-6">
            <p className="type-eyebrow text-cyan">What is CmdTab</p>
            <h2 className="mt-4 text-xl font-medium tracking-[-0.03em] text-text">{howItWorksContent.whatIs.heading}</h2>
            <p className="mt-3 text-sm leading-7 text-muted">{howItWorksContent.whatIs.text}</p>
          </article>
          <article className="surface-panel p-6">
            <p className="type-eyebrow text-cyan">Audience</p>
            <h2 className="mt-4 text-xl font-medium tracking-[-0.03em] text-text">{howItWorksContent.whoIsItFor.heading}</h2>
            <p className="mt-3 text-sm leading-7 text-muted">{howItWorksContent.whoIsItFor.text}</p>
          </article>
          <article className="surface-panel p-6">
            <p className="type-eyebrow text-cyan">Getting started</p>
            <h2 className="mt-4 text-xl font-medium tracking-[-0.03em] text-text">{howItWorksContent.howToStart.heading}</h2>
            <p className="mt-3 text-sm leading-7 text-muted">{howItWorksContent.howToStart.text}</p>
          </article>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="How the workflow unfolds"
        title="Step-by-step"
        description="From install to trial and daily use."
      >
        <div className="space-y-4">
          {howItWorksContent.steps.map((step, index) => (
            <article key={step.title} className="surface-panel p-6">
              <p className="type-eyebrow text-cyan">Step {index + 1}</p>
              <h2 className="mt-3 text-xl font-medium tracking-[-0.03em] text-text">{step.title}</h2>
              <p className="mt-4 text-sm leading-7 text-muted">{step.body}</p>
            </article>
          ))}
        </div>
      </SectionShell>

      <FooterSection />
    </main>
  );
}
