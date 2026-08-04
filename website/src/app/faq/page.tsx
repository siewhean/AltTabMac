import { FaqList } from "@/components/seo/faq-list";
import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { faqItems } from "@/content/faq";
import { productFacts } from "@/content/product-facts";
import { createPageMetadata } from "@/lib/seo";
import {
  createBreadcrumbStructuredData,
  createFaqStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "CmdTab frequently asked questions";
const description =
  "Factual answers about CmdTab window ordering, multiple windows per app, previews, Spaces, displays, permissions, telemetry, compatibility, and beta availability boundaries.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "FAQ", path: "/faq" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/faq",
  imageAlt: "CmdTab macOS window switcher frequently asked questions",
});

export default function FaqPage() {
  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd data={createFaqStructuredData(faqItems)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/faq",
        })}
      />
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow="FAQ"
        title="Direct answers about CmdTab"
        description="This page is the canonical factual reference for how CmdTab behaves, what permissions and telemetry it uses, and which beta operations remain unavailable."
        className="pt-14"
      >
        <div className="mb-8">
          <LastReviewed date={productFacts.reviewedAt} />
        </div>
        <FaqList items={faqItems} />
      </SectionShell>
      <FooterSection />
    </main>
  );
}
