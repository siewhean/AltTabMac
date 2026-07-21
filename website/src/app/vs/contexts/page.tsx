import type { Metadata } from "next";

import { Button } from "@/components/ui/button";
import { FooterSection } from "@/components/sections/footer-section";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { StructuredData } from "@/components/seo/structured-data";
import { contextsComparison } from "@/content/comparisons";
import { getSiteUrl } from "@/lib/env";
import { buildBreadcrumbSchema, buildFaqSchema } from "@/lib/seo";

export const metadata: Metadata = {
  title: contextsComparison.title,
  description: contextsComparison.description,
  alternates: {
    canonical: "/vs/contexts",
  },
  openGraph: {
    title: contextsComparison.title,
    description: contextsComparison.description,
    url: `${getSiteUrl()}/vs/contexts`,
  },
};

export default function ContextsComparisonPage() {
  const siteUrl = getSiteUrl();
  const breadcrumbSchema = buildBreadcrumbSchema(siteUrl, [
    { name: "Home", path: "/" },
    { name: "CmdTab vs Contexts", path: "/vs/contexts" },
  ]);
  const faqSchema = buildFaqSchema("/vs/contexts", contextsComparison.faq, siteUrl);

  return (
    <main>
      <StructuredData id="cmdtab-vs-contexts-breadcrumb" data={breadcrumbSchema} />
      <StructuredData id="cmdtab-vs-contexts-faq" data={faqSchema} />
      <SiteHeader />

      <SectionShell
        eyebrow={contextsComparison.eyebrow}
        title={contextsComparison.heroHeading}
        description={contextsComparison.heroSubheading}
        className="pt-14"
      >
        <div className="flex flex-wrap gap-4">
          <Button href="/trial" variant="primary">Start the free trial</Button>
          <Button href="/buy" variant="secondary">View one-time pricing</Button>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Side-by-side breakdown"
        title="Feature and compatibility comparison"
        description="See where each app differs for modern Mac workflows."
      >
        <div className="surface-panel overflow-x-auto p-6">
          <table className="w-full text-left text-sm text-text">
            <thead>
              <tr className="border-b border-white/10 text-xs font-semibold uppercase tracking-wider text-muted">
                <th className="pb-4">Feature / Capability</th>
                <th className="pb-4 text-cyan">CmdTab</th>
                <th className="pb-4 text-subdued">Contexts (macOS)</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
              {contextsComparison.features.map((item) => (
                <tr key={item.feature} className="hover:bg-white/[0.02]">
                  <td className="py-4 font-medium">{item.feature}</td>
                  <td className="py-4 text-cyan font-medium">{item.cmdtab}</td>
                  <td className="py-4 text-muted">{item.competitor}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Key advantages"
        title="What works better in practice"
        description="Capture speed, mode choice, and recurring target history."
      >
        <div className="grid gap-6 md:grid-cols-3">
          {contextsComparison.keyDifferences.map((diff) => (
            <article key={diff.title} className="surface-panel p-6">
              <p className="type-eyebrow text-cyan">Upgrade</p>
              <h2 className="mt-3 text-xl font-medium tracking-[-0.03em] text-text">{diff.title}</h2>
              <p className="mt-3 text-sm leading-7 text-muted">{diff.description}</p>
            </article>
          ))}
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="FAQ"
        title="Frequently asked questions"
        description="Questions before switching from Contexts."
      >
        <div className="divide-y divide-white/8 border-t border-white/8">
          {contextsComparison.faq.map((item, index) => (
            <details key={item.question} className="group py-6" open={index === 0}>
              <summary className="flex cursor-pointer list-none items-center justify-between gap-4 text-left text-lg font-medium tracking-[-0.03em] text-text">
                <span>{item.question}</span>
                <span className="text-subdued transition-transform duration-200 group-open:rotate-45">+</span>
              </summary>
              <p className="mt-4 max-w-3xl text-base leading-7 text-muted">{item.answer}</p>
            </details>
          ))}
        </div>
      </SectionShell>

      <FooterSection />
    </main>
  );
}
