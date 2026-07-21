import type { Metadata } from "next";

import { CommerceOfferGrid } from "@/components/commerce/commerce-offer-grid";
import { FooterSection } from "@/components/sections/footer-section";
import { StructuredData } from "@/components/seo/structured-data";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { commercePageContent } from "@/content/commerce-pages";
import { getSiteUrl } from "@/lib/env";
import { buildBreadcrumbSchema, buildProductSchema } from "@/lib/seo";

export const metadata: Metadata = {
  title: "Buy CmdTab | Trial and one-time license",
  description:
    "Start with a trial, then buy the one-time Mac license through hosted checkout.",
  alternates: {
    canonical: "/buy",
  },
  openGraph: {
    title: "Buy CmdTab | Trial then one-time macOS license",
    description:
      "Start with a 14-day trial and upgrade to a one-time purchase. No subscription.",
  },
};

export default function BuyPage() {
  const siteUrl = getSiteUrl();
  const breadcrumbSchema = buildBreadcrumbSchema(siteUrl, [
    { name: "Home", path: "/" },
    { name: "Buy", path: "/buy" },
  ]);
  const productSchema = buildProductSchema(siteUrl);

  return (
    <main>
      <StructuredData id="cmdtab-buy-breadcrumb" data={breadcrumbSchema} />
      <StructuredData id="cmdtab-buy-product" data={productSchema} />
      <SiteHeader />

      <SectionShell
        eyebrow={commercePageContent.buy.eyebrow}
        title={commercePageContent.buy.title}
        description={commercePageContent.buy.description}
        className="pt-14"
      >
        <CommerceOfferGrid context="buy_page" />
      </SectionShell>

      <SectionShell
        eyebrow="How it works"
        title="Three short steps."
        description="Trial, purchase, then support path if needed."
        className="pt-0"
      >
        <div className="grid gap-6 lg:grid-cols-3">
          {commercePageContent.buy.process.map((step, index) => (
            <MotionReveal key={step.title} direction="up" delay={index * 90} className="surface-panel p-6">
              <p className="type-eyebrow text-cyan">Step {index + 1}</p>
              <h2 className="mt-4 text-xl font-medium tracking-[-0.03em] text-text">
                {step.title}
              </h2>
              <p className="mt-3 text-sm leading-7 text-muted">{step.body}</p>
            </MotionReveal>
          ))}
        </div>
      </SectionShell>

      <SectionShell
        eyebrow="Compatibility, install, and support"
        title="What you need before you buy"
        description="Permissions and support are checked before checkout."
      >
        <div className="grid gap-6 lg:grid-cols-2 xl:grid-cols-3">
          <article className="surface-panel p-6 xl:col-span-1">
            <p className="type-eyebrow text-cyan">Mac requirements</p>
            <h2 className="mt-4 text-xl font-medium tracking-[-0.03em] text-text">
              macOS and hardware
            </h2>
            <div className="mt-4 space-y-3 text-sm leading-7 text-muted">
              <p>Use supported macOS versions with required permissions enabled.</p>
              <p>No subscription. One-time license only, after trial.</p>
            </div>
          </article>

          <article className="surface-panel p-6 xl:col-span-1">
            <p className="type-eyebrow text-cyan">Permissions</p>
            <h2 className="mt-4 text-xl font-medium tracking-[-0.03em] text-text">
              Accessibility + Screen Recording
            </h2>
            <div className="mt-4 space-y-3 text-sm leading-7 text-muted">
              <p>Accessibility keeps shortcut handling and switch actions responsive.</p>
              <p>Screen Recording enables live window previews.</p>
              <p>Permission state appears in CmdTab Settings.</p>
            </div>
          </article>

          <article className="surface-panel p-6 xl:col-span-1">
            <p className="type-eyebrow text-cyan">Paths</p>
            <h2 className="mt-4 text-xl font-medium tracking-[-0.03em] text-text">
              Trial, install, and support
            </h2>
            <div className="mt-4 space-y-3 text-sm leading-7 text-muted">
              <p>
                <a href="/trial" className="text-cyan hover:text-sky-300">Go to /trial</a> to download and configure.
              </p>
              <p>
                <a href="/help" className="text-cyan hover:text-sky-300">Use /help</a> for setup or license support.
              </p>
              <p>If /trial is not ready, open /help for delivery status.</p>
            </div>
          </article>
        </div>
      </SectionShell>

      <FooterSection />
    </main>
  );
}
