import { FooterSection } from "@/components/sections/footer-section";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { createPageMetadata } from "@/lib/seo";

export const metadata = createPageMetadata({
  title: "CmdTab purchase confirmation unavailable",
  description:
    "CmdTab does not provide checkout, purchase confirmation, licence activation, or beta downloads on this route.",
  path: "/thank-you",
  imageAlt: "CmdTab beta purchase confirmation unavailable",
  noIndex: true,
});

export default function ThankYouPage() {
  return (
    <main>
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        eyebrow="Public beta"
        title="Purchase confirmation is unavailable."
        description="CmdTab is preparing a signed Apple-silicon public beta. This route does not provide checkout, payment, purchase confirmation, licence activation, or a beta download."
        className="pt-14"
      >
        <div className="mt-8 flex flex-col gap-3 sm:flex-row">
          <Button href="/trial">Join the beta waitlist</Button>
          <Button href="/buy" variant="secondary">
            Read the pricing plan
          </Button>
        </div>

        <p className="mt-6 max-w-3xl text-sm leading-7 text-subdued">
          A US$12 personal licence is planned for general availability. The public beta remains
          non-transactional until its separate release gates are complete.
        </p>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
