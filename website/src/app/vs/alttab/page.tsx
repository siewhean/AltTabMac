import type { Metadata } from "next";

import { Button } from "@/components/ui/button";
import { FooterSection } from "@/components/sections/footer-section";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { StructuredData } from "@/components/seo/structured-data";
import { altTabComparison } from "@/content/comparisons";
import { getSiteUrl } from "@/lib/env";
import { buildBreadcrumbSchema, buildFaqSchema } from "@/lib/seo";

export const metadata: Metadata = {
  title: altTabComparison.title,
  description: altTabComparison.description,
  alternates: {
    canonical: "/vs/alttab",
  },
  openGraph: {
    title: altTabComparison.title,
    description: altTabComparison.description,
    url: `${getSiteUrl()}/vs/alttab`,
  },
};

export default function AltTabComparisonPage() {
  const siteUrl = getSiteUrl();
  const breadcrumbSchema = buildBreadcrumbSchema(siteUrl, [
    { name: "Home", path: "/" },
    { name: "CmdTab vs AltTab", path: "/vs/alttab" },
  ]);
  const faqSchema = buildFaqSchema("/vs/alttab", altTabComparison.faq, siteUrl);

  return (
    <main>
      <StructuredData id="cmdtab-vs-alttab-breadcrumb" data={breadcrumbSchema} />
      <StructuredData id="cmdtab-vs-alttab-faq" data={faqSchema} />
      <SiteHeader />

      <SectionShell
        eyebrow={altTabComparison.eyebrow}
        title={altTabComparison.heroHeading}
        description={altTabComparison.heroSubheading}
        className="pt-14"
      >
        <div className="flex flex-wrap gap-4">
          <Button href="/trial" variant="primary">Start the free trial</Button>
          <Button href="/buy" variant="secondary">View one-time pricing</Button>
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Side-by-side breakdown"
        title="Feature and performance matrix"
        description="Compare capture speed, mode choice, and window actions."
      >
        <div className="surface-panel overflow-x-auto p-6">
          <table className="w-full text-left text-sm text-text">
            <thead>
              <tr className="border-b border-white/10 text-xs font-semibold uppercase tracking-wider text-muted">
                <th className="pb-4">Feature / Capability</th>
                <th className="pb-4 text-cyan">CmdTab</th>
                <th className="pb-4 text-subdued">AltTab (macOS)</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
              {altTabComparison.features.map((item) => (
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
        title="What changes in practice"
        description="Three places where workflow usually feels different."
      >
        <div className="grid gap-6 md:grid-cols-2">
          {altTabComparison.keyDifferences.map((diff) => (
            <article key={diff.title} className="surface-panel p-6">
              <p className="type-eyebrow text-cyan">Differentiator</p>
              <h2 className="mt-3 text-xl font-medium tracking-[-0.03em] text-text">{diff.title}</h2>
              <p className="mt-3 text-sm leading-7 text-muted">{diff.description}</p>
            </article>
          ))}
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="FAQ"
        title="Frequently asked questions"
        description="Common questions before changing your switcher."
      >
        <div className="divide-y divide-white/8 border-t border-white/8">
          {altTabComparison.faq.map((item, index) => (
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
