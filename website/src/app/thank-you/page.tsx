import { FooterSection } from "@/components/sections/footer-section";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { SiteHeader } from "@/components/ui/site-header";
import { createPageMetadata } from "@/lib/seo";

export const metadata = createPageMetadata({
  title: "CmdTab purchase confirmed",
  description:
    "Your CmdTab purchase is confirmed. Open the activation email on your Mac to activate CmdTab in one click or use the manual code in Settings.",
  path: "/thank-you",
  imageAlt: "CmdTab purchase confirmation and activation steps",
  noIndex: true,
});

const steps = [
  {
    title: "Check your purchase email",
    body:
      "The activation credential is delivered by email after the signed entitlement is created. CmdTab never exposes that credential in this web page or its URL.",
  },
  {
    title: "Activate on your Mac",
    body:
      "Choose Activate CmdTab in the email. macOS opens CmdTab directly, shows Licensing, and verifies the credential with the activation service.",
  },
  {
    title: "Keep the manual fallback",
    body:
      "When a mail client blocks custom links, copy the activation code and paste it into CmdTab > Settings > Licensing.",
  },
] as const;

export default function ThankYouPage() {
  return (
    <main>
      <SiteHeader />
      <SectionShell
        headingAs="h1"
        eyebrow="Purchase confirmed"
        title="Thank you for supporting CmdTab."
        description="Your activation email is the secure hand-off from checkout to the native app. It contains a one-click CmdTab link and a manual code fallback."
        className="pt-14"
      >
        <div className="grid gap-6 lg:grid-cols-3">
          {steps.map((step, index) => (
            <article key={step.title} className="surface-panel p-6">
              <p className="type-eyebrow text-cyan">Step {index + 1}</p>
              <h2 className="mt-4 text-xl font-medium tracking-[-0.03em] text-text">
                {step.title}
              </h2>
              <p className="mt-3 text-sm leading-7 text-muted">{step.body}</p>
            </article>
          ))}
        </div>

        <div className="mt-8 flex flex-col gap-3 sm:flex-row">
          <Button href="/waitlist">Join the waitlist</Button>
          <Button href="/help" variant="secondary">
            Activation help
          </Button>
        </div>

        <p className="mt-6 max-w-3xl text-sm leading-7 text-subdued">
          Delivery can take a few minutes. Check spam or promotions before submitting a recovery
          request. CmdTab support will never ask for your administrator password or Apple ID.
        </p>
      </SectionShell>
      <FooterSection />
    </main>
  );
}
