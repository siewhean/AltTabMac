import { CommerceOfferGrid } from "@/components/commerce/commerce-offer-grid";
import { JsonLd } from "@/components/seo/json-ld";
import { LastReviewed } from "@/components/seo/last-reviewed";
import { FooterSection } from "@/components/sections/footer-section";
import { TrialWaitlistForm } from "@/components/sections/trial-waitlist-form";
import { MotionReveal } from "@/components/ui/motion-reveal";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { commercePageContent } from "@/content/commerce-pages";
import { productFacts } from "@/content/product-facts";
import { createPageMetadata } from "@/lib/seo";
import { getCommerceConfig } from "@/lib/commerce";
import { getStableReleaseManifest } from "@/lib/stable-release";
import {
  createBreadcrumbStructuredData,
  createWebPageStructuredData,
} from "@/lib/structured-data";

const title = "CmdTab Pricing and Early Access";
const description =
  "Review CmdTab pricing and join the early access waitlist. A one-time personal license will be available when purchase opens.";
const breadcrumbs = [
  { name: "Home", path: "/" as const },
  { name: "Buy", path: "/buy" as const },
];

export const metadata = createPageMetadata({
  title,
  description,
  path: "/buy",
  imageAlt: "CmdTab trial and one-time macOS license",
});

export default function BuyPage() {
  const commerce = getCommerceConfig();
  const release = getStableReleaseManifest();
  const accessOpen = Boolean(commerce.checkoutUrl || release);
  const process = accessOpen
    ? [
        { title: "Try CmdTab", body: release ? "Download the signed build, enable the required permissions, and use it in real work." : "Join the waitlist for an email when trial access opens." },
        { title: "Buy through hosted checkout", body: commerce.checkoutUrl ? "Complete the one-time purchase through the hosted checkout." : "The one-time purchase will open when checkout is ready." },
        { title: "Use Help if needed", body: "If you lose the receipt or need activation help later, use the Help page." },
      ]
    : commercePageContent.buy.process;
  const availabilityDescription = accessOpen
    ? "Review the current access and purchase options below. Join the waitlist to hear when trial access or checkout changes."
    : "Sign up below and we’ll email you when early access opens. No trial download or purchase is currently available during the private preview.";

  return (
    <main>
      <JsonLd data={createBreadcrumbStructuredData(breadcrumbs)} />
      <JsonLd
        data={createWebPageStructuredData({
          name: title,
          description,
          path: "/buy",
        })}
      />
      <SiteHeader />

      <SectionShell
        headingAs="h1"
        breadcrumbs={breadcrumbs}
        eyebrow={commercePageContent.buy.eyebrow}
        title={commercePageContent.buy.title}
        description={commercePageContent.buy.description}
        className="pt-14"
      >
        <div className="mb-8">
          <LastReviewed date={productFacts.reviewedAt} label="Pricing reviewed" />
        </div>
        <CommerceOfferGrid context="buy_page" />
        <p className="mt-6 max-w-3xl text-sm leading-7 text-subdued">
          US$12 is a one-time perpetual personal license for up to three personally owned Macs
          and all CmdTab 1.x updates. It is not a recurring subscription. A full refund can be
          requested within 14 days of purchase.
        </p>
      </SectionShell>

      <SectionShell
        id="waitlist"
        eyebrow="Early access"
        title="Join the CmdTab waitlist"
        description={availabilityDescription}
        className="pt-0"
      >
        <MotionReveal className="surface-panel p-6 max-w-2xl">
          <TrialWaitlistForm />
        </MotionReveal>
      </SectionShell>

      <SectionShell
        eyebrow="How it works"
        title="Three clear steps"
        description="Join the waitlist, try CmdTab when access opens, and decide whether it belongs in your workflow."
        className="pt-0"
      >
        <div className="grid gap-6 lg:grid-cols-3">
          {process.map((step, index) => (
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

      <FooterSection />
    </main>
  );
}
