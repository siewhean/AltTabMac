import type { Metadata } from "next";

import { Button } from "@/components/ui/button";
import { FooterSection } from "@/components/sections/footer-section";
import { StructuredData } from "@/components/seo/structured-data";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { faqPageContent } from "@/content/faq";
import { getSiteUrl } from "@/lib/env";
import { buildBreadcrumbSchema, buildFaqSchema } from "@/lib/seo";

export const metadata: Metadata = {
  title: `${faqPageContent.eyebrow} | CmdTab`,
  description: faqPageContent.description,
  alternates: {
    canonical: "/faq",
  },
};

export default function FaqPage() {
  const siteUrl = getSiteUrl();
  const breadcrumbSchema = buildBreadcrumbSchema(siteUrl, [
    { name: "Home", path: "/" },
    { name: "FAQ", path: "/faq" },
  ]);
  const faqSchema = buildFaqSchema("/faq", faqPageContent.items, siteUrl);

  return (
    <main>
      <StructuredData id="cmdtab-faq-breadcrumb" data={breadcrumbSchema} />
      <StructuredData id="cmdtab-faq-page" data={faqSchema} />
      <SiteHeader />

      <SectionShell
        eyebrow={faqPageContent.eyebrow}
        title={faqPageContent.title}
        description={faqPageContent.description}
        className="pt-14"
      >
        <div className="divide-y divide-white/8 border-t border-white/8">
          {faqPageContent.items.map((item, index) => (
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

      <SectionShell
        eyebrow="Need more help"
        title="Use support channels"
        description="If your question is not answered here, use Help or email support directly."
        className="pt-0"
      >
        <div className="grid gap-4 md:grid-cols-2">
          <Button href="/help" variant="secondary">Open help page</Button>
          <Button href="mailto:tohsh17@gmail.com">Contact support</Button>
        </div>
      </SectionShell>

      <FooterSection />
    </main>
  );
}
