import { JsonLd } from "@/components/seo/json-ld";
import { Button } from "@/components/ui/button";
import { SectionShell } from "@/components/ui/section-shell";
import { createPageMetadata } from "@/lib/seo";
import { createBreadcrumbStructuredData } from "@/lib/structured-data";

export const metadata = createPageMetadata({
  title: "CmdTab security disclosure policy",
  description:
    "Review how to report security issues affecting the CmdTab website, trial delivery, purchase flow, licensing, or native macOS app.",
  path: "/security",
  imageAlt: "CmdTab security disclosure policy",
});

const disclosureSections = [
  {
    title: "How to report a vulnerability",
    body: [
      "Report suspected security issues privately to tohsh17@gmail.com.",
      "Include the affected URL or feature, clear reproduction steps, impact, and any proof-of-concept details that help the CmdTab team validate the issue quickly.",
    ],
  },
  {
    title: "What to avoid",
    body: [
      "Do not publish exploit details, publicly disclose unpatched vulnerabilities, or access data that does not belong to you.",
      "Do not send large-scale denial-of-service traffic, automated abuse against the site, or destructive payloads against the production service.",
    ],
  },
  {
    title: "Current scope",
    body: [
      "The current public web surface is the CmdTab marketing site, privacy page, security page, and the hosted trial / purchase links exposed from the site.",
      "The native macOS app should also be reported through the same security contact if you identify a security-sensitive issue.",
    ],
  },
];

export default function SecurityPage() {
  return (
    <main>
      <JsonLd
        data={createBreadcrumbStructuredData([
          { name: "Home", path: "/" },
          { name: "Security", path: "/security" },
        ])}
      />
      <SectionShell
        headingAs="h1"
        eyebrow="Security"
        title="CmdTab security disclosure"
        description="Use this page to privately report security issues affecting the CmdTab website, purchase flow, trial delivery, or app."
        className="pt-24"
      >
        <div className="space-y-10">
          {disclosureSections.map((section) => (
            <section key={section.title} className="border-t border-white/8 pt-6">
              <h2 className="text-2xl font-medium tracking-[-0.03em] text-text">
                {section.title}
              </h2>
              <div className="mt-4 space-y-4">
                {section.body.map((paragraph) => (
                  <p key={paragraph} className="max-w-3xl text-base leading-8 text-muted">
                    {paragraph}
                  </p>
                ))}
              </div>
            </section>
          ))}

          <div className="flex flex-col gap-3 border-t border-white/8 pt-8 sm:flex-row">
            <Button href="mailto:tohsh17@gmail.com">Contact tohsh17@gmail.com</Button>
            <Button href="/privacy" variant="secondary">
              Read the privacy policy
            </Button>
          </div>
        </div>
      </SectionShell>
    </main>
  );
}
